/***************************************************************************
*
* Module:       rd_ptr_handler
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Generates and updates the binary and Gray-coded read pointers
*   for the asynchronous FIFO. Provides the current read address
*   for memory access and the Gray-coded value for synchronization.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module rd_ptr_handler #(
    parameter ADDR_WIDTH = 4              // Number of address bits
)(
    input  rd_clk,                        // Read clock domain
    input  rst_n,                         // Active-low reset (synchronized externally)
    input  rd_en,                         // Read enable 

    output [ADDR_WIDTH-1:0] rd_addr,      // Current read address (to FIFO memory)
    output reg [ADDR_WIDTH:0] rd_ptr_bin, // Binary read pointer (includes extra MSB)
    output [ADDR_WIDTH:0] rd_ptr_gray     // Gray-coded read pointer (for synchronization)
);

    // =========================================================
    // Next binary read pointer
    // Increment occurs only when rd_en = 1.
    // =========================================================
    wire [ADDR_WIDTH:0] rd_ptr_bin_next = rd_ptr_bin + rd_en;

    // =========================================================
    // Binary-to-Gray code conversion
    // Used for safe synchronization across clock domains.
    // =========================================================
    assign rd_ptr_gray = rd_ptr_bin ^ (rd_ptr_bin >> 1);

    // =========================================================
    // Current read address (lower bits of binary pointer)
    // Used to access the FIFO memory array.
    // =========================================================
    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

    // =========================================================
    // Sequential update of binary read pointer
    // On reset: pointer is cleared to zero.
    // On read enable: pointer increments by 1.
    // =========================================================
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else
            rd_ptr_bin <= rd_ptr_bin_next;
    end

endmodule
