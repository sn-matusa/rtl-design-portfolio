`timescale 1ns/1ps
/***************************************************************************
*
* Module:       axi_lite_tb
* Description:  Stimulus generator for AXI-Lite DUT
*
***************************************************************************/
module axi_lite_tb (
    output reg        wr_req,
    output reg [31:0] wr_addr,
    output reg [31:0] wr_data,
    output reg [3:0]  wr_strb,
    input             wr_done,
    input      [1:0]  wr_resp,

    output reg        rd_req,
    output reg [31:0] rd_addr,
    input      [31:0] rd_data,
    input             rd_done,
    input      [1:0]  rd_resp,

    output reg        aclk,
    output reg        aresetn
);

    // Clock
    initial aclk = 0;
    always #5 aclk = ~aclk;

    // Reset
    initial begin
        aresetn = 0;
        wr_req = 0; rd_req = 0; wr_strb = 4'hF;
        repeat(5) @(posedge aclk);
        aresetn = 1;
        $display("[TB] Reset released");
    end

    // -------------------- TASKS --------------------
    task axi_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge aclk);
        wr_addr <= addr;
        wr_data <= data;
        wr_strb <= 4'b1111;
        wr_req  <= 1;
        @(posedge aclk);
        wr_req  <= 0;
        wait (wr_done == 1);
        @(posedge aclk); // allow RF update on flop
        $display("[TB] WRITE @0x%08h = 0x%08h (resp=%0d)", addr, data, wr_resp);
    end
    endtask

    task axi_read(input [31:0] addr);
    reg [31:0] data;
    begin
        @(posedge aclk);
        rd_addr <= addr;
        rd_req  <= 1;
        @(posedge aclk);
        rd_req  <= 0;
        wait (rd_done == 1);
        @(posedge aclk); // allow RF read flop to settle
	//@(posedge aclk);
        data = rd_data;
        $display("[TB] READ  @0x%08h = 0x%08h (resp=%0d)", addr, data, rd_resp);
    end
    endtask


    // -------------------- TEST PROGRAM --------------------
    initial begin
        $dumpfile("axi_lite.vcd");
        $dumpvars(0, axi_lite_tb);

        @(posedge aresetn);

        axi_write(32'h00, 32'hABCD_1234);
        axi_read (32'h00);

        axi_write(32'h04, 32'h11111111);
        axi_write(32'h08, 32'h22222222);
        axi_write(32'h0C, 32'h33333333);

        axi_read (32'h04);
        axi_read (32'h08);
        axi_read (32'h0C);

        $display("[TB] Test completed");
        #50 $stop;
    end

endmodule

