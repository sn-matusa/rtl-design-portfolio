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

---

### **AXI Master External Ports**

| Signal | Direction | Width | Description |
|--------|-----------|-------|------------|
| aclk | Input | 1-bit | AXI system clock (same as top-level `clk`). |
| aresetn | Input | 1-bit | AXI reset (active-low, same as top-level `rst_n`). |

---

### **User Write Interface**

| Signal | Dir | Width | Description |
|-------|-----|-------|------------|
| wr_req | Input | 1-bit | Write request (start a write transaction). |
| wr_addr | Input | 32-bit (param) | Write address (from user). |
| wr_data | Input | 32-bit (param) | Write data (from user). |
| wr_strb | Input | 4-bit (param) | Write byte strobes (from user). |
| wr_done | Output | 1-bit | Write transaction done (1-cycle pulse when complete). |
| wr_resp | Output | 2-bit | Write response code (`BRESP`) from slave. |

---

### **User Read Interface**

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| rd_req | Input | 1-bit | Read request (start a read transaction). |
| rd_addr | Input | 32-bit (param) | Read address (from user). |
| rd_data | Output | 32-bit (param) | Read data (captured from the AXI bus response). |
| rd_done | Output | 1-bit | Read transaction done (1-cycle pulse when data is valid). |
| rd_resp | Output | 2-bit | Read response code (`RRESP`) from slave. |

---
### **AXI Write Address Channel** (master → slave)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| awaddr | Output | 32-bit (param) | AXI write address. |
| awvalid | Output | 1-bit | AXI write address valid. Master asserts to indicate a valid address/transaction. |
| awready | Input | 1-bit | AXI write address ready (from slave). Indicates slave accepted the address. |

---

### **AXI Write Data Channel** (master → slave)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| wdata | Output | 32-bit (param) | AXI write data. |
| wstrb | Output | 4-bit (param) | AXI write strobes (which bytes of wdata are valid). |
| wvalid | Output | 1-bit | AXI write data valid. Master asserts when write data is available. |
| wready | Input | 1-bit | AXI write data ready (from slave). Indicates slave accepted the data. |

---

### **AXI Write Response Channel** (slave → master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| bresp | Input | 2-bit | AXI write response code from slave (BRESP). |
| bvalid | Input | 1-bit | AXI write response valid from slave. |
| bready | Output | 1-bit | AXI write response ready. Master asserts to accept/write response. |

---

### **AXI Read Address Channel** (master → slave)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| araddr | Output | 32-bit (param) | AXI read address. |
| arvalid | Output | 1-bit | AXI read address valid. Master asserts to request a read at araddr. |
| arready | Input | 1-bit | AXI read address ready (from slave). Indicates slave accepted the read address. |

---

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

---

### AXI Write Data (slave input from master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| wdata | Input | 32-bit (param) | AXI write data from master. |
| wstrb | Input | 4-bit (param) | AXI write strobes from master. |
| wvalid | Input | 1-bit | AXI write data valid from master. |
| wready | Output | 1-bit | AXI write data ready. Slave asserts when it can accept write data. |

---

### AXI Write Response (slave → master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| bresp | Output | 2-bit | AXI write response code (BRESP) to master (e.g., OKAY or SLVERR). |
| bvalid | Output | 1-bit | AXI write response valid. Slave asserts when bresp is available. |
| bready | Input | 1-bit | AXI write response ready from master. |

---

### AXI Read Address (slave input from master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| araddr | Input | 32-bit (param) | AXI read address from master. |
| arvalid | Input | 1-bit | AXI read address valid from master. |
| arready | Output | 1-bit | AXI read address ready. Slave asserts when it can accept a read address. |

---

### AXI Read Data (slave → master)

| Signal | Dir | Width | Description |
|--------|-----|-------|-------------|
| rdata | Output | 32-bit (param) | AXI read data returning to master (from register file). |
| rresp | Output | 2-bit | AXI read response code (RRESP) to master. |
| rvalid | Output | 1-bit | AXI read data valid. Slave asserts when rdata (and rresp) are available. |
| rready | Input | 1-bit | AXI read data ready from master. |

---

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

The AXI4-Lite interface is organized into three main components connected in a pipeline: the master, the slave, and the register file. The top-level module (`axi_system_top`) instantiates and connects these components. Below is an outline of each component’s role and how they interact:

### AXI4-Lite Master
Acts as the initiator of AXI transactions. It provides a user-friendly request interface and translates those into AXI signals. Internally, it uses state machines. It asserts AWVALID/WVALID for writes or ARVALID for reads, holds them until handshake, then waits for BVALID/RVALID. Once complete, output pulses (`wr_done` / `rd_done`) and response/data captured.

### AXI4-Lite Slave
Protocol responder. Accepts address and data in any order for writes. Captures address/data and pulses `user_wr_en`. For reads, accepts AR and pulses `user_rd_en`. Returns responses and data. Only one write and one read transaction are handled at a time.

### Register File
Simple synchronous RAM with byte mask writes. Provides OKAY/SLVERR. Outputs `0xDEADBEEF` for invalid address.

---

## Timing Diagrams

Below are placeholders for timing diagrams illustrating the operation of the AXI4-Lite interface. These diagrams should show the relationship between the handshake signals and data for write and read transactions. (The user can insert waveform screenshots from simulations in place of the TODO items.)

### Write Transaction

**TODO:** Insert waveform for write transaction here.

(The write timing diagram should show signals such as `wr_req` to the master, `AWVALID/AWREADY`, `WVALID/WREADY`, and `BVALID/BREADY`, as well as `user_wr_done/user_wr_resp`, demonstrating a complete write handshake.)

### Read Transaction

**TODO:** Insert waveform for read transaction here.

(The read timing diagram should show `rd_req`, the `ARVALID/ARREADY` handshake, `RVALID/RREADY` with data, and the assertion of `user_rd_done` along with `user_rd_data` and `user_rd_resp` to illustrate a read operation.)

---

## Simulation/Testbench

The project includes a self-checking testbench module (`axi_lite_tb`) that instantiates the AXI-Lite system and generates a series of read/write transactions to verify its functionality. The testbench uses the simplified user interface of the `axi_system_top` (master interface) to drive transactions, rather than toggling AXI signals manually. This mimics how a typical user logic or processor would interact with the AXI master:

### Instantiation
The testbench instantiates the top-level AXI system (master + slave + register file). In the provided testbench, this instance is created (as `axi_lite_test`) with the default parameter configuration (32-bit address/data, 16 registers). The testbench connects to the `user_wr_*` and `user_rd_*` ports of the AXI system, effectively acting as the user logic that makes read/write requests.

### Operation Sequence

#### 1. Single Write
Write a known value to a register (e.g. write `0xABCD1234` to address `0x00000000`).  
The testbench sets `wr_req` high with the address and data, then waits for the `user_wr_done` pulse indicating the write completed.  
The `wr_resp` is checked (expected OKAY) once the write is done.

#### 2. Single Read
Read back from the same address (`0x00000000`).  
The testbench asserts `rd_req` with the address and waits for the `user_rd_done` pulse.  
It then captures `user_rd_data` and prints it, verifying that it matches the value written in the previous step.

#### 3. Multiple Writes
Writes to multiple addresses (`0x04`, `0x08`, `0x0C`) with values  
`0x11111111`, `0x22222222`, `0x33333333`.  
Each write is issued by pulsing `wr_req` with the new address and data and waiting for `wr_done`.

#### 4. Multiple Reads
Reads back from `0x04`, `0x08`, `0x0C` sequentially.  
Prints values and compares — verifying the register file integrity.

#### 5. Completion
If all matches, prints:  

A timeout mechanism stops the simulation if any transaction fails to complete (detects deadlocks/protocol issues).

### AXI Interface Verification
Even though the testbench drives user-level signals, AXI handshake is implicitly validated by proper terminations of `_done` and response correctness.  
Waveforms show VALID/READY interactions.

### Waveform Dumping
Waveforms are dumped (e.g. via `$dumpfile/$dumpvars`) so the user can view AXI interactions in GTKWave.  
Console logs print transaction events and data values.

> The provided testbench covers basic directed tests. Future improvement could include constrained-random verification, SVA formal checks, partial write strobes, invalid address accesses, and long stress sequences.

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

Overall, the current design provides a clear and modular example of an AXI4-Lite interface. Future improvements would depend on the intended use — whether to maintain it as a simple educational model or to evolve it into a more feature-complete bus interface with advanced capabilities.

