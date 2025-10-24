/***************************************************************************
*
* Module:       async_fifo_top
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Top-level module for the asynchronous FIFO architecture.
*   Integrates write and read pointer handlers, dual-clock memory,
*   synchronizers, and full/empty detection logic.
*   Ensures safe data transfer between two asynchronous clock domains.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module async_fifo_top #(
    parameter DATA_WIDTH = 8, 		// Width of data bus
    parameter ADDR_WIDTH = 4    	// Address width
)(
    input wr_clk,               	// Write clock domain
    input rd_clk,              	 	// Read clock domain
    input rst_n,               	 	// Global active-low asynchronous reset
    input wrreq,                	// External write request
    input rdreq,                	// External read request
    input  [DATA_WIDTH-1:0] data_in,  	// Data input
    output [DATA_WIDTH-1:0] data_out, 	// Data output
    output wr_full,             	// FIFO full flag
    output rd_empty             	// FIFO empty flag
);

    // =========================================================
    // Internal signals
    // =========================================================
    wire [ADDR_WIDTH:0] wr_ptr_gray, wr_ptr_gray_next;
    wire [ADDR_WIDTH:0] rd_ptr_gray, rd_ptr_gray_sync;
    wire [ADDR_WIDTH:0] wr_ptr_gray_sync;
    wire [ADDR_WIDTH-1:0] wr_addr, rd_addr;
    wire [ADDR_WIDTH:0] wr_ptr_bin, rd_ptr_bin;
    wire wr_en, rd_en;
    wire wr_rst_n, rd_rst_n;

    // =========================================================
    // Domain-specific synchronized reset signals
    // Each clock domain gets its own synchronized version of rst_n
    // =========================================================
    reset_sync wr_rst_sync (
        .clk(wr_clk),
        .rst_n_in(rst_n),
        .rst_n_out(wr_rst_n)
    );

    reset_sync rd_rst_sync (
        .clk(rd_clk),
        .rst_n_in(rst_n),
        .rst_n_out(rd_rst_n)
    );

    // =========================================================
    // Enable control logic
    // Write is enabled only if FIFO is not full
    // Read  is enabled only if FIFO is not empty
    // =========================================================
    assign wr_en = wrreq & ~wr_full;
    assign rd_en = rdreq & ~rd_empty;

    // =========================================================
    // Write pointer handler
    // Generates binary and Gray-coded write pointers
    // =========================================================
    wr_ptr_handler #(.ADDR_WIDTH(ADDR_WIDTH)) WRPTR (
        .wr_clk(wr_clk),
        .rst_n(wr_rst_n),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_ptr_bin(wr_ptr_bin),
        .wr_ptr_gray(wr_ptr_gray),
        .wr_ptr_gray_next(wr_ptr_gray_next)
    );

    // =========================================================
    // Read pointer handler
    // Generates binary and Gray-coded read pointers
    // =========================================================
    rd_ptr_handler #(.ADDR_WIDTH(ADDR_WIDTH)) RDPTR (
        .rd_clk(rd_clk),
        .rst_n(rd_rst_n),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_ptr_bin(rd_ptr_bin),
        .rd_ptr_gray(rd_ptr_gray)
    );

    // =========================================================
    // Pointer synchronization across clock domains
    // Write pointer is synchronized into the read domain
    // Read pointer is synchronized into the write domain
    // =========================================================
    sync_wr2rd #(.ADDR_WIDTH(ADDR_WIDTH)) WR2RD (
        .rd_clk(rd_clk),
        .rst_n(rd_rst_n),
        .wr_ptr_gray(wr_ptr_gray),
        .wr_ptr_gray_sync(wr_ptr_gray_sync)
    );

    sync_rd2wr #(.ADDR_WIDTH(ADDR_WIDTH)) RD2WR (
        .wr_clk(wr_clk),
        .rst_n(wr_rst_n),
        .rd_ptr_gray(rd_ptr_gray),
        .rd_ptr_gray_sync(rd_ptr_gray_sync)
    );

    // =========================================================
    // Full condition detection
    // Performed in the write clock domain
    // Uses next write pointer and synchronized read pointer
    // =========================================================
    fifo_full #(.ADDR_WIDTH(ADDR_WIDTH)) FULL (
        .wr_clk(wr_clk),
        .rst_n(wr_rst_n),
        .wr_ptr_gray_next(wr_ptr_gray_next),
        .rd_ptr_gray_sync(rd_ptr_gray_sync),
        .wr_full(wr_full)
    );

    // =========================================================
    // Empty condition detection
    // Performed in the read clock domain
    // Uses current read pointer and synchronized write pointer
    // =========================================================
    fifo_empty #(.ADDR_WIDTH(ADDR_WIDTH)) EMPTY (
        .rd_clk(rd_clk),
        .rst_n(rd_rst_n),
        .rd_ptr_gray(rd_ptr_gray),
        .wr_ptr_gray_sync(wr_ptr_gray_sync),
        .rd_empty(rd_empty)
    );

    // =========================================================
    // Dual-port FIFO memory
    // Write and read operations occur on independent clocks
    // =========================================================
    fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) MEM (
        .wr_data(data_in),
        .rd_data(data_out),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr),
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .wr_en(wr_en),
        .rd_en(rd_en)
    );

endmodule
