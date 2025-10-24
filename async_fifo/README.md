


🧠 Asynchronous FIFO (Dual-Clock) – Verilog Implementation

A fully parameterized asynchronous FIFO architecture implemented in Verilog, featuring Gray-coded pointers, clock-domain synchronization, and a self-contained testbench with randomized stimuli.  
Designed for educational, FPGA, and ASIC prototyping purposes.


📘 Overview

This project implements a synthesizable asynchronous FIFO (First-In, First-Out) buffer designed to safely transfer data between two independent clock domains.  
It demonstrates proper use of Gray-coded pointers, dual flip-flop synchronizers, and safe full/empty detection logic.

The design is modular, fully parameterized, and written using clean, reusable Verilog code.

Key Features
- Dual-clock operation (asynchronous read/write)
- Gray-coded read/write pointers
- Full and empty flag detection
- Per-domain reset synchronization
- Dual-port memory array
- Parameterized data width and depth
- Self-checking testbench with random behavior and reset stress tests


⚙️ Architecture
...


🧩 Module Description
...


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


▶️ How to Run

Using ModelSim:
vlib work
vlog src/*.v tb/*.v
vsim work.fifo_test
run -all


📊 Expected Behavior

- Data written on `wr_clk` domain is safely transferred and read on `rd_clk` domain.
- `wr_full` prevents further writes when memory is full.
- `rd_empty` prevents reads when FIFO is empty.
- No metastability or race conditions occur between domains.
- The design remains stable during random resets and async frequency ratios.

🧠 Design Notes

- Gray Code: Only one bit changes at a time, minimizing metastability when crossing domains.
- Synchronizers: Two flip-flops are used for pointer transfer to each clock domain.
- Resets: Asynchronous assertion, synchronous deassertion per domain.
- Memory: Dual-port RAM implemented as a simple `reg` array for synthesis portability.
- Scalability: `DATA_WIDTH` and `ADDR_WIDTH` parameters define FIFO capacity.
- Testbench: Implements deterministic + random testing and clock skew variation.

💡 Possible Extensions

- Add parity or ECC bit for data integrity checks.
- Implement programmable `almost_full` / `almost_empty` flags.
- Include SystemVerilog assertions (SVA) for property checking.
- Integrate with AXI-Stream or APB interface wrapper for SoC use.

🧑‍💻 Author
Sebastian Matusa


