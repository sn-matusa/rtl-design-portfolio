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

🧩 Ports and parameters description

The `async_fifo_top` module represents the **top-level integration** of all submodules implementing the asynchronous FIFO.  
It connects pointer handlers, synchronization stages, full/empty detection logic, and dual-port memory into a complete dual-clock FIFO system.

Parameters

| Parameter | Type | Default | Description |
|------------|------|----------|-------------|
| `DATA_WIDTH` | integer | 8 | Defines the bit-width of the data bus. Determines the width of `data_in` and `data_out`. |
| `ADDR_WIDTH` | integer | 4 | Determines the address pointer size. FIFO depth = 2^ADDR_WIDTH. |

Ports

| Port | Dir. | Width | Clock Domain | Description |
|------|------|--------|---------------|--------------|
| `wr_clk` | Input | 1 | Write | Write-side clock signal controlling all write domain logic. |
| `rd_clk` | Input | 1 | Read | Read-side clock signal controlling all read domain logic. |
| `rst_n` | Input | 1 | Global | Asynchronous active-low reset. Deassertion is synchronized within each domain via `reset_sync` module. |
| `wrreq` | Input | 1 | Write | External write request; valid only when `wr_full = 0`. |
| `rdreq` | Input | 1 | Read | External read request; valid only when `rd_empty = 0`. |
| `data_in` | Input | DATA_WIDTH | Write | Parallel input data to be written into FIFO memory. |
| `data_out` | Output | DATA_WIDTH | Read | Parallel output data read from FIFO memory. |
| `wr_full` | Output | 1 | Write | Indicates FIFO is full. Write operations are ignored while asserted. |
| `rd_empty` | Output | 1 | Read | Indicates FIFO is empty. Read operations are ignored while asserted. |

---

🧠 Internal Operation Summary
- The FIFO depth is defined by `ADDR_WIDTH`, e.g., for `ADDR_WIDTH = 4`, depth = 16 entries.  
- Gray-coded pointers are used for synchronization across `wr_clk` and `rd_clk` domains.  
- `wrreq` and `rdreq` are automatically masked when FIFO is full/empty.  
- `wr_full` and `rd_empty` are registered outputs, synchronized to their respective domains.  
- The module uses `reset_sync` blocks to ensure safe reset release for both clock domains.  

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

  <img width="1654" height="522" alt="image" src="https://github.com/user-attachments/assets/ae5c3560-76bf-4a25-8f90-38d1efbe02c0" />


Example Output:
### 🧾 Example Simulation Output

```text
=== FIFO TEST (port-driven TB) ===

[63000] Reset released
[175000] Reset sync complete

[175000] Writing 10 values...
[185000] >>> WRITE request: 0
[195000] WRITE OK: 0
[205000] >>> WRITE request: 1
[215000] WRITE OK: 1
[225000] >>> WRITE request: 2
[235000] WRITE OK: 2
[245000] >>> WRITE request: 3
[255000] WRITE OK: 3
[265000] >>> WRITE request: 4
[275000] WRITE OK: 4
[285000] >>> WRITE request: 5
[295000] WRITE OK: 5
[305000] >>> WRITE request: 6
[315000] WRITE OK: 6
[325000] >>> WRITE request: 7
[335000] WRITE OK: 7
[345000] >>> WRITE request: 8
[355000] WRITE OK: 8
[365000] >>> WRITE request: 9
[375000] WRITE OK: 9

[375000] Reading 5 values...
[385000] >>> READ request
[413000] <<< READ DATA: 0
[413000] >>> READ request
[441000] <<< READ DATA: 1
[441000] >>> READ request
[469000] <<< READ DATA: 2
[469000] >>> READ request
[497000] <<< READ DATA: 3
[497000] >>> READ request
[511000] Filling until FULL...
[515000] >>> WRITE request: 101
[525000] WRITE OK: 101
[525000] <<< READ DATA: 4
[535000] >>> WRITE request: 64
[545000] WRITE OK: 64
[555000] >>> WRITE request: 69
[565000] WRITE OK: 69
[575000] >>> WRITE request: 167
[585000] WRITE OK: 167
[595000] >>> WRITE request: 234
[605000] WRITE OK: 234
[615000] >>> WRITE request: 104
[625000] WRITE OK: 104
[635000] >>> WRITE request: 227
[645000] WRITE OK: 227
[655000] >>> WRITE request: 58
[665000] WRITE OK: 58
[675000] >>> WRITE request: 187
[685000] WRITE OK: 187
[695000] >>> WRITE request: 41
[705000] WRITE OK: 41
[715000] >>> WRITE request: 242
[725000] WRITE OK: 242
[735000] >>> WRITE skipped (FULL)
[745000] FIFO FULL detected

[745000] Emptying FIFO...
[749000] >>> READ request
[777000] <<< READ DATA: 5
[777000] >>> READ request
[805000] <<< READ DATA: 6
[805000] >>> READ request
[833000] <<< READ DATA: 7
[833000] >>> READ request
[861000] <<< READ DATA: 8
[861000] >>> READ request
[889000] <<< READ DATA: 9
[889000] >>> READ request
[917000] <<< READ DATA: 101
[917000] >>> READ request
[945000] <<< READ DATA: 64
[945000] >>> READ request
[973000] <<< READ DATA: 69
[973000] >>> READ request
[1001000] <<< READ DATA: 167
[1001000] >>> READ request
[1029000] <<< READ DATA: 234
[1029000] >>> READ request
[1057000] <<< READ DATA: 104
[1057000] >>> READ request
[1085000] <<< READ DATA: 227
[1085000] >>> READ request
[1113000] <<< READ DATA: 58
[1113000] >>> READ request
[1141000] <<< READ DATA: 187
[1141000] >>> READ request
[1169000] <<< READ DATA: 41
[1169000] >>> READ request
[1197000] <<< READ DATA: 242
[1197000] >>> READ request
[1211000] FIFO EMPTY detected
```
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


