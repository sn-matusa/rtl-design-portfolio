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
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_state <= WR_IDLE;       // Reset to idle
        else
            wr_state <= wr_state_next; // Move to next state each clock
    end
    
    // =========================================================================
    // WRITE FSM - next-state logic
    // =========================================================================
    always @(*) begin
        wr_state_next = wr_state;      // Hold state by default
        
        case (wr_state)
            WR_IDLE: begin
                // Begin write when user asserts wr_req
                if (wr_req)
                    wr_state_next = WR_BOTH; // Attempt to send addr+data together
            end
            
            WR_BOTH: begin
                // Try to send both address and data in same cycle
                if (awready && wready)
                    wr_state_next = WR_RESP; // Both handshakes done
                else if (awready)
                    wr_state_next = WR_DATA; // Address accepted first
                else if (wready)
                    wr_state_next = WR_ADDR; // Data accepted first
            end
            
            WR_ADDR: begin
                // Continuing until address is accepted
                if (awready)
                    wr_state_next = WR_RESP;
            end
            
            WR_DATA: begin
                // Continuing until data is accepted
                if (wready)
                    wr_state_next = WR_RESP;
            end
            
            WR_RESP: begin
                // Wait for write response from slave
                if (bvalid)
                    wr_state_next = WR_IDLE; // Transaction complete
            end
            
            default: wr_state_next = WR_IDLE;
        endcase
    end
    
    // =========================================================================
    // WRITE FSM - output logic (combinational)
    // =========================================================================
    always @(*) begin
        // Default outputs (deassert everything)
        awvalid = 1'b0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        
        case (wr_state)
            WR_BOTH: begin
                awvalid = 1'b1;        // Assert both in parallel
                wvalid  = 1'b1;
            end
            
            WR_ADDR: begin
                awvalid = 1'b1;        // Retry address phase only
            end
            
            WR_DATA: begin
                wvalid  = 1'b1;        // Retry data phase only
            end
            
            WR_RESP: begin
                bready  = 1'b1;        // Accept slave response
            end
            
            default: begin
                awvalid = 1'b0;
                wvalid  = 1'b0;
                bready  = 1'b0;
            end
        endcase
    end

    // =========================================================================
    // WRITE done pulse
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_done <= 1'b0;
        else
            wr_done <= (bvalid && bready);  // Pulse when response completes
    end
    
    // =========================================================================
    // Latch write request parameters when transaction starts
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awaddr <= {ADDR_WIDTH{1'b0}};
            wdata  <= {DATA_WIDTH{1'b0}};
            wstrb  <= {(DATA_WIDTH/8){1'b0}};
        end else if (wr_req && wr_state == WR_IDLE) begin
            awaddr <= wr_addr;   // Capture user address
            wdata  <= wr_data;   // Capture user data
            wstrb  <= wr_strb;   // Capture byte strobes
        end
    end
    
    // =========================================================================
    // Capture BRESP at handshake
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            wr_resp <= 2'b00;
        else if (bvalid && bready)
            wr_resp <= bresp;    // Store response code (OKAY/SLVERR)
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
                if (rd_req)
                    rd_state_next = RD_ADDR; // Start read transaction
            end
            
            RD_ADDR: begin
                if (arready)
                    rd_state_next = RD_DATA; // Address accepted
            end
            
            RD_DATA: begin
                if (rvalid)
                    rd_state_next = RD_IDLE; // Read completed
            end
            
            default: rd_state_next = RD_IDLE;
        endcase
    end
    
    // =========================================================================
    // READ FSM - output logic (combinational)
    // =========================================================================
    always @(*) begin
        case (rd_state)
	    RD_IDLE: begin
		 // Default outputs inactive
       		 arvalid = 1'b0;
       		 rready  = 1'b0;
	    end

            RD_ADDR: begin
                arvalid = 1'b1;  // Issue read address
		rready  = 1'b1;  // Accept read data ASAP (pipeline-friendly)
            end
            
            RD_DATA: begin
		arvalid = 1'b0;  // Address phase done
		rready  = 1'b1;  // Keep ready to complete handshake
            end
            
            default: begin
                arvalid = 1'b0;
                rready  = 1'b0;
            end
        endcase
    end
    
    // =========================================================================
    // READ done pulse (delay 1 cycle to ensure rd_data stable)
    // =========================================================================
	reg r_done_d;

	always @(posedge aclk or negedge aresetn) begin
	    if (!aresetn) begin
	        rd_done <= 1'b0;
	        r_done_d <= 1'b0;
	    end else begin
	        r_done_d <= (rvalid && rready);
	        rd_done  <= r_done_d; // Guarantees read data already latched
	    end
	end
    
    // =========================================================================
    // Latch read address at start of transaction
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            araddr <= {ADDR_WIDTH{1'b0}};
        else if (rd_req && rd_state == RD_IDLE)
            araddr <= rd_addr;
    end
    
    // =========================================================================
    // Capture RDATA and RRESP at handshake
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_data <= {DATA_WIDTH{1'b0}};
            rd_resp <= 2'b00;
        end else if (rvalid && rready) begin
            rd_data <= rdata;  // Capture read data
            rd_resp <= rresp;  // Capture response code
        end
    end

endmodule
