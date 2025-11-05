/******************************************************************************
* Module:       register_file
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Simplified parametric register file with minimal decoding logic.
*   Uses addresses directly without intermediate variables.
*
* Revision History:
*   Rev 1.0 - Initial version
*   Rev 1.1 - Combinational read path
*   Rev 1.2 - Added simulation debug displays (Oct 2025)
*   Rev 1.3 - Moved address decoding from top module (Nov 2025)
*   Rev 1.4 - Simplified - removed intermediate variables (Nov 2025)
*   Rev 1.5 - Changed wr_resp type assignment
******************************************************************************/

module register_file #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16
)(
    input                       clk,
    input                       rst_n,

    // Write interface (byte address)
    input   [ADDR_WIDTH-1:0]    wr_addr,
    input                       wr_en,
    input   [DATA_WIDTH-1:0]    wr_data,
    input   [DATA_WIDTH/8-1:0]  wr_strb,
    output  [1:0]           wr_resp,

    // Read interface (byte address)
    input   [ADDR_WIDTH-1:0]    rd_addr,
    input                       rd_en,
    output  reg [DATA_WIDTH-1:0] rd_data,
    output  reg [1:0]           rd_resp
);

    // Register storage
    reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    integer i;

    // ------------------------ WRITE ---------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            if (wr_en) begin
                // Direct indexing: wr_addr[5:2] extracts register index for 32-bit words
                // Byte-granular write based on strobe
                if (wr_strb[0]) regs[wr_addr[5:2]][ 7: 0] <= wr_data[ 7: 0];
                if (wr_strb[1]) regs[wr_addr[5:2]][15: 8] <= wr_data[15: 8];
                if (wr_strb[2]) regs[wr_addr[5:2]][23:16] <= wr_data[23:16];
                if (wr_strb[3]) regs[wr_addr[5:2]][31:24] <= wr_data[31:24];
            end
        end
    end

    assign wr_resp = wr_en ? 2'b00 : 2'b10;

    // ------------------------ READ ----------------------------
    always @(*) begin
        if (rd_en) begin
            // Direct indexing: rd_addr[5:2] extracts register index
            rd_data = regs[rd_addr[5:2]];
            rd_resp = 2'b00;  // OKAY response (AXI standard)
        end else begin
            rd_data = {DATA_WIDTH{1'b0}};
            rd_resp = 2'b10;
        end
    end

endmodule
