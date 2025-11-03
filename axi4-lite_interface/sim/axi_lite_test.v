`timescale 1ns/1ps
/***************************************************************************
*
* Module:       axi_lite_test
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   AXI4-Lite top-level test environment.
*   Instantiates both:
*     - the AXI system top (DUT)
*     - the AXI testbench stimulus module
*
*   Generates waveform dumps and ties the testbench to the DUT.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
***************************************************************************/

module axi_lite_test;

    // --------------------------------------------------------------------
    // Interconnect wires between TB and DUT
    // --------------------------------------------------------------------
    wire        wr_req, rd_req;
    wire [31:0] wr_addr, rd_addr, wr_data;
    wire [3:0]  wr_strb;
    wire        wr_done, rd_done;
    wire [1:0]  wr_resp, rd_resp;
    wire [31:0] rd_data;
    wire        aclk, aresetn;

    // --------------------------------------------------------------------
    // DUT instance (AXI system top)
    // --------------------------------------------------------------------
    axi_system_top #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .NUM_REGS(16)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),

        .m_wr_req (wr_req),
        .m_wr_addr(wr_addr),
        .m_wr_data(wr_data),
        .m_wr_strb(wr_strb),
        .m_wr_done(wr_done),
        .m_wr_resp(wr_resp),

        .m_rd_req (rd_req),
        .m_rd_addr(rd_addr),
        .m_rd_data(rd_data),
        .m_rd_done(rd_done),
        .m_rd_resp(rd_resp)
    );

    // --------------------------------------------------------------------
    // Stimulus generator
    // --------------------------------------------------------------------
    axi_lite_tb stim (
        .wr_req(wr_req), .wr_addr(wr_addr), .wr_data(wr_data), .wr_strb(wr_strb),
        .wr_done(wr_done), .wr_resp(wr_resp),

        .rd_req(rd_req), .rd_addr(rd_addr),
        .rd_data(rd_data), .rd_done(rd_done), .rd_resp(rd_resp),

        .aresetn(aresetn),
        .aclk(aclk)
    );


endmodule
