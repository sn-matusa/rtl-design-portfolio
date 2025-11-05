`timescale 1ns/1ps
/***************************************************************************
*
* Module:       axi_lite_tb (Enhanced Version)
* Description:  Comprehensive stimulus generator for AXI-Lite DUT
*               - Back-to-back operations
*               - Simultaneous read/write
*               - Random reset injection
*               - Partial write strobes
*               - Self-checking with expected values
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

    // -------------------- Configuration --------------------
    parameter CLK_PERIOD = 10;
    integer test_passed = 0;
    integer test_failed = 0;
    
    // Expected data storage for verification
    reg [31:0] expected_regs [0:15];
    integer i;

    // -------------------- Clock Generation --------------------
    initial aclk = 0;
    always #(CLK_PERIOD/2) aclk = ~aclk;

    // -------------------- Initial Reset --------------------
    initial begin
        aresetn = 0;
        wr_req = 0; 
        rd_req = 0; 
        wr_strb = 4'hF;
        wr_addr = 0;
        wr_data = 0;
        rd_addr = 0;
        
        // Initialize expected register array
        for (i = 0; i < 16; i = i + 1)
            expected_regs[i] = 32'h0;
            
        repeat(5) @(posedge aclk);
        aresetn = 1;
        $display("\n[%0t] ========== RESET RELEASED ==========", $time);
    end

    // -------------------- ENHANCED TASKS --------------------
    
    // Basic write with verification tracking
    task axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
    integer reg_idx;
    begin
        @(posedge aclk);
        wr_addr <= addr;
        wr_data <= data;
        wr_strb <= strb;
        wr_req  <= 1;
        @(posedge aclk);
        wr_req  <= 0;
        wait (wr_done == 1);
        @(posedge aclk);
        
        // Update expected register value
        reg_idx = addr[5:2]; // Assuming byte-addressable, 32-bit aligned
        if (strb[0]) expected_regs[reg_idx][ 7: 0] = data[ 7: 0];
        if (strb[1]) expected_regs[reg_idx][15: 8] = data[15: 8];
        if (strb[2]) expected_regs[reg_idx][23:16] = data[23:16];
        if (strb[3]) expected_regs[reg_idx][31:24] = data[31:24];
        
        $display("[%0t] WRITE @0x%02h = 0x%08h (strb=%b, resp=%0d)", 
                 $time, addr, data, strb, wr_resp);
    end
    endtask

    // Read with automatic verification
    task axi_read_verify(input [31:0] addr);
    reg [31:0] data;
    integer reg_idx;
    begin
        @(posedge aclk);
        rd_addr <= addr;
        rd_req  <= 1;
        @(posedge aclk);
        rd_req  <= 0;
        wait (rd_done == 1);
        @(posedge aclk);
        data = rd_data;
        
        reg_idx = addr[5:2];
        if (data === expected_regs[reg_idx]) begin
            $display("[%0t] READ  @0x%02h = 0x%08h [PASS] (resp=%0d)", 
                     $time, addr, data, rd_resp);
            test_passed = test_passed + 1;
        end else begin
            $display("[%0t] READ  @0x%02h = 0x%08h [FAIL] Expected: 0x%08h", 
                     $time, addr, data, expected_regs[reg_idx]);
            test_failed = test_failed + 1;
        end
    end
    endtask

    // Back-to-back writes (no wait between transactions)
    task back_to_back_writes(input [31:0] start_addr, input integer count);
    integer j;
    begin
        $display("\n[%0t] --- Back-to-Back Writes Test ---", $time);
        for (j = 0; j < count; j = j + 1) begin
            axi_write(start_addr + (j*4), 32'hBB000000 + j, 4'b1111);
        end
    end
    endtask

    // Back-to-back reads
    task back_to_back_reads(input [31:0] start_addr, input integer count);
    integer j;
    begin
        $display("\n[%0t] --- Back-to-Back Reads Test ---", $time);
        for (j = 0; j < count; j = j + 1) begin
            axi_read_verify(start_addr + (j*4));
        end
    end
    endtask

    // Simultaneous read and write (issue both requests in same cycle)
    task simultaneous_rd_wr(input [31:0] wr_a, input [31:0] wr_d, 
                            input [31:0] rd_a);
    reg [31:0] data;
    integer reg_idx;
    begin
        $display("\n[%0t] --- Simultaneous Read/Write Test ---", $time);
        
        // Issue both requests simultaneously
        @(posedge aclk);
        wr_addr <= wr_a;
        wr_data <= wr_d;
        wr_strb <= 4'b1111;
        wr_req  <= 1;
        rd_addr <= rd_a;
        rd_req  <= 1;
        
        @(posedge aclk);
        wr_req  <= 0;
        rd_req  <= 0;
        
        // Wait for both to complete
        fork
            begin
                wait (wr_done == 1);
                @(posedge aclk);
                reg_idx = wr_a[5:2];
                expected_regs[reg_idx] = wr_d;
                $display("[%0t]   WRITE completed @0x%02h = 0x%08h", 
                         $time, wr_a, wr_d);
            end
            begin
                wait (rd_done == 1);
                @(posedge aclk);
                data = rd_data;
                reg_idx = rd_a[5:2];
                if (data === expected_regs[reg_idx]) begin
                    $display("[%0t]   READ completed  @0x%02h = 0x%08h [PASS]", 
                             $time, rd_a, data);
                    test_passed = test_passed + 1;
                end else begin
                    $display("[%0t]   READ completed  @0x%02h = 0x%08h [FAIL]", 
                             $time, rd_a, data);
                    test_failed = test_failed + 1;
                end
            end
        join
    end
    endtask

    // Random reset during operation
    task random_reset_test();
    integer delay;
    begin
        $display("\n[%0t] --- Random Reset Test ---", $time);
        
        // Start a write operation
        @(posedge aclk);
        wr_addr <= 32'h10;
        wr_data <= 32'hDEADBEEF;
        wr_strb <= 4'b1111;
        wr_req  <= 1;
        @(posedge aclk);
        wr_req  <= 0;
        
        // Random delay before reset (1-3 cycles)
        delay = 1 + ($random % 3);
        repeat(delay) @(posedge aclk);
        
        // Assert reset
        $display("[%0t]   Asserting RESET during transaction", $time);
        aresetn <= 0;
        
        // Clear expected registers
        for (i = 0; i < 16; i = i + 1)
            expected_regs[i] = 32'h0;
            
        repeat(3) @(posedge aclk);
        
        // Release reset
        aresetn <= 1;
        $display("[%0t]   Reset released", $time);
        @(posedge aclk);
        
        // Verify registers are cleared
        axi_read_verify(32'h00);
        axi_read_verify(32'h10);
    end
    endtask

    // Partial write strobes test
    task partial_write_test();
    begin
        $display("\n[%0t] --- Partial Write Strobe Test ---", $time);
        
        // Write full word
        axi_write(32'h20, 32'h12345678, 4'b1111);
        axi_read_verify(32'h20);
        
        // Modify only byte 0
        axi_write(32'h20, 32'hXXXXXXAA, 4'b0001);
        axi_read_verify(32'h20);
        
        // Modify only byte 2
        axi_write(32'h20, 32'hXXBBXXXX, 4'b0100);
        axi_read_verify(32'h20);
        
        // Modify bytes 1 and 3
        axi_write(32'h20, 32'hDDXXCCXX, 4'b1010);
        axi_read_verify(32'h20);
    end
    endtask

    // Stress test: rapid fire operations
    task stress_test(input integer num_ops);
    integer j;
    reg do_write;
    begin
        $display("\n[%0t] --- Stress Test (%0d operations) ---", $time, num_ops);
        
        for (j = 0; j < num_ops; j = j + 1) begin
            do_write = $random % 2;
            
            if (do_write) begin
                axi_write(($random % 16) * 4, $random, 4'b1111);
            end else begin
                axi_read_verify(($random % 16) * 4);
            end
        end
    end
    endtask

    // -------------------- MAIN TEST PROGRAM --------------------
    initial begin
        // Wait for reset release
        @(posedge aresetn);
        repeat(2) @(posedge aclk);

        // ========== TEST 1: Basic Read/Write ==========
        $display("\n[%0t] ===== TEST 1: Basic Operations =====", $time);
        axi_write(32'h00, 32'hABCD_1234, 4'b1111);
        axi_read_verify(32'h00);
        
        axi_write(32'h04, 32'h11111111, 4'b1111);
        axi_write(32'h08, 32'h22222222, 4'b1111);
        axi_write(32'h0C, 32'h33333333, 4'b1111);
        
        axi_read_verify(32'h04);
        axi_read_verify(32'h08);
        axi_read_verify(32'h0C);

        // ========== TEST 2: Back-to-Back Operations ==========
        $display("\n[%0t] ===== TEST 2: Back-to-Back =====", $time);
        back_to_back_writes(32'h10, 4);
        back_to_back_reads(32'h10, 4);

        // ========== TEST 3: Simultaneous Read/Write ==========
        $display("\n[%0t] ===== TEST 3: Simultaneous Rd/Wr =====", $time);
        axi_write(32'h24, 32'hAAAA_AAAA, 4'b1111);
        axi_write(32'h28, 32'hBBBB_BBBB, 4'b1111);
        repeat(2) @(posedge aclk);
        
        simultaneous_rd_wr(32'h2C, 32'hCCCC_CCCC, 32'h24);
        simultaneous_rd_wr(32'h30, 32'hDDDD_DDDD, 32'h28);

        // ========== TEST 4: Partial Write Strobes ==========
        $display("\n[%0t] ===== TEST 4: Partial Strobes =====", $time);
        partial_write_test();

        // ========== TEST 5: Random Reset ==========
        $display("\n[%0t] ===== TEST 5: Random Reset =====", $time);
        random_reset_test();
        repeat(3) @(posedge aclk);

        // ========== TEST 6: Stress Test ==========
        $display("\n[%0t] ===== TEST 6: Stress Test =====", $time);
        stress_test(20);

        // ========== FINAL REPORT ==========
        repeat(5) @(posedge aclk);
        $display("\n========================================");
        $display("          TEST SUMMARY");
        $display("========================================");
        $display("Tests Passed: %0d", test_passed);
        $display("Tests Failed: %0d", test_failed);
        
        if (test_failed == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end
        
        $display("Simulation completed at %0t", $time);
        #50 $stop;
    end

    // -------------------- TIMEOUT WATCHDOG --------------------
    initial begin
        #100000; // 100us timeout
        $display("\n[ERROR] Simulation timeout!");
        $stop;
    end

endmodule
