# AXI4-Lite Interface

## Overview

The AXI4-Lite Interface project implements a simple AXI4-Lite bus system consisting of an AXI-Lite master, an AXI-Lite slave, and a memory-mapped register file. The design demonstrates a complete AXI-Lite read/write transaction flow by connecting the master to the slave, which in turn interfaces with a register file for data storage. This modular architecture (master → slave → register file) allows a user to issue read/write requests through a simplified interface; the master converts these requests into AXI4-Lite protocol signals, the slave handles the AXI handshake and protocol compliance, and the register file provides the actual data storage (16 registers by default). The project serves as a reference for understanding AXI4-Lite transactions and can be integrated as a lightweight AXI-Lite peripheral in larger systems.

## Features

### Full AXI4-Lite Protocol Compliance
Implements all five AXI-Lite channels (write address, write data, write response, read address, read data) with proper handshake signals (VALID/READY) on each. The design handles write address and data in any order (address-first, data-first, or simultaneous) as allowed by the AXI protocol, ensuring a robust handshake mechanism.

### Single Outstanding Transactions
Supports one write and one read transaction at a time (per AXI4-Lite specifications). The master and slave FSMs allow one write and one read to be in progress concurrently (one of each type), but do not pipeline multiple outstanding writes or reads. This simplifies the design while covering typical AXI-Lite use-cases.

### Byte-Enable Write Strobes
Supports byte-aligned data transfers using the WSTRB signals for partial writes. The register file honors write strobes to enable or disable writing of each byte within the 32-bit word, allowing sub-word updates (e.g., writing only certain bytes of a register).

### Parameterizable Widths and Depth
The address and data bus widths are configurable via parameters (default 32-bit address and 32-bit data). The register file depth (number of 32-bit registers) is also parameterized (default 16 registers), making it easy to scale the interface for different memory sizes.

### Standard AXI Responses
Uses standard AXI4-Lite response codes on read/write completion. A successful access returns OKAY (2’b00), while an invalid access (e.g., address out of range) returns SLVERR (2’b10). The slave passes through the response from the register file to the master, ensuring error conditions in the register file (like invalid address) are reported up the chain.

### Synchronous Design with Reset
All modules operate on a common clock (aclk) and utilize an active-low asynchronous reset (aresetn) for initialization. Internal registers (including the register file storage) are reset to 0 on startup for a known initial state.

## Interface Description

This section describes the key I/O signals of the top-level AXI system and its main sub-modules: the AXI-Lite master, AXI-Lite slave, and register file. Signal widths are parameterized (shown with default widths where applicable).

### Top-Level `axi_system_top` Interface

The top-level module connects the master, slave, and register file. It exposes a simplified user interface for issuing transactions, which the master module uses internally to drive the AXI signals.

| Signal | Direction | Width | Description |
|--------|----------|-------|-------------|
| clk | Input | 1-bit | System clock for AXI interface (common to all modules). |
| rst_n | Input | 1-bit | Global reset (active-low). Asynchronous reset for all modules. |
| user_wr_req | Input | 1-bit | Write request strobe. When high, requests a new write transaction. |
| user_wr_addr | Input | 32-bit (param) | Write address (byte address for the target register). |
| user_wr_data | Input | 32-bit (param) | Write data to be written to the addressed register. |
| user_wr_strb | Input | 4-bit (param) | Write strobes (one bit per byte) indicating which bytes of `user_wr_data` are valid. For 32-bit data, `4’b1111` indicates a full 32-bit write. |
| user_wr_done | Output | 1-bit | Write completion indicator. Pulses high for one cycle when the write transaction is completed. |
| user_wr_resp | Output | 2-bit | Write response code (AXI BRESP). `2’b00 = OKAY`, `2’b10 = SLVERR`. |
| user_rd_req | Input | 1-bit | Read request strobe. When high, requests a new read transaction. |
| user_rd_addr | Input | 32-bit (param) | Read address (byte address of the register to read). |
| user_rd_data | Output | 32-bit (param) | Read data returned from the addressed register. Valid when `user_rd_done` is asserted. |
| user_rd_done | Output | 1-bit | Read completion indicator. Pulses high for one cycle when the read transaction is completed and data is available. |
| user_rd_resp | Output | 2-bit | Read response code (AXI RRESP). `2’b00 = OKAY`, `2’b10 = SLVERR` (e.g., invalid address). |

> **Note:** The `axi_system_top` internally generates and wires all the standard AXI4-Lite bus signals (`awaddr`, `awvalid`, `wdata`, `wstrb`, `bresp`, `araddr`, `rdata`, etc.) between the master and slave. These internal signals follow the AXI protocol but are not directly exposed at the top level.

---

## AXI4-Lite Master (`axi_lite_master`) Interface

The AXI-Lite master module converts the simple user requests into AXI bus transactions. It has a user-side interface (matching the signals above) and an AXI bus interface that connects to the slave.

### **AXI Master External Ports**

| Signal | Direction | Width | Description |
|--------|-----------|-------|------------|
| aclk | Input | 1-bit | AXI system clock (same as top-level `clk`). |
| aresetn | Input | 1-bit | AXI reset (active-low, same as top-level `rst_n`). |

### **User Write Interface**

| Signal | Dir | Width | Description |
|-------|-----|-------|------------|
| wr_req | Input | 1-bit | Write request (start a write transaction). |
| wr_addr | Input | 32-bit (param) | Write address (from user). |
| wr_data | Input | 32-bit (param) | Write data (from user). |
| wr_strb | Input | 4-bit (param) | Write byte strobes (from user). |
| wr_done | Output | 1-bit | Write transaction done (1-cycle pulse when complete). |
| wr_resp | Output | 2-bit | Write response code (`BRESP`) from slave. |

### **User Read Interface**

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| rd_req | Input | 1-bit | Read request (start a read transaction). |
| rd_addr | Input | 32-bit (param) | Read address (from user). |
| rd_data | Output | 32-bit (param) | Read data (captured from the AXI bus response). |
| rd_done | Output | 1-bit | Read transaction done (1-cycle pulse when data is valid). |
| rd_resp | Output | 2-bit | Read response code (`RRESP`) from slave. |

### **AXI Write Address Channel** (master → slave)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| awaddr | Output | 32-bit (param) | AXI write address. |
| awvalid | Output | 1-bit | AXI write address valid. Master asserts to indicate a valid address/transaction. |
| awready | Input | 1-bit | AXI write address ready (from slave). Indicates slave accepted the address. |

### **AXI Write Data Channel** (master → slave)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| wdata | Output | 32-bit (param) | AXI write data. |
| wstrb | Output | 4-bit (param) | AXI write strobes (which bytes of wdata are valid). |
| wvalid | Output | 1-bit | AXI write data valid. Master asserts when write data is available. |
| wready | Input | 1-bit | AXI write data ready (from slave). Indicates slave accepted the data. |

### **AXI Write Response Channel** (slave → master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| bresp | Input | 2-bit | AXI write response code from slave (BRESP). |
| bvalid | Input | 1-bit | AXI write response valid from slave. |
| bready | Output | 1-bit | AXI write response ready. Master asserts to accept/write response. |

### **AXI Read Address Channel** (master → slave)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| araddr | Output | 32-bit (param) | AXI read address. |
| arvalid | Output | 1-bit | AXI read address valid. Master asserts to request a read at araddr. |
| arready | Input | 1-bit | AXI read address ready (from slave). Indicates slave accepted the read address. |

### **AXI Read Data Channel** (slave → master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| rdata | Input | 32-bit (param) | AXI read data from slave. |
| rresp | Input | 2-bit | AXI read response code from slave (RRESP). |
| rvalid | Input | 1-bit | AXI read data valid (from slave). Indicates rdata and rresp are valid. |
| rready | Output | 1-bit | AXI read data ready. Master asserts to accept the read data. |

> Note: The master uses internal state machines to coordinate the above signals. When a user issues wr_req or rd_req, the master drives the appropriate AXI address (AW or AR) and data (W) signals. It manages the handshake (AWVALID/WVALID and AWREADY/WREADY) and waits for the corresponding response (BVALID for writes or RVALID for reads) before signaling *_done to the user. The master captures bresp/rresp into wr_resp/rd_resp and latches read data into rd_data for the user.

---

## AXI4-Lite Slave (`axi_lite_slave`) Interface

The AXI-Lite slave module receives AXI transactions and interfaces with the user register file. It implements the AXI4-Lite protocol on the slave side (address, data, and response handshaking) and translates accepted transactions into simple register file operations.

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| aclk | Input | 1-bit | AXI clock (same domain as master). |
| aresetn | Input | 1-bit | AXI reset (active-low). |
### AXI Write Address (slave input from master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| awaddr | Input | 32-bit (param) | AXI write address from master. |
| awvalid | Input | 1-bit | AXI write address valid from master. |
| awready | Output | 1-bit | AXI write address ready. Slave asserts when it can accept an address. |

### AXI Write Data (slave input from master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| wdata | Input | 32-bit (param) | AXI write data from master. |
| wstrb | Input | 4-bit (param) | AXI write strobes from master. |
| wvalid | Input | 1-bit | AXI write data valid from master. |
| wready | Output | 1-bit | AXI write data ready. Slave asserts when it can accept write data. |

### AXI Write Response (slave → master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| bresp | Output | 2-bit | AXI write response code (BRESP) to master (e.g., OKAY or SLVERR). |
| bvalid | Output | 1-bit | AXI write response valid. Slave asserts when bresp is available. |
| bready | Input | 1-bit | AXI write response ready from master. |

### AXI Read Address (slave input from master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| araddr | Input | 32-bit (param) | AXI read address from master. |
| arvalid | Input | 1-bit | AXI read address valid from master. |
| arready | Output | 1-bit | AXI read address ready. Slave asserts when it can accept a read address. |

### AXI Read Data (slave → master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| rdata | Output | 32-bit (param) | AXI read data returning to master (from register file). |
| rresp | Output | 2-bit | AXI read response code (RRESP) to master. |
| rvalid | Output | 1-bit | AXI read data valid. Slave asserts when rdata (and rresp) are available. |
| rready | Input | 1-bit | AXI read data ready from master. |

### Register File Interface (slave → RF)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| user_wr_addr | Output | 32-bit (param) | Write address to the register file (full byte address captured from awaddr). |
| user_wr_data | Output | 32-bit (param) | Write data to the register file (from wdata). |
| user_wr_strb | Output | 4-bit (param) | Write strobes to the register file (from wstrb). |
| user_wr_en | Output | 1-bit | Write enable pulse to register file. Indicates a write operation should be performed at the captured address/data. This pulses high for one cycle when both address and data have been received. |
| user_wr_resp | Input | 2-bit | Write response from register file logic. Typically OKAY or SLVERR. Forwarded to bresp. |
| user_rd_addr | Output | 32-bit (param) | Read address to the register file (captured from araddr). |
| user_rd_en | Output | 1-bit | Read enable pulse to register file. Indicates a read operation should be performed. |
| user_rd_data | Input | 32-bit (param) | Read data from register file. Forwarded to rdata. |
| user_rd_resp | Input | 2-bit | Read response from register file (OKAY or SLVERR). Forwarded to rresp. |

> Note: The slave contains internal finite state machines for write and read transactions. It accepts write address/data in any order by using a handshake process (it will assert awready and/or wready accordingly to latch the address/data when they arrive). Once both address and data are received, the slave pulses user_wr_en to initiate the register file write and then issues the write response (bvalid/bresp). For reads, when an araddr is received (arvalid & arready), the slave triggers a read (user_rd_en) and, after getting the data/response from the register file, asserts rvalid with the rdata/rresp. The slave ensures only one write and one read transaction are handled at a time, as per AXI-Lite ordering rules.

---

## Register File (`register_file`) Interface

The register file module is a simple memory array that stores data for the AXI-Lite slave. It receives read/write commands from the slave and provides data and response codes. By default, the register file implements 16 registers of 32-bit width each (addressable in a 64-byte address space with 4-byte alignment per register).

| Signal | Direction | Width | Description |
|--------|----------|-------|-------------|
| clk | Input | 1-bit | Clock (same as AXI clock, for synchronous memory operations). |
| rst_n | Input | 1-bit | Reset (active-low). Clears register contents on reset. |
| wr_addr | Input | ⌈log2(NUM_REGS)⌉ bits | Write address (register index). Top uses address bits `[5:2]` for 16 registers. |
| wr_data | Input | 32-bit (param) | Write data to be stored in the register at wr_addr. |
| wr_strb | Input | 4-bit (param) | Write strobes (byte enable signals). Each bit corresponds to one byte of wr_data. |
| wr_en | Input | 1-bit | Write enable (pulse). |
| wr_resp | Output | 2-bit | Write response (`OKAY` or `SLVERR`). |
| rd_addr | Input | ⌈log2(NUM_REGS)⌉ bits | Read address (register index). |
| rd_en | Input | 1-bit | Read enable (pulse). |
| rd_data | Output | 32-bit (param) | Read data output. |
| rd_resp | Output | 2-bit | Read response (`OKAY` or `SLVERR`). |

> Note: On reset, the register file clears all registers to zero. The use of byte-write strobes means that partial writes will only update selected bytes of a register, leaving other bytes unchanged. The logic ensures that any out-of-bound address does not modify the register array and results in an error response. Since NUM_REGS is a power of 2 in this design, address validity is simply checked by bounds (if not power of 2, a comparison would be used).

---

## RTL Structure

<img width="1872" height="836" alt="image" src="https://github.com/user-attachments/assets/0a1b3c13-d75d-4c5b-836c-4aadf5a7c3fd" />

The AXI4-Lite interface is organized into three main components connected in a pipeline: the master, the slave, and the register file. The top-level module (`axi_system_top`) instantiates and connects these components. Below is an outline of each component’s role and how they interact:

### AXI4-Lite Master
Acts as the initiator of AXI transactions. It provides a user-friendly request interface and translates those into AXI signals. Internally, it uses state machines. It asserts AWVALID/WVALID for writes or ARVALID for reads, holds them until handshake, then waits for BVALID/RVALID. Once complete, output pulses (`wr_done` / `rd_done`) and response/data captured.

### AXI4-Lite Slave
Protocol responder. Accepts address and data in any order for writes. Captures address/data and pulses `user_wr_en`. For reads, accepts AR and pulses `user_rd_en`. Returns responses and data. Only one write and one read transaction are handled at a time.

### Register File
Simple synchronous RAM with byte mask writes. Provides OKAY/SLVERR.

---

## Timing Diagrams

<img width="1401" height="512" alt="image" src="https://github.com/user-attachments/assets/0a3e0272-19e8-4238-9750-9fcac920ef80" />

### Write Transaction

<img width="1374" height="311" alt="image" src="https://github.com/user-attachments/assets/b98fcdfe-39e5-42ff-b488-3c2cc109002a" />

### Read Transaction

<img width="1380" height="224" alt="image" src="https://github.com/user-attachments/assets/de4dcd0b-9dba-4bc4-b592-1ea675ac5a84" />

---

## Simulation/Testbench

The testbench provides a self-checking AXI-Lite verification environment that drives both read and write transactions and validates the DUT against a local reference model. It generates a clock and reset sequence, then executes a mix of directed and stress-style operations across a 16 × 32-bit memory map. Expected register values are tracked in an internal array (`expected_regs[0:15]`), with byte-level updates based on write strobes (`wr_strb`) and word-aligned addressing (`addr[5:2]`).

Stimulus tasks assert `wr_req` and `rd_req`, wait for the corresponding `wr_done` and `rd_done` handshakes, and record results. The test sequence includes back-to-back requests, concurrent read and write issuance, partial-byte writes, random reset assertion during traffic, and a small randomized stress phase. Each read is automatically compared against the expected mirror and logged as pass or fail, with counters tracking totals.

Console output includes detailed transaction logs and a final summary banner. A watchdog prevents simulation deadlock. The environment uses plain Verilog and minimal infrastructure, no UVM, making it compact and portable while still exercising core AXI-Lite behaviors and reset corner cases.


Simulation output:
```text
[45000] ========== RESET RELEASED ==========

[65000] ===== TEST 1: Basic Operations =====
[115000] WRITE @0x00 = 0xabcd1234 (strb=1111, resp=0)
[175000] READ  @0x00 = 0xabcd1234 [PASS] (resp=0)
[225000] WRITE @0x04 = 0x11111111 (strb=1111, resp=0)
[275000] WRITE @0x08 = 0x22222222 (strb=1111, resp=0)
[325000] WRITE @0x0c = 0x33333333 (strb=1111, resp=0)
[385000] READ  @0x04 = 0x11111111 [PASS] (resp=0)
[445000] READ  @0x08 = 0x22222222 [PASS] (resp=0)
[505000] READ  @0x0c = 0x33333333 [PASS] (resp=0)

[505000] ===== TEST 2: Back-to-Back =====

[505000] --- Back-to-Back Writes Test ---
[555000] WRITE @0x10 = 0xbb000000 (strb=1111, resp=0)
[605000] WRITE @0x14 = 0xbb000001 (strb=1111, resp=0)
[655000] WRITE @0x18 = 0xbb000002 (strb=1111, resp=0)
[705000] WRITE @0x1c = 0xbb000003 (strb=1111, resp=0)

[705000] --- Back-to-Back Reads Test ---
[765000] READ  @0x10 = 0xbb000000 [PASS] (resp=0)
[825000] READ  @0x14 = 0xbb000001 [PASS] (resp=0)
[885000] READ  @0x18 = 0xbb000002 [PASS] (resp=0)
[945000] READ  @0x1c = 0xbb000003 [PASS] (resp=0)

[945000] ===== TEST 3: Simultaneous Rd/Wr =====
[995000] WRITE @0x24 = 0xaaaaaaaa (strb=1111, resp=0)
[1045000] WRITE @0x28 = 0xbbbbbbbb (strb=1111, resp=0)

[1065000] --- Simultaneous Read/Write Test ---
[1115000]   WRITE completed @0x2c = 0xcccccccc
[1125000]   READ completed  @0x24 = 0xaaaaaaaa [PASS]

[1125000] --- Simultaneous Read/Write Test ---
[1175000]   WRITE completed @0x30 = 0xdddddddd
[1185000]   READ completed  @0x28 = 0xbbbbbbbb [PASS]

[1185000] ===== TEST 4: Partial Strobes =====

[1185000] --- Partial Write Strobe Test ---
[1235000] WRITE @0x20 = 0x12345678 (strb=1111, resp=0)
[1295000] READ  @0x20 = 0x12345678 [PASS] (resp=0)
[1345000] WRITE @0x20 = 0xxxxxxxaa (strb=0001, resp=0)
[1405000] READ  @0x20 = 0x123456aa [PASS] (resp=0)
[1455000] WRITE @0x20 = 0xxxbbxxxx (strb=0100, resp=0)
[1515000] READ  @0x20 = 0x12bb56aa [PASS] (resp=0)
[1565000] WRITE @0x20 = 0xddxxccxx (strb=1010, resp=0)
[1625000] READ  @0x20 = 0xddbbccaa [PASS] (resp=0)

[1625000] ===== TEST 5: Random Reset =====

[1625000] --- Random Reset Test ---
[1675000]   Asserting RESET during transaction
[1705000]   Reset released
[1775000] READ  @0x00 = 0x00000000 [PASS] (resp=0)
[1835000] READ  @0x10 = 0x00000000 [PASS] (resp=0)

[1865000] ===== TEST 6: Stress Test =====

[1865000] --- Stress Test (20 operations) ---
[1915000] WRITE @0xffffffe4 = 0xb1f05663 (strb=1111, resp=0)
[1965000] WRITE @0x34 = 0xb2c28465 (strb=1111, resp=0)
[2025000] READ  @0x04 = 0x00000000 [PASS] (resp=0)
[2075000] WRITE @0x18 = 0x1e8dcd3d (strb=1111, resp=0)
[2125000] WRITE @0x30 = 0x7cfde9f9 (strb=1111, resp=0)
[2185000] READ  @0xffffffd4 = 0x00000000 [PASS] (resp=0)
[2245000] READ  @0x14 = 0x00000000 [PASS] (resp=0)
[2295000] WRITE @0xffffffc8 = 0x47ecdb8f (strb=1111, resp=0)
[2355000] READ  @0xfffffff8 = 0x00000000 [PASS] (resp=0)
[2415000] READ  @0xffffffd4 = 0x00000000 [PASS] (resp=0)
[2475000] READ  @0xfffffff4 = 0xb2c28465 [PASS] (resp=0)
[2525000] WRITE @0xffffffd4 = 0xb1ef6263 (strb=1111, resp=0)
[2585000] READ  @0x00 = 0x00000000 [PASS] (resp=0)
[2645000] READ  @0x28 = 0x00000000 [PASS] (resp=0)
[2695000] WRITE @0xffffffd8 = 0x8983b813 (strb=1111, resp=0)
[2745000] WRITE @0xffffffcc = 0x359fdd6b (strb=1111, resp=0)
[2795000] WRITE @0xffffffc8 = 0xd7563eae (strb=1111, resp=0)
[2845000] WRITE @0xfffffffc = 0x11844923 (strb=1111, resp=0)
[2905000] READ  @0xffffffe8 = 0x00000000 [PASS] (resp=0)
[2965000] READ  @0x08 = 0xd7563eae [PASS] (resp=0)

========================================
          TEST SUMMARY
========================================
Tests Passed: 26
Tests Failed: 0

*** ALL TESTS PASSED ***

Simulation completed at 3015000
```
---

## Limitations and Future Improvements

While the AXI4-Lite interface design is fully functional for its intended scope, there are some limitations and potential improvements to consider:

### No Burst Transfers
The interface is limited to AXI4-Lite single-beat transactions. It does not support AXI4 burst transfers or multiple data beats per transaction (AXI4-Lite by definition only allows single transfers). Future extensions could implement a full AXI4 master/slave to support bursts if multi-beat transactions are required.

### Blocking Transactions
The user request interface (`wr_req/rd_req`) is essentially blocking. The user logic must wait for a transaction to complete (`*_done`) before issuing another request of the same type. The design does not queue multiple user requests internally. An improvement could be to add request buffering or pipelining to allow back-to-back command issuance. However, as it stands, one write and one read can be handled concurrently (one in each channel), but a second write cannot start until the first write is finished (and similarly for reads).

### Address Alignment and Width
The design assumes properly aligned addresses for the given data width (e.g., 32-bit word-aligned addresses). If an unaligned address were used, the lower address bits are simply ignored for indexing the register file (since `wr_addr/rd_addr` use the upper bits, e.g., `[5:2]` for 32-bit words). This means an unaligned access would effectively target the aligned address (lower two bits ignored) but still honor the byte strobes for any partial byte effect. In a real system, unaligned accesses might be disallowed or handled differently; this could be clarified or enforced in future revisions.

### Response Codes
Currently the design uses only OKAY and SLVERR response codes. Other AXI response codes (e.g., DECERR or EXOKAY) are not utilized. For AXI4-Lite this is usually sufficient, but future improvement could involve more detailed error reporting if needed.

### Extensibility
The master and slave are designed specifically to work together in this demo. In a larger system, one might integrate this slave with a different AXI master (like a microprocessor) or the master with a different AXI4-Lite slave. In such cases, the modules should be compatible as they follow the AXI4-Lite protocol, but additional features like timeouts, error injections, or more complex bus arbitration (if multiple masters/slaves) are not present. These could be added as enhancements for robustness.

### Verification
The included testbench is a basic sanity test. More thorough verification (randomized testing, formal verification of AXI compliance, etc.) could be done as a future effort to ensure the design meets all edge cases of the AXI4-Lite specification (such as handling of XREADY/XVALID toggling, etc.). Additionally, testing partial write scenarios and invalid address accesses in simulation would further validate the error-handling paths.

---

🧑‍💻 Author
- Sebastian Mătușa

