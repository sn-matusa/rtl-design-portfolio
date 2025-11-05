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
    output reg [1:0]                bresp,      // Write response to master
    output reg                      bvalid,     // Write response valid to master
    input                           bready,     // Master ready to accept write response
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Read Address Channel
    // ------------------------------------------------------------------------
    input [ADDR_WIDTH-1:0]          araddr,     // Read address from master
    input                           arvalid,    // Address valid handshake from master
    output reg                      arready,    // Slave ready to accept read address
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Read Data Channel
    // ------------------------------------------------------------------------
    output reg [DATA_WIDTH-1:0]     rdata,      // Read data to master
    output reg [1:0]                rresp,      // Read response to master
    output reg                      rvalid,     // Read data valid to master
    input                           rready,     // Master ready to accept read data
    
    // ------------------------------------------------------------------------
    // User-side register interface (internal memory bus)
    // ------------------------------------------------------------------------
    output reg [ADDR_WIDTH-1:0]     user_wr_addr,   // Latched write address
    output reg [DATA_WIDTH-1:0]     user_wr_data,   // Latched write data
    output reg [DATA_WIDTH/8-1:0]   user_wr_strb,   // Byte strobes for partial write
    output reg                      user_wr_en,     // 1-cycle write strobe
    input [1:0]                     user_wr_resp,   // Write response from user
    
    output reg [ADDR_WIDTH-1:0]     user_rd_addr,   // Latched read address
    output reg                      user_rd_en,     // 1-cycle read strobe
    input [DATA_WIDTH-1:0]          user_rd_data,   // Read data from user
    input [1:0]                     user_rd_resp    // Read response from user
);

    // =========================================================================
    // Write FSM
    // Supports out-of-order arrival of AW & W
    // =========================================================================
    localparam W_IDLE = 2'b00;   // Waiting for AW and/or W
    localparam W_ADDR = 2'b01;   // W accepted first, waiting for AW
    localparam W_DATA = 2'b10;   // AW accepted first, waiting for W
    localparam W_RESP = 2'b11;   // Send BRESP
    
    reg [1:0] w_state;
    reg [1:0] w_state_next;
    
    // =========================================================================
    // Read FSM
    // =========================================================================
    localparam R_IDLE = 2'b00;   // Waiting for ARVALID
    localparam R_DATA = 2'b10;   // Returning RDATA
    
    reg [1:0] r_state;
    reg [1:0] r_state_next;

    reg [1:0] user_rd_resp_int;  // Registered user read response

    // =========================================================================
    // Write FSM State Register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            w_state <= W_IDLE;
        else
            w_state <= w_state_next;
    end
    
    // =========================================================================
    // Write FSM Next-State Logic
    // =========================================================================
    always @(*) begin
        w_state_next = w_state;

        case (w_state)
            W_IDLE: begin
                // Handle all AW/W arrival permutations
                if (awvalid && wvalid)
                    w_state_next = W_RESP;
                else if (awvalid)
                    w_state_next = W_DATA;
                else if (wvalid)
                    w_state_next = W_ADDR;
            end
            
            W_ADDR: begin
                // Waiting for AW handshake
                if (awvalid)
                    w_state_next = W_RESP;
            end
            
            W_DATA: begin
                // Waiting for W handshake
                if (wvalid)
                    w_state_next = W_RESP;
            end
            
            W_RESP: begin
                // Wait until master accepts response
                if (bready)
                    w_state_next = W_IDLE;
            end
            
            default: w_state_next = W_IDLE;
        endcase
    end
    
    // =========================================================================
    // Write FSM Output Logic
    // Drives awready, wready, bvalid, bresp
    // =========================================================================
    always @(*) begin
        // Default inactive
        awready = 1'b0;
        wready  = 1'b0;
        bvalid  = 1'b0;
        bresp   = user_wr_resp;  // Forward user response (OKAY/SLVERR)
        
        case (w_state)
            W_IDLE: begin
                // Accept both or either
                if (awvalid && wvalid) begin
                    awready = 1'b1;
                    wready  = 1'b1;
                end else if (awvalid) begin
                    awready = 1'b1;
                end else if (wvalid) begin
                    wready  = 1'b1;
                end
            end
            
            W_ADDR: begin
                if (awvalid)
                    awready = 1'b1;
            end
            
            W_DATA: begin
                if (wvalid)
                    wready = 1'b1;
            end
            
            W_RESP: begin
                // Drive BRESP to master
                bvalid = 1'b1;
                bresp  = user_wr_resp;
            end
            
            default: begin
                awready = 1'b0;
                wready  = 1'b0;
                bvalid  = 1'b0;
                bresp   = 2'b10;
            end
        endcase
    end
    
    // =========================================================================
    // Capture AWADDR / WDATA when handshakes occur
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            user_wr_addr <= {ADDR_WIDTH{1'b0}};
            user_wr_data <= {DATA_WIDTH{1'b0}};
            user_wr_strb <= {(DATA_WIDTH/8){1'b0}};
        end else begin
            if (awvalid && awready)
                user_wr_addr <= awaddr; // Latch write address
            
            if (wvalid && wready) begin
                user_wr_data <= wdata;  // Latch write data
                user_wr_strb <= wstrb;  // Capture byte enables
            end
        end
    end
    
    // =========================================================================
    // Generate 1-cycle write strobe when both AW & W are received
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_wr_en <= 1'b0;
        else
            user_wr_en <= ((w_state == W_IDLE && awvalid && wvalid) ||
                           (w_state == W_ADDR && awvalid) ||
                           (w_state == W_DATA && wvalid));
    end
    
    // =========================================================================
    // READ FSM State Register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            r_state <= R_IDLE;
        else
            r_state <= r_state_next;
    end
    
    // =========================================================================
    // READ FSM Next-State Logic
    // =========================================================================
    always @(*) begin
        r_state_next = r_state;
        
        case (r_state)
            R_IDLE: begin
                if (arvalid)
                    r_state_next = R_DATA;
            end
            
            R_DATA: begin
                // Return to idle only when master accepts RVALID
                if (rready && rvalid)
                    r_state_next = R_IDLE;
            end
            
            default: r_state_next = R_IDLE;
        endcase
    end
    
    // =========================================================================
    // READ FSM Output Logic
    // Drives ARREADY, RVALID, RRESP
    // =========================================================================
    always @(*) begin
        case (r_state)
            R_IDLE: begin
                arready = 1'b1;   // Ready to accept address
                rvalid  = 1'b0;   // No data yet
                rresp   = 2'b10;  // Default response
            end
            
            R_DATA: begin
                arready = 1'b0;   // Address phase done
                
                // Only assert RVALID if user logic posted a valid response
                if (user_rd_resp_int == 2'b00) begin
                    rvalid = 1'b1;
                    rresp  = user_rd_resp_int;
                end else begin
                    rvalid = 1'b0; // Waiting for valid data
                    rresp  = 2'b10;
                end
            end
            
            default: begin
                arready = 1'b0;
                rvalid  = 1'b0;
                rresp   = 2'b10;
            end
        endcase
    end
    
    // =========================================================================
    // Capture read address when AR handshake occurs
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_addr <= {ADDR_WIDTH{1'b0}};
        else if (arvalid && arready)
            user_rd_addr <= araddr;
    end
    
    // =========================================================================
    // Generate 1-cycle read enable pulse
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_en <= 1'b0;
        else
            user_rd_en <= (arvalid && arready);
    end
    
    // =========================================================================
    // Capture read data from user logic every cycle
    // (User design must present valid data in time)
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            rdata <= {DATA_WIDTH{1'b0}};
        else 
            rdata <= user_rd_data; // Direct register-stage into AXI output flop
    end

    // =========================================================================
    // Register read response from user logic
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_resp_int <= 2'b10;
        else
            user_rd_resp_int <= user_rd_resp; // Move into internal flop
    end

endmodule
