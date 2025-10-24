`timescale 1ns/1ps
/***************************************************************************
*
* Module:       fifo_tb
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Self-contained testbench for the asynchronous FIFO.
*   Generates two asynchronous clocks, applies reset, performs
*   write and read transactions, and monitors FIFO behavior.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module fifo_tb (
    output reg        wr_clk,
    output reg        rd_clk,
    output reg        rst_n,
    output reg        wrreq,
    output reg        rdreq,
    output reg [7:0]  data_in,
    input      [7:0]  data_out,
    input             wr_full,
    input             rd_empty
);

    // ---------------------------------------------------------
    // Clock generation
    // ---------------------------------------------------------
    initial begin
        wr_clk = 0;
        forever #5 wr_clk = ~wr_clk;   // ~100 MHz
    end

    initial begin
        rd_clk = 0;
        forever #7 rd_clk = ~rd_clk;   // ~71 MHz
    end

    // ---------------------------------------------------------
    // Reset and operation tasks
    // ---------------------------------------------------------
    task do_reset;
        begin
            rst_n   = 0;
            wrreq   = 0;
            rdreq   = 0;
            data_in = 0;
            repeat (3) @(posedge wr_clk);
            repeat (3) @(posedge rd_clk);
            rst_n = 1;
            $display("\n[%0t] Reset released", $time);
            repeat (5) @(posedge wr_clk);
            repeat (5) @(posedge rd_clk);
            $display("[%0t] Reset sync complete\n", $time);
        end
    endtask

    task write_data(input [7:0] value);
        begin
            @(posedge wr_clk);
            if (!wr_full) begin
                wrreq   <= 1'b1;
                data_in <= value;
                $display("[%0t] >>> WRITE request: %0d", $time, value);
            end else begin
                wrreq <= 1'b0;
                $display("[%0t] >>> WRITE skipped (FULL)", $time);
            end
            @(posedge wr_clk);
            wrreq <= 1'b0;
        end
    endtask

    task read_data;
        begin
            @(posedge rd_clk);
            if (!rd_empty) begin
                rdreq <= 1'b1;
                $display("[%0t] >>> READ request", $time);
            end else begin
                rdreq <= 1'b0;
                $display("[%0t] >>> READ skipped (EMPTY)", $time);
            end
            @(posedge rd_clk);
            rdreq <= 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // Stimulus sequence
    // ---------------------------------------------------------
    integer i;

    initial begin
        $display("=== FIFO TEST (port-driven TB) ===\n");
        rst_n   = 0;
        wrreq   = 0;
        rdreq   = 0;
        data_in = 0;

        do_reset();

        $display("[%0t] Writing 10 values...", $time);
        for (i = 0; i < 10; i = i + 1)
            write_data(i[7:0]);

        $display("[%0t] Reading 5 values...", $time);
        for (i = 0; i < 5; i = i + 1)
            read_data();

        $display("[%0t] Filling until FULL...", $time);
        while (!wr_full)
            write_data($urandom_range(0,255));
        $display("[%0t] FIFO FULL detected", $time);

        $display("[%0t] Emptying FIFO...", $time);
        while (!rd_empty)
            read_data();
        $display("[%0t] FIFO EMPTY detected", $time);

        $display("[%0t] Random resets + mixed ops...", $time);
        fork
            begin
                repeat (3) begin
                    #($urandom_range(100,300));
                    do_reset();
                    $display("[%0t] Random reset applied", $time);
                end
            end
            begin
                repeat (40) begin
                    write_data($urandom_range(0,255));
                    read_data();
                end
            end
        join

        $display("\n[%0t] TEST COMPLETE", $time);
        #200;
        $stop;
    end

    // ---------------------------------------------------------
    // Output monitors
    // ---------------------------------------------------------
    reg rdreq_d, rd_empty_d;
    always @(posedge rd_clk) begin
        rdreq_d    <= rdreq;
        rd_empty_d <= rd_empty;
        if (rdreq_d && !rd_empty_d)
            $display("[%0t] <<< READ DATA: %0d", $time, data_out);
    end

    always @(posedge wr_clk) begin
        if (wrreq && !wr_full)
            $display("[%0t] WRITE OK: %0d", $time, data_in);
    end

endmodule
