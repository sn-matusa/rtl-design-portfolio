🧠 Asynchronous FIFO (Dual-Clock) – Verilog Implementation

A fully parameterized asynchronous FIFO architecture implemented in Verilog, featuring Gray-coded pointers, clock-domain synchronization, and a self-contained testbench with randomized stimuli.  
Designed for educational, FPGA, and ASIC prototyping purposes.

---

📘 Overview

This project implements a synthesizable asynchronous FIFO (First-In, First-Out) buffer designed to safely transfer data between two independent clock domains. 
It demonstrates proper use of Gray-coded pointers, dual flip-flop synchronizers, and safe full/empty detection logic. The design is modular, fully parameterized, and written using clean, reusable Verilog code.

Key Features:
- Dual-clock operation (asynchronous read/write)
- Gray-coded read/write pointers
- Full and empty flag detection
- Per-domain reset synchronization
- Dual-port memory array
- Parameterized data width and depth
- Self-checking testbench with random behavior and reset stress tests

---

⚙️ RTL View
<img width="1864" height="749" alt="image" src="https://github.com/user-attachments/assets/19f2f79d-74b4-4ff6-a981-6089239f40a6" />

---

🧩 Modules Description

| Module               | Description                                                                                                                                                                                                                 |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **async_fifo_top.v** | Top-level integration of all FIFO components. Connects write and read pointer handlers, dual-port memory, synchronizers, and full/empty detection logic. Provides a clean interface between two asynchronous clock domains. |
| **wr_ptr_handler.v** | Generates and updates the binary and Gray-coded write pointer. Provides the current write address and next Gray-coded pointer used for full-condition detection. Operates entirely in the `wr_clk` domain.                  |
| **rd_ptr_handler.v** | Handles the binary and Gray-coded read pointer logic. Provides the current read address for memory access and the Gray-coded pointer for synchronization. Operates entirely in the `rd_clk` domain.                         |
| **fifo_mem.v**       | Implements the dual-port memory array used to store FIFO data. Supports concurrent write and read operations on independent clocks (`wr_clk` and `rd_clk`) using separate address pointers.                                 |
| **fifo_full.v**      | Detects the FULL condition in the write clock domain. Compares the next Gray-coded write pointer with the synchronized read pointer (with MSBs inverted) to detect wrap-around and prevent overflow.                        |
| **fifo_empty.v**     | Detects the EMPTY condition in the read clock domain. Asserts when the Gray-coded read pointer equals the synchronized write pointer, indicating that no unread data remains in the buffer.                                 |
| **sync_wr2rd.v**     | Two-flip-flop synchronizer that safely transfers the Gray-coded write pointer from the `wr_clk` domain into the `rd_clk` domain. Minimizes metastability during clock-domain crossing.                                      |
| **sync_rd2wr.v**     | Two-flip-flop synchronizer that safely transfers the Gray-coded read pointer from the `rd_clk` domain into the `wr_clk` domain. Ensures stable pointer values for full-condition detection.                                 |
| **reset_sync.v**     | Synchronizes the deassertion of an asynchronous reset into a specific clock domain using a two-stage flip-flop chain. Ensures that all logic exits reset synchronously and safely.                                          |
| **fifo_test.v**      | Top-level test wrapper that instantiates both the FIFO DUT and the testbench. Connects all signals between the two modules and serves as the simulation entry point.                                                        |
| **fifo_tb.v**        | Self-contained testbench that generates asynchronous clocks, applies resets, performs randomized write/read operations, and logs FIFO behavior. Verifies functionality and robustness under various conditions.             |

---

🧪 Simulation and Testbench

The testbench (`fifo_tb.v`) automatically:
- Generates two asynchronous clocks  
  - `wr_clk` ≈ 100 MHz  
  - `rd_clk` ≈ 71 MHz  
- Applies asynchronous resets and waits for synchronization  
- Performs deterministic writes and reads  
- Fills and empties the FIFO to check `FULL` and `EMPTY` flags  
- Inserts **random resets and operations** to stress-test the design  

Example Output
...

---

▶️ How to Run

Using ModelSim:
- vlib work
- vlog src/*.v tb/*.v
- vsim work.fifo_test
- run -all

---

📊 Expected Behavior

- Data written on `wr_clk` domain is safely transferred and read on `rd_clk` domain.
- `wr_full` prevents further writes when memory is full.
- `rd_empty` prevents reads when FIFO is empty.
- No metastability or race conditions occur between domains.
- The design remains stable during random resets and async frequency ratios.

---

🧠 Design Notes

- Gray Code: Only one bit changes at a time, minimizing metastability when crossing domains.
- Synchronizers: Two flip-flops are used for pointer transfer to each clock domain.
- Resets: Asynchronous assertion, synchronous deassertion per domain.
- Memory: Dual-port RAM implemented as a simple `reg` array for synthesis portability.
- Scalability: `DATA_WIDTH` and `ADDR_WIDTH` parameters define FIFO capacity.
- Testbench: Implements deterministic + random testing and clock skew variation.

---

💡 Possible Extensions

- Add parity or ECC bit for data integrity checks.
- Implement programmable `almost_full` / `almost_empty` flags.
- Include SystemVerilog assertions (SVA) for property checking.
- Integrate with AXI-Stream or APB interface wrapper for SoC use.

---

🧑‍💻 Author
- Sebastian Mătușa


