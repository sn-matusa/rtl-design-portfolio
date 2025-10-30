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
    // User Interface - Memory/Register Access
    // Full byte-aligned address passed to user logic for decoding
    // ------------------------------------------------------------------------
    output reg [ADDR_WIDTH-1:0]     user_wr_addr,   // Write address to user logic
    output reg [DATA_WIDTH-1:0]     user_wr_data,   // Write data to user logic
    output reg [DATA_WIDTH/8-1:0]   user_wr_strb,   // Write byte strobes to user logic
    output reg                      user_wr_en,     // Write enable pulse (1-cycle)
    input [1:0]                     user_wr_resp,   // Write response from user logic
    
    output reg [ADDR_WIDTH-1:0]     user_rd_addr,   // Read address to user logic
    output reg                      user_rd_en,     // Read enable pulse (1-cycle)
    input [DATA_WIDTH-1:0]          user_rd_data,   // Read data from user logic
    input [1:0]                     user_rd_resp    // Read response from user logic
);

    // =========================================================================
    // Write FSM states (Mealy)
    // =========================================================================
    localparam W_IDLE = 2'b00;   // Idle, waiting for AWVALID or WVALID
    localparam W_ADDR = 2'b01;   // Received WVALID first, waiting for AWVALID
    localparam W_DATA = 2'b10;   // Received AWVALID first, waiting for WVALID
    localparam W_RESP = 2'b11;   // Both received, sending write response
    
    reg [1:0] w_state;           // Current write state
    reg [1:0] w_state_next;      // Next write state (combinational)
    
    // =========================================================================
    // Read FSM states (Mealy)
    // =========================================================================
    localparam R_IDLE = 2'b00;   // Idle, waiting for ARVALID
    localparam R_DATA = 2'b10;   // Sending read data response
    
    reg [1:0] r_state;           // Current read state
    reg [1:0] r_state_next;      // Next read state (combinational)
    
    // =========================================================================
    // WRITE FSM - state register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            w_state <= W_IDLE;         // Reset to idle
        else
            w_state <= w_state_next;   // State transition
    end
    
    // =========================================================================
    // WRITE FSM - next-state logic
    // =========================================================================
    always @(*) begin
        w_state_next = w_state;        // Default stay in current state
        
        case (w_state)
            W_IDLE: begin
                // AXI allows address and data to arrive in any order
                if (awvalid && wvalid)
                    w_state_next = W_RESP;      // Both arrived simultaneously
                else if (awvalid)
                    w_state_next = W_DATA;      // Address arrived first, wait for data
                else if (wvalid)
                    w_state_next = W_ADDR;      // Data arrived first, wait for address
            end
            
            W_ADDR: begin
                // Waiting for address (data already received)
                if (awvalid)
                    w_state_next = W_RESP;      // Got address, proceed to response
            end
            
            W_DATA: begin
                // Waiting for data (address already received)
                if (wvalid)
                    w_state_next = W_RESP;      // Got data, proceed to response
            end
            
            W_RESP: begin
                // Waiting for master to accept write response
                if (bready)
                    w_state_next = W_IDLE;      // Response accepted, return to idle
            end
            
            default: w_state_next = W_IDLE;
        endcase
    end
    
    // =========================================================================
    // WRITE FSM - output logic (Mealy - depends on state and inputs)
    // =========================================================================
    always @(*) begin
        // Default outputs inactive
        awready = 1'b0;
        wready  = 1'b0;
        bvalid  = 1'b0;
        bresp   = user_wr_resp;            // Use response from user logic
        
        case (w_state)
            W_IDLE: begin
                // Accept whatever arrives (address, data, or both)
                if (awvalid && wvalid) begin
                    awready = 1'b1;            // Accept address
                    wready  = 1'b1;            // Accept data
                end else if (awvalid) begin
                    awready = 1'b1;            // Accept address only
                end else if (wvalid) begin
                    wready  = 1'b1;            // Accept data only
                end
            end
            
            W_ADDR: begin
                // Waiting for address, ready to accept when it arrives
                if (awvalid)
                    awready = 1'b1;
            end
            
            W_DATA: begin
                // Waiting for data, ready to accept when it arrives
                if (wvalid)
                    wready  = 1'b1;
            end
            
            W_RESP: begin
                // Drive write response back to master
                bvalid  = 1'b1;
                bresp   = user_wr_resp;        // Forward user response
            end
            
            default: begin
                awready = 1'b0;
                wready  = 1'b0;
                bvalid  = 1'b0;
                bresp   = 2'b00;
            end
        endcase
    end
    
    // =========================================================================
    // WRITE address and data capture
    // Latches address, data, and strobes when handshakes occur
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            user_wr_addr <= {ADDR_WIDTH{1'b0}};
            user_wr_data <= {DATA_WIDTH{1'b0}};
            user_wr_strb <= {(DATA_WIDTH/8){1'b0}};
        end else begin
            // Capture address when AWVALID && AWREADY
            if (awvalid && awready)
                user_wr_addr <= awaddr;
            
            // Capture data and strobes when WVALID && WREADY
            if (wvalid && wready) begin
                user_wr_data <= wdata;
                user_wr_strb <= wstrb;
            end
        end
    end
    
    // =========================================================================
    // WRITE enable pulse generation
    // Generate 1-cycle pulse when both address and data have been received
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_wr_en <= 1'b0;
        else
            // Pulse when transitioning to W_RESP state
            user_wr_en <= ((w_state == W_IDLE && awvalid && wvalid) ||
                          (w_state == W_ADDR && awvalid) ||
                          (w_state == W_DATA && wvalid));
    end
    
    // =========================================================================
    // READ FSM - state register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            r_state <= R_IDLE;                 // Reset to idle
        else
            r_state <= r_state_next;           // State transition
    end
    
    // =========================================================================
    // READ FSM - next-state logic
    // =========================================================================
    always @(*) begin
        r_state_next = r_state;                // Default stay in current state
        
        case (r_state)
            R_IDLE: begin
                // Start new read transaction when address arrives
                if (arvalid)
                    r_state_next = R_DATA;     // Proceed to data phase
            end
            
            R_DATA: begin
                // Wait for master to accept read data
                if (rready)
                    r_state_next = R_IDLE;     // Data accepted, return to idle
            end
            
            default: r_state_next = R_IDLE;
        endcase
    end
    
    // =========================================================================
    // READ FSM - output logic (Mealy - depends on state and inputs)
    // =========================================================================
    always @(*) begin
        // Default outputs inactive
        arready = 1'b0;
        rvalid  = 1'b0;
        rresp   = user_rd_resp;                // Use response from user logic
        
        case (r_state)
            R_IDLE: begin
                // Ready to accept read address when it arrives
                if (arvalid)
                    arready = 1'b1;
            end
            
            R_DATA: begin
                // Drive read data and response back to master
                rvalid  = 1'b1;
                rresp   = user_rd_resp;        // Forward user response
            end
            
            default: begin
                arready = 1'b0;
                rvalid  = 1'b0;
                rresp   = 2'b00;
            end
        endcase
    end
    
    // =========================================================================
    // READ address capture
    // Latches address when read address handshake occurs
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_addr <= {ADDR_WIDTH{1'b0}};
        else if (arvalid && arready)
            user_rd_addr <= araddr;            // Latch read address
    end
    
    // =========================================================================
    // READ enable pulse generation
    // Generate 1-cycle pulse when read address is accepted
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_en <= 1'b0;
        else
            user_rd_en <= (arvalid && arready);
    end
    
    // =========================================================================
    // READ data capture from user logic
    // Registers the data from user memory/registers
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            rdata <= {DATA_WIDTH{1'b0}};
        else if (user_rd_en)
            rdata <= user_rd_data;             // Capture data from user logic
    end

endmodule
