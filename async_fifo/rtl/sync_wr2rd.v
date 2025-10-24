/***************************************************************************
*
* Module:       sync_wr2rd
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description: 
*   Two-stage synchronizer used to safely transfer the Gray-coded 
*   write pointer from the write clock domain into the read clock domain. 
*   Minimizes metastability and ensures reliable FIFO operation.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module sync_wr2rd #(
    parameter ADDR_WIDTH = 4               	// Number of address bits
)(
    input  rd_clk,                        	// Read clock domain
    input  rst_n,                         	// Active-low reset
    input  [ADDR_WIDTH:0] wr_ptr_gray,     	// Write pointer (Gray-coded)
    output reg [ADDR_WIDTH:0] wr_ptr_gray_sync 	// Synchronized write pointer
);

    // ---------------------------------------------------------
    // Two-stage synchronizer (rd_clk domain)
    // ---------------------------------------------------------
    reg [ADDR_WIDTH:0] wr_ptr_gray_ff;  // First stage

    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr_gray_ff   <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray_sync <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            wr_ptr_gray_ff   <= wr_ptr_gray;     // Capture
            wr_ptr_gray_sync <= wr_ptr_gray_ff;  // Stabilize
        end
    end

endmodule
