/******************************************************************************
*
* Module:       register_file
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Parametric register file used as backend storage for AXI-Lite slave.
*   Supports byte-granular write strobes and synchronous read/write semantics.
*
*   Features:
*     - Parameterizable number of registers
*     - Byte-level write mask support (WSTRB)
*     - Default 32-bit register width
*     - Valid AXI response signaling (OKAY/SLVERR)
*
*   Designed as a clean and simple model suitable for simulation and FPGA
*   prototyping in memory-mapped peripheral blocks.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
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

    // Storage
    reg [DATA_WIDTH-1:0] regs      [0:NUM_REGS-1];
    reg [DATA_WIDTH-1:0] regs_next [0:NUM_REGS-1];

    // Next-state logic outputs
    reg [1:0] wr_resp_next;
    reg [1:0] rd_resp_next;
    reg [DATA_WIDTH-1:0] rd_data_next;

    integer i;

    // ------------------------------------------------------------
    // COMBINATIONAL NEXT STATE
    // ------------------------------------------------------------
    always @(*) begin
        // defaults
        wr_resp_next = 2'b00;
        rd_resp_next = rd_resp;
        rd_data_next = rd_data;

        // propagate regs forward
        for (i = 0; i < NUM_REGS; i = i + 1)
            regs_next[i] = regs[i];

        // Write path with strobes
        if (wr_en) begin
            wr_resp_next = 2'b00; // OKAY
            if (wr_strb[0]) regs_next[wr_addr][ 7: 0] = wr_data[ 7: 0];
            if (wr_strb[1]) regs_next[wr_addr][15: 8] = wr_data[15: 8];
            if (wr_strb[2]) regs_next[wr_addr][23:16] = wr_data[23:16];
            if (wr_strb[3]) regs_next[wr_addr][31:24] = wr_data[31:24];
        end

        // Read path
        if (rd_en) begin
            rd_resp_next = 2'b00;       // OKAY
            rd_data_next = regs[rd_addr];
        end
    end

    // ------------------------------------------------------------
    // SEQUENTIAL FLOPS ONLY (no logic)
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {DATA_WIDTH{1'b0}};
            wr_resp <= 2'b00;
            rd_resp <= 2'b00;
            rd_data <= {DATA_WIDTH{1'b0}};
        end else begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= regs_next[i];
            wr_resp <= wr_resp_next;
            rd_resp <= rd_resp_next;
            rd_data <= rd_data_next;
        end
    end

endmodule
