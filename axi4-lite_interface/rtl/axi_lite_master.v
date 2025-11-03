/******************************************************************************
*
* Module:       axi_lite_master
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   AXI-Lite master interface module.
*   Generates valid AXI-Lite read and write transactions based on simple
*   user control signals (wr_req / rd_req).
*
*   Implements Mealy-style FSMs for both READ and WRITE channels:
*     - Address phase
*     - Data phase
*     - Response handling
*
*   Supports single outstanding transaction per channel (AXI-Lite spec).
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
******************************************************************************/

module axi_lite_master #(
    parameter ADDR_WIDTH = 32,   // AXI address bus width
    parameter DATA_WIDTH = 32    // AXI data bus width (must be multiple of 8)
)(
    input                           aclk,       // Global AXI clock
    input                           aresetn,    // Asynchronous active-low reset
    
    // ------------------------------------------------------------------------
    // User interface (WRITE)
    // ------------------------------------------------------------------------
    input                           wr_req,     // User request to start a write transaction
    input [ADDR_WIDTH-1:0]          wr_addr,    // Write address from user
    input [DATA_WIDTH-1:0]          wr_data,    // Write data from user
    input [DATA_WIDTH/8-1:0]        wr_strb,    // Byte enables for write
    output reg                      wr_done,    // Write transaction completed (1-cycle pulse)
    output reg [1:0]                wr_resp,    // Write response captured from AXI
    
    // ------------------------------------------------------------------------
    // User interface (READ)
    // ------------------------------------------------------------------------
    input                           rd_req,     // User request to start a read transaction
    input [ADDR_WIDTH-1:0]          rd_addr,    // Read address from user
    output reg [DATA_WIDTH-1:0]     rd_data,    // Read data captured from AXI
    output reg                      rd_done,    // Read transaction completed (1-cycle pulse)
    output reg [1:0]                rd_resp,    // Read response captured from AXI
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Write Address Channel
    // ------------------------------------------------------------------------
    input                           awready, 	// Slave ready to accept address
    output reg [ADDR_WIDTH-1:0]     awaddr,	    // Write address driven by master
    output reg                      awvalid,	// Address valid handshake from master
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Write Data Channel
    // ------------------------------------------------------------------------
    input                           wready,	    // Slave ready to accept write data
    output reg [DATA_WIDTH-1:0]     wdata,	    // Write data driven by master
    output reg [DATA_WIDTH/8-1:0]   wstrb,	    // Byte strobes for write data
    output reg                      wvalid,	    // Write data valid handshake from master 
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Write Response Channel
    // ------------------------------------------------------------------------
    input [1:0]                     bresp,	    // Write response from slave
    input                           bvalid,	    // Write response valid from slave
    output reg                      bready,	    // Master ready to accept write response
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Read Address Channel
    // ------------------------------------------------------------------------
    input                           arready, 	// Slave ready to accept read address
    output reg [ADDR_WIDTH-1:0]     araddr,	    // Read address driven by master
    output reg                      arvalid,	// Address valid handshake from master
    
    // ------------------------------------------------------------------------
    // AXI4-Lite Read Data Channel
    // ------------------------------------------------------------------------
    input [DATA_WIDTH-1:0]          rdata,	    // Read data from slave
    input [1:0]                     rresp,	    // Read response from slave
    input                           rvalid,	    // Read data valid from slave
    output reg                      rready	    // Master ready to accept read data
);
    
    // =========================================================================
    // Write FSM states (Mealy)
    // =========================================================================
    localparam WR_IDLE = 3'b000;  // Idle, waiting for wr_req
    localparam WR_ADDR = 3'b001;  // Sending only address (AWVALID)
    localparam WR_DATA = 3'b010;  // Sending only data (WVALID)
    localparam WR_BOTH = 3'b011;  // Sending both address and data simultaneously
    localparam WR_RESP = 3'b100;  // Waiting for write response (BVALID)
    
    reg [2:0] wr_state;           // Current write state
    reg [2:0] wr_state_next;      // Next write state (combinational)
    
    // =========================================================================
    // Read FSM states (Mealy)
    // =========================================================================
    localparam RD_IDLE = 2'b00;   // Idle, waiting for rd_req
    localparam RD_ADDR = 2'b01;   // Sending read address (ARVALID)
    localparam RD_DATA = 2'b10;   // Waiting for read data (RVALID)
    
    reg [1:0] rd_state;           // Current read state
    reg [1:0] rd_state_next;      // Next read state (combinational)
    
    // =========================================================================
    // WRITE FSM - state register
    // ============================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_state <= WR_IDLE;       // Return to idle on reset
        else
            wr_state <= wr_state_next; // Move to next write state
    end
    
    // =========================================================================
    // WRITE FSM - next-state logic
    // Controls AWVALID/WVALID sequencing per AXI-Lite rules
    // =========================================================================
    always @(*) begin
        wr_state_next = wr_state;      // Default: remain in current state
        
        case (wr_state)
            WR_IDLE: begin
                // Start write when user asserts wr_req
                if (wr_req)
                    wr_state_next = WR_BOTH;   // Issue address + data together initially
            end
            
            WR_BOTH: begin
                // Drive both AW and W; transitions depend on handshake timing
                if (awready && wready)
                    wr_state_next = WR_RESP;   // Both accepted ? wait response
                else if (awready)
                    wr_state_next = WR_DATA;   // Only address accepted so far
                else if (wready)
                    wr_state_next = WR_ADDR;   // Only data accepted so far
            end
            
            WR_ADDR: begin
                // Continue sending address until slave accepts it
                if (awready)
                    wr_state_next = WR_RESP;   // All write info delivered
            end
            
            WR_DATA: begin
                // Continue sending data until slave accepts it
                if (wready)
                    wr_state_next = WR_RESP;   // All write info delivered
            end
            
            WR_RESP: begin
                // Wait until write response arrives from slave
                if (bvalid)
                    wr_state_next = WR_IDLE;   // Write completed
            end
        endcase
    end
    
    // =========================================================================
    // Write channel control signals
    // Drive handshakes based on FSM state
    // =========================================================================
    always @(*) begin
        awvalid = 1'b0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        
        case (wr_state)
            WR_BOTH: begin
                awvalid = 1'b1; // Present address
                wvalid  = 1'b1; // Present data
            end
            
            WR_ADDR: begin
                awvalid = 1'b1; // Continue asserting AWVALID
            end
            
            WR_DATA: begin
                wvalid  = 1'b1; // Continue asserting WVALID
            end
            
            WR_RESP: begin
                bready  = 1'b1; // Accept BRESP when valid
            end
        endcase
    end

    // =========================================================================
    // WRITE done pulse ? 1 cycle handshake pulse after BRESP
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_done <= 1'b0;
        else
            wr_done <= (bvalid && bready);  // Single-cycle completion strobe
    end
    
    // =========================================================================
    // Latch write address/data/strobes when transaction begins
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awaddr <= {ADDR_WIDTH{1'b0}};
            wdata  <= {DATA_WIDTH{1'b0}};
            wstrb  <= {(DATA_WIDTH/8){1'b0}};
        end else if (wr_req && wr_state == WR_IDLE) begin
            awaddr <= wr_addr;  // Capture write address
            wdata  <= wr_data;  // Capture write payload
            wstrb  <= wr_strb;  // Capture byte enables
        end
    end
    
    // =========================================================================
    // Latch BRESP from slave
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_resp <= 2'b00;
        else if (bvalid && bready)
            wr_resp <= bresp;   // Store write response
    end
    
    // =========================================================================
    // READ FSM - state register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            rd_state <= RD_IDLE;
        else
            rd_state <= rd_state_next;
    end
    
    // =========================================================================
    // READ FSM - next-state logic
    // =========================================================================
    always @(*) begin
        rd_state_next = rd_state;

        case (rd_state)
            RD_IDLE: begin
                // User requests read
                if (rd_req)
                    rd_state_next = RD_ADDR;    // Send address
            end
            
            RD_ADDR: begin
                // Wait for slave to accept AR
                if (arready)
                    rd_state_next = RD_DATA;    // Expect data next
            end
            
            RD_DATA: begin
                // Wait for valid read data
                if (rvalid)
                    rd_state_next = RD_IDLE;    // Read complete
            end
        endcase
    end
    
    // =========================================================================
    // Read channel handshake control
    // =========================================================================
    always @(*) begin
        // Safe defaults
        arvalid = 1'b0;
        rready  = 1'b0;

        case (rd_state)
            RD_IDLE: begin
                // keep defaults (no address, not ready)
            end

            RD_ADDR: begin
                arvalid = 1'b1; // Assert ARVALID until ARREADY
                rready  = 1'b1; // Pre-assert RREADY to catch data ASAP
            end
            
            RD_DATA: begin
                arvalid = 1'b0; // Address already issued
                rready  = 1'b1; // Keep ready high until RVALID arrives
            end
        endcase
    end
    
    // =========================================================================
    // Read done pulse ? delayed to ensure rd_data is already captured
    // =========================================================================
    reg r_done_d;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_done  <= 1'b0;
            r_done_d <= 1'b0;
        end else begin
            r_done_d <= (rvalid && rready); // Detect handshake
            rd_done  <= r_done_d;           // Delay 1 cycle for data stability
        end
    end
    
    // =========================================================================
    // Capture read address on transaction start
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            araddr <= {ADDR_WIDTH{1'b0}};
        else if (rd_req && rd_state == RD_IDLE)
            araddr <= rd_addr; // Latch address at read request
    end
    
    // =========================================================================
    // Capture read data/response when handshake completes
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_data <= {DATA_WIDTH{1'b0}};
            rd_resp <= 2'b00;
        end else if (rvalid && rready) begin
            rd_data <= rdata;   // Capture read data
            rd_resp <= rresp;   // Capture read response
        end
    end

endmodule
