// (c) Copyright 1995-2020 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: analog.com:user:axi_dmac:1.0
// IP Revision: 1

(* X_CORE_INFO = "axi_dmac,Vivado 2018.3" *)
(* CHECK_LICENSE_TYPE = "system_axi_ad9361_dac_dma_0,axi_dmac,{}" *)
(* IP_DEFINITION_SOURCE = "package_project" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module system_axi_ad9361_dac_dma_0 (
  s_axi_aclk,
  s_axi_aresetn,
  s_axi_awvalid,
  s_axi_awaddr,
  s_axi_awready,
  s_axi_awprot,
  s_axi_wvalid,
  s_axi_wdata,
  s_axi_wstrb,
  s_axi_wready,
  s_axi_bvalid,
  s_axi_bresp,
  s_axi_bready,
  s_axi_arvalid,
  s_axi_araddr,
  s_axi_arready,
  s_axi_arprot,
  s_axi_rvalid,
  s_axi_rready,
  s_axi_rresp,
  s_axi_rdata,
  irq,
  m_src_axi_aclk,
  m_src_axi_aresetn,
  m_src_axi_arready,
  m_src_axi_arvalid,
  m_src_axi_araddr,
  m_src_axi_arlen,
  m_src_axi_arsize,
  m_src_axi_arburst,
  m_src_axi_arprot,
  m_src_axi_arcache,
  m_src_axi_rdata,
  m_src_axi_rready,
  m_src_axi_rvalid,
  m_src_axi_rresp,
  m_src_axi_rlast,
  fifo_rd_clk,
  fifo_rd_en,
  fifo_rd_valid,
  fifo_rd_dout,
  fifo_rd_underflow,
  fifo_rd_xfer_req
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_aclk, ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000, PHASE 0.000, CLK_DOMAIN system_sys_ps7_0_FCLK_CLK0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
input wire s_axi_aclk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
input wire s_axi_aresetn;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWVALID" *)
input wire s_axi_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWADDR" *)
input wire [10 : 0] s_axi_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWREADY" *)
output wire s_axi_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWPROT" *)
input wire [2 : 0] s_axi_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WVALID" *)
input wire s_axi_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WDATA" *)
input wire [31 : 0] s_axi_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WSTRB" *)
input wire [3 : 0] s_axi_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WREADY" *)
output wire s_axi_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BVALID" *)
output wire s_axi_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BRESP" *)
output wire [1 : 0] s_axi_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BREADY" *)
input wire s_axi_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARVALID" *)
input wire s_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARADDR" *)
input wire [10 : 0] s_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARREADY" *)
output wire s_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARPROT" *)
input wire [2 : 0] s_axi_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RVALID" *)
output wire s_axi_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RREADY" *)
input wire s_axi_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RRESP" *)
output wire [1 : 0] s_axi_rresp;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 11, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 1, PHASE 0.000, CLK_DOMAIN system_sys_ps7_0_FCLK_CLK0, NUM_READ_THREADS 1, NUM_WRITE_\
THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RDATA" *)
output wire [31 : 0] s_axi_rdata;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME irq, SENSITIVITY LEVEL_HIGH, PortWidth 1" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTERRUPT" *)
output wire irq;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_src_axi_aclk, ASSOCIATED_BUSIF m_src_axi, ASSOCIATED_RESET m_src_axi_aresetn, FREQ_HZ 100000000, PHASE 0.000, CLK_DOMAIN system_sys_ps7_0_FCLK_CLK0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 m_src_axi_aclk CLK" *)
input wire m_src_axi_aclk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_src_axi_aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 m_src_axi_aresetn RST" *)
input wire m_src_axi_aresetn;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARREADY" *)
input wire m_src_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARVALID" *)
output wire m_src_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARADDR" *)
output wire [28 : 0] m_src_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARLEN" *)
output wire [3 : 0] m_src_axi_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARSIZE" *)
output wire [2 : 0] m_src_axi_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARBURST" *)
output wire [1 : 0] m_src_axi_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARPROT" *)
output wire [2 : 0] m_src_axi_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi ARCACHE" *)
output wire [3 : 0] m_src_axi_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi RDATA" *)
input wire [63 : 0] m_src_axi_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi RREADY" *)
output wire m_src_axi_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi RVALID" *)
input wire m_src_axi_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi RRESP" *)
input wire [1 : 0] m_src_axi_rresp;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_src_axi, SUPPORTS_NARROW_BURST 0, DATA_WIDTH 64, PROTOCOL AXI3, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 29, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, NUM_READ_OUTSTANDING 8, NUM_WRITE_OUTSTANDING 0, MAX_BURST_LENGTH 16, PHASE 0.000, CLK_DOMAIN system_sys_ps7_0_FCLK_CLK0, NUM_READ_THREADS 1, NUM_WRITE_\
THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_src_axi RLAST" *)
input wire m_src_axi_rlast;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME fifo_rd_clk, FREQ_HZ 100000000, PHASE 0.000, ASSOCIATED_BUSIF fifo_rd, INSERT_VIP 0, XIL_INTERFACENAME fifo_rd_signal_clock, ASSOCIATED_BUSIF fifo_rd, FREQ_HZ 100000000, PHASE 0.000, CLK_DOMAIN system_axi_ad9361_0_l_clk, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 fifo_rd_clk CLK, xilinx.com:signal:clock:1.0 fifo_rd_signal_clock CLK" *)
input wire fifo_rd_clk;
(* X_INTERFACE_INFO = "analog.com:interface:fifo_rd:1.0 fifo_rd EN" *)
input wire fifo_rd_en;
(* X_INTERFACE_INFO = "analog.com:interface:fifo_rd:1.0 fifo_rd VALID" *)
output wire fifo_rd_valid;
(* X_INTERFACE_INFO = "analog.com:interface:fifo_rd:1.0 fifo_rd DATA" *)
output wire [31 : 0] fifo_rd_dout;
(* X_INTERFACE_INFO = "analog.com:interface:fifo_rd:1.0 fifo_rd UNDERFLOW" *)
output wire fifo_rd_underflow;
output wire fifo_rd_xfer_req;

  axi_dmac #(
    .ID(0),
    .DMA_DATA_WIDTH_SRC(64),
    .DMA_DATA_WIDTH_DEST(32),
    .DMA_LENGTH_WIDTH(24),
    .DMA_2D_TRANSFER(1'B0),
    .ASYNC_CLK_REQ_SRC(1'B0),
    .ASYNC_CLK_SRC_DEST(1'B1),
    .ASYNC_CLK_DEST_REQ(1'B1),
    .AXI_SLICE_DEST(1'B0),
    .AXI_SLICE_SRC(1'B0),
    .SYNC_TRANSFER_START(1'B0),
    .CYCLIC(1'B1),
    .DMA_AXI_PROTOCOL_DEST(1),
    .DMA_AXI_PROTOCOL_SRC(1),
    .DMA_TYPE_DEST(2),
    .DMA_TYPE_SRC(0),
    .DMA_AXI_ADDR_WIDTH(29),
    .MAX_BYTES_PER_BURST(128),
    .FIFO_SIZE(8),
    .AXI_ID_WIDTH_SRC(1),
    .AXI_ID_WIDTH_DEST(1),
    .DMA_AXIS_ID_W(8),
    .DMA_AXIS_DEST_W(4),
    .DISABLE_DEBUG_REGISTERS(1'B0),
    .ENABLE_DIAGNOSTICS_IF(1'B0),
    .ALLOW_ASYM_MEM(1)
  ) inst (
    .s_axi_aclk(s_axi_aclk),
    .s_axi_aresetn(s_axi_aresetn),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awready(s_axi_awready),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wready(s_axi_wready),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bready(s_axi_bready),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arready(s_axi_arready),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rdata(s_axi_rdata),
    .irq(irq),
    .m_dest_axi_aclk(1'B0),
    .m_dest_axi_aresetn(1'B0),
    .m_dest_axi_awaddr(),
    .m_dest_axi_awlen(),
    .m_dest_axi_awsize(),
    .m_dest_axi_awburst(),
    .m_dest_axi_awprot(),
    .m_dest_axi_awcache(),
    .m_dest_axi_awvalid(),
    .m_dest_axi_awready(1'B0),
    .m_dest_axi_awid(),
    .m_dest_axi_awlock(),
    .m_dest_axi_wdata(),
    .m_dest_axi_wstrb(),
    .m_dest_axi_wready(1'B0),
    .m_dest_axi_wvalid(),
    .m_dest_axi_wlast(),
    .m_dest_axi_wid(),
    .m_dest_axi_bvalid(1'B0),
    .m_dest_axi_bresp(2'B0),
    .m_dest_axi_bready(),
    .m_dest_axi_bid(1'B0),
    .m_dest_axi_arvalid(),
    .m_dest_axi_araddr(),
    .m_dest_axi_arlen(),
    .m_dest_axi_arsize(),
    .m_dest_axi_arburst(),
    .m_dest_axi_arcache(),
    .m_dest_axi_arprot(),
    .m_dest_axi_arready(1'B0),
    .m_dest_axi_rvalid(1'B0),
    .m_dest_axi_rresp(2'B0),
    .m_dest_axi_rdata(32'B0),
    .m_dest_axi_rready(),
    .m_dest_axi_arid(),
    .m_dest_axi_arlock(),
    .m_dest_axi_rid(1'B0),
    .m_dest_axi_rlast(1'B0),
    .m_src_axi_aclk(m_src_axi_aclk),
    .m_src_axi_aresetn(m_src_axi_aresetn),
    .m_src_axi_arready(m_src_axi_arready),
    .m_src_axi_arvalid(m_src_axi_arvalid),
    .m_src_axi_araddr(m_src_axi_araddr),
    .m_src_axi_arlen(m_src_axi_arlen),
    .m_src_axi_arsize(m_src_axi_arsize),
    .m_src_axi_arburst(m_src_axi_arburst),
    .m_src_axi_arprot(m_src_axi_arprot),
    .m_src_axi_arcache(m_src_axi_arcache),
    .m_src_axi_arid(),
    .m_src_axi_arlock(),
    .m_src_axi_rdata(m_src_axi_rdata),
    .m_src_axi_rready(m_src_axi_rready),
    .m_src_axi_rvalid(m_src_axi_rvalid),
    .m_src_axi_rresp(m_src_axi_rresp),
    .m_src_axi_rid(1'B0),
    .m_src_axi_rlast(m_src_axi_rlast),
    .m_src_axi_awvalid(),
    .m_src_axi_awaddr(),
    .m_src_axi_awlen(),
    .m_src_axi_awsize(),
    .m_src_axi_awburst(),
    .m_src_axi_awcache(),
    .m_src_axi_awprot(),
    .m_src_axi_awready(1'B0),
    .m_src_axi_wvalid(),
    .m_src_axi_wdata(),
    .m_src_axi_wstrb(),
    .m_src_axi_wlast(),
    .m_src_axi_wready(1'B0),
    .m_src_axi_bvalid(1'B0),
    .m_src_axi_bresp(2'B0),
    .m_src_axi_bready(),
    .m_src_axi_awid(),
    .m_src_axi_awlock(),
    .m_src_axi_wid(),
    .m_src_axi_bid(1'B0),
    .s_axis_aclk(1'B0),
    .s_axis_ready(),
    .s_axis_valid(1'B0),
    .s_axis_data(64'B0),
    .s_axis_strb(8'B0),
    .s_axis_keep(8'B0),
    .s_axis_user(1'B1),
    .s_axis_id(8'B0),
    .s_axis_dest(4'B0),
    .s_axis_last(1'B0),
    .s_axis_xfer_req(),
    .m_axis_aclk(1'B0),
    .m_axis_ready(1'B0),
    .m_axis_valid(),
    .m_axis_data(),
    .m_axis_strb(),
    .m_axis_keep(),
    .m_axis_user(),
    .m_axis_id(),
    .m_axis_dest(),
    .m_axis_last(),
    .m_axis_xfer_req(),
    .fifo_wr_clk(1'B0),
    .fifo_wr_en(1'B0),
    .fifo_wr_din(64'B0),
    .fifo_wr_overflow(),
    .fifo_wr_sync(1'B1),
    .fifo_wr_xfer_req(),
    .fifo_rd_clk(fifo_rd_clk),
    .fifo_rd_en(fifo_rd_en),
    .fifo_rd_valid(fifo_rd_valid),
    .fifo_rd_dout(fifo_rd_dout),
    .fifo_rd_underflow(fifo_rd_underflow),
    .fifo_rd_xfer_req(fifo_rd_xfer_req),
    .dest_diag_level_bursts()
  );
endmodule
