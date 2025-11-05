/******************************************************************************
*
* Module:       axi_system_top
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Top-level AXI-Lite system integration module.
*   Pure interconnect - no address decoding logic.
*   All address decoding is handled by the register_file module.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*   Rev 1.1 - Removed address decoding logic from top (Nov 2025)
*
******************************************************************************/

module axi_system_top #
(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16
)
(
    // Global signals
    input                       aclk,
    input                       aresetn,

    // User write interface
    input                       m_wr_req,
    input   [ADDR_WIDTH-1:0]    m_wr_addr,
    input   [DATA_WIDTH-1:0]    m_wr_data,
    input   [DATA_WIDTH/8-1:0]  m_wr_strb,
    output                      m_wr_done,
    output  [1:0]               m_wr_resp,

    // User read interface
    input                       m_rd_req,
    input   [ADDR_WIDTH-1:0]    m_rd_addr,
    output  [DATA_WIDTH-1:0]    m_rd_data,
    output                      m_rd_done,
    output  [1:0]               m_rd_resp
);

//
// Internal AXI wires
//
wire [ADDR_WIDTH-1:0] awaddr;
wire                  awvalid;
wire                  awready;

wire [DATA_WIDTH-1:0] wdata;
wire [DATA_WIDTH/8-1:0] wstrb;
wire                  wvalid;
wire                  wready;

wire [1:0]            bresp;
wire                  bvalid;
wire                  bready;

wire [ADDR_WIDTH-1:0] araddr;
wire                  arvalid;
wire                  arready;

wire [DATA_WIDTH-1:0] rdata_axi;
wire [1:0]            rresp_axi;
wire                  rvalid;
wire                  rready;

//
// AXI -> User bus
//
wire [ADDR_WIDTH-1:0]     user_wr_addr;
wire [DATA_WIDTH-1:0]     user_wr_data;
wire [DATA_WIDTH/8-1:0]   user_wr_strb;
wire                      user_wr_en;
wire [1:0]                user_wr_resp;

wire [ADDR_WIDTH-1:0]     user_rd_addr;
wire                      user_rd_en;
wire [DATA_WIDTH-1:0]     user_rd_data;
wire [1:0]                user_rd_resp;

//
// AXI-Lite Master
//
axi_lite_master #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) u_axi_master (
    .aclk      (aclk),
    .aresetn   (aresetn),

    .wr_req    (m_wr_req),
    .wr_addr   (m_wr_addr),
    .wr_data   (m_wr_data),
    .wr_strb   (m_wr_strb),
    .wr_done   (m_wr_done),
    .wr_resp   (m_wr_resp),

    .rd_req    (m_rd_req),
    .rd_addr   (m_rd_addr),
    .rd_data   (m_rd_data),
    .rd_done   (m_rd_done),
    .rd_resp   (m_rd_resp),

    .awready   (awready),
    .awaddr    (awaddr),
    .awvalid   (awvalid),

    .wready    (wready),
    .wdata     (wdata),
    .wstrb     (wstrb),
    .wvalid    (wvalid),

    .bresp     (bresp),
    .bvalid    (bvalid),
    .bready    (bready),

    .arready   (arready),
    .araddr    (araddr),
    .arvalid   (arvalid),

    .rdata     (rdata_axi),
    .rresp     (rresp_axi),
    .rvalid    (rvalid),
    .rready    (rready)
);

//
// AXI-Lite Slave
//
axi_lite_slave #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) u_axi_slave (
    .aclk        (aclk),
    .aresetn     (aresetn),

    .awaddr      (awaddr),
    .awvalid     (awvalid),
    .awready     (awready),

    .wdata       (wdata),
    .wstrb       (wstrb),
    .wvalid      (wvalid),
    .wready      (wready),

    .bresp       (bresp),
    .bvalid      (bvalid),
    .bready      (bready),

    .araddr      (araddr),
    .arvalid     (arvalid),
    .arready     (arready),

    .rdata       (rdata_axi),
    .rresp       (rresp_axi),
    .rvalid      (rvalid),
    .rready      (rready),

    .user_wr_addr(user_wr_addr),
    .user_wr_data(user_wr_data),
    .user_wr_strb(user_wr_strb),
    .user_wr_en  (user_wr_en),
    .user_wr_resp(user_wr_resp),

    .user_rd_addr(user_rd_addr),
    .user_rd_en  (user_rd_en),
    .user_rd_data(user_rd_data),
    .user_rd_resp(user_rd_resp)
);

//
// Register File 
//
register_file #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .NUM_REGS   (NUM_REGS)
) u_reg_file (
    .clk      (aclk),
    .rst_n    (aresetn),

    .wr_addr  (user_wr_addr), 
    .wr_data  (user_wr_data),
    .wr_strb  (user_wr_strb),
    .wr_en    (user_wr_en),
    .wr_resp  (user_wr_resp),

    .rd_addr  (user_rd_addr),  
    .rd_en    (user_rd_en),
    .rd_data  (user_rd_data),
    .rd_resp  (user_rd_resp)
);

endmodule
