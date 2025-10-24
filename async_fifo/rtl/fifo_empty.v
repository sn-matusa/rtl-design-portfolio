/***************************************************************************
*
* Module:       fifo_empty
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Detects the EMPTY condition of the asynchronous FIFO.
*   Asserts when the Gray-coded read pointer equals the synchronized
*   write pointer, indicating no unread data remains in the buffer.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module fifo_empty #(
    parameter ADDR_WIDTH = 4               	// Number of address bits
)(
    input  rd_clk,                         	// Read clock domain
    input  rst_n,                          	// Active-low reset
    input  [ADDR_WIDTH:0] rd_ptr_gray,     	// Read pointer (Gray-coded)
    input  [ADDR_WIDTH:0] wr_ptr_gray_sync,	// Synchronized write pointer
    output reg rd_empty                    	// Registered empty flag
);

    // ---------------------------------------------------------
    // FIFO is empty when read and write pointers are equal
    // (comparison in Gray code is safe for async domains)
    // ---------------------------------------------------------
    wire empty_cond = (rd_ptr_gray == wr_ptr_gray_sync);

    // ---------------------------------------------------------
    // Registered empty flag
    // ---------------------------------------------------------
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n)
            rd_empty <= 1'b1;  // FIFO starts empty
        else
            rd_empty <= empty_cond;
    end

endmodule
