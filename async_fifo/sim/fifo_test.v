/***************************************************************************
*
* Module:       fifo_test
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Top-level test structure connecting the asynchronous FIFO (DUT)
*   and the testbench generator module. This wrapper interconnects
*   the stimulus and the DUT signals for simulation purposes.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module fifo_test;

    // ---------------------------------------------------------
    // Common interconnect signals between DUT and testbench
    // ---------------------------------------------------------
    wire         wr_clk, rd_clk, rst_n;
    wire         wrreq, rdreq;
    wire [7:0]   data_in;
    wire [7:0]   data_out;
    wire         wr_full, rd_empty;

    // ---------------------------------------------------------
    // Device Under Test (Asynchronous FIFO)
    // ---------------------------------------------------------
    async_fifo_top #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) DUT (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),
        .wrreq(wrreq),
        .rdreq(rdreq),
        .data_in(data_in),
        .data_out(data_out),
        .wr_full(wr_full),
        .rd_empty(rd_empty)
    );

    // ---------------------------------------------------------
    // Testbench stimulus and checker
    // ---------------------------------------------------------
    fifo_tb TB (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),
        .wrreq(wrreq),
        .rdreq(rdreq),
        .data_in(data_in),
        .data_out(data_out),
        .wr_full(wr_full),
        .rd_empty(rd_empty)
    );

endmodule
