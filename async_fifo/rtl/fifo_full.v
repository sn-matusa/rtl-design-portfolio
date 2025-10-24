/***************************************************************************
*
* Module:       fifo_full
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Detects the FULL condition of the asynchronous FIFO.
*   Compares the next Gray-coded write pointer with the synchronized
*   read pointer (with MSBs inverted) to detect wrap-around and
*   prevent write overflow.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module fifo_full #(
    parameter ADDR_WIDTH = 4                // Number of address bits
)(
    input  wr_clk,                          // Write clock domain
    input  rst_n,                           // Active-low reset
    input  [ADDR_WIDTH:0] wr_ptr_gray_next, // Next Gray-coded write pointer
    input  [ADDR_WIDTH:0] rd_ptr_gray_sync, // Read pointer synchronized into write domain
    output reg wr_full                      // Registered full flag
);

    // ---------------------------------------------------------
    // FIFO is full when next write pointer equals the
    // synchronized read pointer with its two MSBs inverted
    // (Gray-code wrap-around detection)
    // ---------------------------------------------------------
    wire full_cond = (wr_ptr_gray_next ==
                      {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1],
                       rd_ptr_gray_sync[ADDR_WIDTH-2:0]});

    // ---------------------------------------------------------
    // Registered FULL flag
    // ---------------------------------------------------------
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n)
            wr_full <= 1'b0;
        else
            wr_full <= full_cond;
    end

endmodule
