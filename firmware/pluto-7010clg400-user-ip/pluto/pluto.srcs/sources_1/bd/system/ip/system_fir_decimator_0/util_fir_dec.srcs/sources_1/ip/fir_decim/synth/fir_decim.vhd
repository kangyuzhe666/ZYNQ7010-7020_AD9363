-- (c) Copyright 1995-2020 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:fir_compiler:7.2
-- IP Revision: 11

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY fir_compiler_v7_2_11;
USE fir_compiler_v7_2_11.fir_compiler_v7_2_11;

ENTITY fir_decim IS
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END fir_decim;

ARCHITECTURE fir_decim_arch OF fir_decim IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF fir_decim_arch: ARCHITECTURE IS "yes";
  COMPONENT fir_compiler_v7_2_11 IS
    GENERIC (
      C_XDEVICEFAMILY : STRING;
      C_ELABORATION_DIR : STRING;
      C_COMPONENT_NAME : STRING;
      C_COEF_FILE : STRING;
      C_COEF_FILE_LINES : INTEGER;
      C_FILTER_TYPE : INTEGER;
      C_INTERP_RATE : INTEGER;
      C_DECIM_RATE : INTEGER;
      C_ZERO_PACKING_FACTOR : INTEGER;
      C_SYMMETRY : INTEGER;
      C_NUM_FILTS : INTEGER;
      C_NUM_TAPS : INTEGER;
      C_NUM_CHANNELS : INTEGER;
      C_CHANNEL_PATTERN : STRING;
      C_ROUND_MODE : INTEGER;
      C_COEF_RELOAD : INTEGER;
      C_NUM_RELOAD_SLOTS : INTEGER;
      C_COL_MODE : INTEGER;
      C_COL_PIPE_LEN : INTEGER;
      C_COL_CONFIG : STRING;
      C_OPTIMIZATION : INTEGER;
      C_DATA_PATH_WIDTHS : STRING;
      C_DATA_IP_PATH_WIDTHS : STRING;
      C_DATA_PX_PATH_WIDTHS : STRING;
      C_DATA_WIDTH : INTEGER;
      C_COEF_PATH_WIDTHS : STRING;
      C_COEF_WIDTH : INTEGER;
      C_DATA_PATH_SRC : STRING;
      C_COEF_PATH_SRC : STRING;
      C_PX_PATH_SRC : STRING;
      C_DATA_PATH_SIGN : STRING;
      C_COEF_PATH_SIGN : STRING;
      C_ACCUM_PATH_WIDTHS : STRING;
      C_OUTPUT_WIDTH : INTEGER;
      C_OUTPUT_PATH_WIDTHS : STRING;
      C_ACCUM_OP_PATH_WIDTHS : STRING;
      C_EXT_MULT_CNFG : STRING;
      C_DATA_PATH_PSAMP_SRC : STRING;
      C_OP_PATH_PSAMP_SRC : STRING;
      C_NUM_MADDS : INTEGER;
      C_OPT_MADDS : STRING;
      C_OVERSAMPLING_RATE : INTEGER;
      C_INPUT_RATE : INTEGER;
      C_OUTPUT_RATE : INTEGER;
      C_DATA_MEMTYPE : INTEGER;
      C_COEF_MEMTYPE : INTEGER;
      C_IPBUFF_MEMTYPE : INTEGER;
      C_OPBUFF_MEMTYPE : INTEGER;
      C_DATAPATH_MEMTYPE : INTEGER;
      C_MEM_ARRANGEMENT : INTEGER;
      C_DATA_MEM_PACKING : INTEGER;
      C_COEF_MEM_PACKING : INTEGER;
      C_FILTS_PACKED : INTEGER;
      C_LATENCY : INTEGER;
      C_HAS_ARESETn : INTEGER;
      C_HAS_ACLKEN : INTEGER;
      C_DATA_HAS_TLAST : INTEGER;
      C_S_DATA_HAS_FIFO : INTEGER;
      C_S_DATA_HAS_TUSER : INTEGER;
      C_S_DATA_TDATA_WIDTH : INTEGER;
      C_S_DATA_TUSER_WIDTH : INTEGER;
      C_M_DATA_HAS_TREADY : INTEGER;
      C_M_DATA_HAS_TUSER : INTEGER;
      C_M_DATA_TDATA_WIDTH : INTEGER;
      C_M_DATA_TUSER_WIDTH : INTEGER;
      C_HAS_CONFIG_CHANNEL : INTEGER;
      C_CONFIG_SYNC_MODE : INTEGER;
      C_CONFIG_PACKET_SIZE : INTEGER;
      C_CONFIG_TDATA_WIDTH : INTEGER;
      C_RELOAD_TDATA_WIDTH : INTEGER
    );
    PORT (
      aresetn : IN STD_LOGIC;
      aclk : IN STD_LOGIC;
      aclken : IN STD_LOGIC;
      s_axis_data_tvalid : IN STD_LOGIC;
      s_axis_data_tready : OUT STD_LOGIC;
      s_axis_data_tlast : IN STD_LOGIC;
      s_axis_data_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_config_tvalid : IN STD_LOGIC;
      s_axis_config_tready : OUT STD_LOGIC;
      s_axis_config_tlast : IN STD_LOGIC;
      s_axis_config_tdata : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axis_reload_tvalid : IN STD_LOGIC;
      s_axis_reload_tready : OUT STD_LOGIC;
      s_axis_reload_tlast : IN STD_LOGIC;
      s_axis_reload_tdata : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      m_axis_data_tvalid : OUT STD_LOGIC;
      m_axis_data_tready : IN STD_LOGIC;
      m_axis_data_tlast : OUT STD_LOGIC;
      m_axis_data_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      event_s_data_tlast_missing : OUT STD_LOGIC;
      event_s_data_tlast_unexpected : OUT STD_LOGIC;
      event_s_data_chanid_incorrect : OUT STD_LOGIC;
      event_s_config_tlast_missing : OUT STD_LOGIC;
      event_s_config_tlast_unexpected : OUT STD_LOGIC;
      event_s_reload_tlast_missing : OUT STD_LOGIC;
      event_s_reload_tlast_unexpected : OUT STD_LOGIC
    );
  END COMPONENT fir_compiler_v7_2_11;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF fir_decim_arch: ARCHITECTURE IS "fir_compiler_v7_2_11,Vivado 2018.3";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF fir_decim_arch : ARCHITECTURE IS "fir_decim,fir_compiler_v7_2_11,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF fir_decim_arch: ARCHITECTURE IS "fir_decim,fir_compiler_v7_2_11,{x_ipProduct=Vivado 2018.3,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=fir_compiler,x_ipVersion=7.2,x_ipCoreRevision=11,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_XDEVICEFAMILY=zynq,C_ELABORATION_DIR=./,C_COMPONENT_NAME=fir_decim,C_COEF_FILE=fir_decim.mif,C_COEF_FILE_LINES=72,C_FILTER_TYPE=1,C_INTERP_RATE=1,C_DECIM_RATE=8,C_ZERO_PACKING_FACTOR=1,C_SYMMETRY=1,C_NUM_FILTS=1,C_NUM_TAPS=129,C_NUM_CHANNELS=1,C_CHANNEL_PATTERN=fixed,C_ROUND_MODE=2,C_COEF_RELOAD=0,C_N" & 
"UM_RELOAD_SLOTS=1,C_COL_MODE=1,C_COL_PIPE_LEN=4,C_COL_CONFIG=9,C_OPTIMIZATION=0,C_DATA_PATH_WIDTHS=16_16,C_DATA_IP_PATH_WIDTHS=16_16,C_DATA_PX_PATH_WIDTHS=16_16,C_DATA_WIDTH=16,C_COEF_PATH_WIDTHS=16_16,C_COEF_WIDTH=16,C_DATA_PATH_SRC=0_1,C_COEF_PATH_SRC=0_0,C_PX_PATH_SRC=0_1,C_DATA_PATH_SIGN=0_0,C_COEF_PATH_SIGN=0_0,C_ACCUM_PATH_WIDTHS=34_34,C_OUTPUT_WIDTH=16,C_OUTPUT_PATH_WIDTHS=16_16,C_ACCUM_OP_PATH_WIDTHS=34_34,C_EXT_MULT_CNFG=none,C_DATA_PATH_PSAMP_SRC=0,C_OP_PATH_PSAMP_SRC=0,C_NUM_MADDS=9,C" & 
"_OPT_MADDS=none,C_OVERSAMPLING_RATE=1,C_INPUT_RATE=1,C_OUTPUT_RATE=8,C_DATA_MEMTYPE=0,C_COEF_MEMTYPE=2,C_IPBUFF_MEMTYPE=2,C_OPBUFF_MEMTYPE=0,C_DATAPATH_MEMTYPE=2,C_MEM_ARRANGEMENT=1,C_DATA_MEM_PACKING=0,C_COEF_MEM_PACKING=0,C_FILTS_PACKED=0,C_LATENCY=17,C_HAS_ARESETn=0,C_HAS_ACLKEN=0,C_DATA_HAS_TLAST=0,C_S_DATA_HAS_FIFO=1,C_S_DATA_HAS_TUSER=0,C_S_DATA_TDATA_WIDTH=32,C_S_DATA_TUSER_WIDTH=1,C_M_DATA_HAS_TREADY=0,C_M_DATA_HAS_TUSER=0,C_M_DATA_TDATA_WIDTH=32,C_M_DATA_TUSER_WIDTH=1,C_HAS_CONFIG_CHANN" & 
"EL=0,C_CONFIG_SYNC_MODE=0,C_CONFIG_PACKET_SIZE=0,C_CONFIG_TDATA_WIDTH=1,C_RELOAD_TDATA_WIDTH=1}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_data_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DATA TDATA";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axis_data_tvalid: SIGNAL IS "XIL_INTERFACENAME M_AXIS_DATA, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_data_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DATA TVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_data_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_DATA TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_data_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_DATA TREADY";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axis_data_tvalid: SIGNAL IS "XIL_INTERFACENAME S_AXIS_DATA, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.000, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_data_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_DATA TVALID";
  ATTRIBUTE X_INTERFACE_PARAMETER OF aclk: SIGNAL IS "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF S_AXIS_CONFIG:M_AXIS_DATA:S_AXIS_DATA:S_AXIS_RELOAD, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 100000000, PHASE 0.000, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF aclk: SIGNAL IS "xilinx.com:signal:clock:1.0 aclk_intf CLK";
BEGIN
  U0 : fir_compiler_v7_2_11
    GENERIC MAP (
      C_XDEVICEFAMILY => "zynq",
      C_ELABORATION_DIR => "./",
      C_COMPONENT_NAME => "fir_decim",
      C_COEF_FILE => "fir_decim.mif",
      C_COEF_FILE_LINES => 72,
      C_FILTER_TYPE => 1,
      C_INTERP_RATE => 1,
      C_DECIM_RATE => 8,
      C_ZERO_PACKING_FACTOR => 1,
      C_SYMMETRY => 1,
      C_NUM_FILTS => 1,
      C_NUM_TAPS => 129,
      C_NUM_CHANNELS => 1,
      C_CHANNEL_PATTERN => "fixed",
      C_ROUND_MODE => 2,
      C_COEF_RELOAD => 0,
      C_NUM_RELOAD_SLOTS => 1,
      C_COL_MODE => 1,
      C_COL_PIPE_LEN => 4,
      C_COL_CONFIG => "9",
      C_OPTIMIZATION => 0,
      C_DATA_PATH_WIDTHS => "16,16",
      C_DATA_IP_PATH_WIDTHS => "16,16",
      C_DATA_PX_PATH_WIDTHS => "16,16",
      C_DATA_WIDTH => 16,
      C_COEF_PATH_WIDTHS => "16,16",
      C_COEF_WIDTH => 16,
      C_DATA_PATH_SRC => "0,1",
      C_COEF_PATH_SRC => "0,0",
      C_PX_PATH_SRC => "0,1",
      C_DATA_PATH_SIGN => "0,0",
      C_COEF_PATH_SIGN => "0,0",
      C_ACCUM_PATH_WIDTHS => "34,34",
      C_OUTPUT_WIDTH => 16,
      C_OUTPUT_PATH_WIDTHS => "16,16",
      C_ACCUM_OP_PATH_WIDTHS => "34,34",
      C_EXT_MULT_CNFG => "none",
      C_DATA_PATH_PSAMP_SRC => "0",
      C_OP_PATH_PSAMP_SRC => "0",
      C_NUM_MADDS => 9,
      C_OPT_MADDS => "none",
      C_OVERSAMPLING_RATE => 1,
      C_INPUT_RATE => 1,
      C_OUTPUT_RATE => 8,
      C_DATA_MEMTYPE => 0,
      C_COEF_MEMTYPE => 2,
      C_IPBUFF_MEMTYPE => 2,
      C_OPBUFF_MEMTYPE => 0,
      C_DATAPATH_MEMTYPE => 2,
      C_MEM_ARRANGEMENT => 1,
      C_DATA_MEM_PACKING => 0,
      C_COEF_MEM_PACKING => 0,
      C_FILTS_PACKED => 0,
      C_LATENCY => 17,
      C_HAS_ARESETn => 0,
      C_HAS_ACLKEN => 0,
      C_DATA_HAS_TLAST => 0,
      C_S_DATA_HAS_FIFO => 1,
      C_S_DATA_HAS_TUSER => 0,
      C_S_DATA_TDATA_WIDTH => 32,
      C_S_DATA_TUSER_WIDTH => 1,
      C_M_DATA_HAS_TREADY => 0,
      C_M_DATA_HAS_TUSER => 0,
      C_M_DATA_TDATA_WIDTH => 32,
      C_M_DATA_TUSER_WIDTH => 1,
      C_HAS_CONFIG_CHANNEL => 0,
      C_CONFIG_SYNC_MODE => 0,
      C_CONFIG_PACKET_SIZE => 0,
      C_CONFIG_TDATA_WIDTH => 1,
      C_RELOAD_TDATA_WIDTH => 1
    )
    PORT MAP (
      aresetn => '1',
      aclk => aclk,
      aclken => '1',
      s_axis_data_tvalid => s_axis_data_tvalid,
      s_axis_data_tready => s_axis_data_tready,
      s_axis_data_tlast => '0',
      s_axis_data_tuser => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      s_axis_data_tdata => s_axis_data_tdata,
      s_axis_config_tvalid => '0',
      s_axis_config_tlast => '0',
      s_axis_config_tdata => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      s_axis_reload_tvalid => '0',
      s_axis_reload_tlast => '0',
      s_axis_reload_tdata => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      m_axis_data_tvalid => m_axis_data_tvalid,
      m_axis_data_tready => '1',
      m_axis_data_tdata => m_axis_data_tdata
    );
END fir_decim_arch;
