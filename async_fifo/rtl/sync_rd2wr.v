/***************************************************************************
*
* Module:       sync_rd2wr
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Two-stage synchronizer used to safely transfer the Gray-coded
*   read pointer from the read clock domain into the write clock domain.
*   Reduces metastability and enables correct full detection.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module sync_rd2wr #(
    parameter ADDR_WIDTH = 4                	// Number of address bits
)(
    input  wr_clk,                          	// Write clock domain
    input  rst_n,                           	// Active-low reset
    input  [ADDR_WIDTH:0] rd_ptr_gray,      	// Read pointer (Gray-coded)
    output reg [ADDR_WIDTH:0] rd_ptr_gray_sync 	// Synchronized read pointer
);

    // ---------------------------------------------------------
    // Two-stage synchronizer (wr_clk domain)
    // ---------------------------------------------------------
    reg [ADDR_WIDTH:0] rd_ptr_gray_ff;  // First stage

    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr_gray_ff   <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray_sync <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            rd_ptr_gray_ff   <= rd_ptr_gray;     // Capture
            rd_ptr_gray_sync <= rd_ptr_gray_ff;  // Stabilize
        end
    end

endmodule
