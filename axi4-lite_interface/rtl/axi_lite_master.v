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
    // Write FSM states 
    // =========================================================================
    localparam WR_IDLE = 3'b000;  // Idle, no transaction pending
    localparam WR_ADDR = 3'b001;  // Driving address only
    localparam WR_DATA = 3'b010;  // Driving data only
    localparam WR_BOTH = 3'b011;  // Driving both address and data
    localparam WR_RESP = 3'b100;  // Waiting for BRESP
    
    reg [2:0] wr_state;           // Current write state
    reg [2:0] wr_state_next;      // Next write state (combinational logic)
    
    // =========================================================================
    // Read FSM states 
    // =========================================================================
    localparam RD_IDLE = 2'b00;   // Idle, waiting for user request
    localparam RD_ADDR = 2'b01;   // Address phase (ARVALID active)
    localparam RD_DATA = 2'b10;   // Waiting for RVALID
    
    reg [1:0] rd_state;           // Current read state
    reg [1:0] rd_state_next;      // Next read state (combinational)
    
    // =========================================================================
    // WRITE FSM - sequential state update
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_state <= WR_IDLE;       // Reset to idle on reset
        else
            wr_state <= wr_state_next; // Move to next state
    end
    
    // =========================================================================
    // WRITE FSM - next-state logic
    // =========================================================================
    always @(*) begin
        wr_state_next = wr_state;      // Default stay in same state
        
        case (wr_state)
            WR_IDLE: begin
                // Start write when requested
                if (wr_req)
                    wr_state_next = WR_BOTH;
            end
            
            WR_BOTH: begin
                // Handle possible handshake combinations
                if (awready && wready)
                    wr_state_next = WR_RESP; // Both accepted in same cycle
                else if (awready)
                    wr_state_next = WR_DATA; // Address accepted first
                else if (wready)
                    wr_state_next = WR_ADDR; // Data accepted first
            end
            
            WR_ADDR: begin
                // Waiting for address acceptance
                if (awready)
                    wr_state_next = WR_RESP;
            end
            
            WR_DATA: begin
                // Waiting for data acceptance
                if (wready)
                    wr_state_next = WR_RESP;
            end
            
            WR_RESP: begin
                // Wait for slave to return write response
                if (bvalid)
                    wr_state_next = WR_IDLE;
            end
            
            default: wr_state_next = WR_IDLE; // Defensive default case
        endcase
    end
    
    // =========================================================================
    // WRITE FSM - output logic (Mealy)
    // Drives AWVALID / WVALID / BREADY based on state
    // =========================================================================
    always @(*) begin
        awvalid = 1'b0; // Default: do not drive address
        wvalid  = 1'b0; // Default: do not drive data
        bready  = 1'b0; // Default: not ready for response
        
        case (wr_state)
            WR_BOTH: begin
                awvalid = 1'b1; // Drive both channels
                wvalid  = 1'b1;
            end
            
            WR_ADDR: begin
                awvalid = 1'b1; // Only address phase active
            end
            
            WR_DATA: begin
                wvalid  = 1'b1; // Only data phase active
            end
            
            WR_RESP: begin
                bready  = 1'b1; // Accept BRESP
            end
            
            default: begin
                awvalid = 1'b0;
                wvalid  = 1'b0;
                bready  = 1'b0;
            end
        endcase
    end

    // =========================================================================
    // wr_done generation
    // Pulses high for one cycle when write completes
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_done <= 1'b0;
        else
            wr_done <= (bvalid && bready); // End of write
    end
    
    // =========================================================================
    // Write request capture
    // Capture write data/address only at start of transaction
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awaddr <= {ADDR_WIDTH{1'b0}};
            wdata  <= {DATA_WIDTH{1'b0}};
            wstrb  <= {(DATA_WIDTH/8){1'b0}};
        end else if (wr_req && wr_state == WR_IDLE) begin
            awaddr <= wr_addr; // Store address to drive AW channel
            wdata  <= wr_data; // Store data to drive W channel
            wstrb  <= wr_strb; // Store byte enables
        end
    end
    
    // =========================================================================
    // Write response capture
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_resp <= 2'b10;
        else if (bvalid && bready)
            wr_resp <= bresp; // Save BRESP from slave
    end
    
    // =========================================================================
    // READ FSM - sequential state update
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
                if (rd_req)
                    rd_state_next = RD_ADDR; // Start read
            end
            
            RD_ADDR: begin
                if (arready)
                    rd_state_next = RD_DATA; // Wait for read data
            end
            
            RD_DATA: begin
                if (rvalid)
                    rd_state_next = RD_IDLE; // End read
            end
            
            default: rd_state_next = RD_IDLE; // Safety
        endcase
    end
    
    // =========================================================================
    // READ FSM - output logic
    // =========================================================================
    always @(*) begin
        case (rd_state)
            RD_IDLE: begin
                arvalid = 1'b0; // IDLE: no bus activity
                rready  = 1'b0;
            end

            RD_ADDR: begin
                arvalid = 1'b1; // Drive ARVALID to send address
                rready  = 1'b1; // Ready early for data phase (allowed in AXI-lite)
            end
            
            RD_DATA: begin
                arvalid = 1'b0; // Address phase done
                // rready defaults to 0 unless asserted in RD_ADDR
            end
            
            default: begin
                arvalid = 1'b0;
                rready  = 1'b0;
            end
        endcase
    end
    
    // =========================================================================
    // Read done pulse generation
    // Delayed by 1 cycle to guarantee rd_data stable for user logic
    // =========================================================================
    //reg r_done_d;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_done  <= 1'b0;
           // r_done_d <= 1'b0;
        end else begin
            rd_done <= (rvalid && rready);
           // rd_done  <= r_done_d;
        end
    end
    
    // =========================================================================
    // Latch read address at request time
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            araddr <= {ADDR_WIDTH{1'b0}};
        else if (rd_req && rd_state == RD_IDLE)
            araddr <= rd_addr; // Capture requested address
    end
    
    // =========================================================================
    // Capture RDATA and RRESP from slave when handshake completes
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_data <= {DATA_WIDTH{1'b0}};
            rd_resp <= 2'b10;
        end else if (rvalid && rready) begin
            rd_data <= rdata;  // Store received data
            rd_resp <= rresp;  // Store RRESP code
        end
    end

endmodule
