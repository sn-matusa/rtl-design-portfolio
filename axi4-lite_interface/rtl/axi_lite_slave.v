/******************************************************************************
*
* Module:       axi_lite_slave
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   AXI-Lite slave protocol controller.
*   Accepts AXI-Lite read and write requests and translates them into a
*   simplified local register file bus:
*     - user_wr_addr / user_wr_data / user_wr_en
*     - user_rd_addr / user_rd_en / user_rd_data
*
*   Handles AXI-Lite handshake signals and generates valid response channels
*   according to the specification (OKAY/SLVERR).
*
*   Decodes addresses and provides clean separation between bus protocol logic
*   and local memory/register access logic.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
******************************************************************************/

module axi_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input                       aclk,
    input                       aresetn,

    // ---------------- AXI WRITE ADDRESS ----------------
    input   [ADDR_WIDTH-1:0]   awaddr,
    input                       awvalid,
    output reg                  awready,

    // ---------------- AXI WRITE DATA -------------------
    input   [DATA_WIDTH-1:0]   wdata,
    input   [DATA_WIDTH/8-1:0] wstrb,
    input                       wvalid,
    output reg                  wready,

    // ---------------- AXI WRITE RESPONSE ---------------
    output reg [1:0]           bresp,
    output reg                  bvalid,
    input                       bready,

    // ---------------- AXI READ ADDRESS -----------------
    input   [ADDR_WIDTH-1:0]   araddr,
    input                       arvalid,
    output reg                  arready,

    // ---------------- AXI READ DATA --------------------
    output reg [DATA_WIDTH-1:0] rdata,
    output reg [1:0]            rresp,
    output reg                  rvalid,
    input                       rready,

    // ---------------- USER WRITE IF --------------------
    output reg [ADDR_WIDTH-1:0]    user_wr_addr,
    output reg [DATA_WIDTH-1:0]    user_wr_data,
    output reg [DATA_WIDTH/8-1:0]  user_wr_strb,
    output reg                     user_wr_en,
    input      [1:0]               user_wr_resp,

    // ---------------- USER READ IF ---------------------
    output reg [ADDR_WIDTH-1:0]    user_rd_addr,
    output reg                     user_rd_en,
    input      [DATA_WIDTH-1:0]    user_rd_data,
    input      [1:0]               user_rd_resp
);

    // =========================================================================
    // FSM state encoding (AXI-Lite write allows AW/W in any order)
    // =========================================================================
    localparam W_IDLE = 2'b00;
    localparam W_ADDR = 2'b01;
    localparam W_DATA = 2'b10;
    localparam W_RESP = 2'b11;

    reg [1:0] w_state, w_state_next;

    // Read FSM (simple ? one beat read)
    localparam R_IDLE = 2'b00;
    localparam R_DATA = 2'b10;

    reg [1:0] r_state, r_state_next;

    // Internal registered read response (for timing alignment)
    reg [1:0] user_rd_resp_int;

    // =========================================================================
    // WRITE FSM ? state register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            w_state <= W_IDLE;
        else
            w_state <= w_state_next;
    end

    // =========================================================================
    // WRITE FSM ? next state logic
    // Decides when address/data are received in any order
    // =========================================================================
    always @(*) begin
        w_state_next = w_state;

        case (w_state)
            W_IDLE: begin
                if (awvalid && wvalid)
                    w_state_next = W_RESP;
                else if (awvalid)
                    w_state_next = W_DATA;
                else if (wvalid)
                    w_state_next = W_ADDR;
            end

            W_ADDR: begin
                if (awvalid)
                    w_state_next = W_RESP;
            end

            W_DATA: begin
                if (wvalid)
                    w_state_next = W_RESP;
            end

            W_RESP: begin
                if (bready)
                    w_state_next = W_IDLE;
            end
        endcase
    end

    // =========================================================================
    // WRITE channel output / handshake logic
    // =========================================================================
    always @(*) begin
        awready = 1'b0;
        wready  = 1'b0;
        bvalid  = 1'b0;
        bresp   = user_wr_resp;

        case (w_state)
            W_IDLE: begin
                if (awvalid && wvalid) begin
                    awready = 1'b1;
                    wready  = 1'b1;
                end else if (awvalid) begin
                    awready = 1'b1;
                end else if (wvalid) begin
                    wready = 1'b1;
                end
            end

            W_ADDR: if (awvalid) awready = 1'b1;
            W_DATA: if (wvalid)  wready  = 1'b1;

            W_RESP: begin
                bvalid = 1'b1;
                bresp  = user_wr_resp;
            end
        endcase
    end

    // =========================================================================
    // WRITE address/data latch
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            user_wr_addr <= 0;
            user_wr_data <= 0;
            user_wr_strb <= 0;
        end
        else begin
            if (awvalid && awready)
                user_wr_addr <= awaddr;

            if (wvalid && wready) begin
                user_wr_data <= wdata;
                user_wr_strb <= wstrb;
            end
        end
    end

    // =========================================================================
    // WRITE enable pulse ? 1 cycle strobe to register file
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_wr_en <= 1'b0;
        else
            user_wr_en <= ((w_state == W_IDLE && awvalid && wvalid) ||
                           (w_state == W_ADDR && awvalid) ||
                           (w_state == W_DATA && wvalid));
    end

    // =========================================================================
    // READ FSM ? state register
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            r_state <= R_IDLE;
        else
            r_state <= r_state_next;
    end

    // =========================================================================
    // READ FSM ? next state logic
    // =========================================================================
    always @(*) begin
        r_state_next = r_state;

        case (r_state)
            R_IDLE: if (arvalid) r_state_next = R_DATA;
            R_DATA: if (rready && rvalid) r_state_next = R_IDLE;
        endcase
    end

    // =========================================================================
    // READ handshake + response logic
    // =========================================================================
    always @(*) begin
        case (r_state)
            R_IDLE: begin
                arready = 1'b1;   // Accept new read address
                rvalid  = 1'b0;
                rresp   = 2'b00;  // Default OKAY until data arrives
            end

            R_DATA: begin
                arready = 1'b0;

                // Only assert RVALID once user read response latched
                if (user_rd_resp_int == 2'b11) begin
                    rvalid = 1'b1;
                    rresp  = user_rd_resp_int;
                end else begin
                    rvalid = 1'b0;
                    rresp  = 2'b00;
                end
            end

            default: begin
                arready = 1'b0;
                rvalid  = 1'b0;
                rresp   = 2'b00;
            end
        endcase
    end

    // =========================================================================
    // READ address capture
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_addr <= 0;
        else if (arvalid && arready)
            user_rd_addr <= araddr;
    end

    // =========================================================================
    // READ request pulse to register file
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_en <= 1'b0;
        else
            user_rd_en <= (arvalid && arready);
    end

    // =========================================================================
    // Capture read data from user logic every cycle
    // (AXI-Lite read latency modeled externally)
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            rdata <= 0;
        else
            rdata <= user_rd_data;
    end

    // =========================================================================
    // Capture user read response and delay it (aligns with data)
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            user_rd_resp_int <= 2'b00;
        else
            user_rd_resp_int <= user_rd_resp;
    end

endmodule
