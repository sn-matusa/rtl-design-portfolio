`timescale 1ns/1ps

/******************************************************************************
* Module:       register_file
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Parametric register file used as backend storage for AXI-Lite slave.
*   Supports byte-granular write strobes and synchronous read/write semantics.
*
* Revision History:
*   Rev 1.0 - Initial version
*   Rev 1.1 - Combinational read path
*   Rev 1.2 - Added simulation debug displays (Oct 2025)
******************************************************************************/

module register_file #(
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16
)(
    input                           clk,
    input                           rst_n,

    // Write interface
    input   [$clog2(NUM_REGS)-1:0]  wr_addr,
    input                           wr_en,
    input   [DATA_WIDTH-1:0]        wr_data,
    input   [DATA_WIDTH/8-1:0]      wr_strb,
    output  reg [1:0]               wr_resp,

    // Read interface
    input   [$clog2(NUM_REGS)-1:0]  rd_addr,
    input                           rd_en,
    output  reg [DATA_WIDTH-1:0]    rd_data,
    output  reg [1:0]               rd_resp
);

    // Register storage
    reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    integer i;

    // ------------------------ WRITE ---------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {DATA_WIDTH{1'b0}};
            wr_resp <= 2'b00;
        end else begin
            if (wr_en) begin
                wr_resp <= 2'b00;

                if (wr_strb[0]) regs[wr_addr][ 7: 0] <= wr_data[ 7: 0];
                if (wr_strb[1]) regs[wr_addr][15: 8] <= wr_data[15: 8];
                if (wr_strb[2]) regs[wr_addr][23:16] <= wr_data[23:16];
                if (wr_strb[3]) regs[wr_addr][31:24] <= wr_data[31:24];
            end
        end
    end

    // ------------------------ READ ----------------------------
    always @(*) begin
        if (rd_en) begin
            rd_data = regs[rd_addr];
            rd_resp = 2'b11;
        end else begin
            rd_data = {DATA_WIDTH{1'b0}};
            rd_resp = 2'b00;
        end
    end

endmodule
