/***************************************************************************
*
* Module:       wr_ptr_handler
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Generates and updates the binary and Gray-coded write pointers
*   for the asynchronous FIFO. Also provides the current write address
*   and next Gray-coded value for full detection logic.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module wr_ptr_handler #(
    parameter ADDR_WIDTH = 4              	// Number of address bits 
)(
    input  wr_clk,                        	// Write clock domain
    input  rst_n,                         	// Active-low reset (synchronized externally)
    input  wr_en,                         	// Write enable

    output [ADDR_WIDTH-1:0] wr_addr,      	// Current write address (to FIFO memory)
    output reg [ADDR_WIDTH:0] wr_ptr_bin, 	// Binary write pointer (includes extra MSB)
    output [ADDR_WIDTH:0] wr_ptr_gray,    	// Current Gray-coded write pointer
    output [ADDR_WIDTH:0] wr_ptr_gray_next	// Next Gray-coded write pointer (used for FULL detection)
);

    // =========================================================
    // Next binary write pointer
    // Increment occurs only when wr_en = 1.
    // =========================================================
    wire [ADDR_WIDTH:0] wr_ptr_bin_next = wr_ptr_bin + wr_en;

    // =========================================================
    // Binary-to-Gray code conversion
    // Current and next Gray pointers are both needed:
    // - Current Gray pointer: for synchronization into read domain
    // - Next Gray pointer: for FULL condition detection
    // =========================================================
    assign wr_ptr_gray      = wr_ptr_bin ^ (wr_ptr_bin >> 1);
    assign wr_ptr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    // =========================================================
    // Current write address (lower bits of binary pointer)
    // Used to access the FIFO memory array.
    // =========================================================
    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

    // =========================================================
    // Sequential update of binary write pointer
    // On reset: pointer is cleared to zero.
    // On write enable: pointer increments by 1.
    // =========================================================
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else
            wr_ptr_bin <= wr_ptr_bin_next;
    end

endmodule
