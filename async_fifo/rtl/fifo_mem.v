/***************************************************************************
*
* Module:       fifo_mem
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Dual-port memory array used to store FIFO data.
*   Supports independent read and write operations on separate
*   clock domains (wr_clk and rd_clk) using binary address pointers.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module fifo_mem #(
    parameter DATA_WIDTH = 8,               // Width of each data word
    parameter ADDR_WIDTH = 4,               // Number of address bits
    parameter DEPTH = (1 << ADDR_WIDTH)     // FIFO depth = 2^ADDR_WIDTH
)(
    input  [DATA_WIDTH-1:0] wr_data,        // Write data input
    input  [ADDR_WIDTH-1:0] wr_addr,        // Write address
    input  [ADDR_WIDTH-1:0] rd_addr,        // Read address
    input  wr_clk,                          // Write clock domain
    input  rd_clk,                          // Read clock domain
    input  wr_en,                           // Write enable
    input  rd_en,                           // Read enable
    output reg [DATA_WIDTH-1:0] rd_data     // Registered read data output
);

    // ---------------------------------------------------------
    // Dual-port memory array
    // ---------------------------------------------------------
    reg [DATA_WIDTH-1:0] fifo [0:DEPTH-1];

    // ---------------------------------------------------------
    // Write port (wr_clk domain)
    // ---------------------------------------------------------
    always @(posedge wr_clk) begin
        if (wr_en)
            fifo[wr_addr] <= wr_data;
    end

    // ---------------------------------------------------------
    // Read port (rd_clk domain)
    // ---------------------------------------------------------
    always @(posedge rd_clk) begin
        if (rd_en)
            rd_data <= fifo[rd_addr];
    end

endmodule
