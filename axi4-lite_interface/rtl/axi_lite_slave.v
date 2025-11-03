/******************************************************************************
*
* Module:       axi_lite_slave
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   AXI-Lite slave protocol controller.
*   Accepts AXI-Lite read and write requests and translates them into a
*   simplified local register file bus:
*     - user_wr_addr / user_wr_data / user_wr_en
*     - user_rd_addr / user_rd_en / user_rd_data
*
*   Handles AXI-Lite handshake signals and generates valid response channels
*   according to the specification (OKAY/SLVERR).
*
*   Decodes addresses and provides clean separation between bus protocol logic
*   and local memory/register access logic.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
******************************************************************************/

module axi_lite_slave #(
    parameter ADDR_WIDTH = 32,   // AXI address bus width
    parameter DATA_WIDTH = 32    // AXI data bus width (must be multiple of 8)
)(
    input                           aclk,       // Global AXI clock
    input                           aresetn,    // Asynchronous active-low reset
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Write Address Channel
    // ------------------------------------------------------------------------
    input [ADDR_WIDTH-1:0]          awaddr,     // Write address from master
    input                           awvalid,    // Address valid handshake from master
    output reg                      awready,    // Slave ready to accept address
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Write Data Channel
    // ------------------------------------------------------------------------
    input [DATA_WIDTH-1:0]          wdata,      // Write data from master
    input [DATA_WIDTH/8-1:0]        wstrb,      // Byte strobes for write data
    input                           wvalid,     // Write data valid handshake from master
    output reg                      wready,     // Slave ready to accept write data
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Write Response Channel
    // ------------------------------------------------------------------------
    output reg [1:0]                bresp,      // Write response (OKAY/SLVERR)
    output reg                      bvalid,     // Write response valid
    input                           bready,     // Master accepts response
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Read Address Channel
    // ------------------------------------------------------------------------
    input [ADDR_WIDTH-1:0]          araddr,     // Read address from master
    input                           arvalid,    // Read address valid
    output reg                      arready,    // Slave ready to accept read address
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Read Data Channel
    // ------------------------------------------------------------------------
    output reg [DATA_WIDTH-1:0]     rdata,      // Data returned to master
    output reg [1:0]                rresp,      // Read response (OKAY/SLVERR)
    output reg                      rvalid,     // Read data valid
    input                           rready,     // Master ready to accept read data
    
    // ------------------------------------------------------------------------
    // User register file interface
    // ------------------------------------------------------------------------
    output reg [ADDR_WIDTH-1:0]     user_wr_addr,   // Write address to user logic
    output reg [DATA_WIDTH-1:0]     user_wr_data,   // Write data to user logic
    output reg [DATA_WIDTH/8-1:0]   user_wr_strb,   // Byte strobes
    output reg                      user_wr_en,     // Write enable (1 clk pulse)
    input [1:0]                     user_wr_resp,   // Write response from user
    
    output reg [ADDR_WIDTH-1:0]     user_rd_addr,   // Read address to user logic
    output reg                      user_rd_en,     // Read enable pulse
    input [DATA_WIDTH-1:0]          user_rd_data,   // Read data from user
    input [1:0]                     user_rd_resp    // Read response from user
);

    // =========================================================================
    // Internal enums and state registers
    // =========================================================================
    localparam W_IDLE = 2'b00;   // No write pending
    localparam W_ADDR = 2'b01;   // Got data first, wait address
    localparam W_DATA = 2'b10;   // Got address first, wait data
    localparam W_RESP = 2'b11;   // Both received, issue response

    reg [1:0] w_state, w_state_next;

    localparam R_IDLE = 2'b00;   // Waiting for ARVALID
    localparam R_DATA = 2'b10;   // Returning read data to master

    reg [1:0] r_state, r_state_next;

    // Response registered so it's stable in R_DATA state
    reg [1:0] user_rd_resp_int;

    // =========================================================================
    // WRITE FSM ? State register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            w_state <= W_IDLE;
        else
            w_state <= w_state_next;
    end

    // =========================================================================
    // WRITE FSM ? Next state logic (Mealy)
    // =========================================================================
    always @(*) begin
        w_state_next = w_state;  

        case (w_state)
            W_IDLE: begin
                // Accept address first, data first, or both
                if (awvalid && wvalid)
                    w_state_next = W_RESP;
                else if (awvalid)
                    w_state_next = W_DATA;
                else if (wvalid)
                    w_state_next = W_ADDR;
            end

            W_ADDR: begin
                // Got data first ? wait for address
                if (awvalid)
                    w_state_next = W_RESP;
            end

            W_DATA: begin
                // Got address first ? wait for data
                if (wvalid)
                    w_state_next = W_RESP;
            end

            W_RESP: begin
                // Complete when master accepts BRESP
                if (bready)
                    w_state_next = W_IDLE;
            end
        endcase
    end

    // =========================================================================
    // WRITE FSM ? Output logic
    // =========================================================================
    always @(*) begin
        awready = 0;
        wready  = 0;
        bvalid  = 0;
        bresp   = user_wr_resp; // Pass internal response to AXI

        case (w_state)
            W_IDLE: begin
                // Accept address, data, or both
                if (awvalid) awready = 1;
                if (wvalid)  wready  = 1;
            end

            W_ADDR: if (awvalid) awready = 1;
            W_DATA: if (wvalid)  wready  = 1;

            W_RESP: begin
                bvalid = 1; // Response valid to master
            end
        endcase
    end

    // =========================================================================
    // Capture write address/data on handshake
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            user_wr_addr <= 0;
            user_wr_data <= 0;
            user_wr_strb <= 0;
        end else begin
            if (awvalid && awready)
                user_wr_addr <= awaddr;
            if (wvalid && wready) begin
                user_wr_data <= wdata;
                user_wr_strb <= wstrb;
            end
        end
    end

    // =========================================================================
    // Generate write enable pulse when both address and data were received
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_wr_en <= 0;
        else
            user_wr_en <= (
                  (w_state == W_IDLE && awvalid && wvalid) || 
                  (w_state == W_ADDR && awvalid) ||
                  (w_state == W_DATA && wvalid)
            );
    end

    // =========================================================================
    // READ FSM ? State register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            r_state <= R_IDLE;
        else
            r_state <= r_state_next;
    end

    // =========================================================================
    // READ FSM ? Next state logic
    // =========================================================================
    always @(*) begin
        r_state_next = r_state;

        case (r_state)
            R_IDLE: if (arvalid) r_state_next = R_DATA;
            R_DATA: if (rready && rvalid) r_state_next = R_IDLE;
        endcase
    end

    // =========================================================================
    // READ FSM ? Output logic
    // =========================================================================
    always @(*) begin
        case (r_state)
            R_IDLE: begin
                arready = 1;    // Ready to accept address
                rvalid  = 0;
                rresp   = 2'b00;
            end

            R_DATA: begin
                arready = 0;
                rvalid  = (user_rd_resp_int == 2'b11); // Signal valid data only if user marked ready/OK
                rresp   = user_rd_resp_int;            // Forward response to AXI
            end

            default: begin
                arready = 0;
                rvalid  = 0;
                rresp   = 2'b00;
            end
        endcase
    end

    // =========================================================================
    // Capture read address on AR handshake
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_addr <= 0;
        else if (arvalid && arready)
            user_rd_addr <= araddr;
    end

    // =========================================================================
    // Generate read enable pulse for register file
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_en <= 0;
        else
            user_rd_en <= (arvalid && arready);
    end

    // =========================================================================
    // Capture read data each cycle (simple reg-file model)
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            rdata <= 0;
        else
            rdata <= user_rd_data;
    end

    // =========================================================================
    // Register read response so it's available in R_DATA state
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_resp_int <= 2'b00;
        else
            user_rd_resp_int <= user_rd_resp;
    end

endmodule
