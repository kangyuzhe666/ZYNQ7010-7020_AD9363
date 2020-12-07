--soft_reset.vhd   v1.01a
-------------------------------------------------------------------------------
--
-- *************************************************************************
-- **                                                                     **
-- ** DISCLAIMER OF LIABILITY                                             **
-- **                                                                     **
-- ** This text/file contains proprietary, confidential                   **
-- ** information of Xilinx, Inc., is distributed under                   **
-- ** license from Xilinx, Inc., and may be used, copied                  **
-- ** and/or disclosed only pursuant to the terms of a valid              **
-- ** license agreement with Xilinx, Inc. Xilinx hereby                   **
-- ** grants you a license to use this text/file solely for               **
-- ** design, simulation, implementation and creation of                  **
-- ** design files limited to Xilinx devices or technologies.             **
-- ** Use with non-Xilinx devices or technologies is expressly            **
-- ** prohibited and immediately terminates your license unless           **
-- ** covered by a separate agreement.                                    **
-- **                                                                     **
-- ** Xilinx is providing this design, code, or information               **
-- ** "as-is" solely for use in developing programs and                   **
-- ** solutions for Xilinx devices, with no obligation on the             **
-- ** part of Xilinx to provide support. By providing this design,        **
-- ** code, or information as one possible implementation of              **
-- ** this feature, application or standard, Xilinx is making no          **
-- ** representation that this implementation is free from any            **
-- ** claims of infringement. You are responsible for obtaining           **
-- ** any rights you may require for your implementation.                 **
-- ** Xilinx expressly disclaims any warranty whatsoever with             **
-- ** respect to the adequacy of the implementation, including            **
-- ** but not limited to any warranties or representations that this      **
-- ** implementation is free from claims of infringement, implied         **
-- ** warranties of merchantability or fitness for a particular           **
-- ** purpose.                                                            **
-- **                                                                     **
-- ** Xilinx products are not intended for use in life support            **
-- ** appliances, devices, or systems. Use in such applications is        **
-- ** expressly prohibited.                                               **
-- **                                                                     **
-- ** Any modifications that are made to the Source Code are              **
-- ** done at the user’s sole risk and will be unsupported.               **
-- ** The Xilinx Support Hotline does not have access to source           **
-- ** code and therefore cannot answer specific questions related         **
-- ** to source HDL. The Xilinx Hotline support of original source        **
-- ** code IP shall only address issues and questions related             **
-- ** to the standard Netlist version of the core (and thus               **
-- ** indirectly, the original core source).                              **
-- **                                                                     **
-- ** Copyright (c) 2006-2010 Xilinx, Inc. All rights reserved.           **
-- **                                                                     **
-- ** This copyright and support notice must be retained as part          **
-- ** of this text at all times.                                          **
-- **                                                                     **
-- *************************************************************************
--
-------------------------------------------------------------------------------
-- Filename:        soft_reset.vhd
-- Version:         v1_00_a
-- Description:     This VHDL design file is the Soft Reset Service
--
-------------------------------------------------------------------------------
-- Structure:   
--
--              soft_reset.vhd
--                  
--
-------------------------------------------------------------------------------
-- Author:      Gary Burch
--
-- History:
--     GAB     Aug 2, 2006  v1.00a (initial release)
--
--
--     DET     1/17/2008     v4_0
-- ~~~~~~
--     - Incorporated new disclaimer header
-- ^^^^^^
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
-- Library definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------

entity soft_reset is
    generic (
        C_SIPIF_DWIDTH          : integer := 32;
            -- Width of the write data bus

        C_RESET_WIDTH           : integer := 4     
            -- Width of triggered reset in Bus Clocks
    ); 
    port (
  
        -- Inputs From the IPIF Bus 
        Bus2IP_Reset        : in  std_logic;
        Bus2IP_Clk          : in  std_logic;
        Bus2IP_WrCE         : in  std_logic;
        Bus2IP_Data         : in  std_logic_vector(0 to C_SIPIF_DWIDTH-1);
        Bus2IP_BE           : in  std_logic_vector(0 to (C_SIPIF_DWIDTH/8)-1);

        -- Final Device Reset Output
        Reset2IP_Reset      : out std_logic; 

        -- Status Reply Outputs to the Bus 
        Reset2Bus_WrAck     : out std_logic;
        Reset2Bus_Error     : out std_logic;
        Reset2Bus_ToutSup   : out std_logic
    
    );
  end soft_reset ;
  
  

-------------------------------------------------------------------------------

architecture implementation of soft_reset is

-------------------------------------------------------------------------------
-- Function Declarations 
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Type Declarations
-------------------------------------------------------------------------------
    
-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------

-- Module Software Reset screen value for write data
-- This requires a Hex 'A' to be written to ativate the S/W reset port
constant RESET_MATCH    : std_logic_vector(0 to 3) := "1010"; 
                                                           
-- Required BE index to be active during Reset activation
constant BE_MATCH       : integer := 3; 
                                                            
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

signal sm_reset         : std_logic;
signal error_reply      : std_logic;
signal reset_wrack      : std_logic;
signal reset_error      : std_logic;
signal reset_trig       : std_logic;
signal wrack            : std_logic;
signal wrack_ff_chain   : std_logic;
signal flop_q_chain     : std_logic_vector(0 to C_RESET_WIDTH);
--signal bus2ip_wrce_d1   : std_logic;

signal data_is_non_reset_match  : std_logic;
signal sw_rst_cond              : std_logic;
signal sw_rst_cond_d1           : std_logic;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
  
begin
           
-- Misc assignments         
Reset2Bus_WrAck     <= reset_wrack;
Reset2Bus_Error     <= reset_error;
Reset2Bus_ToutSup   <= sm_reset; -- Suppress a data phase timeout when
                                 -- a commanded reset is active.

reset_wrack         <=  (reset_error or wrack);-- and Bus2IP_WrCE;
reset_error         <=  data_is_non_reset_match and Bus2IP_WrCE;
Reset2IP_Reset      <=  Bus2IP_Reset or sm_reset;
      
---------------------------------------------------------------------------------
---- Register WRCE for use in creating a strobe pulse
---------------------------------------------------------------------------------
--REG_WRCE : process(Bus2IP_Clk)
--    begin
--        if(Bus2IP_Clk'EVENT and Bus2IP_Clk = '1')then
--            if(Bus2IP_Reset = '1')then
--                bus2ip_wrce_d1 <= '0';
--            else
--                bus2ip_wrce_d1 <= Bus2IP_WrCE;
--            end if;
--        end if;
--    end process REG_WRCE;
--
-------------------------------------------------------------------------------
-- Start the S/W reset state machine as a result of an IPIF Bus write to
-- the Reset port and the data on the DBus inputs matching the Reset 
-- match value. If the value on the data bus input does not match the 
-- designated reset key, an error acknowledge is generated.
-------------------------------------------------------------------------------
--DETECT_SW_RESET : process (Bus2IP_Clk)
--    begin
--        if(Bus2IP_Clk'EVENT and Bus2IP_Clk = '1') then
--            if (Bus2IP_Reset = '1') then
--                error_reply       <= '0';
--                reset_trig        <= '0';
--            elsif (Bus2IP_WrCE = '1' 
--            and Bus2IP_BE(BE_MATCH) = '1'
--            and Bus2IP_Data(28 to 31) = RESET_MATCH) then
--                error_reply       <= '0';
--                reset_trig        <= Bus2IP_WrCE and not bus2ip_wrce_d1;
--            elsif (Bus2IP_WrCE = '1') then 
--                error_reply       <= '1';
--                reset_trig        <= '0';
--            else
--                error_reply       <= '0';
--                reset_trig        <= '0';
--            end if;
--        end if;
--    end process DETECT_SW_RESET;


    data_is_non_reset_match <=
        '0' when (Bus2IP_Data(C_SIPIF_DWIDTH-4 to C_SIPIF_DWIDTH-1) = RESET_MATCH
             and Bus2IP_BE(BE_MATCH) = '1')
        else '1';

--------------------------------------------------------------------------------
-- SW Reset
--------------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    sw_rst_cond <= Bus2IP_WrCE and not data_is_non_reset_match;
    --
    RST_PULSE_PROC : process (Bus2IP_Clk)
    Begin
       if (Bus2IP_Clk'EVENT and Bus2IP_Clk = '1') Then
           if (Bus2IP_Reset = '1') Then
              sw_rst_cond_d1    <= '0';
              reset_trig        <= '0';
           else
              sw_rst_cond_d1    <= sw_rst_cond;
              reset_trig        <= sw_rst_cond and not sw_rst_cond_d1;
           end if;
       end if;
    End process;

        
-------------------------------------------------------------------------------
-- RESET_FLOPS:
-- This FORGEN implements the register chain used to create 
-- the parameterizable reset pulse width.
-------------------------------------------------------------------------------
RESET_FLOPS : for index in 0 to C_RESET_WIDTH-1 generate

    flop_q_chain(0) <= '0';

    RST_FLOPS : FDRSE
        port map(
            Q   =>  flop_q_chain(index+1), -- :    out std_logic;
            C   =>  Bus2IP_Clk,            -- :    in  std_logic;
            CE  =>  '1',                   -- :    in  std_logic;
            D   =>  flop_q_chain(index),   -- :    in  std_logic;    
            R   =>  Bus2IP_Reset,          -- :    in  std_logic;
            S   =>  reset_trig             -- :    in  std_logic
        );

end generate RESET_FLOPS;

    
-- Use the last flop output for the commanded reset pulse 
sm_reset        <= flop_q_chain(C_RESET_WIDTH);

wrack_ff_chain  <= flop_q_chain(C_RESET_WIDTH) and 
                    not(flop_q_chain(C_RESET_WIDTH-1));


-- Register the Write Acknowledge for the Reset write
-- This is generated at the end of the reset pulse. This
-- keeps the Slave busy until the commanded reset completes.
FF_WRACK : FDRSE
    port map(
        Q   =>  wrack,            -- :  out std_logic;
        C   =>  Bus2IP_Clk,       -- :  in  std_logic;
        CE  =>  '1',              -- :  in  std_logic;
        D   =>  wrack_ff_chain,   -- :  in  std_logic;    
        R   =>  Bus2IP_Reset,     -- :  in  std_logic;
        S   =>  '0'               -- :  in  std_logic
    );


end implementation;


 








-- SRL_FIFO entity and architecture
-------------------------------------------------------------------------------
--
-- *************************************************************************
-- **                                                                     **
-- ** DISCLAIMER OF LIABILITY                                             **
-- **                                                                     **
-- ** This text/file contains proprietary, confidential                   **
-- ** information of Xilinx, Inc., is distributed under                   **
-- ** license from Xilinx, Inc., and may be used, copied                  **
-- ** and/or disclosed only pursuant to the terms of a valid              **
-- ** license agreement with Xilinx, Inc. Xilinx hereby                   **
-- ** grants you a license to use this text/file solely for               **
-- ** design, simulation, implementation and creation of                  **
-- ** design files limited to Xilinx devices or technologies.             **
-- ** Use with non-Xilinx devices or technologies is expressly            **
-- ** prohibited and immediately terminates your license unless           **
-- ** covered by a separate agreement.                                    **
-- **                                                                     **
-- ** Xilinx is providing this design, code, or information               **
-- ** "as-is" solely for use in developing programs and                   **
-- ** solutions for Xilinx devices, with no obligation on the             **
-- ** part of Xilinx to provide support. By providing this design,        **
-- ** code, or information as one possible implementation of              **
-- ** this feature, application or standard, Xilinx is making no          **
-- ** representation that this implementation is free from any            **
-- ** claims of infringement. You are responsible for obtaining           **
-- ** any rights you may require for your implementation.                 **
-- ** Xilinx expressly disclaims any warranty whatsoever with             **
-- ** respect to the adequacy of the implementation, including            **
-- ** but not limited to any warranties or representations that this      **
-- ** implementation is free from claims of infringement, implied         **
-- ** warranties of merchantability or fitness for a particular           **
-- ** purpose.                                                            **
-- **                                                                     **
-- ** Xilinx products are not intended for use in life support            **
-- ** appliances, devices, or systems. Use in such applications is        **
-- ** expressly prohibited.                                               **
-- **                                                                     **
-- ** Any modifications that are made to the Source Code are              **
-- ** done at the user’s sole risk and will be unsupported.               **
-- ** The Xilinx Support Hotline does not have access to source           **
-- ** code and therefore cannot answer specific questions related         **
-- ** to source HDL. The Xilinx Hotline support of original source        **
-- ** code IP shall only address issues and questions related             **
-- ** to the standard Netlist version of the core (and thus               **
-- ** indirectly, the original core source).                              **
-- **                                                                     **
-- ** Copyright (c) 2001-2010 Xilinx, Inc. All rights reserved.           **
-- **                                                                     **
-- ** This copyright and support notice must be retained as part          **
-- ** of this text at all times.                                          **
-- **                                                                     **
-- *************************************************************************
--
-------------------------------------------------------------------------------
-- Filename:        srl_fifo.vhd
--
-- Description:     
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--              srl_fifo.vhd
--
-------------------------------------------------------------------------------
-- Author:          goran
-- Revision:        $Revision: 1.1.4.1 $
-- Date:            $Date: 2010/09/14 22:35:47 $
--
-- History:
--   goran  2001-05-11    First Version
--   KC     2001-06-20    Added Addr as an output port, for use as an occupancy
--                        value
--
--   DCW    2002-03-12    Structural implementation of synchronous reset for
--                        Data_Exists DFF (using FDR)
--   jam    2002-04-12    added C_XON generic for mixed vhdl/verilog sims
--
--   als    2002-04-18    added default for XON generic in SRL16E, FDRE, and FDR
--                        component declarations
--
--     DET     1/17/2008     v5_0
-- ~~~~~~
--     - Incorporated new disclaimer header
-- ^^^^^^
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
library unisim;
use unisim.all;

entity SRL_FIFO is
  generic (
    C_DATA_BITS : natural := 8;
    C_DEPTH     : natural := 16;
    C_XON       : boolean := false
    );
  port (
    Clk         : in  std_logic;
    Reset       : in  std_logic;
    FIFO_Write  : in  std_logic;
    Data_In     : in  std_logic_vector(0 to C_DATA_BITS-1);
    FIFO_Read   : in  std_logic;
    Data_Out    : out std_logic_vector(0 to C_DATA_BITS-1);
    FIFO_Full   : out std_logic;
    Data_Exists : out std_logic;
    Addr        : out std_logic_vector(0 to 3) -- Added Addr as a port
    );

end entity SRL_FIFO;

architecture IMP of SRL_FIFO is

  component SRL16E is
      -- pragma translate_off
    generic (
      INIT : bit_vector := X"0000"
      );
      -- pragma translate_on    
    port (
      CE  : in  std_logic;
      D   : in  std_logic;
      Clk : in  std_logic;
      A0  : in  std_logic;
      A1  : in  std_logic;
      A2  : in  std_logic;
      A3  : in  std_logic;
      Q   : out std_logic);
  end component SRL16E;

  component LUT4
    generic(
      INIT : bit_vector := X"0000"
      );
    port (
      O  : out std_logic;
      I0 : in  std_logic;
      I1 : in  std_logic;
      I2 : in  std_logic;
      I3 : in  std_logic);
  end component;

  component MULT_AND
    port (
      I0 : in  std_logic;
      I1 : in  std_logic;
      LO : out std_logic);
  end component;

  component MUXCY_L
    port (
      DI : in  std_logic;
      CI : in  std_logic;
      S  : in  std_logic;
      LO : out std_logic);
  end component;

  component XORCY
    port (
      LI : in  std_logic;
      CI : in  std_logic;
      O  : out std_logic);
  end component;

  component FDRE is
    port (
      Q  : out std_logic;
      C  : in  std_logic;
      CE : in  std_logic;
      D  : in  std_logic;
      R  : in  std_logic);
  end component FDRE;

  component FDR is
    port (
      Q  : out std_logic;
      C  : in  std_logic;
      D  : in  std_logic;
      R  : in  std_logic);
  end component FDR;

  signal addr_i       : std_logic_vector(0 to 3);  
  signal buffer_Full  : std_logic;
  signal buffer_Empty : std_logic;

  signal next_Data_Exists : std_logic;
  signal data_Exists_I    : std_logic;

  signal valid_Write : std_logic;

  signal hsum_A  : std_logic_vector(0 to 3);
  signal sum_A   : std_logic_vector(0 to 3);
  signal addr_cy : std_logic_vector(0 to 4);
  
begin  -- architecture IMP

  buffer_Full <= '1' when (addr_i = "1111") else '0';
  FIFO_Full   <= buffer_Full;

  buffer_Empty <= '1' when (addr_i = "0000") else '0';

  next_Data_Exists <= (data_Exists_I and not buffer_Empty) or
                      (buffer_Empty and FIFO_Write) or
                      (data_Exists_I and not FIFO_Read);

  Data_Exists_DFF : FDR
    port map (
      Q  => data_Exists_I,            -- [out std_logic]
      C  => Clk,                      -- [in  std_logic]
      D  => next_Data_Exists,         -- [in  std_logic]
      R  => Reset);                   -- [in std_logic]

  Data_Exists <= data_Exists_I;
  
  valid_Write <= FIFO_Write and (FIFO_Read or not buffer_Full);

  addr_cy(0) <= valid_Write;

  Addr_Counters : for I in 0 to 3 generate

    hsum_A(I) <= (FIFO_Read xor addr_i(I)) and (FIFO_Write or not buffer_Empty);

    MUXCY_L_I : MUXCY_L
      port map (
        DI => addr_i(I),                  -- [in  std_logic]
        CI => addr_cy(I),               -- [in  std_logic]
        S  => hsum_A(I),                -- [in  std_logic]
        LO => addr_cy(I+1));            -- [out std_logic]

    XORCY_I : XORCY
      port map (
        LI => hsum_A(I),                -- [in  std_logic]
        CI => addr_cy(I),               -- [in  std_logic]
        O  => sum_A(I));                -- [out std_logic]

    FDRE_I : FDRE
      port map (
        Q  => addr_i(I),                  -- [out std_logic]
        C  => Clk,                      -- [in  std_logic]
        CE => data_Exists_I,            -- [in  std_logic]
        D  => sum_A(I),                 -- [in  std_logic]
        R  => Reset);                   -- [in std_logic]

  end generate Addr_Counters;

  FIFO_RAM : for I in 0 to C_DATA_BITS-1 generate
    SRL16E_I : SRL16E
      -- pragma translate_off
      generic map (
        INIT => x"0000")
      -- pragma translate_on
      port map (
        CE  => valid_Write,             -- [in  std_logic]
        D   => Data_In(I),              -- [in  std_logic]
        Clk => Clk,                     -- [in  std_logic]
        A0  => addr_i(0),                 -- [in  std_logic]
        A1  => addr_i(1),                 -- [in  std_logic]
        A2  => addr_i(2),                 -- [in  std_logic]
        A3  => addr_i(3),                 -- [in  std_logic]
        Q   => Data_Out(I));            -- [out std_logic]
  end generate FIFO_RAM;
  
-------------------------------------------------------------------------------
-- INT_ADDR_PROCESS
-------------------------------------------------------------------------------
-- This process assigns the internal address to the output port
-------------------------------------------------------------------------------
  INT_ADDR_PROCESS:process (addr_i)
  begin   -- process
    Addr <= addr_i;
  end process;
  

end architecture IMP;


-------------------------------------------------------------------------------
-- upcnt_n.vhd  entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        upcnt_n.vhd
-- Version:         v1.01.b                        
--
-- Description:     
--                  This file contains a parameterizable N-bit up counter 
--                                    
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
-- NLR      01/07/11
-- ^^^^^^
-- -  Release of v1.01.b
-- ~~~~~~
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_SIZE     -- Data width of counter
--
-- Definition of Ports:
--      Clk               -- System clock
--      Clr               -- Active low clear
--      Data              -- Serial data in
--      Cnt_en            -- Count enable
--      Load              -- Load line enable
--      Qout              -- Shift register shift enable
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------
entity upcnt_n is
   generic(
          C_SIZE : integer :=9
          );
      
    port(
         Clr      : in std_logic;                        
         Clk      : in std_logic;                        
         Data     : in std_logic_vector (0 to C_SIZE-1); 
         Cnt_en   : in std_logic;                        
         Load     : in std_logic;                        
         Qout     : inout std_logic_vector (0 to C_SIZE-1)
         );
        
end upcnt_n;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture RTL  of upcnt_n is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";

    
    constant enable_n : std_logic := '0';
    signal q_int : unsigned (0 to C_SIZE-1);
    
begin

   ----------------------------------------------------------------------------
   -- PROCESS: UP_COUNT_GEN
   -- purpose: Up counter
   ----------------------------------------------------------------------------
   UP_COUNT_GEN : process(Clk)
   begin
      if (Clk'event) and Clk = '1' then
         if (Clr = enable_n) then     -- Clear output register
            q_int <= (others => '0');
         elsif (Load = '1') then      -- Load in start value
            q_int <= unsigned(Data);
         elsif Cnt_en = '1' then      -- If count enable is high
            q_int <= q_int + 1;
         else
            q_int <= q_int;
         end if;
      end if;
   end process UP_COUNT_GEN;

   Qout <= std_logic_vector(q_int);

end architecture RTL;


-------------------------------------------------------------------------------
-- shift8.vhd - Entity and Architecture
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        shift8.vhd
-- Version:         v1.01.b                        
-- Description:     
--                  This file contains an 8 bit shift register 
--
--  VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Release of v1.01.b
-- ~~~~~~
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Ports:
--      Clk           -- System clock
--      Clr           -- System reset
--      Data_ld       -- Shift register data load enable
--      Data_in       -- Shift register data in
--      Shift_in      -- Shift register serial data in
--      Shift_en      -- Shift register shift enable
--      Shift_out     -- Shift register serial data out
--      Data_out      -- Shift register shift data out
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity shift8 is
    port(
         Clk         : in std_logic;    -- Clock
         Clr         : in std_logic;    -- Clear
         Data_ld     : in std_logic;    -- Data load enable
         Data_in     : in std_logic_vector (7 downto 0);-- Data to load in
         Shift_in    : in std_logic;    -- Serial data in
         Shift_en    : in std_logic;    -- Shift enable
         Shift_out   : out std_logic;   -- Shift serial data out
         Data_out    : out std_logic_vector (7 downto 0)  -- Shifted data
         );
        
end shift8;  

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture RTL of shift8 is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


    constant enable_n : std_logic := '0';

    signal data_int : std_logic_vector (7 downto 0);

begin

   ----------------------------------------------------------------------------
   -- PROCESS: SHIFT_REG_GEN
   -- purpose: generate shift register
   ----------------------------------------------------------------------------
   
   SHIFT_REG_GEN : process(Clk)
   begin
      if Clk'event and Clk = '1' then
         if (Clr = enable_n) then -- Clear output register
            data_int <= (others => '0');
         elsif (Data_ld = '1') then  -- Load data
            data_int <= Data_in;
         elsif Shift_en = '1' then -- If shift enable is high
            data_int <= data_int(6 downto 0) & Shift_in; -- Shift the data
         end if;
      end if;
   end process SHIFT_REG_GEN;
   
    Shift_out <= data_int(7);     
    Data_out  <= data_int;

end architecture RTL; 


-------------------------------------------------------------------------------
-- iic_pkg.vhd - Package
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2009 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        iic_pkg.vhd
-- Version:         v1.01.b                        
-- Description:     This file contains the constants used in the design of the
--                  iic bus interface.
--
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Release of v1.01.b
-- ~~~~~~
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package iic_pkg is

   ----------------------------------------------------------------------------
   -- Constant Declarations
   ----------------------------------------------------------------------------
   constant RESET_ACTIVE : std_logic              := '1'; -- Reset Constant
   
   constant NUM_IIC_REGS : integer := 11;       -- should be same as C_NUM_IIC_REGS in axi_iic top

   constant DATA_BITS    : natural                := 8; -- FIFO Width Generic
   constant TX_FIFO_BITS : integer range 0 to 256 := 4; -- Number of addr bits
   constant RC_FIFO_BITS : integer range 0 to 256 := 4; -- Number of addr bits
   
   
   --IPIF Generics that must remain at these values for the IIC
   constant  INCLUDE_DEV_PENCODER      : BOOLEAN := False;  
   constant  IPIF_ABUS_WIDTH           : INTEGER := 32; 
   constant  INCLUDE_DEV_ISC           : Boolean := false;
   
   type STD_LOGIC_VECTOR_ARRAY is array (0 to NUM_IIC_REGS-1) of std_logic_vector(24 to 31);
   type INTEGER_ARRAY is array (24 to 31) of integer; 
   ----------------------------------------------------------------------------
   -- Function and Procedure Declarations
   ----------------------------------------------------------------------------
   function num_ctr_bits(C_S_AXI_ACLK_FREQ_HZ : integer;
                         C_IIC_FREQ : integer)  return integer;
   function ten_bit_addr_used(C_TEN_BIT_ADR : integer) return std_logic_vector;
   function gpo_bit_used(C_GPO_WIDTH : integer) return std_logic_vector;
   function count_reg_bits_used(REG_BITS_USED : STD_LOGIC_VECTOR_ARRAY) return
                                                                INTEGER_ARRAY;

end package iic_pkg;

-------------------------------------------------------------------------------
-- Package body
-------------------------------------------------------------------------------

package body iic_pkg is

   ----------------------------------------------------------------------------
   -- Function Definitions
   ----------------------------------------------------------------------------
   -- Function num_ctr_bits
   --
   -- This function returns the number of bits required to count 1/2 the period
   -- of the SCL clock.
   --
   ----------------------------------------------------------------------------
   function num_ctr_bits(C_S_AXI_ACLK_FREQ_HZ : integer;
                        C_IIC_FREQ : integer) return integer is
   
      variable num_bits    : integer :=0;
      variable i           : integer :=0;
   begin   
      --  for loop used because XST service pack 2 does not support While loops
      if C_S_AXI_ACLK_FREQ_HZ/C_IIC_FREQ > C_S_AXI_ACLK_FREQ_HZ/212766 then
         for i in 0 to 30 loop  -- 30 is a magic number needed for for loops
            if 2**i < C_S_AXI_ACLK_FREQ_HZ/C_IIC_FREQ then
                  num_bits := num_bits + 1;   
            end if;
         end loop;
         return (num_bits);
      else
         for i in 0 to 30 loop
            if 2**i < C_S_AXI_ACLK_FREQ_HZ/212766 then
                  num_bits := num_bits + 1; 
            end if;
         end loop;
         return (num_bits);
      end if;
   end function num_ctr_bits;         
     
   ----------------------------------------------------------------------------
   -- Function ten_bit_addr_used
   --
   -- This function returns either b"00000000" for no ten bit addressing or
   --                              b"00000111" for ten bit addressing
   --
   ----------------------------------------------------------------------------
   
   function ten_bit_addr_used(C_TEN_BIT_ADR : integer) return std_logic_vector is
   begin   
      if C_TEN_BIT_ADR = 0 then
         return (b"00000000");
      else
         return (b"00000111");
      end if;
   end function ten_bit_addr_used;         
   
   ----------------------------------------------------------------------------
   -- Function gpo_bit_used
   --
   -- This function returns b"00000000" up to b"11111111" depending on
   -- C_GPO_WIDTH
   --
   ----------------------------------------------------------------------------
   
   function gpo_bit_used(C_GPO_WIDTH : integer) return std_logic_vector is
   begin   
      if C_GPO_WIDTH = 1 then
         return (b"00000001");
      elsif C_GPO_WIDTH = 2 then
         return (b"00000011");
      elsif C_GPO_WIDTH = 3 then
         return (b"00000111");
      elsif C_GPO_WIDTH = 4 then
         return (b"00001111");
      elsif C_GPO_WIDTH = 5 then
         return (b"00011111");
      elsif C_GPO_WIDTH = 6 then
         return (b"00111111");
      elsif C_GPO_WIDTH = 7 then
         return (b"01111111");
      elsif C_GPO_WIDTH = 8 then
         return (b"11111111");
      end if;
   end function gpo_bit_used;  
   
   ----------------------------------------------------------------------------
   -- Function count_reg_bits_used
   --
   -- This function returns either b"00000000" for no ten bit addressing or
   --                              b"00000111" for ten bit addressing
   --
   ----------------------------------------------------------------------------
   
   function count_reg_bits_used(REG_BITS_USED : STD_LOGIC_VECTOR_ARRAY) 
                                         return INTEGER_ARRAY is 
      variable count : INTEGER_ARRAY;
   begin
      for i in 24 to 31 loop
         count(i) := 0;
         for m in 0 to NUM_IIC_REGS-1 loop --IP_REG_NUM - 1
            if (REG_BITS_USED(m)(i) = '1') then
               count(i) := count(i) + 1;
            end if;
         end loop;
      end loop;
      return count;
   end function count_reg_bits_used;
   
end package body iic_pkg;


-------------------------------------------------------------------------------
-- debounce.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2009 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        debounce.vhd
-- Version:         v1.01.b                        
-- Description:     
--                 This file implements a simple debounce (inertial delay)
--                 filter to remove short glitches from a signal based upon
--                 using user definable delay parameters. It accepts a "Stable"
--                 signal which allows the filter to dynamically stretch its
--                 delay based on whether another signal is Stable or not. If
--                 the filter has detected a change on is "Noisy" input then it
--                 will signal its output is "unstable". That can be cross
--                 coupled into the "Stable" input of another filter if
--                 necessary.
-- Notes:
-- 1) A default assignment based on the generic C_DEFAULT is made for the flip
-- flop output of the delay logic when C_INERTIAL_DELAY > 0. Otherwise, the
-- logic is free running and no reset is possible.
-- 2) A C_INERTIAL_DELAY value of 0 eliminates the debounce logic and connects
-- input to output directly.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Release of v1.01.b
--  - Fixed the CR#613486
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lib_cdc_v1_0_2;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_INERTIAL_DELAY     -- Filtering delay       
--      C_DEFAULT            -- User logic high address 
-- Definition of Ports:
--      Sysclk               -- System clock
--      Stable               -- IIC signal is Stable
--      Unstable_n           -- IIC signal is unstable
--      Noisy                -- IIC signal is Noisy
--      Clean                -- IIC signal is Clean
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity debounce is
   
   generic (
      C_INERTIAL_DELAY : integer range 0 to 255 := 5;
      C_DEFAULT        : std_logic              := '1'
      );

   port (
      Sysclk     : in std_logic;
      Rst        : in std_logic;
      Stable     : in  std_logic;
      Unstable_n : out std_logic;
      Noisy      : in  std_logic;
      Clean      : out std_logic);

end entity debounce;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture RTL of debounce is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


   -- XST proceses default assignments for configuration purposes
   signal clean_cs  : std_logic := C_DEFAULT;
   signal stable_cs : std_logic := '1';
   signal debounce_ct : integer range 0 to 255;
   signal Noisy_d1 : std_logic := '1';
   signal Noisy_d2 : std_logic := '1';
begin

   ----------------------------------------------------------------------------
   -- Input Registers Process 
   -- This process samples the incoming SDA and SCL with the system clock
   ----------------------------------------------------------------------------
--   INPUT_DOUBLE_REGS : process(Sysclk)
--   begin
--      if Sysclk'event and Sysclk = '1' then
--            Noisy_d1 <= Noisy;
--            Noisy_d2 <= Noisy_d1; -- double buffer async input
--      end if;
--   end process INPUT_DOUBLE_REGS;

INPUT_DOUBLE_REGS : entity  lib_cdc_v1_0_2.cdc_sync
    generic map (
        C_CDC_TYPE                 => 1,
        C_RESET_STATE              => 0,  
        C_SINGLE_BIT               => 1,
        C_VECTOR_WIDTH             => 32, 
        C_MTBF_STAGES              => 4
    )
    port map (
        prmry_aclk                 => '0',
        prmry_resetn               => '0', 
        prmry_in                   => Noisy, 
        prmry_vect_in              => (others => '0'),

        scndry_aclk                => Sysclk, 
        scndry_resetn              => '0',
        scndry_out                 => Noisy_d2,
        scndry_vect_out            => open
    );


   ----------------------------------------------------------------------------
   --  GEN_INERTIAL : Generate when C_INERTIAL_DELAY > 0
   ----------------------------------------------------------------------------

   GEN_INERTIAL : if (C_INERTIAL_DELAY > 0) generate

   ----------------------------------------------------------------------------
   --  GEN_INERTIAL : C_INERTIAL_DELAY > 0
   -- Inertial delay filters out pulses that are smaller in width then the
   -- specified delay. If the C_INERTIAL_DELAY is 0 then the input is passed
   -- directly to the "Clean" output signal.
   ----------------------------------------------------------------------------
      INRTL_PROCESS : process (Sysclk) is
      begin

         if ((rising_edge(Sysclk))) then
            if Rst = '1' then 
               clean_cs <= C_DEFAULT;
               debounce_ct <= C_INERTIAL_DELAY  ;
               Unstable_n  <= '1';
            elsif (clean_cs = Noisy_d2) then
               debounce_ct <= C_INERTIAL_DELAY   ;
               Unstable_n  <= '1';
            else
               if (debounce_ct > 0) then
                  debounce_ct <= debounce_ct - 1;
                  Unstable_n <= '0';
               else 
                  if Stable = '1' then
                    clean_cs <= Noisy_d2;
                    debounce_ct <= C_INERTIAL_DELAY   ;
                    Unstable_n <= '1';
                  end if;  
               end if;
            end if;
         end if;
      
      end process INRTL_PROCESS;

      s0 : Clean <= clean_cs;
   end generate GEN_INERTIAL;

   ----------------------------------------------------------------------------
   -- NO_INERTIAL : C_INERTIAL_DELAY = 0
   -- No inertial delay means output is always Stable
   ----------------------------------------------------------------------------
   NO_INERTIAL : if (C_INERTIAL_DELAY = 0) generate
      
      s0 : Clean      <= Noisy_d2;
      s1 : Unstable_n <= '1';  
                               
   end generate NO_INERTIAL;
   
end architecture RTL;


-------------------------------------------------------------------------------
-- reg_interface.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        reg_interface.vhd
-- Version:         v1.01.b                        
-- Description:
--                  This file contains the interface between the IPIF
--                  and the iic controller.  All registers are generated
--                  here and all interrupts are processed here.
--
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Release of v1.01.b
-- ~~~~~~
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_arith.all;

library axi_iic_v2_0_21;
use axi_iic_v2_0_21.iic_pkg.all;

library unisim;
use unisim.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_TX_FIFO_EXIST     -- IIC transmit FIFO exist       
--      C_TX_FIFO_BITS      -- Transmit FIFO bit size 
--      C_RC_FIFO_EXIST     -- IIC receive FIFO exist       
--      C_RC_FIFO_BITS      -- Receive FIFO bit size
--      C_TEN_BIT_ADR       -- 10 bit slave addressing       
--      C_GPO_WIDTH         -- Width of General purpose output vector 
--      C_S_AXI_DATA_WIDTH      -- Slave bus data width      
--      C_NUM_IIC_REGS      -- Number of IIC Registers 
--
-- Definition of Ports:
--      Clk                   -- System clock
--      Rst                   -- System reset
--      Bus2IIC_Addr          -- Bus to IIC address bus
--      Bus2IIC_Data          -- Bus to IIC data bus
--      Bus2IIC_WrCE          -- Bus to IIC write chip enable
--      Bus2IIC_RdCE          -- Bus to IIC read chip enable
--      IIC2Bus_Data          -- IIC to Bus data bus
--      IIC2Bus_IntrEvent     -- IIC Interrupt events
--      Gpo                   -- General purpose outputs
--      Cr                    -- Control register
--      Msms_rst              -- MSMS reset signal
--      Rsta_rst              -- Repeated start reset
--      Msms_set              -- MSMS set 
--      DynMsmsSet            -- Dynamic MSMS set signal
--      DynRstaSet            -- Dynamic repeated start set signal
--      Cr_txModeSelect_set   -- Sets transmit mode select
--      Cr_txModeSelect_clr   -- Clears transmit mode select
--      Aas                   -- Addressed as slave indicator
--      Bb                    -- Bus busy indicator
--      Srw                   -- Slave read/write indicator
--      Abgc                  -- Addressed by general call indicator
--      Dtr                   -- Data transmit register
--      Rdy_new_xmt           -- New data loaded in shift reg indicator
--      Dtre                  -- Data transmit register empty
--      Drr                   -- Data receive register
--      Data_i2c              -- IIC data for processor
--      New_rcv_dta           -- New Receive Data ready
--      Ro_prev               -- Receive over run prevent
--      Adr                   -- IIC slave address
--      Ten_adr               -- IIC slave 10 bit address
--      Al                    -- Arbitration lost indicator
--      Txer                  -- Received acknowledge indicator
--      Tx_under_prev         -- DTR or Tx FIFO empty IRQ indicator
--      Tx_fifo_data          -- FIFO data to transmit
--      Tx_data_exists        -- next FIFO data exists
--      Tx_fifo_wr            -- Decode to enable writes to FIFO
--      Tx_fifo_rd            -- Decode to enable read from FIFO
--      Tx_fifo_rst           -- Reset Tx FIFO on IP Reset or CR(6)
--      Tx_fifo_Full          -- Transmit FIFO full indicator
--      Tx_addr               -- Transmit FIFO address
--      Rc_fifo_data          -- Read Fifo data for AXI
--      Rc_fifo_wr            -- Write IIC data to fifo
--      Rc_fifo_rd            -- AXI read from fifo
--      Rc_fifo_Full          -- Read Fifo is full prevent rcv overrun
--      Rc_data_Exists        -- Next FIFO data exists
--      Rc_addr               -- Receive FIFO address
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity reg_interface is
   generic(
      C_SCL_INERTIAL_DELAY : integer range 0 to 255 := 5;
      C_S_AXI_ACLK_FREQ_HZ : integer := 100000000;
      C_IIC_FREQ           : integer := 100000;
      C_SMBUS_PMBUS_HOST   : integer := 0;   -- SMBUS/PMBUS support
      C_TX_FIFO_EXIST      : boolean := TRUE;
      C_TX_FIFO_BITS       : integer := 4;
      C_RC_FIFO_EXIST      : boolean := TRUE;
      C_RC_FIFO_BITS       : integer := 4;
      C_TEN_BIT_ADR        : integer := 0;
      C_GPO_WIDTH          : integer := 0;
      C_S_AXI_ADDR_WIDTH   : integer := 32;
      C_S_AXI_DATA_WIDTH   : integer := 32;
      C_SIZE               : integer := 32;
      C_NUM_IIC_REGS       : integer;
      C_DEFAULT_VALUE      : std_logic_vector(7 downto 0) := X"FF"
      );
   port(
      -- IPIF Interface Signals
      Clk               : in std_logic;
      Rst               : in std_logic;
      Bus2IIC_Addr      : in std_logic_vector (0 to C_S_AXI_ADDR_WIDTH-1);
      Bus2IIC_Data      : in std_logic_vector (0 to C_S_AXI_DATA_WIDTH - 1);
      Bus2IIC_WrCE      : in std_logic_vector (0 to C_NUM_IIC_REGS - 1);
      Bus2IIC_RdCE      : in std_logic_vector (0 to C_NUM_IIC_REGS - 1);
      IIC2Bus_Data      : out std_logic_vector (0 to C_S_AXI_DATA_WIDTH - 1);
      IIC2Bus_IntrEvent : out std_logic_vector (0 to 7);

      -- Internal iic Bus Registers
      -- GPO Register  Offset 124h
      Gpo               : out std_logic_vector(32 - C_GPO_WIDTH to
                                            C_S_AXI_DATA_WIDTH - 1);
      -- Control Register  Offset 100h
      Cr                : out std_logic_vector(0 to 7);
      Msms_rst          : in  std_logic;  
      Rsta_rst          : in  std_logic;  
      Msms_set          : out std_logic;  

      DynMsmsSet          : in std_logic;  
      DynRstaSet          : in std_logic;  
      Cr_txModeSelect_set : in std_logic;  
      Cr_txModeSelect_clr : in std_logic;  

      -- Status Register  Offest 04h
      Aas                 : in std_logic;    
      Bb                  : in std_logic;    
      Srw                 : in std_logic;    
      Abgc                : in std_logic;    

      -- Data Transmit Register Offset 108h
      Dtr                 : out std_logic_vector(0 to 7);
      Rdy_new_xmt         : in  std_logic;
      Dtre                : out std_logic;

      -- Data Receive Register  Offset 10Ch
      Drr                 : out std_logic_vector(0 to 7);
      Data_i2c            : in  std_logic_vector(0 to 7);
      New_rcv_dta         : in  std_logic;  
      Ro_prev             : out std_logic;  

      -- Address Register Offset 10h
      Adr                 : out std_logic_vector(0 to 7);
        
      -- Ten Bit Address Register Offset 1Ch
      Ten_adr             : out std_logic_vector(5 to 7) := (others => '0');
      Al                  : in std_logic;  
      Txer                : in std_logic;  
      Tx_under_prev       : in std_logic;  

      -- Timing Parameters to iic_control
      Timing_param_tsusta : out std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tsusto : out std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_thdsta : out std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tsudat : out std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tbuf   : out std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_thigh  : out std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tlow   : out std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_thddat : out std_logic_vector(C_SIZE-1 downto 0);

      --  FIFO input (fifo write) and output (fifo read)
      Tx_fifo_data        : in  std_logic_vector(0 to 7);  
      Tx_data_exists      : in  std_logic;  
      Tx_fifo_wr          : out std_logic;  
      Tx_fifo_rd          : out std_logic;  
      Tx_fifo_rst         : out std_logic;  
      Tx_fifo_Full        : in  std_logic;
      Tx_addr             : in  std_logic_vector(0 to C_TX_FIFO_BITS - 1);
      Rc_fifo_data        : in  std_logic_vector(0 to 7);  
      Rc_fifo_wr          : out std_logic;  
      Rc_fifo_rd          : out std_logic;  
      Rc_fifo_Full        : in  std_logic;  
      Rc_data_Exists      : in  std_logic;
      Rc_addr             : in  std_logic_vector(0 to C_RC_FIFO_BITS - 1);
      reg_empty           : in  std_logic

      );

end reg_interface;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture RTL of reg_interface is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


   ----------------------------------------------------------------------------
   --  Constant Declarations
   ----------------------------------------------------------------------------
   
   -- Calls the function from the iic_pkg.vhd
   --constant C_SIZE : integer := num_ctr_bits(C_S_AXI_ACLK_FREQ_HZ, C_IIC_FREQ);


   constant IIC_CNT : integer := (C_S_AXI_ACLK_FREQ_HZ/C_IIC_FREQ - 14);

   -- Calls the function from the iic_pkg.vhd
   --constant C_SIZE : integer := num_ctr_bits(C_S_AXI_ACLK_FREQ_HZ, C_IIC_FREQ);

   -- number of SYSCLK in iic SCL High time
   constant HIGH_CNT : std_logic_vector(C_SIZE-1 downto 0)
      := conv_std_logic_vector(IIC_CNT/2 - C_SCL_INERTIAL_DELAY, C_SIZE);

   -- number of SYSCLK in iic SCL Low time
   constant LOW_CNT : std_logic_vector(C_SIZE-1 downto 0)
      := conv_std_logic_vector(IIC_CNT/2 - C_SCL_INERTIAL_DELAY, C_SIZE);

   -- half of HIGH_CNT
   constant HIGH_CNT_2 : std_logic_vector(C_SIZE-1 downto 0)
      := conv_std_logic_vector(IIC_CNT/4, C_SIZE);

   ----------------------------------------------------------------------------
   -- Function calc_tsusta
   --
   -- This function returns Setup time integer value for repeated start for
   -- Standerd mode or Fast mode opertation.
   ----------------------------------------------------------------------------

   FUNCTION calc_tsusta (
      constant C_IIC_FREQ : integer;
      constant C_S_AXI_ACLK_FREQ_HZ : integer;
      constant C_SIZE     : integer)
      RETURN std_logic_vector is
   begin
      -- Calculate setup time for repeated start condition depending on the
      -- mode {standard, fast}
      if (C_IIC_FREQ <= 100000) then
         -- Standard Mode timing 4.7 us
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/175438, C_SIZE);
         -- Added to have 5.7 us (tr+tsu-sta)
      elsif (C_IIC_FREQ <= 400000) then
         -- Fast Mode timing is 0.6 us
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/1111111, C_SIZE);
         -- Added to have 0.9 us (tr+tsu-sta)
      else
         -- Fast Mode Plus timing is 0.26 us
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/2631579, C_SIZE);
         -- Added to have 0.380 us (tr+tsu-sta)
      end if;
   end FUNCTION calc_tsusta;

   ----------------------------------------------------------------------------
   -- Function calc_tsusto
   --
   -- This function returns Setup time integer value for stop condition for
   -- Standerd mode or Fast mode opertation.
   ----------------------------------------------------------------------------

   FUNCTION calc_tsusto (
      constant C_IIC_FREQ : integer;
      constant C_S_AXI_ACLK_FREQ_HZ : integer;
      constant C_SIZE     : integer)
      RETURN std_logic_vector is
   begin
      -- Calculate setup time for stop condition depending on the
      -- mode {standard, fast}
      if (C_IIC_FREQ <= 100000) then
         -- Standard Mode timing 4.0 us
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/200000, C_SIZE);
         -- Added to have 5 us (tr+tsu-sto)
      elsif (C_IIC_FREQ <= 400000) then
         -- Fast Mode timing is 0.6 us
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/1111111, C_SIZE);
         -- Added to have 0.9 us (tr+tsu-sto)
      else
         -- Fast-mode Plus timing is 0.26 us
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/2631579, C_SIZE);
         -- Added to have 0.380 us (tr+tsu-sto)
      end if;
   end FUNCTION calc_tsusto;

   ----------------------------------------------------------------------------
   -- Function calc_thdsta
   --
   -- This function returns Hold time integer value for reapeted start for
   -- Standerd mode or Fast mode opertation.
   ----------------------------------------------------------------------------

   FUNCTION calc_thdsta (
      constant C_IIC_FREQ : integer;
      constant C_S_AXI_ACLK_FREQ_HZ : integer;
      constant C_SIZE     : integer)
      RETURN std_logic_vector is
   begin
      -- Calculate (repeated) START hold time depending on the
      -- mode {standard, fast}
      if (C_IIC_FREQ <= 100000) then
         -- Standard Mode timing 4.0 us
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/232558, C_SIZE);
         -- Added to have 4.3 us (tf+thd-sta)
      elsif (C_IIC_FREQ <= 400000) then
         -- Fast Mode timing is 0.6 us
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/1111111, C_SIZE);
         -- Added to have 0.9 us (tf+thd-sta)
      else
         -- Fast-mode Plus timing is 0.26 us
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/2631579, C_SIZE);
         -- Added to have 0.380 us (tf+thd-sta)
      end if;
   end FUNCTION calc_thdsta;

   ----------------------------------------------------------------------------
   -- Function calc_tsudat
   --
   -- This function returns Data Setup time integer value for
   -- Standerd mode or Fast mode opertation.
   ----------------------------------------------------------------------------

   FUNCTION calc_tsudat (
      constant C_IIC_FREQ : integer;
      constant C_S_AXI_ACLK_FREQ_HZ : integer;
      constant C_SIZE     : integer)
      RETURN std_logic_vector is
   begin
      -- Calculate data setup time depending on the
      -- mode {standard, fast}
      if (C_IIC_FREQ <= 100000) then
         -- Standard Mode timing 250 ns
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/1818181, C_SIZE);
         -- Added to have 550 ns (tf+tsu-dat)
      elsif (C_IIC_FREQ <= 400000) then
         -- Fast Mode timing is 100 ns
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/2500000, C_SIZE);
         -- Added to have 400 ns (tf+tsu-dat)
      else
         -- Fast-mode Plus timing is 50 ns
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/5882353, C_SIZE);
         -- Added to have 170 ns (tf+tsu-dat)
      end if;
   end FUNCTION calc_tsudat;

   ----------------------------------------------------------------------------
   -- Function calc_tbuf
   --
   -- This function returns Bus free time between a STOP and START condition 
   -- integer value for Standerd mode or Fast mode opertation.
   ----------------------------------------------------------------------------

   FUNCTION calc_tbuf (
      constant C_IIC_FREQ : integer;
      constant C_S_AXI_ACLK_FREQ_HZ : integer;
      constant C_SIZE     : integer)
      RETURN std_logic_vector is
   begin
      -- Calculate data setup time depending on the
      -- mode {standard, fast}
      if (C_IIC_FREQ <= 100000) then
         -- Standard Mode timing 4.7 us
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/200000, C_SIZE);
         -- Added to have 5 us 
      elsif (C_IIC_FREQ <= 400000) then
         -- Fast Mode timing is 1.3 us
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/625000, C_SIZE);
         -- Added to have 1.6 us 
      else
         -- Fast-mode Plus timing is 0.5 us
         RETURN conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/1612904, C_SIZE);
         -- Added to have 0.62 us 
      end if;
   end FUNCTION calc_tbuf;

   ----------------------------------------------------------------------------
   -- Function calc_thddat
   --
   -- This function returns the data hold time integer value for I2C and
   -- SMBus/PMBus protocols. 
   ----------------------------------------------------------------------------

   FUNCTION calc_thddat (
      constant C_SMBUS_PMBUS_HOST : integer;
      constant C_IIC_FREQ : integer;
      constant C_S_AXI_ACLK_FREQ_HZ : integer;
      constant C_SIZE     : integer)
      RETURN std_logic_vector is
   begin
      -- Calculate data hold time depending on SMBus/PMBus compatability
      if (C_SMBUS_PMBUS_HOST = 1) then
         -- hold time of 300 ns for SMBus/PMBus
         RETURN  conv_std_logic_vector(C_S_AXI_ACLK_FREQ_HZ/3333334, C_SIZE);
      else
         -- hold time of 0 ns for normal I2C
         RETURN conv_std_logic_vector(1, C_SIZE);
      end if;
   end FUNCTION calc_thddat;

   -- Set-up time for a repeated start
   constant TSUSTA : std_logic_vector(C_SIZE-1 downto 0)
      := calc_tsusta(C_IIC_FREQ, C_S_AXI_ACLK_FREQ_HZ, C_SIZE);

   -- Set-up time for a stop
   constant TSUSTO : std_logic_vector(C_SIZE-1 downto 0)
      := calc_tsusto(C_IIC_FREQ, C_S_AXI_ACLK_FREQ_HZ, C_SIZE);

   -- Hold time (repeated) START condition. After this period, the first clock
   -- pulse is generated.
   constant THDSTA : std_logic_vector(C_SIZE-1 downto 0)
      := calc_thdsta(C_IIC_FREQ, C_S_AXI_ACLK_FREQ_HZ, C_SIZE);

   -- Data setup time.
   constant TSUDAT : std_logic_vector(C_SIZE-1 downto 0)
      := calc_tsudat(C_IIC_FREQ, C_S_AXI_ACLK_FREQ_HZ, C_SIZE);

   -- Bus free time.
   constant TBUF : std_logic_vector(C_SIZE-1 downto 0)
      := calc_tbuf(C_IIC_FREQ, C_S_AXI_ACLK_FREQ_HZ, C_SIZE);

   -- Data Hold time 
   constant THDDAT : std_logic_vector(C_SIZE-1 downto 0)
      := calc_thddat(C_SMBUS_PMBUS_HOST, C_IIC_FREQ, C_S_AXI_ACLK_FREQ_HZ, C_SIZE);


   ----------------------------------------------------------------------------
   -- Signal and Type Declarations
   ----------------------------------------------------------------------------

   signal cr_i           : std_logic_vector(0 to 7);  -- intrnl control reg
   signal sr_i           : std_logic_vector(0 to 7);  -- intrnl statuss reg
   signal dtr_i          : std_logic_vector(0 to 7);  -- intrnl dta trnsmt reg
   signal drr_i          : std_logic_vector(0 to 7);  -- intrnl dta receive reg
   signal adr_i          : std_logic_vector(0 to 7);  -- intrnl slave addr reg
   signal rc_fifo_pirq_i : std_logic_vector(4 to 7);  -- intrnl slave addr reg
   signal ten_adr_i      : std_logic_vector(5 to 7) := (others => '0');  
                                                      -- intrnl slave addr reg
   signal ro_a           : std_logic;  -- receive overrun SRFF
   signal ro_i           : std_logic;  -- receive overrun SRFF
   signal dtre_i         : std_logic;  -- data tranmit register empty register
   signal new_rcv_dta_d1 : std_logic;  -- delay new_rcv_dta to find rising edge
   signal msms_d1        : std_logic;  -- delay msms cr(5)
   signal ro_prev_i      : std_logic;  -- internal Ro_prev
   signal msms_set_i     : std_logic;  -- SRFF set on falling edge of msms
   signal rtx_i          : std_logic_vector(0 to 7);
   signal rrc_i          : std_logic_vector(0 to 7);
   signal rtn_i          : std_logic_vector(0 to 7);
   signal rpq_i          : std_logic_vector(0 to 7);
   signal gpo_i          : std_logic_vector(32 - C_GPO_WIDTH to 31); -- GPO

   signal timing_param_tsusta_i  : std_logic_vector(C_SIZE-1 downto 0);
   signal timing_param_tsusto_i  : std_logic_vector(C_SIZE-1 downto 0);
   signal timing_param_thdsta_i  : std_logic_vector(C_SIZE-1 downto 0);
   signal timing_param_tsudat_i  : std_logic_vector(C_SIZE-1 downto 0);
   signal timing_param_tbuf_i    : std_logic_vector(C_SIZE-1 downto 0);
   signal timing_param_thigh_i   : std_logic_vector(C_SIZE-1 downto 0);
   signal timing_param_tlow_i    : std_logic_vector(C_SIZE-1 downto 0);
   signal timing_param_thddat_i  : std_logic_vector(C_SIZE-1 downto 0);

   signal rback_data : std_logic_vector(0 to 32 * C_NUM_IIC_REGS - 1)
                                                           := (others => '0');
begin

   ----------------------------------------------------------------------------
   -- CONTROL_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the control register is enabled.
   ----------------------------------------------------------------------------
   CONTROL_REGISTER_PROCESS : process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            cr_i <= (others => '0');
         elsif                --  Load Control Register with AXI
            --  data if there is a write request
            --  and the control register is enabled
            Bus2IIC_WrCE(0) = '1' then
            cr_i(0 to 7) <= Bus2IIC_Data(24 to 31);
         else                 -- Load Control Register with iic data
            cr_i(0) <= cr_i(0);
            cr_i(1) <= cr_i(1);
            cr_i(2) <= (cr_i(2) or DynRstaSet) and not(Rsta_rst);
            cr_i(3) <= cr_i(3);
            cr_i(4) <= (cr_i(4) or Cr_txModeSelect_set) and 
                                not(Cr_txModeSelect_clr);
            cr_i(5) <= (cr_i(5) or DynMsmsSet) and not (Msms_rst);
            cr_i(6) <= cr_i(6);
            cr_i(7) <= cr_i(7);
         end if;
      end if;
   end process CONTROL_REGISTER_PROCESS;
   Cr <= cr_i;

   ----------------------------------------------------------------------------
   -- Delay msms by one clock to find falling edge
   ----------------------------------------------------------------------------
   MSMS_DELAY_PROCESS : process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            msms_d1 <= '0';
         else
            msms_d1 <= cr_i(5);
         end if;
      end if;
   end process MSMS_DELAY_PROCESS;

   ----------------------------------------------------------------------------
   -- Set when a fall edge of msms has occurred and Ro_prev is active
   -- This will prevent a throttle condition when a master receiver and
   -- trying to initiate a stop condition.
   ----------------------------------------------------------------------------
   MSMS_EDGE_SET_PROCESS : process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            msms_set_i <= '0';
         elsif ro_prev_i = '1' and cr_i(5) = '0' and msms_d1 = '1' then
            msms_set_i <= '1';
         elsif (cr_i(5) = '1' and msms_d1 = '0') or Bb = '0' then
            msms_set_i <= '0';
         else
            msms_set_i <= msms_set_i;
         end if;
      end if;
   end process MSMS_EDGE_SET_PROCESS;

   Msms_set <= msms_set_i;

   ----------------------------------------------------------------------------
   -- STATUS_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process resets the status register. The status register is read only
   ----------------------------------------------------------------------------
   STATUS_REGISTER_PROCESS : process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            sr_i <= (others => '0');
         else                         -- Load Status Register with iic data
            sr_i(0) <= not Tx_data_exists;
            sr_i(1) <= not Rc_data_Exists;
            sr_i(2) <= Rc_fifo_Full;
            sr_i(3) <= Tx_fifo_Full;  -- addressed by a general call
            sr_i(4) <= Srw;           -- slave read/write
            sr_i(5) <= Bb;            -- bus busy
            sr_i(6) <= Aas;           -- addressed as slave
            sr_i(7) <= Abgc;          -- addressed by a general call
         end if;
      end if;
   end process STATUS_REGISTER_PROCESS;
                          
   ----------------------------------------------------------------------------
   -- Transmit FIFO CONTROL signal GENERATION
   ----------------------------------------------------------------------------
   -- This process allows the AXI to write data to the  write FIFO and assigns
   -- that data to the output port and to the internal signals for reading
   ----------------------------------------------------------------------------
   FIFO_GEN_DTR : if C_TX_FIFO_EXIST generate
      
      -------------------------------------------------------------------------
      -- FIFO_WR_CNTL_PROCESS  - Tx fifo write process
      -------------------------------------------------------------------------
      FIFO_WR_CNTL_PROCESS : process (Clk)
      begin
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               Tx_fifo_wr <= '0';
            elsif
               Bus2IIC_WrCE(2) = '1' then
               Tx_fifo_wr <= '1';
            else
               Tx_fifo_wr <= '0';
            end if;
         end if;
      end process FIFO_WR_CNTL_PROCESS;

      -------------------------------------------------------------------------
      -- FIFO_DTR_REG_PROCESS
      -------------------------------------------------------------------------
      FIFO_DTR_REG_PROCESS : process (Tx_fifo_data)
      begin  -- process
         Dtr   <= Tx_fifo_data;
         dtr_i <= Tx_fifo_data;
      end process FIFO_DTR_REG_PROCESS;

      -------------------------------------------------------------------------
      -- Tx_FIFO_RD_PROCESS
      -------------------------------------------------------------------------
      -- This process generates the Read from the Transmit FIFO
      -------------------------------------------------------------------------
      Tx_FIFO_RD_PROCESS : process (Clk)
      begin
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               Tx_fifo_rd <= '0';
            elsif Rdy_new_xmt = '1' then
               Tx_fifo_rd <= '1';
            elsif Rdy_new_xmt = '0'  --and Tx_data_exists = '1'
            then Tx_fifo_rd <= '0';
            end if;
         end if;
      end process Tx_FIFO_RD_PROCESS;

      -------------------------------------------------------------------------
      -- DTRE_PROCESS
      -------------------------------------------------------------------------
      -- This process generates the Data Transmit Register Empty Interrupt
      -- Interrupt(2)
      -------------------------------------------------------------------------
      DTRE_PROCESS : process (Clk)
      begin
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               dtre_i <= '0';
            else
               dtre_i <= not (Tx_data_exists);
            end if;
         end if;
      end process DTRE_PROCESS;

      -------------------------------------------------------------------------
      -- Additional FIFO Interrupt
      -------------------------------------------------------------------------
      -- FIFO_Int_PROCESS generates interrupts back to the IPIF when Tx FIFO 
      -- exists
      -------------------------------------------------------------------------
      FIFO_INT_PROCESS : process (Clk)
      begin
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               IIC2Bus_IntrEvent(7) <= '0';
            else
               IIC2Bus_IntrEvent(7) <= not Tx_addr(3);  -- Tx FIFO half empty
            end if;
         end if;
      end process FIFO_INT_PROCESS;


      -------------------------------------------------------------------------
      -- Tx_FIFO_RESET_PROCESS
      -------------------------------------------------------------------------
      -- This process generates the Data Transmit Register Empty Interrupt
      -- Interrupt(2)
      -------------------------------------------------------------------------
      TX_FIFO_RESET_PROCESS : process (Clk)
      begin
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               Tx_fifo_rst <= '1';
            else
               Tx_fifo_rst <= cr_i(6);
            end if;
         end if;
      end process TX_FIFO_RESET_PROCESS;


   end generate FIFO_GEN_DTR;
   
   Dtre <= dtre_i;
   
   ----------------------------------------------------------------------------
   -- If a read FIFO exists then generate control signals
   ----------------------------------------------------------------------------
   RD_FIFO_CNTRL : if (C_RC_FIFO_EXIST) generate
      
      -------------------------------------------------------------------------
      -- WRITE_TO_READ_FIFO_PROCESS
      -------------------------------------------------------------------------
      WRITE_TO_READ_FIFO_PROCESS : process (Clk)
      begin
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               Rc_fifo_wr <= '0';
            -- Load iic Data When new data x-fer complete and not x-mitting
            elsif  
               New_rcv_dta = '1' and new_rcv_dta_d1 = '0' then
               Rc_fifo_wr <= '1';
            else
               Rc_fifo_wr <= '0';
            end if;
         end if;
      end process WRITE_TO_READ_FIFO_PROCESS;

      -------------------------------------------------------------------------
      -- Assign the Receive FIFO data to the DRR so AXI can read the data
      -------------------------------------------------------------------------
      AXI_READ_FROM_READ_FIFO_PROCESS : process (Clk)
      begin  -- process
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               Rc_fifo_rd <= '0';
            elsif Bus2IIC_RdCE(3) = '1' then
               Rc_fifo_rd <= '1';
            else
               Rc_fifo_rd <= '0';
            end if;
         end if;
      end process AXI_READ_FROM_READ_FIFO_PROCESS;

      -------------------------------------------------------------------------
      -- Assign the Receive FIFO data to the DRR so AXI can read the data
      -------------------------------------------------------------------------
      RD_FIFO_DRR_PROCESS : process (Rc_fifo_data)
      begin
         Drr   <= Rc_fifo_data;
         drr_i <= Rc_fifo_data;
      end process RD_FIFO_DRR_PROCESS;
   
      -------------------------------------------------------------------------
      -- Rc_FIFO_PIRQ
      -------------------------------------------------------------------------
      -- This process loads data from the AXI when there is a write request and
      -- the Rc_FIFO_PIRQ register is enabled.
      -------------------------------------------------------------------------
      Rc_FIFO_PIRQ_PROCESS : process (Clk)
      begin  -- process
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               rc_fifo_pirq_i <= (others => '0');
            elsif             --  Load Status Register with AXI
               --  data if there is a write request
               --  and the status register is enabled
               Bus2IIC_WrCE(8) = '1' then
               rc_fifo_pirq_i(4 to 7) <= Bus2IIC_Data(28 to 31);
            else
               rc_fifo_pirq_i(4 to 7) <= rc_fifo_pirq_i(4 to 7);
            end if;
         end if;
      end process Rc_FIFO_PIRQ_PROCESS;
   
      -------------------------------------------------------------------------
      -- RC_FIFO_FULL_PROCESS
      -------------------------------------------------------------------------
      -- This process throttles the bus when receiving and the RC_FIFO_PIRQ is 
      -- equalto the Receive FIFO Occupancy value
      -------------------------------------------------------------------------
      RC_FIFO_FULL_PROCESS : process (Clk)
      begin  -- process
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               ro_prev_i <= '0';

            elsif msms_set_i = '1' then
               ro_prev_i <= '0';

            elsif (rc_fifo_pirq_i(4) = Rc_addr(3) and
                   rc_fifo_pirq_i(5) = Rc_addr(2) and
                   rc_fifo_pirq_i(6) = Rc_addr(1) and
                   rc_fifo_pirq_i(7) = Rc_addr(0)) and
               Rc_data_Exists = '1'
            then
               ro_prev_i <= '1';
            else
               ro_prev_i <= '0';
            end if;
         end if;
      end process RC_FIFO_FULL_PROCESS;

      Ro_prev <= ro_prev_i;

   end generate RD_FIFO_CNTRL;

   ----------------------------------------------------------------------------
   -- RCV_OVRUN_PROCESS
   ----------------------------------------------------------------------------
   -- This process determines when the data receive register has had new data
   -- written to it without a read of the old data
   ----------------------------------------------------------------------------
   NEW_RECIEVE_DATA_PROCESS : process (Clk)  -- delay new_rcv_dta to find edge
   begin
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            new_rcv_dta_d1 <= '0';
         else
            new_rcv_dta_d1 <= New_rcv_dta;
         end if;
      end if;
   end process NEW_RECIEVE_DATA_PROCESS;

   ----------------------------------------------------------------------------
   -- RCV_OVRUN_PROCESS
   ----------------------------------------------------------------------------
   RCV_OVRUN_PROCESS : process (Clk)
   begin  
      -- SRFF set when new data is received, reset when a read of DRR occurs
      -- The second SRFF is set when new data is again received before a
      -- read of DRR occurs.  This sets the Receive Overrun Status Bit
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            ro_a <= '0';
         elsif New_rcv_dta = '1' and new_rcv_dta_d1 = '0' then
            ro_a <= '1';
         elsif New_rcv_dta = '0' and Bus2IIC_RdCE(3) = '1'
         then ro_a <= '0';
         else
            ro_a <= ro_a;
         end if;
      end if;
   end process RCV_OVRUN_PROCESS;

   ----------------------------------------------------------------------------
   -- ADDRESS_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the address register is enabled.
   ----------------------------------------------------------------------------
   ADDRESS_REGISTER_PROCESS : process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            adr_i <= (others => '0');
         elsif                --  Load Status Register with AXI
            --  data if there is a write request
            --  and the status register is enabled
            --   Bus2IIC_WrReq = '1' and Bus2IIC_WrCE(4) = '1' then
            Bus2IIC_WrCE(4) = '1' then
            adr_i(0 to 7) <= Bus2IIC_Data(24 to 31);
         else
            adr_i <= adr_i;
         end if;
      end if;
   end process ADDRESS_REGISTER_PROCESS;

   Adr <= adr_i;


   --PER_BIT_0_TO_31_GEN : for i in 0 to C_S_AXI_DATA_WIDTH-1 generate
   -- BIT_0_TO_31_LOOP : process (rback_data, Bus2IIC_RdCE) is
   -- begin
   --    if (or_reduce(Bus2IIC_RdCE) = '1') then
   --       for m in 0 to C_NUM_IIC_REGS-1 loop
   --          if (Bus2IIC_RdCE(m) = '1') then
   --             IIC2Bus_Data(i) <= rback_data(m*32 + i);
   --          else
   --             IIC2Bus_Data(i) <= '0';
   --          end if;
   --       end loop;
   --    else
   --       IIC2Bus_Data(i) <= '0';
   --    end if;
   -- end process BIT_0_TO_31_LOOP;
   --end generate PER_BIT_0_TO_31_GEN;


   OUTPUT_DATA_GEN_P : process (rback_data, Bus2IIC_RdCE, Bus2IIC_Addr) is
   begin

       if (or_reduce(Bus2IIC_RdCE) = '1') then
           --IIC2Bus_Data <= rback_data((32*TO_INTEGER(unsigned(Bus2IIC_Addr(24 to 29)))) 
                             -- to ((32*TO_INTEGER(unsigned(Bus2IIC_Addr(24 to 29))))+31)); -- CR          
           --case Bus2IIC_Addr(C_S_AXI_ADDR_WIDTH-8 to C_S_AXI_ADDR_WIDTH-1) is
           case Bus2IIC_Addr(1 to 8) is
               when X"00"  => IIC2Bus_Data <= rback_data(0 to 31);    -- CR          
               when X"04"  => IIC2Bus_Data <= rback_data(32 to 63);   -- SR          
               when X"08"  => IIC2Bus_Data <= rback_data(64 to 95);   -- TX_FIFO          
               when X"0C"  => IIC2Bus_Data <= rback_data(96 to 127);  -- RX_FIFO          
               when X"10"  => IIC2Bus_Data <= rback_data(128 to 159); -- ADR          
               when X"14"  => IIC2Bus_Data <= rback_data(160 to 191); -- TX_FIFO_OCY          
               when X"18"  => IIC2Bus_Data <= rback_data(192 to 223); -- RX_FIFO_OCY          
               when X"1C"  => IIC2Bus_Data <= rback_data(224 to 255); -- TEN_ADR          
               when X"20"  => IIC2Bus_Data <= rback_data(256 to 287); -- RX_FIFO_PIRQ          
               when X"24"  => IIC2Bus_Data <= rback_data(288 to 319); -- GPO          
               when X"28"  => IIC2Bus_Data <= rback_data(320 to 351); -- TSUSTA          
               when X"2C"  => IIC2Bus_Data <= rback_data(352 to 383); -- TSUSTO          
               when X"30"  => IIC2Bus_Data <= rback_data(384 to 415); -- THDSTA          
               when X"34"  => IIC2Bus_Data <= rback_data(416 to 447); -- TSUDAT          
               when X"38"  => IIC2Bus_Data <= rback_data(448 to 479); -- TBUF          
               when X"3C"  => IIC2Bus_Data <= rback_data(480 to 511); -- THIGH          
               when X"40"  => IIC2Bus_Data <= rback_data(512 to 543); -- TLOW          
               when X"44"  => IIC2Bus_Data <= rback_data(544 to 575); -- THDDAT          
               when others => IIC2Bus_Data <= (others => '0');
           end case;
       else 
           IIC2Bus_Data <= (others => '0');
       end if;
   end process OUTPUT_DATA_GEN_P;


   ----------------------------------------------------------------------------
   -- READ_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   rback_data(32*1-8 to 32*1-1) <= cr_i(0 to 7);
   rback_data(32*2-9 to 32*2-1) <= '0' & sr_i(0 to 7);--reg_empty & sr_i(0 to 7);
   rback_data(32*3-8 to 32*3-1) <= dtr_i(0 to 7);
   rback_data(32*4-8 to 32*4-1) <= drr_i(0 to 7);
   rback_data(32*5-8 to 32*5-2) <= adr_i(0 to 6);
   rback_data(32*6-8 to 32*6-1) <= rtx_i(0 to 7);
   rback_data(32*7-8 to 32*7-1) <= rrc_i(0 to 7);
   rback_data(32*8-8 to 32*8-1) <= rtn_i(0 to 7);
   rback_data(32*9-8 to 32*9-1) <= rpq_i(0 to 7);

   ----------------------------------------------------------------------------
   -- GPO_RBACK_GEN generate 
   ----------------------------------------------------------------------------
   GPO_RBACK_GEN : if C_GPO_WIDTH /= 0 generate
      rback_data(32*10-C_GPO_WIDTH to 32*10-1)
                       <= gpo_i(32 - C_GPO_WIDTH to C_S_AXI_DATA_WIDTH - 1);

   end generate GPO_RBACK_GEN;

   rback_data(32*11-C_SIZE to 32*11-1) <= timing_param_tsusta_i(C_SIZE-1 downto 0);
   rback_data(32*12-C_SIZE to 32*12-1) <= timing_param_tsusto_i(C_SIZE-1 downto 0);
   rback_data(32*13-C_SIZE to 32*13-1) <= timing_param_thdsta_i(C_SIZE-1 downto 0);
   rback_data(32*14-C_SIZE to 32*14-1) <= timing_param_tsudat_i(C_SIZE-1 downto 0);
   rback_data(32*15-C_SIZE to 32*15-1) <= timing_param_tbuf_i(C_SIZE-1 downto 0);
   rback_data(32*16-C_SIZE to 32*16-1) <= timing_param_thigh_i(C_SIZE-1 downto 0);
   rback_data(32*17-C_SIZE to 32*17-1) <= timing_param_tlow_i(C_SIZE-1 downto 0);
   rback_data(32*18-C_SIZE to 32*18-1) <= timing_param_thddat_i(C_SIZE-1 downto 0);

   rtx_i(0 to 3) <= (others => '0');
   rtx_i(4)      <= Tx_addr(3);
   rtx_i(5)      <= Tx_addr(2);
   rtx_i(6)      <= Tx_addr(1);
   rtx_i(7)      <= Tx_addr(0);

   rrc_i(0 to 3) <= (others => '0');
   rrc_i(4)      <= Rc_addr(3);
   rrc_i(5)      <= Rc_addr(2);
   rrc_i(6)      <= Rc_addr(1);
   rrc_i(7)      <= Rc_addr(0);

   rtn_i(0 to 4) <= (others => '0');
   rtn_i(5 to 7) <= ten_adr_i(5 to 7);

   rpq_i(0 to 3) <= (others => '0');
   rpq_i(4 to 7) <= rc_fifo_pirq_i(4 to 7);

   ----------------------------------------------------------------------------
   -- Interrupts
   ----------------------------------------------------------------------------
   -- Int_PROCESS generates interrupts back to the IPIF
   ----------------------------------------------------------------------------
   INT_PROCESS : process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            IIC2Bus_IntrEvent(0 to 6) <= (others => '0');
         else
            IIC2Bus_IntrEvent(0) <= Al;    -- arbitration lost interrupt
            IIC2Bus_IntrEvent(1) <= Txer;  -- transmit error interrupt
            IIC2Bus_IntrEvent(2) <= Tx_under_prev;  --dtre_i; 
                                           -- Data Tx Register Empty interrupt
            IIC2Bus_IntrEvent(3) <= ro_prev_i;  --New_rcv_dta; 
                                            -- Data Rc Register Full interrupt
            IIC2Bus_IntrEvent(4) <= not Bb;
            IIC2Bus_IntrEvent(5) <= Aas;
            IIC2Bus_IntrEvent(6) <= not Aas;
         end if;
      end if;
   end process INT_PROCESS;

   ----------------------------------------------------------------------------
   -- Ten Bit Slave Address Generate
   ----------------------------------------------------------------------------
   -- Int_PROCESS generates interrupts back to the IPIF
   ----------------------------------------------------------------------------
   TEN_ADR_GEN : if (C_TEN_BIT_ADR = 1) generate

      -------------------------------------------------------------------------
      -- TEN_ADR_REGISTER_PROCESS
      -------------------------------------------------------------------------
      TEN_ADR_REGISTER_PROCESS : process (Clk)
      begin  -- process
         if (Clk'event and Clk = '1') then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               ten_adr_i <= (others => '0');
            elsif             --  Load Status Register with AXI
               --  data if there is a write request
               --  and the status register is enabled
               Bus2IIC_WrCE(7) = '1' then
               ten_adr_i(5 to 7) <= Bus2IIC_Data(29 to 31);
            else
               ten_adr_i <= ten_adr_i;
            end if;
         end if;
      end process TEN_ADR_REGISTER_PROCESS;

      Ten_adr <= ten_adr_i;

   end generate TEN_ADR_GEN;

   ----------------------------------------------------------------------------
   -- General Purpose Ouput Register Generate
   ----------------------------------------------------------------------------
   -- Generate the GPO if C_GPO_WIDTH is not equal to zero
   ----------------------------------------------------------------------------
   GPO_GEN : if (C_GPO_WIDTH /= 0) generate

      -------------------------------------------------------------------------
      -- GPO_REGISTER_PROCESS
      -------------------------------------------------------------------------
      GPO_REGISTER_PROCESS : process (Clk)
      begin  -- process
         if Clk'event and Clk = '1' then
            if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
               gpo_i <= C_DEFAULT_VALUE(C_GPO_WIDTH - 1 downto 0);
            elsif             --  Load Status Register with AXI
               --  data if there is a write CE
               --Bus2IIC_WrCE(C_NUM_IIC_REGS - 1) = '1' then
               Bus2IIC_WrCE(9) = '1' then
               gpo_i(32 - C_GPO_WIDTH to 31) <= 
                                          Bus2IIC_Data(32 - C_GPO_WIDTH to 31);
            else
               gpo_i <= gpo_i;
            end if;
         end if;
      end process GPO_REGISTER_PROCESS;

      Gpo <= gpo_i;

   end generate GPO_GEN;

   ----------------------------------------------------------------------------
   -- TSUSTA_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the tsusta register is enabled.
   ----------------------------------------------------------------------------
   TSUSTA_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            --timing_param_tsusta_i <= (others => '0');
            timing_param_tsusta_i <= TSUSTA;
         elsif                --  Load tsusta Register with AXI
            --  data if there is a write request
            --  and the tsusta register is enabled
            Bus2IIC_WrCE(10) = '1' then
               timing_param_tsusta_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_tsusta_i(C_SIZE-1 downto 0) <= timing_param_tsusta_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process TSUSTA_REGISTER_PROCESS;

   Timing_param_tsusta <= timing_param_tsusta_i;

   ----------------------------------------------------------------------------
   -- TSUSTO_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the tsusto register is enabled.
   ----------------------------------------------------------------------------
   TSUSTO_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            --timing_param_tsusto_i <= (others => '0');
            timing_param_tsusto_i <= TSUSTO;
         elsif                --  Load tsusto Register with AXI
            --  data if there is a write request
            --  and the tsusto register is enabled
            Bus2IIC_WrCE(11) = '1' then
               timing_param_tsusto_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_tsusto_i(C_SIZE-1 downto 0) <= timing_param_tsusto_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process TSUSTO_REGISTER_PROCESS;

   Timing_param_tsusto <= timing_param_tsusto_i;

   ----------------------------------------------------------------------------
   -- THDSTA_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the thdsta register is enabled.
   ----------------------------------------------------------------------------
   THDSTA_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            timing_param_thdsta_i <= THDSTA;
         elsif                --  Load thdsta Register with AXI
            --  data if there is a write request
            --  and the thdsta register is enabled
            Bus2IIC_WrCE(12) = '1' then
               timing_param_thdsta_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_thdsta_i(C_SIZE-1 downto 0) <= timing_param_thdsta_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process THDSTA_REGISTER_PROCESS;

   Timing_param_thdsta <= timing_param_thdsta_i;

   ----------------------------------------------------------------------------
   -- TSUDAT_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the thdsta register is enabled.
   ----------------------------------------------------------------------------
   TSUDAT_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            timing_param_tsudat_i <= TSUDAT;
         elsif                --  Load tsudat Register with AXI
            --  data if there is a write request
            --  and the tsudat register is enabled
            Bus2IIC_WrCE(13) = '1' then
               timing_param_tsudat_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_tsudat_i(C_SIZE-1 downto 0) <= timing_param_tsudat_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process TSUDAT_REGISTER_PROCESS;

   Timing_param_tsudat <= timing_param_tsudat_i;

   ----------------------------------------------------------------------------
   -- TBUF_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the tbuf register is enabled.
   ----------------------------------------------------------------------------
   TBUF_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            timing_param_tbuf_i <= TBUF;
         elsif                --  Load tbuf Register with AXI
            --  data if there is a write request
            --  and the tbuf register is enabled
            Bus2IIC_WrCE(14) = '1' then
               timing_param_tbuf_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_tbuf_i(C_SIZE-1 downto 0) <= timing_param_tbuf_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process TBUF_REGISTER_PROCESS;

   Timing_param_tbuf <= timing_param_tbuf_i;

   ----------------------------------------------------------------------------
   -- THIGH_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the thigh register is enabled.
   ----------------------------------------------------------------------------
   THIGH_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            timing_param_thigh_i <= HIGH_CNT;
         elsif                --  Load thigh Register with AXI
            --  data if there is a write request
            --  and the thigh register is enabled
            Bus2IIC_WrCE(15) = '1' then
               timing_param_thigh_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_thigh_i(C_SIZE-1 downto 0) <= timing_param_thigh_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process THIGH_REGISTER_PROCESS;

   Timing_param_thigh <= timing_param_thigh_i;

   ----------------------------------------------------------------------------
   -- TLOW_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the thigh register is enabled.
   ----------------------------------------------------------------------------
   TLOW_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            timing_param_tlow_i <= LOW_CNT;
         elsif                --  Load tlow Register with AXI
            --  data if there is a write request
            --  and the tlow register is enabled
            Bus2IIC_WrCE(16) = '1' then
               timing_param_tlow_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_tlow_i(C_SIZE-1 downto 0) <= timing_param_tlow_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process TLOW_REGISTER_PROCESS;

   Timing_param_tlow <= timing_param_tlow_i;

   ----------------------------------------------------------------------------
   -- THDDAT_REGISTER_PROCESS
   ----------------------------------------------------------------------------
   -- This process loads data from the AXI when there is a write request and 
   -- the thddat register is enabled.
   ----------------------------------------------------------------------------
   THDDAT_REGISTER_PROCESS: process (Clk)
   begin  -- process
      if (Clk'event and Clk = '1') then
         if Rst = axi_iic_v2_0_21.iic_pkg.RESET_ACTIVE then
            timing_param_thddat_i <= THDDAT;
         elsif                --  Load thddat Register with AXI
            --  data if there is a write request
            --  and the thddat register is enabled
            Bus2IIC_WrCE(17) = '1' then
               timing_param_thddat_i(C_SIZE-1 downto 0) <= Bus2IIC_Data(C_S_AXI_DATA_WIDTH-C_SIZE to C_S_AXI_DATA_WIDTH-1);
         else                 -- Load Control Register with iic data
               timing_param_thddat_i(C_SIZE-1 downto 0) <= timing_param_thddat_i(C_SIZE-1 downto 0);
         end if;
      end if;
   end process THDDAT_REGISTER_PROCESS;

   Timing_param_thddat <= timing_param_thddat_i;

end architecture RTL;


-------------------------------------------------------------------------------
-- iic_control.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        iic_control.vhd
-- Version:         v1.01.b
-- Description:
--                  This file contains the main state machines for the iic
--                  bus interface logic
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
--  - Added function calc_tbuf to calculate the TBUF delay
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Fixed the CR#613282
--  - Release of v1.01.b
-- ~~~~~~
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library axi_iic_v2_0_21;
use axi_iic_v2_0_21.iic_pkg.all;
use axi_iic_v2_0_21.upcnt_n;
use axi_iic_v2_0_21.shift8;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_S_AXI_ACLK_FREQ_HZ-- Specifies AXI clock frequency
--      C_IIC_FREQ          -- Maximum IIC frequency of Master Mode in Hz
--      C_TEN_BIT_ADR       -- 10 bit slave addressing
--
-- Definition of Ports:
--      Sys_clk             -- System clock
--      Reset               -- System Reset
--      Sda_I               -- IIC serial data input
--      Sda_O               -- IIC serial data output
--      Sda_T               -- IIC seral data output enable
--      Scl_I               -- IIC serial clock input
--      Scl_O               -- IIC serial clock output
--      Scl_T               -- IIC serial clock output enable
--      Txak                -- Value for acknowledge when xmit
--      Gc_en               -- General purpose outputs
--      Ro_prev             -- Receive over run prevent
--      Dtre                -- Data transmit register empty
--      Msms                -- Data transmit register empty
--      Msms_rst            -- Msms Reset signal
--      Msms_set            -- Msms set
--      Rsta                -- Repeated start
--      Rsta_rst            -- Repeated start Reset
--      Tx                  -- Master read/write
--      Dtr                 -- Data transmit register
--      Adr                 -- IIC slave address
--      Ten_adr             -- IIC slave 10 bit address
--      Bb                  -- Bus busy indicator
--      Dtc                 -- Data transfer
--      Aas                 -- Addressed as slave indicator
--      Al                  -- Arbitration lost indicator
--      Srw                 -- Slave read/write indicator
--      Txer                -- Received acknowledge indicator
--      Abgc                -- Addressed by general call indicator
--      Data_i2c            -- IIC data for processor
--      New_rcv_dta         -- New Receive Data ready
--      Rdy_new_xmt         -- New data loaded in shift reg indicator
--      Tx_under_prev       -- DTR or Tx FIFO empty IRQ indicator
--      EarlyAckHdr         -- ACK_HEADER state strobe signal
--      EarlyAckDataState   -- Data ack early acknowledge signal
--      AckDataState        -- Data ack acknowledge signal
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------
entity iic_control is
   generic(
      C_SCL_INERTIAL_DELAY        : integer range 0 to 255 := 5;
      C_S_AXI_ACLK_FREQ_HZ        : integer := 100000000;
      C_IIC_FREQ                  : integer := 100000;
      C_SIZE                      : integer := 32;
      C_TEN_BIT_ADR               : integer := 0;
      C_SDA_LEVEL                 : integer := 1;
      C_SMBUS_PMBUS_HOST          : integer := 0   -- SMBUS/PMBUS support
      );
   port(

      -- System signals
      Sys_clk           : in std_logic;
      Reset             : in std_logic;

      -- iic bus tristate driver control signals
      Sda_I             : in  std_logic;
      Sda_O             : out std_logic;
      Sda_T             : out std_logic;
      Scl_I             : in  std_logic;
      Scl_O             : out std_logic;
      Scl_T             : out std_logic;

      Timing_param_tsusta   : in std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tsusto   : in std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_thdsta   : in std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tsudat   : in std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tbuf     : in std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_thigh    : in std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_tlow     : in std_logic_vector(C_SIZE-1 downto 0);
      Timing_param_thddat   : in std_logic_vector(C_SIZE-1 downto 0);

      -- interface signals from uP
      Txak              : in  std_logic;
      Gc_en             : in  std_logic;
      Ro_prev           : in  std_logic;
      Dtre              : in  std_logic;
      Msms              : in  std_logic;
      Msms_rst          : out std_logic;
      Msms_set          : in  std_logic;
      Rsta              : in  std_logic;
      Rsta_rst          : out std_logic;
      Tx                : in  std_logic;
      Dtr               : in  std_logic_vector(7 downto 0);
      Adr               : in  std_logic_vector(7 downto 0);
      Ten_adr           : in  std_logic_vector(7 downto 5);
      Bb                : out std_logic;
      Dtc               : out std_logic;
      Aas               : out std_logic;
      Al                : out std_logic;
      Srw               : out std_logic;
      Txer              : out std_logic;
      Abgc              : out std_logic;
      Data_i2c          : out std_logic_vector(7 downto 0);
      New_rcv_dta       : out std_logic;
      Rdy_new_xmt       : out std_logic;
      Tx_under_prev     : out std_logic;
      EarlyAckHdr       : out std_logic;
      EarlyAckDataState : out std_logic;
      AckDataState      : out std_logic;
      reg_empty         :out std_logic
      );

end iic_control;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------

architecture RTL of iic_control is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


   -- Bus free time.
   constant CLR_REG    : std_logic_vector(7 downto 0)       := "00000000";
   constant START_CNT  : std_logic_vector(3 downto 0)       := "0000";
   constant CNT_DONE   : std_logic_vector(3 downto 0)       := "1000";
   constant ZERO_CNT   : std_logic_vector(C_SIZE-1 downto 0):= (others => '0');
   constant ZERO       : std_logic                          := '0';
   constant ENABLE_N   : std_logic                          := '0';
   constant CNT_ALMOST_DONE : std_logic_vector (3 downto 0) := "0111";

   type state_type is (IDLE,
                       HEADER,
                       ACK_HEADER,
                       RCV_DATA,
                       ACK_DATA,
                       XMIT_DATA,
                       WAIT_ACK);
   signal state : state_type;

   type scl_state_type is (SCL_IDLE,
                           START_WAIT,
                           START,
                           START_EDGE,
                           SCL_LOW_EDGE,
                           SCL_LOW,
                           SCL_HIGH_EDGE,
                           SCL_HIGH,
                           STOP_EDGE,
                           STOP_WAIT);
   signal scl_state      : scl_state_type;
   signal next_scl_state : scl_state_type;

   signal scl_rin          : std_logic;  -- sampled version of scl
   signal scl_d1           : std_logic;  -- sampled version of scl
   signal scl_rin_d1       : std_logic;  -- delayed version of Scl_rin
   signal scl_cout         : std_logic;  -- combinatorial scl output
   signal scl_cout_reg     : std_logic;  -- registered version of scl_cout
   signal scl_rising_edge  : std_logic;  -- falling edge of SCL
   signal scl_falling_edge : std_logic;  -- falling edge of SCL
   signal scl_f_edg_d1     : std_logic;  -- falling edge of SCL delayed one
                                         -- clock
   signal scl_f_edg_d2     : std_logic;  -- falling edge of SCL delayed two
                                         -- clock
   signal scl_f_edg_d3     : std_logic;  -- falling edge of SCL delayed three
                                         -- clock
   signal sda_rin          : std_logic;  -- sampled version of sda
   signal sda_d1           : std_logic;  -- sampled version of sda
   signal sda_rin_d1       : std_logic;  -- delayed version of sda_rin
   signal sda_falling      : std_logic;  -- Pulses when SDA falls
   signal sda_rising       : std_logic;  -- Pulses when SDA rises
   signal sda_changing     : std_logic;  -- Pulses when SDA changes
   signal sda_setup        : std_logic;  -- SDA setup time in progress
   signal sda_setup_cnt    : std_logic_vector (C_SIZE-1 downto 0);
                                         -- SDA setup time count
   signal sda_cout         : std_logic;  -- combinatorial sda output
   signal sda_cout_reg     : std_logic;  -- registered version of sda_cout
   signal sda_cout_reg_d1  : std_logic;  -- delayed sda output for arb
                                         -- comparison
   signal sda_sample       : std_logic;  -- SDA_RIN sampled at SCL rising edge
   signal slave_sda        : std_logic;  -- sda value when slave
   signal master_sda       : std_logic;  -- sda value when master

   signal sda_oe       : std_logic;
   signal master_slave : std_logic;  -- 1 if master, 0 if slave

-- Shift Register and the controls
   signal shift_reg       : std_logic_vector(7 downto 0); -- iic data shift reg
   signal shift_out       : std_logic;
   signal shift_reg_en    : std_logic;
   signal shift_reg_ld    : std_logic;
   signal shift_reg_ld_d1 : std_logic;
   signal i2c_header      : std_logic_vector(7 downto 0);-- I2C header register
   signal i2c_header_en   : std_logic;
   signal i2c_header_ld   : std_logic;
   signal i2c_shiftout    : std_logic;

-- Used to check slave address detected
   signal addr_match : std_logic;

   signal arb_lost   : std_logic;  -- 1 if arbitration is lost
   signal msms_d1    : std_logic;  -- Msms processed to initiate a stop
                                   -- sequence after data has been transmitted
   signal msms_d2    : std_logic;  -- delayed sample of msms_d1
   signal msms_rst_i : std_logic;  -- internal msms_rst

   signal detect_start : std_logic;  -- START condition has been detected
   signal detect_stop  : std_logic;  -- STOP condition has been detected
   signal detect_stop_b: std_logic;
   signal sm_stop      : std_logic;  -- STOP condition needs to be generated
                                     -- from state machine
   signal bus_busy     : std_logic;  -- indicates that the bus is busy
                                     -- set when START, cleared when STOP
   signal bus_busy_d1  : std_logic;  -- delayed sample of bus busy
   signal gen_start    : std_logic;  -- uP wants to generate a START
   signal gen_stop     : std_logic;  -- uP wants to generate a STOP
   signal rep_start    : std_logic;  -- uP wants to generate a repeated START
   signal stop_scl     : std_logic;  -- signal in SCL state machine
                                     -- indicating a STOP
   signal stop_scl_reg : std_logic;  -- registered version of STOP_SCL

-- Bit counter 0 to 7
   signal bit_cnt      : std_logic_vector(3 downto 0);
   signal bit_cnt_ld   : std_logic;
   signal bit_cnt_clr  : std_logic;
   signal bit_cnt_en   : std_logic;

-- Clock Counter
   signal clk_cnt     : std_logic_vector (C_SIZE-1 downto 0);
   signal clk_cnt_rst : std_logic;
   signal clk_cnt_en  : std_logic;
   signal stop_start_wait  : std_logic;

-- the following signals are only here because Viewlogic's VHDL compiler won't
-- allow a constant to be used in a component instantiation
   signal reg_clr   : std_logic_vector(7 downto 0);
   signal zero_sig  : std_logic;
   signal cnt_zero  : std_logic_vector(C_SIZE-1 downto 0);
   signal cnt_start : std_logic_vector(3 downto 0);

   signal data_i2c_i         : std_logic_vector(7 downto 0);
   signal aas_i              : std_logic;  -- internal addressed as slave
                                           -- signal
   signal srw_i              : std_logic;  -- internal slave read write signal
   signal abgc_i             : std_logic;  -- internal addressed by a general
                                           -- call
   signal dtc_i              : std_logic;  -- internal data transmit compete
                                           -- signal
   signal dtc_i_d1           : std_logic;  -- delayed internal data transmit
                                           -- complete
   signal dtc_i_d2           : std_logic;  -- 2nd register delay of dtc
   signal al_i               : std_logic;  -- internal arbitration lost signal
   signal al_prevent         : std_logic;  -- prevent arbitration lost when
                                           -- last word
   signal rdy_new_xmt_i      : std_logic;  -- internal ready to transmit new
                                           -- data
   signal tx_under_prev_i    : std_logic;  -- TX underflow prevent signal
   signal rsta_tx_under_prev : std_logic;  -- Repeated Start Tx underflow
                                           -- prevent
   signal rsta_d1            : std_logic;  -- Delayed one clock version of Rsta
   signal dtre_d1            : std_logic;  -- Delayed one clock version of Dtre
   signal txer_i             : std_logic;  -- internal Txer signal
   signal txer_edge          : std_logic;  -- Pulse for Txer IRQ

   -- the following signal are used only when 10-bit addressing has been
   -- selected
   signal msb_wr             : std_logic;  -- the 1st byte of 10 bit addressing
                                           -- comp
   signal msb_wr_d           : std_logic;  -- delayed version of msb_wr
   signal msb_wr_d1          : std_logic;  -- delayed version of msb_wr_d
   signal sec_addr           : std_logic := '0';  -- 2nd byte qualifier
   signal sec_adr_match      : std_logic;  -- 2nd byte compare
   signal adr_dta_l          : std_logic := '0';  -- prevents 2nd adr byte load
                                                  -- in DRR
   signal new_rcv_dta_i      : std_logic;  -- internal New_rcv_dta
   signal ro_prev_d1         : std_logic;  -- delayed version of Ro_prev


   signal gen_stop_and_scl_hi : std_logic;  -- signal to prevent SCL state
                              -- machine from getting stuck during a No Ack

   signal setup_cnt_rst      : std_logic;
   signal tx_under_prev_d1   : std_logic;
   signal tx_under_prev_fe   : std_logic;
   signal rsta_re            : std_logic;
   signal gen_stop_d1        : std_logic;
   signal gen_stop_re        : std_logic;
----Mathew
   signal shift_cnt          : std_logic_vector(8 downto 0);
--   signal reg_empty          : std_logic;
----------   
begin

   ----------------------------------------------------------------------------
   -- SCL Tristate driver controls for open-collector emulation
   ----------------------------------------------------------------------------
   Scl_T <= '0' when scl_cout_reg = '0'
                     -- Receive fifo overflow throttle condition
                     or Ro_prev = '1'
                     -- SDA changing requires additional setup to SCL change
                     or (sda_setup = '1' )
                     -- Restart w/ transmit underflow prevention throttle
                     -- condition
                     or rsta_tx_under_prev = '1'  else
            '1';

   Scl_O <= '0';

   ----------------------------------------------------------------------------
   -- SDA Tristate driver controls for open-collector emulation
   ----------------------------------------------------------------------------
   Sda_T <= '0' when ((master_slave = '1' and arb_lost = '0'
                       and sda_cout_reg = '0')
                       or (master_slave = '0' and slave_sda = '0')
                       or stop_scl_reg = '1') else
            '1';

   Sda_O <= '0';


   -- the following signals are only here because Viewlogic's VHDL compiler
   -- won't allow a constant to be used in a component instantiation
   reg_clr   <= CLR_REG;
   zero_sig  <= ZERO;
   cnt_zero  <= ZERO_CNT;
   cnt_start <= START_CNT;

   ----------------------------------------------------------------------------
   -- INT_DTRE_RSTA_DELAY_PROCESS
   ----------------------------------------------------------------------------
   -- This process delays Dtre and RSTA by one clock to edge detect
   -- Dtre = data transmit register empty
   -- Rsta = firmware restart command
   ----------------------------------------------------------------------------
   INT_DTRE_RSTA_DELAY_PROCESS : process (Sys_clk)
   begin
      if (Sys_clk'event and Sys_clk = '1') then
         if Reset = ENABLE_N then
            rsta_d1     <= '0';
            dtre_d1     <= '0';
            ro_prev_d1  <= '0';
            gen_stop_d1 <= '0';
            tx_under_prev_d1 <= '0';
         else
            rsta_d1     <= Rsta;
            dtre_d1     <= Dtre;
            ro_prev_d1  <= Ro_prev;
            gen_stop_d1 <= gen_stop;
            tx_under_prev_d1 <= tx_under_prev_i;
         end if;
      end if;
   end process INT_DTRE_RSTA_DELAY_PROCESS;

   tx_under_prev_fe <= tx_under_prev_d1 and not tx_under_prev_i;
   rsta_re <= Rsta and not rsta_d1 ;
   gen_stop_re <= gen_stop and not gen_stop_d1;

   ----------------------------------------------------------------------------
   -- INT_RSTA_TX_UNDER_PREV_PROCESS
   ----------------------------------------------------------------------------
   -- This process creates a signal that prevent SCL from going high when a
   -- underflow condition would be caused, by a repeated start condition.
   ----------------------------------------------------------------------------
   INT_RSTA_TX_UNDER_PREV_PROCESS : process (Sys_clk)
   begin
      if (Sys_clk'event and Sys_clk = '1') then
         if Reset = ENABLE_N then
            rsta_tx_under_prev <= '0';
         elsif (Rsta = '1' and rsta_d1 = '0' and Dtre = '1' ) then
            rsta_tx_under_prev <= '1';
         elsif (Dtre = '0' and dtre_d1 = '1') then
            rsta_tx_under_prev <= '0';
         else
            rsta_tx_under_prev <= rsta_tx_under_prev;
         end if;
      end if;
   end process INT_RSTA_TX_UNDER_PREV_PROCESS;

   ----------------------------------------------------------------------------
   -- INT_TX_UNDER_PREV_PROCESS
   ----------------------------------------------------------------------------
   -- This process creates a signal that prevent SCL from going high when a
   -- underflow condition would be caused. Transmit underflow can occur in both
   -- master and slave situations
   ----------------------------------------------------------------------------
   INT_TX_UNDER_PREV_PROCESS : process (Sys_clk)
   begin
      if (Sys_clk'event and Sys_clk = '1') then
         if Reset = ENABLE_N then
            tx_under_prev_i <= '0';
         elsif (Dtre = '1' and (state = WAIT_ACK or state = ACK_HEADER)
                and scl_falling_edge = '1' and gen_stop = '0'
                and ((aas_i = '0' and srw_i = '0')
                     or (aas_i = '1' and srw_i = '1'))) then
            tx_under_prev_i <= '1';
         elsif (state = RCV_DATA or state = IDLE or Dtre='0') then
            tx_under_prev_i <= '0';
         end if;
      end if;
   end process INT_TX_UNDER_PREV_PROCESS;

   Tx_under_prev <= tx_under_prev_i;

   ----------------------------------------------------------------------------
   -- SDASETUP
   ----------------------------------------------------------------------------
   -- Whenever SDA changes there is an associated setup time that must be
   -- obeyed before SCL can change. (The exceptions are starts/stops which
   -- haven't other timing specifications.) It doesn't matter whether this is
   -- a Slave | Master, TX | RX. The "setup" counter and the "sdasetup" process
   -- guarantee this time is met regardless of the devices on the bus and their
   -- attempts to manage setup time. The signal sda_setup, when asserted,
   -- causes SCL to be held low until the setup condition is removed. Anytime a
   -- change in SDA is detected on the bus the setup process is invoked. Also,
   -- sda_setup is asserted if the transmit throttle condition is active.
   -- When it deactivates, SDA **may** change on the SDA bus. In this way,
   -- the SCL_STATE machine will be held off as well because it waits for SCL
   -- to actually go high.
   ----------------------------------------------------------------------------
   SETUP_CNT : entity axi_iic_v2_0_21.upcnt_n
      generic map (
         C_SIZE => C_SIZE
         )

      port map(
               Clk    => Sys_clk,
               Clr    => Reset,
               Data   => cnt_zero,
               Cnt_en => sda_setup,
               Load   => sda_changing,
               Qout   => sda_setup_cnt
               );

   ----------------------------------------------------------------------------
   -- SDASETUP Process
   ----------------------------------------------------------------------------
   SDASETUP : process (Sys_clk)
   begin
      if (Sys_clk'event and Sys_clk = '1') then
         if Reset = ENABLE_N then
            sda_setup <= '0';
         elsif (
            -- If SDA is changing on the bus then enforce setup time
            sda_changing = '1'
            -- or if SDA is about to change ...
            or tx_under_prev_i = '1') -- modified
            -- For either of the above cases the controller only cares
            -- about SDA setup when it is legal to change SDA.
            and scl_rin='0' then
            sda_setup <= '1';
         elsif (sda_setup_cnt=Timing_param_tsudat) then
            sda_setup <= '0';
         end if;
      end if;
   end process SDASETUP;

   ----------------------------------------------------------------------------
   -- Arbitration Process
   -- This process checks the master's outgoing SDA with the incoming SDA to
   -- determine if control of the bus has been lost. SDA is checked only when
   -- SCL is high and during the states HEADER and XMIT_DATA (when data is
   -- actively being clocked out of the controller). When arbitration is lost,
   -- a Reset is generated for the Msms bit per the product spec.
   -- Note that when arbitration is lost, the mode is switched to slave.
   -- arb_lost stays set until scl state machine goes to IDLE state
   ----------------------------------------------------------------------------
   ARBITRATION : process (Sys_clk)
   begin
      if (Sys_clk'event and Sys_clk = '1') then
         if Reset = ENABLE_N then
            arb_lost   <= '0';
            msms_rst_i <= '0';
         elsif scl_state = SCL_IDLE or scl_state = STOP_WAIT then
            arb_lost   <= '0';
            msms_rst_i <= '0';
         elsif (master_slave = '1') then
            -- Actively generating SCL clock as the master and (possibly)
            -- participating in multi-master arbitration.
            if (scl_rising_edge='1'
                and (state = HEADER or state = XMIT_DATA)) then
               if (sda_cout_reg='1' and sda_rin = '0') then
                  -- Other master drove SDA to 0 but the controller is trying
                  -- to drive a 1. That is the exact case for loss of
                  -- arbitration
                  arb_lost   <= '1';
                  msms_rst_i <= '1';
               else
                  arb_lost   <= '0';
                  msms_rst_i <= '0';
               end if;
            else
               msms_rst_i <= '0';
            end if;

         end if;
      end if;
   end process ARBITRATION;

   Msms_rst <= msms_rst_i
               -- The spec states that the Msms bit should be cleared when an
               -- address is not-acknowledged. The sm_stop indicates that
               -- a not-acknowledge occured on either a data or address
               -- (header) transfer. This fixes CR439859.
               or sm_stop;

   ----------------------------------------------------------------------------
   -- SCL_GENERATOR_COMB Process
   -- This process generates SCL and SDA when in Master mode. It generates the
   -- START and STOP conditions. If arbitration is lost, SCL will not be
   -- generated until the end of the byte transfer.
   ----------------------------------------------------------------------------
   SCL_GENERATOR_COMB : process (
                                 scl_state,
                                 arb_lost,
                                 sm_stop,
                                 gen_stop,
                                 rep_start,
                                 bus_busy,
                                 gen_start,
                                 master_slave,
                                 stop_scl_reg,
                                 clk_cnt,
                                 scl_rin,
                                 sda_rin,
                                 state,
                                 sda_cout_reg,
                                 master_sda,
                                 detect_stop_b,
                                 stop_start_wait,
                                 Timing_param_tsusta,
                                 Timing_param_tsusto,
                                 Timing_param_thdsta,
                                 Timing_param_thddat,
                                 Timing_param_tbuf,
                                 Timing_param_tlow,
                                 Timing_param_thigh
                                 )
   begin
      -- state machine defaults
      scl_cout       <= '1';
      sda_cout       <= sda_cout_reg;
      stop_scl       <= stop_scl_reg;
      clk_cnt_en     <= '0';
      clk_cnt_rst    <= '1';
      next_scl_state <= scl_state;
      Rsta_rst       <= (ENABLE_N);
      stop_start_wait  <= detect_stop_b;

      case scl_state is

         when SCL_IDLE =>
            sda_cout <= '1';
            stop_scl <= '0';
            clk_cnt_en  <= detect_stop_b;
            clk_cnt_rst <= not(detect_stop_b);
            stop_start_wait  <= detect_stop_b;
            if clk_cnt = Timing_param_tbuf then
             clk_cnt_rst <= '1';
             clk_cnt_en  <= '0';
             stop_start_wait  <= '0';
            end if;
            -- leave IDLE state when master, bus is idle, and gen_start
            if master_slave = '1' and bus_busy = '0' and gen_start = '1' then
              if stop_start_wait = '1' then
               next_scl_state <= START_WAIT;
              else
               next_scl_state <= START;
              end if;
            else
               next_scl_state <= SCL_IDLE;
            end if;

         when START_WAIT =>
            clk_cnt_en  <= '1';
            clk_cnt_rst <= '0';
            stop_scl    <= '0';
            if clk_cnt = Timing_param_tbuf then
               next_scl_state <= START;
               stop_start_wait  <= '0';
            else
               next_scl_state <= START_WAIT;
            end if;

         when START =>
            -- generate start condition
            clk_cnt_en  <= '0';
            clk_cnt_rst <= '1';
            sda_cout    <= '0';
            stop_scl    <= '0';
            if sda_rin='0' then
               next_scl_state <= START_EDGE;
            else
               next_scl_state <= START;
            end if;

         when START_EDGE =>
            -- This state ensures that the hold time for the (repeated) start
            -- condition is met. The hold time is measured from the Vih level
            -- of SDA so it is critical for SDA to be sampled low prior to
            -- starting the hold time counter.
            clk_cnt_en  <= '1';
            clk_cnt_rst <= '0';
            -- generate Reset for repeat start bit if repeat start condition
            if rep_start = '1' then
               Rsta_rst <= not(ENABLE_N);
            end if;

            if clk_cnt = Timing_param_thdsta then
               next_scl_state <= SCL_LOW_EDGE;
            else
               next_scl_state <= START_EDGE;
            end if;

         when SCL_LOW_EDGE =>
            clk_cnt_rst    <= '1';
            scl_cout       <= '0';
            stop_scl       <= '0';
            if (scl_rin='0') then
               clk_cnt_en  <= '1';
               clk_cnt_rst <= '0';
            end if;
            if ((scl_rin = '0') and (clk_cnt = Timing_param_thddat)) then
               -- SCL sampled to be 0 so everything on the bus can see that it
               -- is low too. The very large propagation delays caused by
               -- potentially large (~300ns or more) fall time should not be
               -- ignored by the controller.It must VERIFY that the bus is low.
               next_scl_state <= SCL_LOW;
               clk_cnt_en  <= '0';
               clk_cnt_rst <= '1';
            else
               next_scl_state <= SCL_LOW_EDGE;
            end if;

         when SCL_LOW =>
            clk_cnt_en <= '1';
            clk_cnt_rst <= '0';
            scl_cout    <= '0';
            stop_scl <= '0';

            -- SDA (the data) can only be changed when SCL is low. Note that
            -- STOPS and RESTARTS could appear  after the SCL low period
            -- has expired because the controller is throttled.
            if (sm_stop = '1' or gen_stop = '1')
               and state /= ACK_DATA
               and state /= ACK_HEADER
               and state /= WAIT_ACK then
               stop_scl <= '1';
               -- Pull SDA low in anticipation of raising it to generate the
               -- STOP edge
               sda_cout <= '0';
            elsif rep_start = '1' then
               -- Release SDA in anticipation of dropping it to generate the
               -- START edge
               sda_cout <= '1';
            else
               sda_cout <= master_sda;
            end if;

            -- Wait until minimum low clock period requirement is met then
            -- proceed to release the SCL_COUT so that it is "possible" for the
            -- scl clock to go high on the bus. Note that a SLAVE device can
            -- continue to hold SCL low to throttle the bus OR the master
            -- itself may hold SCL low because of an internal throttle
            -- condition.
            if clk_cnt = Timing_param_tlow then
               next_scl_state <= SCL_HIGH_EDGE;
            else
               next_scl_state <= SCL_LOW;
            end if;

         when SCL_HIGH_EDGE =>
            clk_cnt_rst <= '1';
            stop_scl <= '0';
            -- SCL low time met. Try to release SCL to make it go high.
            scl_cout    <= '1';

            -- SDA (the data) can only be changed when SCL is low. In this
            -- state the fsm wants to change SCL to high and is waiting to see
            -- it go high. However, other processes may be inhibiting SCL from
            -- going high because the controller is throttled. While throttled,
            -- and scl is still low:
            -- (1) a STOP may be requested by the firmware, **OR**
            -- (2) a RESTART may be requested (with or without data available)
            --     by the firmware, **OR**
            -- (3) new data may get loaded into the TX_FIFO and the first bit
            --     is available to be loaded onto the SDA pin

            -- Removed this condition as sda_cout should not go low when
            -- SCL goes high. SDA should be changed in SCL_LOW state.
            if (sm_stop = '1' or gen_stop = '1')
               and state /= ACK_DATA
               and state /= ACK_HEADER
               and state /= WAIT_ACK then
               stop_scl <= '1';
            --   -- Pull SDA low in anticipation of raising it to generate the
            --   -- STOP edge
               sda_cout <= '0';
            elsif rep_start = '1' then
            --if stop_scl_reg = '1' then
            --   stop_scl <= '1';
            --   sda_cout <= '0';
            --elsif rep_start = '1' then
               -- Release SDA in anticipation of dropping it to generate the
               -- START edge
               sda_cout <= '1';
            else
               sda_cout <= master_sda;
            end if;

            -- Nothing in the controller should
            --  a) sample SDA_RIN until the controller actually verifies that
            --  SCL has gone high, and
            --  b) change SDA_COUT given that it is trying to change SCL now.
            -- Note that other processes may inhibit SCL from going high to
            -- wait for the transmit data register to be filled with data. In
            -- that case data setup requirements imposed by the I2C spec must
            -- be satisfied. Regardless, the SCL clock generator can wait here
            -- in SCL_HIGH_EDGE until that is accomplished.
            if (scl_rin='1') then
               next_scl_state <= SCL_HIGH;
            else
               next_scl_state <= SCL_HIGH_EDGE;
            end if;

         when SCL_HIGH =>
            -- SCL is now high (released) on the external bus. At this point
            -- the state machine doesn't have to worry about any throttle
            -- conditions -- by definition they are removed as SCL is no longer
            -- low. The firmware **must** signal the desire to STOP or Repeat
            -- Start when throttled.

            -- It is decision time. Should another SCL clock pulse get
            -- generated? (IE a low period + high period?) The answer depends
            -- on whether the previous clock was a DATA XFER clock or an ACK
            -- CLOCK. Should a Repeated Start be generated? Should a STOP be
            -- generated?

            clk_cnt_en  <= '1';
            clk_cnt_rst <= '0';
            scl_cout    <= '1';
            if (arb_lost='1') then
               -- No point in continuing! The other master will generate the
               -- clock.
               next_scl_state <= SCL_IDLE;
            else
               -- Determine HIGH time based on need to generate a repeated
               -- start, a stop or the full high period of the SCL clock.
               -- (Without some analysis it isn't clear if rep_start and
               -- stop_scl_reg are mutually exclusive. Hence the priority
               -- encoder.)
               if rep_start = '1' then
                  if (clk_cnt=Timing_param_tsusta) then
                    -- The hidden assumption here is that SDA has been released
                    -- by the slave|master receiver after the ACK clock so that
                    -- a repeated start is possible
                     next_scl_state <= START;
                     clk_cnt_en     <= '0';
                     clk_cnt_rst    <= '1';
                  end if;
               elsif stop_scl_reg = '1' then
                  if (clk_cnt=Timing_param_tsusto) then
                     -- The hidden assumption here is that SDA has been pulled
                     -- low by the master after the ACK clock so that a
                     -- stop is possible
                     next_scl_state <= STOP_EDGE;
                     clk_cnt_rst    <= '1';
                     clk_cnt_en     <= '0';
                     sda_cout       <= '1';  -- issue the stop
                     stop_scl       <= '0';
                  end if;
               else
                  -- Neither repeated start nor stop requested
                  if clk_cnt= Timing_param_thigh then
                     next_scl_state <= SCL_LOW_EDGE;
                     clk_cnt_rst    <= '1';
                     clk_cnt_en     <= '0';
                  end if;
               end if;
            end if;

         when STOP_EDGE =>
            if (sda_rin='1') then
               next_scl_state <= STOP_WAIT;
            else
               next_scl_state <= STOP_EDGE;
            end if;

         when STOP_WAIT =>
            -- The Stop setup time was satisfied and SDA was sampled high
            -- indicating the stop occured. Now wait the TBUF time required
            -- between a stop and the next start.
            clk_cnt_en  <= '1';
            clk_cnt_rst <= '0';
            stop_scl    <= '0';
            if clk_cnt = Timing_param_tbuf then
               next_scl_state <= SCL_IDLE;
            else
               next_scl_state <= STOP_WAIT;
            end if;

       -- coverage off
         when others  =>
            next_scl_state <= SCL_IDLE;
       -- coverage on

      end case;

   end process SCL_GENERATOR_COMB;

   ----------------------------------------------------------------------------
   --PROCESS : SCL_GENERATOR_REGS
   ----------------------------------------------------------------------------
   SCL_GENERATOR_REGS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            scl_state    <= SCL_IDLE;
            sda_cout_reg <= '1';
            scl_cout_reg <= '1';
            stop_scl_reg <= '0';
        else
           scl_state    <= next_scl_state;
           sda_cout_reg <= sda_cout;
           -- Ro_prev = receive overflow prevent = case where controller must
           -- hold SCL low itself until receive fifo is emptied by the firmware
           scl_cout_reg <= scl_cout and not Ro_prev;
           stop_scl_reg <= stop_scl;
        end if;
      end if;
   end process SCL_GENERATOR_REGS;

   ----------------------------------------------------------------------------
   -- Clock Counter Implementation
   -- The following code implements the counter that divides the sys_clock for
   -- creation of SCL. Control lines for this counter are set in SCL state
   -- machine
   ----------------------------------------------------------------------------
   CLKCNT : entity axi_iic_v2_0_21.upcnt_n
      generic map (
         C_SIZE => C_SIZE
         )

      port map(
                Clk    => Sys_clk,
                Clr    => Reset,
                Data    => cnt_zero,
                Cnt_en => clk_cnt_en,
                Load   => clk_cnt_rst,
                Qout   => clk_cnt
                );

   ----------------------------------------------------------------------------
   -- Input Registers Process
   -- This process samples the incoming SDA and SCL with the system clock
   ----------------------------------------------------------------------------
  
   sda_rin <= Sda_I;
   scl_rin <= Scl_I;

   INPUT_REGS : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then

          sda_rin_d1 <= sda_rin;  -- delay sda_rin to find edges

          scl_rin_d1 <= scl_rin;  -- delay Scl_rin to find edges

          sda_cout_reg_d1 <= sda_cout_reg;
      end if;
   end process INPUT_REGS;


   ----------------------------------------------------------------------------
   -- Master Slave Mode Select Process
   -- This process allows software to write the value of Msms with each data
   -- word to be transmitted.  So writing a '0' to Msms will initiate a stop
   -- sequence on the I2C bus after the that byte in the DTR has been sent.
   ----------------------------------------------------------------------------
   MSMS_PROCESS : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            msms_d1 <= '0';
            msms_d2 <= '0';
         else
            msms_d1 <= (Msms and not msms_rst_i)
                       or ((msms_d1 and not (dtc_i_d1 and not dtc_i_d2) and
                           not msms_rst_i)
                           and not Msms_set and not txer_i) ;
            msms_d2 <= msms_d1;
         end if;
      end if;
   end process MSMS_PROCESS;

   ----------------------------------------------------------------------------
   -- START/STOP Detect Process
   -- This process detects the start condition by finding the falling edge of
   -- sda_rin and checking that SCL is high. It detects the stop condition on
   -- the bus by finding a rising edge of SDA when SCL is high.
   ----------------------------------------------------------------------------
   sda_falling <= sda_rin_d1 and not sda_rin;
   sda_rising <= not sda_rin_d1 and sda_rin;
   sda_changing <= sda_falling or sda_rising or tx_under_prev_fe
                               or rsta_re    or gen_stop_re;

   ----------------------------------------------------------------------------
   -- START Detect Process
   ----------------------------------------------------------------------------

   START_DET_PROCESS : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N or state = HEADER then
            detect_start <= '0';
         elsif sda_falling = '1' then
            if scl_rin = '1' then
               detect_start <= '1';
            else
               detect_start <= '0';
            end if;
         end if;
      end if;
   end process START_DET_PROCESS;

   ----------------------------------------------------------------------------
   -- STOP Detect Process
   ----------------------------------------------------------------------------

   STOP_DET_PROCESS : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N or detect_start = '1' then
            detect_stop <= '0';
         elsif sda_rising = '1' then
            if scl_rin = '1' then
               detect_stop <= '1';
            else
               detect_stop <= '0';
            end if;
         elsif msms_d2 = '0' and msms_d1 = '1' then
            -- rising edge of Msms - generate start condition
            detect_stop <= '0';  -- clear on a generate start condition
         end if;
      end if;
   end process STOP_DET_PROCESS;

   STOP_DET_PROCESS_B : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N or detect_start = '1' then
            detect_stop_b <= '0';
         elsif sda_rising = '1' then
            if scl_rin = '1' then
               detect_stop_b <= '1';
            else
               detect_stop_b <= '0';
            end if;
         elsif scl_state = START then
            -- rising edge of Msms - generate start condition
            detect_stop_b <= '0';  -- clear on a generate start condition
         end if;
      end if;
   end process STOP_DET_PROCESS_B;
   
   ----------------------------------------------------------------------------
   -- Bus Busy Process
   -- This process sets bus_busy as soon as START is detected which would
   -- always set arb lost (Al).
   ----------------------------------------------------------------------------

   SET_BUS_BUSY_PROCESS : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            bus_busy    <= '0';
         else
            if detect_stop = '1' then
               bus_busy <= '0';
            elsif detect_start = '1' then
               bus_busy <= '1';
            end if;
         end if;
      end if;
   end process SET_BUS_BUSY_PROCESS;

   ----------------------------------------------------------------------------
   -- BUS_BUSY_REG_PROCESS:
   -- This process describes a delayed version of the bus busy bit which is
   -- used to determine arb lost (Al).
   ----------------------------------------------------------------------------

   BUS_BUSY_REG_PROCESS : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            bus_busy_d1 <= '0';
         else
            bus_busy_d1 <= bus_busy;
         end if;
      end if;
   end process BUS_BUSY_REG_PROCESS;

   ----------------------------------------------------------------------------
   -- GEN_START_PROCESS
   -- This process detects the rising and falling edges of Msms and sets
   -- signals to control generation of start condition
   ----------------------------------------------------------------------------

   GEN_START_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
             gen_start    <= '0';
         else
             if msms_d2 = '0' and msms_d1 = '1' then
                -- rising edge of Msms - generate start condition
                gen_start <= '1';
             elsif detect_start = '1' then
                gen_start <= '0';
             end if;
          end if;
       end if;
   end process GEN_START_PROCESS;

   ----------------------------------------------------------------------------
   -- GEN_STOP_PROCESS
   -- This process detects the rising and falling edges of Msms and sets
   -- signals to control generation of stop condition
   ----------------------------------------------------------------------------

   GEN_STOP_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
             gen_stop     <= '0';
         else
             if arb_lost = '0' and msms_d2 = '1' and msms_d1 = '0' then
                -- falling edge of Msms - generate stop condition only
                -- if arbitration has not been lost
                gen_stop <= '1';
             elsif detect_stop = '1' then
                gen_stop <= '0';
             end if;
          end if;
       end if;
   end process GEN_STOP_PROCESS;

   ----------------------------------------------------------------------------
   -- GEN_MASTRE_SLAVE_PROCESS
   -- This process sets the master slave bit based on Msms if and only if
   -- it is not in the middle of a cycle, i.e. bus_busy = '0'
   ----------------------------------------------------------------------------

   GEN_MASTRE_SLAVE_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
             master_slave <= '0';
         else
             if bus_busy = '0' then
                master_slave <= msms_d1;
             elsif arb_lost = '1' then
                master_slave <= '0';
             else
                master_slave <= master_slave;
             end if;
          end if;
       end if;
   end process GEN_MASTRE_SLAVE_PROCESS;

   rep_start <= Rsta;         -- repeat start signal is Rsta control bit

   ----------------------------------------------------------------------------
   -- GEN_STOP_AND_SCL_HIGH
   ----------------------------------------------------------------------------
   -- This process does not go high until both gen_stop and SCL have gone high
   -- This is used to prevent the SCL state machine from getting stuck when a
   -- slave no acks during the last data byte being transmitted
   ----------------------------------------------------------------------------
   GEN_STOP_AND_SCL_HIGH : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            gen_stop_and_scl_hi <= '0';
         elsif gen_stop = '0' then
            gen_stop_and_scl_hi <= '0';  --clear
         elsif gen_stop = '1' and scl_rin = '1' then
            gen_stop_and_scl_hi <= '1';
         else
            gen_stop_and_scl_hi <= gen_stop_and_scl_hi;  --hold condition
         end if;
      end if;
   end process GEN_STOP_AND_SCL_HIGH;

   ----------------------------------------------------------------------------
   -- SCL_EDGE_PROCESS
   ----------------------------------------------------------------------------
   -- This process generates a 1 Sys_clk wide pulse for both the rising edge
   -- and the falling edge of SCL_RIN
   ----------------------------------------------------------------------------
   SCL_EDGE_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            scl_falling_edge <= '0';
            scl_rising_edge  <= '0';
            scl_f_edg_d1     <= '0';
            scl_f_edg_d2     <= '0';
            scl_f_edg_d3     <= '0';
         else
            scl_falling_edge <= scl_rin_d1 and (not scl_rin);  -- 1 to 0
            scl_rising_edge  <= (not scl_rin_d1) and scl_rin;  -- 0 to 1
            scl_f_edg_d1     <= scl_falling_edge;
            scl_f_edg_d2     <= scl_f_edg_d1;
            scl_f_edg_d3     <= scl_f_edg_d2;
         end if;
      end if;
   end process SCL_EDGE_PROCESS;

   ----------------------------------------------------------------------------
   -- EARLY_ACK_HDR_PROCESS
   ----------------------------------------------------------------------------
   -- This process generates 1 Sys_clk wide pulses when the statemachine enters
   -- the ACK_HEADER state
   ----------------------------------------------------------------------------
   EARLY_ACK_HDR_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            EarlyAckHdr       <= '0';
         elsif (scl_f_edg_d3 = '1' and state = ACK_HEADER) then
            EarlyAckHdr <= '1';
         else
            EarlyAckHdr <= '0';
         end if;
      end if;
   end process EARLY_ACK_HDR_PROCESS;

   ----------------------------------------------------------------------------
   -- ACK_DATA_PROCESS
   ----------------------------------------------------------------------------
   -- This process generates 1 Sys_clk wide pulses when the statemachine enters
   -- ACK_DATA state
   ----------------------------------------------------------------------------
   ACK_DATA_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            AckDataState <= '0';
         elsif (state = ACK_DATA) then
            AckDataState <= '1';
         else
            AckDataState <= '0';
         end if;
      end if;
   end process ACK_DATA_PROCESS;

   ----------------------------------------------------------------------------
   -- EARLY_ACK_DATA_PROCESS
   ----------------------------------------------------------------------------
   -- This process generates 1 Sys_clk wide pulses when the statemachine enters
   -- the ACK_DATA ot RCV_DATA state state
   ----------------------------------------------------------------------------
   EARLY_ACK_DATA_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            EarlyAckDataState      <= '0';
         elsif (state = ACK_DATA or (state = RCV_DATA and
            (bit_cnt = CNT_ALMOST_DONE or bit_cnt = CNT_DONE))) then
            EarlyAckDataState <= '1';
         else
            EarlyAckDataState <= '0';
         end if;
      end if;
   end process EARLY_ACK_DATA_PROCESS;

   ----------------------------------------------------------------------------
   -- uP Status Register Bits Processes
   -- Dtc - data transfer complete. Since this only checks whether the
   -- bit_cnt="0111" it will be true for both data and address transfers.
   -- While one byte of data is being transferred, this bit is cleared.
   -- It is set by the falling edge of the 9th clock of a byte transfer and
   -- is not cleared at Reset
   ----------------------------------------------------------------------------
   DTC_I_BIT : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            dtc_i <= '0';
         elsif scl_falling_edge = '1' then
            if bit_cnt = "0111" then
               dtc_i <= '1';
            else
               dtc_i <= '0';
            end if;
         end if;
      end if;
   end process DTC_I_BIT;

   Dtc <= dtc_i;

   ----------------------------------------------------------------------------
   -- DTC_DELAY_PROCESS
   ----------------------------------------------------------------------------
   DTC_DELAY_PROCESS : process (Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            dtc_i_d1 <= '0';
            dtc_i_d2 <= '0';
         else
            dtc_i_d1 <= dtc_i;
            dtc_i_d2 <= dtc_i_d1;
         end if;
      end if;
   end process DTC_DELAY_PROCESS;

   ----------------------------------------------------------------------------
   -- aas_i - Addressed As Slave Bit
   ----------------------------------------------------------------------------
   -- When its own specific address (adr) matches the I2C Address, this bit is
   -- set.
   -- Then the CPU needs to check the Srw bit and this bit when a
   -- TX-RX mode accordingly.
   ----------------------------------------------------------------------------
   AAS_I_BIT : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            aas_i <= '0';
         elsif detect_stop = '1' or addr_match = '0' then
            aas_i <= '0';
         elsif state = ACK_HEADER then
            aas_i <= addr_match;
            -- the signal address match compares adr with I2_ADDR
         else
            aas_i <= aas_i;
         end if;
      end if;
   end process AAS_I_BIT;

   ----------------------------------------------------------------------------
   -- INT_AAS_PROCESS
   ----------------------------------------------------------------------------
   -- This process assigns the internal aas_i signal to the output port Aas
   ----------------------------------------------------------------------------
   INT_AAS_PROCESS : process (aas_i, sec_adr_match)
   begin  -- process
      Aas <= aas_i and sec_adr_match;
   end process INT_AAS_PROCESS;

   ----------------------------------------------------------------------------
   -- Bb - Bus Busy Bit
   ----------------------------------------------------------------------------
   -- This bit indicates the status of the bus. This bit is set when a START
   -- signal is detected and cleared when a stop signal is detected. It is
   -- also cleared on Reset. This bit is identical to the signal bus_busy set
   -- in the process set_bus_busy.
   ----------------------------------------------------------------------------
      Bb <= bus_busy;

   ----------------------------------------------------------------------------
   -- Al - Arbitration Lost Bit
   ----------------------------------------------------------------------------
   -- This bit is set when the arbitration procedure is lost.
   -- Arbitration is lost when:
   --    1. SDA is sampled low when the master drives high during addr or data
   --       transmit cycle
   --    2. SDA is sampled low when the master drives high during the
   --       acknowledge  bit of a data receive cycle
   --    3. A start cycle is attempted when the bus is busy
   --    4. A repeated start is requested in slave mode
   --    5. A stop condition is detected that the master did not request it.
   -- This bit is cleared upon Reset and when the software writes a '0' to it
   -- Conditions 1 & 2 above simply result in sda_rin not matching sda_cout
   -- while SCL is high. This design will not generate a START condition while
   -- the bus is busy. When a START is detected, this hardware will set the bus
   -- busy bit and gen_start stays set until detect_start asserts, therefore
   -- will have to compare with a delayed version of bus_busy. Condition 3 is
   -- really just a check on the uP software control registers as is condition
   -- 4. Condition 5 is also taken care of by the fact that sda_rin does not
   -- equal sda_cout, however, this process also tests for if a stop condition
   -- has been detected when this master did not generate it
   ----------------------------------------------------------------------------
   AL_I_BIT : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            al_i <= '0';
         elsif master_slave = '1' then
            if (arb_lost = '1') or
               (bus_busy_d1 = '1' and gen_start = '1') or
               (detect_stop = '1' and al_prevent = '0' and sm_stop = '0') then
               al_i <= '1';
            else
               al_i <= '0';   -- generate a pulse on al_i, arb lost interrupt
            end if;
         elsif Rsta = '1' then
            -- repeated start requested while slave
            al_i <= '1';
         else
            al_i <= '0';
         end if;
      end if;
   end process AL_I_BIT;

   ----------------------------------------------------------------------------
   -- INT_ARB_LOST_PROCESS
   ----------------------------------------------------------------------------
   -- This process assigns the internal al_i signal to the output port Al
   ----------------------------------------------------------------------------
   INT_ARB_LOST_PROCESS : process (al_i)
   begin  -- process
      Al <= al_i;
   end process INT_ARB_LOST_PROCESS;

   ----------------------------------------------------------------------------
   -- PREVENT_ARB_LOST_PROCESS
   ----------------------------------------------------------------------------
   -- This process prevents arb lost (al_i) when a stop has been initiated by
   -- this device operating as a master.
   ----------------------------------------------------------------------------
   PREVENT_ARB_LOST_PROCESS : process (Sys_clk)
   begin  -- make an SR flip flop that sets on gen_stop and resets on
          -- detect_start
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            al_prevent <= '0';
         elsif (gen_stop = '1' and detect_start = '0')
            or (sm_stop = '1' and detect_start = '0')then
            al_prevent <= '1';
         elsif detect_start = '1' then
            al_prevent <= '0';
         else
            al_prevent <= al_prevent;
         end if;
      end if;
   end process PREVENT_ARB_LOST_PROCESS;

   ----------------------------------------------------------------------------
   -- srw_i - Slave Read/Write Bit
   ----------------------------------------------------------------------------
   -- When aas_i is set, srw_i indicates the value of the R/W command bit of
   -- the calling address sent from the master. This bit is only valid when a
   -- complete transfer has occurred and no other  transfers have been
   -- initiated. The CPU uses this bit to set the slave transmit/receive mode.
   -- This bit is Reset by Reset
   ----------------------------------------------------------------------------
   SRW_I_BIT : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            srw_i <= '0';
         elsif state = ACK_HEADER then
            srw_i <= i2c_header(0);
         else
            srw_i <= srw_i;
         end if;
      end if;
   end process SRW_I_BIT;

   Srw <= srw_i;

   ----------------------------------------------------------------------------
   -- TXER_BIT process
   ----------------------------------------------------------------------------
   -- This process determines the state of the acknowledge bit which may be
   -- used as a transmit error or by a master receiver to indicate to the
   -- slave that the last byte has been transmitted
   ----------------------------------------------------------------------------
   TXER_BIT : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            txer_i <= '0';
         elsif scl_falling_edge = '1' then
            if state = ACK_HEADER or state = ACK_DATA or state = WAIT_ACK then
               txer_i <= sda_sample;
            end if;
         end if;
      end if;
   end process TXER_BIT;

   ----------------------------------------------------------------------------
   -- TXER_EDGE process
   ----------------------------------------------------------------------------
   -- This process creates a one wide clock pulse for Txer IRQ
   ----------------------------------------------------------------------------
   TXER_EDGE_PROCESS : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            txer_edge <= '0';
         elsif scl_falling_edge = '1' then
            if state = ACK_HEADER or state = ACK_DATA or state = WAIT_ACK then
               txer_edge <= sda_sample;
            end if;
         elsif scl_f_edg_d2 = '1' then
            txer_edge <= '0';
         end if;
      end if;
   end process TXER_EDGE_PROCESS;

   Txer <= txer_edge;

   ----------------------------------------------------------------------------
   -- uP Data Register
   -- Register for uP interface data_i2c_i
   ----------------------------------------------------------------------------
   DATA_I2C_I_PROC : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            data_i2c_i    <= (others => '0');
            new_rcv_dta_i <= '0';
         elsif (state = ACK_DATA) and Ro_prev = '0' and scl_falling_edge = '1'
                and adr_dta_l = '0'         then
            data_i2c_i    <= shift_reg;
            new_rcv_dta_i <= '1';
         else
            data_i2c_i    <= data_i2c_i;
            new_rcv_dta_i <= '0';
         end if;
      end if;
   end process DATA_I2C_I_PROC;

   ----------------------------------------------------------------------------
   -- INT_NEW_RCV_DATA_PROCESS
   ----------------------------------------------------------------------------
   -- This process assigns the internal receive data signals to the output port
   ----------------------------------------------------------------------------
   INT_NEW_RCV_DATA_PROCESS : process (new_rcv_dta_i)
   begin  -- process
      New_rcv_dta <= new_rcv_dta_i;
   end process INT_NEW_RCV_DATA_PROCESS;

   Data_i2c <= data_i2c_i;

   ----------------------------------------------------------------------------
   --  Determine if Addressed As Slave or by General Call
   ----------------------------------------------------------------------------
   -- This process determines when the I2C has been addressed as a slave
   -- that is the I2C header matches the slave address stored in ADR or a
   -- general call has happened
   ----------------------------------------------------------------------------
   NO_TEN_BIT_GEN : if C_TEN_BIT_ADR = 0 generate

      addr_match <= '1' when (i2c_header(7 downto 1) = Adr(7 downto 1))
                    or (abgc_i = '1')
                    else '0';

      -- Seven bit addressing, sec_adr_match is always true.
      sec_adr_match <= '1';

   end generate NO_TEN_BIT_GEN;


   TEN_BIT_GEN : if (C_TEN_BIT_ADR = 1) generate
      -------------------------------------------------------------------------
      -- The msb_wr signal indicates that the just received i2c_header matches
      -- the required first byte of a 2-byte, 10-bit address. Since the
      -- i2c_header shift register clocks on the scl rising edge but the timing
      -- of signals dependent on msb_wr expect it to change on the falling edge
      -- the scl_f_edge_d1 qualifier is used to create the expected timing.
      -------------------------------------------------------------------------
      MSB_WR_PROCESS : process (Sys_clk)
      begin
         if Sys_clk'event and Sys_clk = '1' then
            if Reset = ENABLE_N then
               msb_wr <= '0';
            elsif (abgc_i = '1') or
               (scl_f_edg_d1 = '1'
                and i2c_header(7 downto 3) = "11110"
                and (i2c_header(2 downto 1) = Ten_adr(7 downto 6)))
            then
               msb_wr <= '1';
            elsif (scl_f_edg_d1='1') then
               msb_wr <= '0';
            end if;
         end if;
      end process MSB_WR_PROCESS;

      -------------------------------------------------------------------------
      -- MSB_WR_D_PROCESS
      -------------------------------------------------------------------------
      -- msb_wr delay process
      -------------------------------------------------------------------------
      MSB_WR_D_PROCESS : process (Sys_clk)
      begin
         if Sys_clk'event and Sys_clk = '1' then
            if Reset = ENABLE_N then
               msb_wr_d  <= '0';
               msb_wr_d1 <= '0';
            else
               msb_wr_d  <= msb_wr;
               msb_wr_d1 <= msb_wr_d;  -- delayed to align with srw_i
            end if;
         end if;
      end process MSB_WR_D_PROCESS;

      -------------------------------------------------------------------------
      -- SRFF set on leading edge of MSB_WR, Reset on DTC and SCL falling edge
      -- this will qualify the 2nd byte as address and prevent it from being
      -- loaded into the DRR or Rc FIFO
      -------------------------------------------------------------------------
      SECOND_ADDR_PROCESS : process (Sys_clk)
      begin
         if Sys_clk'event and Sys_clk = '1' then
            if Reset = ENABLE_N then
               sec_addr <= '0';
            elsif (msb_wr = '1' and msb_wr_d = '0'
                   and i2c_header(0) = '0') then
               -- First byte of two byte (10-bit addr) matched and
               -- direction=write. Set sec_addr flag to indicate next byte
               -- should be checked against remainder of the address.
               sec_addr <= '1';
            elsif dtc_i = '1' and Ro_prev = '0' and scl_f_edg_d1 = '1'
            then
               sec_addr <= '0';
            else
               sec_addr <= sec_addr;
            end if;
         end if;
      end process SECOND_ADDR_PROCESS;

      -------------------------------------------------------------------------
      -- Compare 2nd byte to see if it matches slave address
      -- A repeated start with the Master writing to the slave must also
      -- compare the second address byte.
      -- A repeated start with the Master reading from the slave only compares
      -- the first (most significant).
      -------------------------------------------------------------------------
      SECOND_ADDR_COMP_PROCESS : process (Sys_clk)
      begin
         if Sys_clk'event and Sys_clk = '1' then
            if Reset = ENABLE_N then
               sec_adr_match <= '0';
            elsif detect_stop = '1'
               -- Repeated Start and Master Writing to Slave
               or (state = ACK_HEADER and i2c_header(0) = '0'
               and master_slave = '0' and msb_wr_d = '1' and abgc_i = '0') then
               sec_adr_match <= '0';

            elsif (abgc_i = '1')
               or (sec_addr = '1' and (shift_reg(7) = Ten_adr(5)
                                  and shift_reg(6 downto 0) = Adr (7 downto 1)
                                  and dtc_i = '1' and msb_wr_d1 = '1')) then
               sec_adr_match <= '1';
            else
               sec_adr_match <= sec_adr_match;
            end if;
         end if;
      end process SECOND_ADDR_COMP_PROCESS;

      -------------------------------------------------------------------------
      -- Prevents 2nd byte of 10 bit address from being loaded into DRR.
      -- When in ACK_HEADER and srw_i is lo then a repeated start or start
      -- condition occured and data is being written to slave so the next
      -- byte will be the remaining portion of the 10 bit address
      -------------------------------------------------------------------------
      ADR_DTA_L_PROCESS : process (Sys_clk)
      begin
         if Sys_clk'event and Sys_clk = '1' then
            if Reset = ENABLE_N then
               adr_dta_l <= '0';
            elsif ((i2c_header(0) = '0' and
                    msb_wr = '1' and
                    msb_wr_d = '0') and
                   sec_adr_match = '0') or
                  (state = ACK_HEADER and srw_i = '0' and
                   master_slave = '0' and
                   msb_wr_d1 = '1') then
               adr_dta_l <= '1';
            elsif (state = ACK_HEADER and
                   master_slave = '1' and
                   msb_wr_d1 = '0') then
               adr_dta_l <= '0';
            elsif (state = ACK_DATA and Ro_prev = '0'
                                    and scl_falling_edge = '1')
               or (detect_start = '1') or (abgc_i = '1')
           --  or (state = ACK_HEADER and srw_i = '1' and master_slave = '0')
            then
               adr_dta_l <= '0';
            else
               adr_dta_l <= adr_dta_l;
            end if;
         end if;
      end process ADR_DTA_L_PROCESS;

      -- Set address match high to get 2nd byte of slave address
      addr_match <= '1' when (msb_wr = '1' and sec_adr_match = '1')
                     or (sec_addr = '1')
                     else '0';

   end generate TEN_BIT_GEN;

   ----------------------------------------------------------------------------
   -- Process : SDA_SMPL
   -- Address by general call process
   ----------------------------------------------------------------------------
   ABGC_PROCESS : process (Sys_clk)
   begin
      if (Sys_clk'event and Sys_clk = '1') then
         if Reset = ENABLE_N then
            abgc_i <= '0';
         elsif detect_stop = '1' or detect_start = '1' then
            abgc_i <= '0';
         elsif i2c_header(7 downto 0) = "00000000" and Gc_en = '1'
            and (state = ACK_HEADER) then
            abgc_i <= '1';
         end if;
      end if;
   end process ABGC_PROCESS;

   Abgc <= abgc_i;

   ----------------------------------------------------------------------------
   -- Process : SDA_SMPL
   -- Sample the SDA_RIN for use in checking the acknowledge bit received by
   -- the controller
   ----------------------------------------------------------------------------
   SDA_SMPL: process (Sys_clk) is
   begin
      if (Sys_clk'event and Sys_clk = '1') then
         if Reset = ENABLE_N then
            sda_sample <= '0';
         elsif (scl_rising_edge='1') then
            sda_sample <= sda_rin;
         end if;
      end if;
   end process SDA_SMPL;

   ----------------------------------------------------------------------------
   -- Main State Machine Process
   -- The following process contains the main I2C state machine for both master
   -- and slave modes. This state machine is clocked on the falling edge of SCL
   -- DETECT_STOP must stay as an asynchronous Reset because once STOP has been
   -- generated, SCL clock stops. Note that the bit_cnt signal updates on the
   -- scl_falling_edge pulse and is available on scl_f_edg_d1. So the count is
   -- available prior to the STATE changing.
   ----------------------------------------------------------------------------
   STATE_MACHINE : process (Sys_clk)
   begin

      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N or detect_stop = '1' then
            state   <= IDLE;
            sm_stop <= '0';

         elsif scl_f_edg_d2 = '1' or (Ro_prev = '0' and ro_prev_d1 = '1') then

            case state is

               ------------- IDLE STATE -------------
               when IDLE =>
                  --sm_stop <= sm_stop ;
                  if detect_start = '1' then
                     state <= HEADER;
                  end if;

                  ------------- HEADER STATE -------------
               when HEADER =>
                  --sm_stop <= sm_stop ;
                  if bit_cnt = CNT_DONE then
                     state <= ACK_HEADER;
                  end if;

                  ------------- ACK_HEADER STATE -------------
               when ACK_HEADER =>
                --  sm_stop <= sm_stop ;
                  if arb_lost = '1' then
                     state <= IDLE;
                  elsif sda_sample = '0' then
                     -- ack has been received, check for master/slave
                     if master_slave = '1' then
                        -- master, so check tx bit for direction
                        if Tx = '0' then
                           -- receive mode
                           state <= RCV_DATA;
                        else
                           --transmit mode
                           state <= XMIT_DATA;
                        end if;
                     else
                        if addr_match = '1' then
                           --if aas_i = '1' then
                           -- addressed slave, so check I2C_HEADER(0)
                           -- for direction
                           if i2c_header(0) = '0' then
                              -- receive mode
                              state <= RCV_DATA;
                           else
                              -- transmit mode
                              state <= XMIT_DATA;
                           end if;
                        else
                           -- not addressed, go back to IDLE
                           state <= IDLE;
                        end if;
                     end if;
                  else
                     -- not acknowledge received, stop as the address put on
                     -- the bus was not recognized/accepted by any slave
                     state <= IDLE;
                     if master_slave = '1' then
                        sm_stop <= '1';
                     end if;

                  end if;

                  ------------- RCV_DATA State --------------
               when RCV_DATA =>

                  --sm_stop <= sm_stop ;
                  -- check for repeated start
                  if (detect_start = '1') then
                     state <= HEADER;
                  elsif bit_cnt = CNT_DONE then
                     if master_slave = '0' and addr_match = '0' then
                        state <= IDLE;
                     else
                        -- Send an acknowledge
                        state <= ACK_DATA;
                     end if;
                  end if;

                  ------------ XMIT_DATA State --------------
               when XMIT_DATA =>
                  --sm_stop <= sm_stop ;

                  -- check for repeated start
                  if (detect_start = '1') then
                     state <= HEADER;

                  elsif bit_cnt = CNT_DONE then

                     -- Wait for acknowledge
                     state <= WAIT_ACK;

                  end if;

                  ------------- ACK_DATA State --------------
               when ACK_DATA =>
                  --sm_stop <= sm_stop ;

                  if Ro_prev = '0' then  -- stay in ACK_DATA until
                     state <= RCV_DATA;  -- a read of DRR has occurred
                  else
                     state <= ACK_DATA;
                  end if;

                  ------------- WAIT_ACK State --------------
               when WAIT_ACK =>
                  if arb_lost = '1' then
                     state <= IDLE;
                  elsif (sda_sample = '0') then
                     if (master_slave = '0' and addr_match = '0') then
                        state <= IDLE;
                     else
                        state <= XMIT_DATA;
                     end if;
                  else
                     -- not acknowledge received. The master transmitter is
                     -- being told to quit sending data as the slave won't take
                     -- anymore. Generate a STOP per spec. (Note that it
                     -- isn't strickly necessary for the master to get off the
                     -- bus at this point. It could retain ownership. However,
                     -- product specification indicates that it will get off
                     -- the bus) The slave transmitter is being informed by the
                     -- master that it won't take any more data.
                     if master_slave = '1' then
                        sm_stop <= '1';
                     end if;
                     state <= IDLE;
                  end if;

       -- coverage off
               when others =>
                  state <= IDLE;
       -- coverage on

            end case;

         end if;
      end if;
   end process STATE_MACHINE;

   LEVEL_1_GEN: if C_SDA_LEVEL = 1 generate
   begin
   ----------------------------------------------------------------------------
   -- Master SDA
   ----------------------------------------------------------------------------
   MAS_SDA : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            master_sda <= '1';
        -- elsif state = HEADER or state = XMIT_DATA then
        --   master_sda <= shift_out;
         elsif state = HEADER or (state = XMIT_DATA and
                                  tx_under_prev_i = '0' ) then
            master_sda <= shift_out;
         ---------------------------------
         -- Updated for CR 555648
         ---------------------------------
         elsif (tx_under_prev_i = '1' and state = XMIT_DATA) then
            master_sda <= '1';
         elsif state = ACK_DATA then
            master_sda <= Txak;
         else
            master_sda <= '1';
         end if;
      end if;
   end process MAS_SDA;
  end generate LEVEL_1_GEN;

  LEVEL_0_GEN:  if C_SDA_LEVEL = 0 generate
  begin
   ----------------------------------------------------------------------------
   -- Master SDA
   ----------------------------------------------------------------------------
   MAS_SDA : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            master_sda <= '1';
        -- elsif state = HEADER or state = XMIT_DATA then
        --   master_sda <= shift_out;
         elsif state = HEADER or (state = XMIT_DATA and
                                  tx_under_prev_i = '0' ) then
            master_sda <= shift_out;
         ---------------------------------
         -- Updated for CR 555648
         ---------------------------------
         elsif (tx_under_prev_i = '1' and state = XMIT_DATA) then
            master_sda <= '0';
         elsif state = ACK_DATA then
            master_sda <= Txak;
         else
            master_sda <= '1';
         end if;
      end if;
   end process MAS_SDA;
  end generate LEVEL_0_GEN;
   ----------------------------------------------------------------------------
   -- Slave SDA
   ----------------------------------------------------------------------------
   SLV_SDA : process(Sys_clk)
   begin
         -- For the slave SDA, address match(aas_i) only has to be checked when
         -- state is ACK_HEADER because state
         -- machine will never get to state XMIT_DATA or ACK_DATA
         -- unless address match is a one.
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            slave_sda  <= '1';
         elsif (addr_match = '1' and state = ACK_HEADER) or
            (state = ACK_DATA) then
            slave_sda <= Txak;
         elsif (state = XMIT_DATA) then
            slave_sda <= shift_out;
         else
            slave_sda <= '1';
         end if;
      end if;
   end process SLV_SDA;

------------------------------------------------------------
--Mathew : Added below process for CR 707697
   SHIFT_COUNT : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            shift_cnt    <= "000000000";
         elsif(shift_reg_ld = '1') then
            shift_cnt    <= "000000001";
         elsif(shift_reg_en = '1') then
            shift_cnt   <=  shift_cnt(7 downto 0) & shift_cnt(8);
         else
            shift_cnt   <=  shift_cnt;
         end if;
       end if;
   end process SHIFT_COUNT ;
 reg_empty <= '1' when shift_cnt(8) = '1' else '0';
------------------------------------------------------------
   ----------------------------------------------------------------------------
   -- I2C Data Shift Register
   ----------------------------------------------------------------------------
   I2CDATA_REG : entity axi_iic_v2_0_21.shift8
      port map (
         Clk       => Sys_clk,
         Clr       => Reset,
         Data_ld   => shift_reg_ld,
         Data_in   => Dtr,
         Shift_in  => sda_rin,
         Shift_en  => shift_reg_en,
         Shift_out => shift_out,
         Data_out  => shift_reg);

   ----------------------------------------------------------------------------
   -- Process : I2CDATA_REG_EN_CTRL
   ----------------------------------------------------------------------------
   I2CDATA_REG_EN_CTRL : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            shift_reg_en <= '0';
         elsif (
            -- Grab second byte of 10-bit address?
            (master_slave = '1' and state = HEADER and scl_rising_edge='1')
            -- Grab data byte
            or (state = RCV_DATA and scl_rising_edge='1'
                                 and detect_start = '0')
            -- Send data byte. Note use of scl_f_edg_d2 which is the 2 clock
            -- delayed version of the SCL falling edge signal
            or (state = XMIT_DATA and scl_f_edg_d2 = '1'
                                  and detect_start = '0')) then
            shift_reg_en <= '1';
         else
            shift_reg_en <= '0';
         end if;
      end if;
   end process I2CDATA_REG_EN_CTRL;

   ----------------------------------------------------------------------------
   -- Process : I2CDATA_REG_LD_CTRL
   ----------------------------------------------------------------------------
   I2CDATA_REG_LD_CTRL : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            shift_reg_ld <= '0';
         elsif (
            (master_slave = '1' and state = IDLE)
            or (state = WAIT_ACK)
            -- Slave Transmitter (i2c_header(0)='1' mean master wants to read)
            or (state = ACK_HEADER and i2c_header(0) = '1'
                                   and master_slave = '0')
            -- Master has a byte to transmit
            or (state = ACK_HEADER and Tx = '1' and master_slave = '1')
            -- ??
            or (state = RCV_DATA and detect_start = '1'))
            or tx_under_prev_i = '1' then
            shift_reg_ld <= '1';
         else
            shift_reg_ld <= '0';
         end if;
      end if;
   end process I2CDATA_REG_LD_CTRL;

   ----------------------------------------------------------------------------
   -- SHFT_REG_LD_PROCESS
   ----------------------------------------------------------------------------
   -- This process registers shift_reg_ld signal
   ----------------------------------------------------------------------------
   SHFT_REG_LD_PROCESS : process (Sys_clk)
   begin  -- process
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            shift_reg_ld_d1 <= '0';
         else                 --  Delay shift_reg_ld one clock
            shift_reg_ld_d1 <= shift_reg_ld;
         end if;
      end if;
   end process SHFT_REG_LD_PROCESS;

   ----------------------------------------------------------------------------
   -- NEW_XMT_PROCESS
   ----------------------------------------------------------------------------
   -- This process sets Rdy_new_xmt signal high for one sysclk after data has
   -- been loaded into the shift register.  This is used to create the Dtre
   -- interrupt.
   ----------------------------------------------------------------------------
   NEW_XMT_PROCESS : process (Sys_clk)
   begin  -- process
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            rdy_new_xmt_i <= '0';
         elsif state = XMIT_DATA or (state = HEADER and Msms = '1') then
            rdy_new_xmt_i <= (not (shift_reg_ld)) and shift_reg_ld_d1;
         end if;
      end if;
   end process NEW_XMT_PROCESS;

   Rdy_new_xmt <= rdy_new_xmt_i;

   ----------------------------------------------------------------------------
   -- I2C Header Shift Register
   -- Header/Address Shift Register
   ----------------------------------------------------------------------------
   I2CHEADER_REG : entity axi_iic_v2_0_21.shift8
      port map (
         Clk       => Sys_clk,
         Clr       => Reset,
         Data_ld   => i2c_header_ld,
         Data_in   => reg_clr,
         Shift_in  => sda_rin,
         Shift_en  => i2c_header_en,
         Shift_out => i2c_shiftout,
         Data_out  => i2c_header);

   ----------------------------------------------------------------------------
   -- Process : I2CHEADER_REG_CTRL
   ----------------------------------------------------------------------------
   I2CHEADER_REG_CTRL : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            i2c_header_en <= '0';
         elsif (state = HEADER and scl_rising_edge='1') then
            i2c_header_en <= '1';
         else
            i2c_header_en <= '0';
         end if;
      end if;
   end process I2CHEADER_REG_CTRL;

   i2c_header_ld <= '0';

   ----------------------------------------------------------------------------
   -- Bit Counter
   ----------------------------------------------------------------------------
   BITCNT : entity axi_iic_v2_0_21.upcnt_n
      generic map (
         C_SIZE => 4
         )
      port map(
                Clk    => Sys_clk,
                Clr    => Reset,
                Data    => cnt_start,
                Cnt_en => bit_cnt_en,
                Load   => bit_cnt_ld,
                Qout   => bit_cnt);

   ----------------------------------------------------------------------------
   -- Process :  Counter control lines
   ----------------------------------------------------------------------------
   BIT_CNT_EN_CNTL : process(Sys_clk)
   begin
      if Sys_clk'event and Sys_clk = '1' then
         if Reset = ENABLE_N then
            bit_cnt_en <= '0';
         elsif (state = HEADER and scl_falling_edge = '1')
            or (state = RCV_DATA and scl_falling_edge = '1')
            or (state = XMIT_DATA and scl_falling_edge = '1') then
            bit_cnt_en <= '1';
         else
            bit_cnt_en <= '0';
         end if;
      end if;
   end process BIT_CNT_EN_CNTL;

   bit_cnt_ld <= '1' when (state = IDLE) or (state = ACK_HEADER)
                 or (state = ACK_DATA)
                 or (state = WAIT_ACK)
                 or (detect_start = '1') else '0';

end architecture RTL;


-------------------------------------------------------------------------------
 -- filter.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        filter.vhd
-- Version:         v1.01.b                        
-- Description:     
--                 This file implements a simple debounce (inertial delay)
--                 filter to remove short glitches from the SCL and SDA signals
--                 using user definable delay parameters. SCL cross couples to
--                 SDA to prevent SDA from changing near changes in SDA.
-- Notes:
-- 1) The default value for both debounce instances is '1' to conform to the
-- IIC bus default value of '1' ('H').
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Release of v1.01.b
-- ~~~~~
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi_iic_v2_0_21;
use axi_iic_v2_0_21.debounce;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      SCL_INERTIAL_DELAY   -- SCL filtering delay 
--      SDA_INERTIAL_DELAY   -- SDA filtering delay 
-- Definition of Ports:
--      Sysclk               -- System clock
--      Scl_noisy            -- IIC SCL is noisy
--      Scl_clean            -- IIC SCL is clean
--      Sda_noisy            -- IIC SDA is Noisy
--      Sda_clean            -- IIC SDA is clean
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------
entity filter is
   
   generic (
      SCL_INERTIAL_DELAY : integer range 0 to 255 := 5;
      SDA_INERTIAL_DELAY : integer range 0 to 255 := 5
      );

   port (
      Sysclk    : in  std_logic;
      Rst       : in  std_logic;
      Scl_noisy : in  std_logic;
      Scl_clean : out std_logic;
      Sda_noisy : in  std_logic;
      Sda_clean : out std_logic
      );

end entity filter;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture RTL of filter is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


   signal scl_unstable_n : std_logic;

begin

   ----------------------------------------------------------------------------
   -- The inertial delay is cross coupled between the two IIC signals to ensure
   -- that a delay in SCL because of a glitch also prevents any changes in SDA
   -- until SCL is clean. This prevents inertial delay on SCL from creating a
   -- situation whereby SCL is held high but SDA transitions low to high thus
   -- making the core think a STOP has occured. Changes on SDA do not inihibit
   -- SCL because that could alter the timing relationships for the clock
   -- edges. If other I2C devices follow the spec then SDA should be stable
   -- prior to the rising edge of SCL anyway. (Excluding noise of course)
   ----------------------------------------------------------------------------

   ----------------------------------------------------------------------------
   -- Assertion that reports the SCL inertial delay
   ----------------------------------------------------------------------------

   ASSERT (FALSE) REPORT "axi_iic configured for SCL inertial delay of "
      & integer'image(SCL_INERTIAL_DELAY) & " clocks."
      SEVERITY NOTE;
   
   ----------------------------------------------------------------------------
   -- Instantiating component debounce 
   ----------------------------------------------------------------------------
   
   SCL_DEBOUNCE : entity axi_iic_v2_0_21.debounce
      generic map (
         C_INERTIAL_DELAY => SCL_INERTIAL_DELAY, 
         C_DEFAULT        => '1')
      port map (
         Sysclk     => Sysclk,
         Rst        => Rst,

         Stable     => '1',
         Unstable_n => scl_unstable_n,

         Noisy      => Scl_noisy,  
         Clean      => Scl_clean); 

   ----------------------------------------------------------------------------
   -- Assertion that reports the SDA inertial delay
   ----------------------------------------------------------------------------
   
   ASSERT (FALSE) REPORT "axi_iic configured for SDA inertial delay of "
      & integer'image(SDA_INERTIAL_DELAY) & " clocks."
      SEVERITY NOTE;
   
   ----------------------------------------------------------------------------
   -- Instantiating component debounce 
   ----------------------------------------------------------------------------
   
   SDA_DEBOUNCE : entity axi_iic_v2_0_21.debounce
      generic map (
         C_INERTIAL_DELAY => SDA_INERTIAL_DELAY,  
         C_DEFAULT        => '1')
      port map (
         Sysclk     => Sysclk,
         Rst        => Rst,
         Stable     => scl_unstable_n,  
         Unstable_n => open,

         Noisy      => Sda_noisy,   
         Clean      => Sda_clean);  

end architecture RTL;


-------------------------------------------------------------------------------
-- dynamic_master.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        dynamic_master.vhd
-- Version:         v1.01.b                        
-- Description:     
--                  This file contains the control logic for the dynamic master.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Release of v1.01.b
-- ~~~~~~
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

-------------------------------------------------------------------------------
-- Definition of Ports:
--      Clk                   -- System clock
--      Rst                   -- System reset
--      Dynamic_MSMS          -- Dynamic master slave mode select
--      Cr                    -- Control register
--      Tx_fifo_rd_i          -- Transmit FIFO read
--      Tx_data_exists        -- Trnasmit FIFO exists
--      AckDataState          -- Data ack acknowledge signal
--      Tx_fifo_data          -- Transmit FIFO read input
--      EarlyAckHdr           -- Ack_header state strobe signal
--      EarlyAckDataState     -- Data ack early acknowledge signal
--      Bb                    -- Bus busy indicator
--      Msms_rst_r            -- MSMS reset indicator
--      DynMsmsSet            -- Dynamic MSMS set signal
--      DynRstaSet            -- Dynamic repeated start set signal
--      Msms_rst              -- MSMS reset signal
--      TxFifoRd              -- Transmit FIFO read output signal
--      Txak                  -- Transmit ack signal
--      Cr_txModeSelect_set   -- Sets transmit mode select
--      Cr_txModeSelect_clr   -- Clears transmit mode select
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity dynamic_master is
   port(
         Clk                 : in std_logic;
         Rst                 : in std_logic;
                             
         Dynamic_MSMS        : in std_logic_vector(0 to 1);
         Cr                  : in std_logic_vector(0 to 7);
         Tx_fifo_rd_i        : in std_logic;
         Tx_data_exists      : in std_logic;
         AckDataState        : in std_logic;
         Tx_fifo_data        : in std_logic_vector(0 to 7);
         EarlyAckHdr         : in std_logic;
         EarlyAckDataState   : in std_logic;
         Bb                  : in std_logic;
         Msms_rst_r          : in std_logic;
         DynMsmsSet          : out std_logic;
         DynRstaSet          : out std_logic;
         Msms_rst            : out std_logic;
         TxFifoRd            : out std_logic;
         Txak                : out std_logic;
         Cr_txModeSelect_set : out std_logic;
         Cr_txModeSelect_clr : out std_logic
        );
      
end dynamic_master;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------

architecture RTL of dynamic_master is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


-------------------------------------------------------------------------------
--  Signal Declarations
-------------------------------------------------------------------------------
 signal firstDynStartSeen   : std_logic;  -- used to detect re-start during 
                                          -- dynamic start generation
 signal dynamic_MSMS_d      : std_logic_vector(0 to 1);
 signal rxCntDone           : std_logic;
 signal forceTxakHigh       : std_logic;
 signal earlyAckDataState_d1: std_logic;
 signal ackDataState_d1     : std_logic;
 signal rdByteCntr          : unsigned(0 to 7);
 signal rdCntrFrmTxFifo     : std_logic;
 signal callingReadAccess   : std_logic;
 signal dynamic_start       : std_logic;
 signal dynamic_stop        : std_logic;
-------------------------------------------------------------------------------

begin
   -- In the case where the tx fifo only contains a single byte (the address)
   -- which contains both start and stop bits set the controller has to rely on
   -- the tx fifo data exists flag to qualify the fifo output. Otherwise the
   -- controller emits a continous stream of bytes. This fixes CR439857
   
   dynamic_start <= Dynamic_MSMS(1) and Tx_data_exists;
   
   dynamic_stop  <= Dynamic_MSMS(0) and Tx_data_exists;

   DynMsmsSet    <=  dynamic_start     -- issue dynamic start by setting MSMS
                     and not(Cr(5))    -- when MSMS is not already set and 
                     and not(Bb);      -- bus isn't busy
                     
   DynRstaSet    <=  dynamic_start           -- issue repeated start when 
                     and Tx_fifo_rd_i
                     and firstDynStartSeen;  -- MSMS is already set
   
   Msms_rst      <= (dynamic_stop and Tx_fifo_rd_i)
                    or Msms_rst_r
                    or rxCntDone;
   
   TxFifoRd      <= Tx_fifo_rd_i or rdCntrFrmTxFifo;
   
   forceTxakHigh <= '1' when (EarlyAckDataState='1' and callingReadAccess='1' 
                                                    and rdByteCntr = 0) else
                    '0';
   
   Txak          <= Cr(3) or forceTxakHigh;

  -----------------------------------------------------------------------------
  -- PROCESS: DYN_MSMS_DLY_PROCESS
  -- purpose: Dynamic Master MSMS registering
  -----------------------------------------------------------------------------
  
  DYN_MSMS_DLY_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        dynamic_MSMS_d       <= (others => '0');
      else
        dynamic_MSMS_d  <= Dynamic_MSMS;
      end if;
    end if;
  end process DYN_MSMS_DLY_PROCESS;

  -----------------------------------------------------------------------------
  -- PROCESS: DYN_START_PROCESS
  -- purpose: reset firstDynStartSeen if CR(5) MSMS is cleared
  -----------------------------------------------------------------------------

  DYN_START_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        firstDynStartSeen    <= '0';
      else
        if(Cr(5) = '0') then  
          firstDynStartSeen <= '0';
        elsif(firstDynStartSeen = '0' and Tx_fifo_rd_i = '1' 
                                      and dynamic_start = '1') then
          firstDynStartSeen <= '1';
        end if;
      end if;
    end if;
  end process DYN_START_PROCESS;

  -----------------------------------------------------------------------------
  -- PROCESS: DYN_RD_ACCESS_PROCESS
  -- purpose: capture access direction initiated via dynamic Start
  -----------------------------------------------------------------------------

  DYN_RD_ACCESS_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        callingReadAccess    <= '0';
      else
        if(Tx_fifo_rd_i = '1' and dynamic_start = '1') then  
           callingReadAccess <= Tx_fifo_data(7);
        end if;
      end if;
    end if;
  end process DYN_RD_ACCESS_PROCESS;

  -----------------------------------------------------------------------------
  -- PROCESS: DYN_MODE_SELECT_SET_PROCESS
  -- purpose: Set the tx Mode Select bit in the CR register at the begining of
  --          each ack_header state 
  -----------------------------------------------------------------------------

  DYN_MODE_SELECT_SET_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
       if Rst = '1' then
         Cr_txModeSelect_set  <= '0';
       elsif(EarlyAckHdr='1' and firstDynStartSeen='1') then
          Cr_txModeSelect_set <= not callingReadAccess;
       else
          Cr_txModeSelect_set <= '0';
      end if;
    end if;
  end process DYN_MODE_SELECT_SET_PROCESS;
  
  -----------------------------------------------------------------------------
  -- PROCESS: DYN_MODE_SELECT_CLR_PROCESS
  -- purpose: Clear the tx Mode Select bit in the CR register at the begining of
  --          each ack_header state 
  -----------------------------------------------------------------------------

  DYN_MODE_SELECT_CLR_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        Cr_txModeSelect_clr  <= '0';
        elsif(EarlyAckHdr='1' and firstDynStartSeen='1') then
           Cr_txModeSelect_clr <=     callingReadAccess;
        else
           Cr_txModeSelect_clr <= '0';
        end if;      
    end if;
  end process DYN_MODE_SELECT_CLR_PROCESS;
  
  -----------------------------------------------------------------------------
  -- PROCESS: DYN_RD_CNTR_PROCESS
  -- purpose: If this iic cycle is generating a read access, create a read 
  --          of the tx fifo to get the number of tx to process
  -----------------------------------------------------------------------------
  
  DYN_RD_CNTR_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        rdCntrFrmTxFifo      <= '0';
      else
        if(EarlyAckHdr='1' and Tx_data_exists='1' 
                           and callingReadAccess='1') then
          rdCntrFrmTxFifo <= '1';
        else
           rdCntrFrmTxFifo <= '0';
        end if;
      end if;
    end if;
  end process DYN_RD_CNTR_PROCESS;

  -----------------------------------------------------------------------------
  -- PROCESS: DYN_RD_BYTE_CNTR_PROCESS
  -- purpose: If this iic cycle is generating a read access, create a read 
  --          of the tx fifo to get the number of rx bytes to process
  -----------------------------------------------------------------------------

  DYN_RD_BYTE_CNTR_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        rdByteCntr           <= (others => '0');
      else
        if(rdCntrFrmTxFifo='1') then
           rdByteCntr <= unsigned(Tx_fifo_data);
        elsif(EarlyAckDataState='1' and earlyAckDataState_d1='0' 
                                    and rdByteCntr /= 0) then
           rdByteCntr <= rdByteCntr - 1;
        end if;
      end if;
    end if;
  end process DYN_RD_BYTE_CNTR_PROCESS;
  
  -----------------------------------------------------------------------------
  -- PROCESS: DYN_RD_BYTE_CNTR_PROCESS
  -- purpose: Initialize read byte counter in order to control master 
  --          generation of ack to slave.
  -----------------------------------------------------------------------------

  DYN_EARLY_DATA_ACK_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        earlyAckDataState_d1 <= '0';
      else
        earlyAckDataState_d1 <= EarlyAckDataState;
      end if;
    end if;    
  end process DYN_EARLY_DATA_ACK_PROCESS;

  -----------------------------------------------------------------------------
  -- PROCESS: DYN_STATE_DATA_ACK_PROCESS
  -- purpose: Register ackdatastate
  -----------------------------------------------------------------------------

  DYN_STATE_DATA_ACK_PROCESS:process (Clk)
  begin
    if Clk'event and Clk = '1' then
      if Rst = '1' then
        ackDataState_d1      <= '0';
      else
        ackDataState_d1 <= AckDataState;
      end if;
    end if;
  end process DYN_STATE_DATA_ACK_PROCESS;
  
  -----------------------------------------------------------------------------
  -- PROCESS: DYN_STATE_DATA_ACK_PROCESS
  -- purpose: Generation of receive count done to generate stop
  -----------------------------------------------------------------------------

    DYN_RX_CNT_PROCESS:process (Clk)
    begin
      if Clk'event and Clk = '1' then
        if Rst = '1' then
          rxCntDone            <= '0';
        else            
          if(AckDataState='1' and ackDataState_d1='0' and callingReadAccess='1'
                                                      and rdByteCntr = 0) then
            rxCntDone <= '1';
          else
            rxCntDone <= '0';
          end if;  
        end if;
      end if;
  end process DYN_RX_CNT_PROCESS;
  
  end architecture RTL; 


-------------------------------------------------------------------------------
-- axi_ipif_ssp1.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        axi_ipif_ssp1.vhd
-- Version:         v1.01.b
--
-- Description:     AXI IPIF Slave Services Package 1
--                      This block provides the following services:
--                      - wraps the axi_lite_ipif interface to IPIC block and
--                        sets up its address decoding.
--                      - Provides the Software Reset register
--                      - Provides interrupt servicing
--                      - IPIC multiplexing service between the external IIC
--                        register block IP2Bus data path and the internal
--                        Interrupt controller's IP2Bus data path.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--  NLR     01/07/11
-- ^^^^^^
--  - Updated the version to v1_01_b
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.or_reduce;

library axi_iic_v2_0_21;

library axi_lite_ipif_v3_0_4;
-- axi_lite_ipif refered from axi_lite_ipif_v2_0
use axi_lite_ipif_v3_0_4.axi_lite_ipif;
use axi_lite_ipif_v3_0_4.ipif_pkg.all;

library interrupt_control_v3_1_4;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_IIC_REGS             -- Number of IIC registers
--      C_S_AXI_ADDR_WIDTH         -- Width of AXI Address Bus (in bits)
--      C_S_AXI_DATA_WIDTH         -- Width of the AXI Data Bus (in bits)
--      C_FAMILY                   -- Target FPGA architecture
-------------------------------------------------------------------------------
-- Definition of Ports:
--   System Signals
--      S_AXI_ACLK            -- AXI Clock
--      S_AXI_ARESETN         -- AXI Reset
--      IP2INTC_Irpt          -- System interrupt output
--
--  AXI signals
--      S_AXI_AWADDR          -- AXI Write address
--      S_AXI_AWVALID         -- Write address valid
--      S_AXI_AWREADY         -- Write address ready
--      S_AXI_WDATA           -- Write data
--      S_AXI_WSTRB           -- Write strobes
--      S_AXI_WVALID          -- Write valid
--      S_AXI_WREADY          -- Write ready
--      S_AXI_BRESP           -- Write response
--      S_AXI_BVALID          -- Write response valid
--      S_AXI_BREADY          -- Response ready
--      S_AXI_ARADDR          -- Read address
--      S_AXI_ARVALID         -- Read address valid
--      S_AXI_ARREADY         -- Read address ready
--      S_AXI_RDATA           -- Read data
--      S_AXI_RRESP           -- Read response
--      S_AXI_RVALID          -- Read valid
--      S_AXI_RREADY          -- Read ready
--
--  IP interconnect port signals
--      Bus2IP_Clk           -- Bus to IIC clock
--      Bus2IP_Reset         -- Bus to IIC reset
--      Bus2IIC_Addr         -- Bus to IIC address
--      Bus2IIC_Data         -- Bus to IIC data bus
--      Bus2IIC_RNW          -- Bus to IIC read not write
--      Bus2IIC_RdCE         -- Bus to IIC read chip enable
--      Bus2IIC_WrCE         -- Bus to IIC write chip enable
--      IIC2Bus_Data         -- IIC to Bus data bus
--      IIC2Bus_IntrEvent    -- IIC Interrupt events
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity axi_ipif_ssp1 is
   generic
      (
      C_NUM_IIC_REGS        : integer                       := 10;
         -- Number of IIC Registers
      C_S_AXI_ADDR_WIDTH    : integer                       := 9;
      C_S_AXI_DATA_WIDTH    : integer range 32 to 32        := 32;

      C_FAMILY              : string                        := "virtex7"
         -- Select the target architecture type
      );
   port
      (
      -- System signals
      S_AXI_ACLK            : in  std_logic;
      S_AXI_ARESETN         : in  std_logic;
      IIC2Bus_IntrEvent     : in  std_logic_vector (0 to 7);
                                              -- IIC Interrupt events
      IIC2INTC_Irpt         : out std_logic;  -- IP-2-interrupt controller

      -- AXI signals
      S_AXI_AWADDR          : in  std_logic_vector
                              (C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_AWVALID         : in  std_logic;
      S_AXI_AWREADY         : out std_logic;
      S_AXI_WDATA           : in  std_logic_vector
                              (C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_WSTRB           : in  std_logic_vector
                              ((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
      S_AXI_WVALID          : in  std_logic;
      S_AXI_WREADY          : out std_logic;
      S_AXI_BRESP           : out std_logic_vector(1 downto 0);
      S_AXI_BVALID          : out std_logic;
      S_AXI_BREADY          : in  std_logic;
      S_AXI_ARADDR          : in  std_logic_vector
                              (C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_ARVALID         : in  std_logic;
      S_AXI_ARREADY         : out std_logic;
      S_AXI_RDATA           : out std_logic_vector
                              (C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_RRESP           : out std_logic_vector(1 downto 0);
      S_AXI_RVALID          : out std_logic;
      S_AXI_RREADY          : in  std_logic;

      -- IP Interconnect (IPIC) port signals used by the IIC registers.
      Bus2IIC_Clk           : out std_logic;
      Bus2IIC_Reset         : out std_logic;
      Bus2IIC_Addr          : out std_logic_vector(0 to C_S_AXI_ADDR_WIDTH - 1);
      Bus2IIC_Data          : out std_logic_vector(0 to C_S_AXI_DATA_WIDTH - 1);
      Bus2IIC_RNW           : out std_logic;
      Bus2IIC_RdCE          : out std_logic_vector(0 to C_NUM_IIC_REGS-1);
      Bus2IIC_WrCE          : out std_logic_vector(0 to C_NUM_IIC_REGS-1);
      IIC2Bus_Data          : in  std_logic_vector(0 to C_S_AXI_DATA_WIDTH - 1)
      );
end entity axi_ipif_ssp1;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------

architecture RTL of axi_ipif_ssp1 is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
   constant ZEROES : std_logic_vector(0 to 31)  := X"00000000";

   constant INTR_BASEADDR    : std_logic_vector := X"00000000";

   constant INTR_HIGHADDR    : std_logic_vector
                             := X"0000003F";

   constant RST_BASEADDR     : std_logic_vector
                             := X"00000040";

   constant RST_HIGHADDR     : std_logic_vector
                             := X"00000043";

   constant IIC_REG_BASEADDR : std_logic_vector
                             := X"00000100";

   constant IIC_REG_HIGHADDR : std_logic_vector
                             := X"000001FF";

   constant C_ARD_ADDR_RANGE_ARRAY : SLV64_ARRAY_TYPE :=
      (
         ZEROES & INTR_BASEADDR,     -- Interrupt controller
         ZEROES & INTR_HIGHADDR,
         ZEROES & RST_BASEADDR,      -- Software reset register
         ZEROES & RST_HIGHADDR,
         ZEROES & IIC_REG_BASEADDR,  -- IIC registers
         ZEROES & IIC_REG_HIGHADDR
         );

   constant C_ARD_IDX_INTERRUPT : integer := 0;
   constant C_ARD_IDX_RESET     : integer := 1;
   constant C_ARD_IDX_IIC_REGS  : integer := 2;

-- The C_IP_INTR_MODE_ARRAY must have the same width as the IP2Bus_IntrEvent
-- entity port.
   constant C_IP_INTR_MODE_ARRAY   : integer_array_type
                                     := (3, 3, 3, 3, 3, 3, 3, 3);
   constant C_INCLUDE_DEV_PENCODER : boolean            := FALSE;
   constant C_INCLUDE_DEV_ISC      : boolean            := FALSE;

   constant C_NUM_INTERRUPT_REGS   : integer := 16;
   constant C_NUM_RESET_REGS       : integer := 1;

   constant C_ARD_NUM_CE_ARRAY : INTEGER_ARRAY_TYPE :=
      (
         C_ARD_IDX_INTERRUPT => C_NUM_INTERRUPT_REGS,
         C_ARD_IDX_RESET     => C_NUM_RESET_REGS,
         C_ARD_IDX_IIC_REGS  => C_NUM_IIC_REGS
      );

   constant C_S_AXI_MIN_SIZE       : std_logic_vector(31 downto 0)
                                   := X"000001FF";

   constant C_USE_WSTRB            : integer := 0;

   constant C_DPHASE_TIMEOUT       : integer := 8;

   SUBTYPE INTERRUPT_CE_RNG is integer
      range calc_start_ce_index(C_ARD_NUM_CE_ARRAY, 0)
      to calc_start_ce_index(C_ARD_NUM_CE_ARRAY, 0)+C_ARD_NUM_CE_ARRAY(0)-1;

   SUBTYPE RESET_CE_RNG is integer
      range calc_start_ce_index(C_ARD_NUM_CE_ARRAY, 1)
      to calc_start_ce_index(C_ARD_NUM_CE_ARRAY, 1)+C_ARD_NUM_CE_ARRAY(1)-1;

   SUBTYPE IIC_CE_RNG is integer
      range calc_start_ce_index(C_ARD_NUM_CE_ARRAY, 2)
      to calc_start_ce_index(C_ARD_NUM_CE_ARRAY, 2)+C_ARD_NUM_CE_ARRAY(2)-1;

-------------------------------------------------------------------------------
-- Signal and Type Declarations
-------------------------------------------------------------------------------
-- IPIC Signals

   signal AXI_Bus2IP_Clk   : std_logic;
   signal AXI_Bus2IP_Resetn: std_logic;
   signal AXI_Bus2IP_Reset : std_logic;
   signal AXI_IP2Bus_Data  : std_logic_vector(0 to C_S_AXI_DATA_WIDTH - 1);
   signal AXI_IP2Bus_WrAck : std_logic;
   signal AXI_IP2Bus_RdAck : std_logic;
   signal AXI_IP2Bus_WrAck1 : std_logic;
   signal AXI_IP2Bus_RdAck1 : std_logic;
   signal AXI_IP2Bus_WrAck2 : std_logic;
   signal AXI_IP2Bus_RdAck2 : std_logic;
   signal Intr2Bus_WrAck   : std_logic;
   signal Intr2Bus_RdAck   : std_logic;
   signal AXI_IP2Bus_Error : std_logic;
   signal AXI_Bus2IP_Addr  : std_logic_vector(0 to C_S_AXI_ADDR_WIDTH - 1);
   signal AXI_Bus2IP_Data  : std_logic_vector(0 to C_S_AXI_DATA_WIDTH - 1);
   signal AXI_Bus2IP_RNW   : std_logic;
   signal AXI_Bus2IP_CS    : std_logic_vector(0 to
                               ((C_ARD_ADDR_RANGE_ARRAY'length)/2)-1);
   signal AXI_Bus2IP_RdCE  : std_logic_vector(0 to
                                calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);
   signal AXI_Bus2IP_WrCE  : std_logic_vector(0 to
                                calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);
-- Derived IPIC signals for use with the reset register functionality
   signal reset2Bus_Error  : std_logic;
   signal reset2IP_Reset   : std_logic;

-- Derived IPIC signals for use with the interrupt controller
   signal Intr2Bus_DevIntr : std_logic;
   signal Intr2Bus_DBus    : std_logic_vector(0 to C_S_AXI_DATA_WIDTH-1);

-------------------------------------------------------------------------------
begin
-------------------------------------------------------------------------------
--------------------------------------------------------------------------
-- RESET signal assignment - IPIC RESET is active low
--------------------------------------------------------------------------

    AXI_Bus2IP_Reset <= not AXI_Bus2IP_Resetn;

    AXI_LITE_IPIF_I : entity axi_lite_ipif_v3_0_4.axi_lite_ipif
      generic map
       (
        C_FAMILY                  => C_FAMILY,
        C_S_AXI_ADDR_WIDTH        => C_S_AXI_ADDR_WIDTH,
        C_S_AXI_DATA_WIDTH        => C_S_AXI_DATA_WIDTH,
        C_S_AXI_MIN_SIZE          => C_S_AXI_MIN_SIZE,
        C_USE_WSTRB               => C_USE_WSTRB,
        C_DPHASE_TIMEOUT          => C_DPHASE_TIMEOUT,
        C_ARD_ADDR_RANGE_ARRAY    => C_ARD_ADDR_RANGE_ARRAY,
        C_ARD_NUM_CE_ARRAY        => C_ARD_NUM_CE_ARRAY
       )
     port map
      (
         -- System signals
        S_AXI_ACLK          =>  S_AXI_ACLK,
        S_AXI_ARESETN       =>  S_AXI_ARESETN,

         -- AXI Interface signals
        S_AXI_AWADDR        =>  S_AXI_AWADDR,
        S_AXI_AWVALID       =>  S_AXI_AWVALID,
        S_AXI_AWREADY       =>  S_AXI_AWREADY,
        S_AXI_WDATA         =>  S_AXI_WDATA,
        S_AXI_WSTRB         =>  S_AXI_WSTRB,
        S_AXI_WVALID        =>  S_AXI_WVALID,
        S_AXI_WREADY        =>  S_AXI_WREADY,
        S_AXI_BRESP         =>  S_AXI_BRESP,
        S_AXI_BVALID        =>  S_AXI_BVALID,
        S_AXI_BREADY        =>  S_AXI_BREADY,
        S_AXI_ARADDR        =>  S_AXI_ARADDR,
        S_AXI_ARVALID       =>  S_AXI_ARVALID,
        S_AXI_ARREADY       =>  S_AXI_ARREADY,
        S_AXI_RDATA         =>  S_AXI_RDATA,
        S_AXI_RRESP         =>  S_AXI_RRESP,
        S_AXI_RVALID        =>  S_AXI_RVALID,
        S_AXI_RREADY        =>  S_AXI_RREADY,

         -- IP Interconnect (IPIC) port signals
        Bus2IP_Clk          =>  AXI_Bus2IP_Clk,
        Bus2IP_Resetn       =>  AXI_Bus2IP_Resetn,
        IP2Bus_Data         =>  AXI_IP2Bus_Data,
        IP2Bus_WrAck        =>  AXI_IP2Bus_WrAck,
        IP2Bus_RdAck        =>  AXI_IP2Bus_RdAck,
        IP2Bus_Error        =>  AXI_IP2Bus_Error,
        Bus2IP_Addr         =>  AXI_Bus2IP_Addr,
        Bus2IP_Data         =>  AXI_Bus2IP_Data,
        Bus2IP_RNW          =>  AXI_Bus2IP_RNW,
        Bus2IP_BE           =>  open,
        Bus2IP_CS           =>  AXI_Bus2IP_CS,
        Bus2IP_RdCE         =>  AXI_Bus2IP_RdCE,
        Bus2IP_WrCE         =>  AXI_Bus2IP_WrCE
        );

-------------------------------------------------------------------------------
-- INTERRUPT DEVICE
-------------------------------------------------------------------------------

   X_INTERRUPT_CONTROL : entity interrupt_control_v3_1_4.interrupt_control
      generic map (
         C_NUM_CE => C_NUM_INTERRUPT_REGS,  -- [integer range 4 to 16]
         -- Number of register chip enables required
         -- For C_IPIF_DWIDTH=32  Set C_NUM_CE = 16
         -- For C_IPIF_DWIDTH=64  Set C_NUM_CE = 8
         -- For C_IPIF_DWIDTH=128 Set C_NUM_CE = 4

         C_NUM_IPIF_IRPT_SRC => 1,  -- [integer range 1 to 29]

         C_IP_INTR_MODE_ARRAY => C_IP_INTR_MODE_ARRAY,  -- [INTEGER_ARRAY_TYPE]
         -- Interrupt Modes
         --1,  -- pass through (non-inverting)
         --2,  -- pass through (inverting)
         --3,  -- registered level (non-inverting)
         --4,  -- registered level (inverting)
         --5,  -- positive edge detect
         --6   -- negative edge detect

         C_INCLUDE_DEV_PENCODER => C_INCLUDE_DEV_PENCODER,  -- [boolean]
         -- Specifies device Priority Encoder function

         C_INCLUDE_DEV_ISC => C_INCLUDE_DEV_ISC,  -- [boolean]
         -- Specifies device ISC hierarchy
         -- Exclusion of Device ISC requires
         -- exclusion of Priority encoder

         C_IPIF_DWIDTH => C_S_AXI_DATA_WIDTH  -- [integer range 32 to 128]
         )
      port map (

         -- Inputs From the IPIF Bus
         Bus2IP_Clk     => AXI_Bus2IP_Clk,
         Bus2IP_Reset   => reset2IP_Reset,
         Bus2IP_Data    => AXI_Bus2IP_Data,
         Bus2IP_BE      => "1111",
         Interrupt_RdCE => AXI_Bus2IP_RdCE(INTERRUPT_CE_RNG),
         Interrupt_WrCE => AXI_Bus2IP_WrCE(INTERRUPT_CE_RNG),

         -- Interrupt inputs from the IPIF sources that will
         -- get registered in this design
         IPIF_Reg_Interrupts => "00",

         -- Level Interrupt inputs from the IPIF sources
         IPIF_Lvl_Interrupts => "0",

         -- Inputs from the IP Interface
         IP2Bus_IntrEvent => IIC2Bus_IntrEvent,

         -- Final Device Interrupt Output
         Intr2Bus_DevIntr => IIC2INTC_Irpt,

         -- Status Reply Outputs to the Bus
         Intr2Bus_DBus    => Intr2Bus_DBus,
         Intr2Bus_WrAck   => open,
         Intr2Bus_RdAck   => open,
         Intr2Bus_Error   => open,
         Intr2Bus_Retry   => open,
         Intr2Bus_ToutSup => open
         );

-------------------------------------------------------------------------------
-- SOFT RESET REGISTER
-------------------------------------------------------------------------------

   X_SOFT_RESET : entity axi_iic_v2_0_21.soft_reset
      generic map (
         C_SIPIF_DWIDTH => C_S_AXI_DATA_WIDTH,  -- [integer]
         -- Width of the write data bus
         C_RESET_WIDTH => 4)
      port map (

         -- Inputs From the IPIF Bus
         Bus2IP_Reset      => AXI_Bus2IP_Reset,
         Bus2IP_Clk        => AXI_Bus2IP_Clk,
         Bus2IP_WrCE       => AXI_Bus2IP_WrCE(RESET_CE_RNG'LEFT),
         Bus2IP_Data       => AXI_Bus2IP_Data,
         Bus2IP_BE         => "1111",

         -- Final Device Reset Output
         reset2IP_Reset    => reset2IP_Reset,

         -- Status Reply Outputs to the Bus
         reset2Bus_WrAck   => open,
         reset2Bus_Error   => reset2Bus_Error,
         Reset2Bus_ToutSup => open);

-------------------------------------------------------------------------------
-- IIC Register (External) Connections
-------------------------------------------------------------------------------
        Bus2IIC_Clk   <= AXI_Bus2IP_Clk;
        Bus2IIC_Reset <= reset2IP_Reset;
        Bus2IIC_Addr  <= AXI_Bus2IP_Addr;
        Bus2IIC_Data  <= AXI_Bus2IP_Data;
        Bus2IIC_RNW   <= AXI_Bus2IP_RNW;
        Bus2IIC_RdCE  <= AXI_Bus2IP_RdCE(IIC_CE_RNG);
        Bus2IIC_WrCE  <= AXI_Bus2IP_WrCE(IIC_CE_RNG);

-------------------------------------------------------------------------------
-- Read Ack/Write Ack generation
-------------------------------------------------------------------------------
      process(AXI_Bus2IP_Clk)
        begin
          if(AXI_Bus2IP_Clk'event and AXI_Bus2IP_Clk = '1') then
            AXI_IP2Bus_RdAck2 <= or_reduce(AXI_Bus2IP_CS) and AXI_Bus2IP_RNW;
            AXI_IP2Bus_RdAck1 <= AXI_IP2Bus_RdAck2;
          end if;
      end process;

      AXI_IP2Bus_RdAck <= (not (AXI_IP2Bus_RdAck1)) and AXI_IP2Bus_RdAck2;

      process(AXI_Bus2IP_Clk)
        begin
          if(AXI_Bus2IP_Clk'event and AXI_Bus2IP_Clk = '1') then
            AXI_IP2Bus_WrAck2 <= (or_reduce(AXI_Bus2IP_CS) and not AXI_Bus2IP_RNW);
            AXI_IP2Bus_WrAck1 <= AXI_IP2Bus_WrAck2;
          end if;
      end process;

      AXI_IP2Bus_WrAck <= (not AXI_IP2Bus_WrAck1) and AXI_IP2Bus_WrAck2;
-------------------------------------------------------------------------------
-- Data and Error generation
-------------------------------------------------------------------------------
    AXI_IP2Bus_Data <= Intr2Bus_DBus or IIC2Bus_Data;
    AXI_IP2Bus_Error <= reset2Bus_Error;
end architecture RTL;


-------------------------------------------------------------------------------
-- iic.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        iic.vhd
-- Version:         v1.01.b
-- Description:
--                  This file contains the top level file for the iic Bus
--                  Interface.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
-- ~~~~~~
--
-- NLR      01/07/11
-- ^^^^^^
--  - Release of v1.01.b
--  - Fixed the CR#613282
-- ~~~~~~~
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi_iic_v2_0_21;
use axi_iic_v2_0_21.iic_pkg.all;


-------------------------------------------------------------------------------
-- Definition of Generics:
--
--   C_NUM_IIC_REGS         -- Number of IIC Registers
--   C_S_AXI_ACLK_FREQ_HZ   -- Specifies AXI clock frequency
--   C_IIC_FREQ             -- Maximum frequency of Master Mode in Hz
--   C_TEN_BIT_ADR          -- 10 bit slave addressing
--   C_GPO_WIDTH            -- Width of General purpose output vector
--   C_SCL_INERTIAL_DELAY   -- SCL filtering
--   C_SDA_INERTIAL_DELAY   -- SDA filtering
--   C_SDA_LEVEL            -- SDA level
--   C_TX_FIFO_EXIST        -- IIC transmit FIFO exist
--   C_RC_FIFO_EXIST        -- IIC receive FIFO exist
--   C_S_AXI_ADDR_WIDTH     -- Width of AXI Address Bus (in bits)
--   C_S_AXI_DATA_WIDTH     -- Width of the AXI Data Bus (in bits)
--   C_FAMILY               -- XILINX FPGA family
-------------------------------------------------------------------------------
-- Definition of ports:
--
--   System Signals
--      S_AXI_ACLK            -- AXI Clock
--      S_AXI_ARESETN         -- AXI Reset
--      IP2INTC_Irpt          -- System interrupt output
--
--   AXI signals
--      S_AXI_AWADDR          -- AXI Write address
--      S_AXI_AWVALID         -- Write address valid
--      S_AXI_AWREADY         -- Write address ready
--      S_AXI_WDATA           -- Write data
--      S_AXI_WSTRB           -- Write strobes
--      S_AXI_WVALID          -- Write valid
--      S_AXI_WREADY          -- Write ready
--      S_AXI_BRESP           -- Write response
--      S_AXI_BVALID          -- Write response valid
--      S_AXI_BREADY          -- Response ready
--      S_AXI_ARADDR          -- Read address
--      S_AXI_ARVALID         -- Read address valid
--      S_AXI_ARREADY         -- Read address ready
--      S_AXI_RDATA           -- Read data
--      S_AXI_RRESP           -- Read response
--      S_AXI_RVALID          -- Read valid
--      S_AXI_RREADY          -- Read ready
--
--   IIC Signals
--      Sda_I               -- IIC serial data input
--      Sda_O               -- IIC serial data output
--      Sda_T               -- IIC seral data output enable
--      Scl_I               -- IIC serial clock input
--      Scl_O               -- IIC serial clock output
--      Scl_T               -- IIC serial clock output enable
--      Gpo                 -- General purpose outputs
--
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------
entity iic is
   generic (

      -- System Generics
      C_NUM_IIC_REGS         : integer                   := 10;

      --IIC Generics to be set by user
      C_S_AXI_ACLK_FREQ_HZ   : integer  := 100000000;
      C_IIC_FREQ             : integer  := 100000;
      C_TEN_BIT_ADR          : integer  := 0;
      C_GPO_WIDTH            : integer  := 0;
      C_SCL_INERTIAL_DELAY   : integer  := 0;
      C_SDA_INERTIAL_DELAY   : integer  := 0;
      C_SDA_LEVEL            : integer  := 1;
      C_SMBUS_PMBUS_HOST     : integer  := 0;   -- SMBUS/PMBUS support
      C_TX_FIFO_EXIST        : boolean  := TRUE;
      C_RC_FIFO_EXIST        : boolean  := TRUE;
      C_S_AXI_ADDR_WIDTH     : integer  := 9;
      C_S_AXI_DATA_WIDTH     : integer range 32 to 32 := 32;
      C_FAMILY               : string   := "virtex7";
      C_DEFAULT_VALUE        : std_logic_vector(7 downto 0) := X"FF"
      );

   port
      (
-- System signals
      S_AXI_ACLK            : in  std_logic;
      S_AXI_ARESETN         : in  std_logic;
      IIC2INTC_Irpt         : out std_logic;

-- AXI signals
      S_AXI_AWADDR          : in  std_logic_vector
                              (C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_AWVALID         : in  std_logic;
      S_AXI_AWREADY         : out std_logic;
      S_AXI_WDATA           : in  std_logic_vector
                              (C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_WSTRB           : in  std_logic_vector
                              ((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
      S_AXI_WVALID          : in  std_logic;
      S_AXI_WREADY          : out std_logic;
      S_AXI_BRESP           : out std_logic_vector(1 downto 0);
      S_AXI_BVALID          : out std_logic;
      S_AXI_BREADY          : in  std_logic;
      S_AXI_ARADDR          : in  std_logic_vector
                              (C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_ARVALID         : in  std_logic;
      S_AXI_ARREADY         : out std_logic;
      S_AXI_RDATA           : out std_logic_vector
                              (C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_RRESP           : out std_logic_vector(1 downto 0);
      S_AXI_RVALID          : out std_logic;
      S_AXI_RREADY          : in  std_logic;

      -- IIC Bus Signals
      Sda_I          : in  std_logic;
      Sda_O          : out std_logic;
      Sda_T          : out std_logic;
      Scl_I          : in  std_logic;
      Scl_O          : out std_logic;
      Scl_T          : out std_logic;
      Gpo            : out std_logic_vector(0 to C_GPO_WIDTH-1)
      );

end entity iic;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------

architecture RTL of iic is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


   -- Calls the function from the iic_pkg.vhd
   constant C_SIZE : integer := num_ctr_bits(C_S_AXI_ACLK_FREQ_HZ, C_IIC_FREQ);

   signal Msms_rst       : std_logic;
   signal Msms_set       : std_logic;
   signal Rsta_rst       : std_logic;
   signal Dtc            : std_logic;
   signal Rdy_new_xmt    : std_logic;
   signal New_rcv_dta    : std_logic;
   signal Ro_prev        : std_logic;
   signal Dtre           : std_logic;
   signal Bb             : std_logic;
   signal Aas            : std_logic;
   signal Al             : std_logic;
   signal Srw            : std_logic;
   signal Txer           : std_logic;
   signal Tx_under_prev  : std_logic;
   signal Abgc           : std_logic;
   signal Data_i2c       : std_logic_vector(0 to 7);
   signal Adr            : std_logic_vector(0 to 7);
   signal Ten_adr        : std_logic_vector(5 to 7);
   signal Cr             : std_logic_vector(0 to 7);
   signal Drr            : std_logic_vector(0 to 7);
   signal Dtr            : std_logic_vector(0 to 7);
   signal Tx_fifo_data   : std_logic_vector(0 to 7);
   signal Tx_data_exists : std_logic;
   signal Tx_fifo_wr     : std_logic;
   signal Tx_fifo_wr_i   : std_logic;
   signal Tx_fifo_wr_d   : std_logic;
   signal Tx_fifo_rd     : std_logic;
   signal Tx_fifo_rd_i   : std_logic;
   signal Tx_fifo_rd_d   : std_logic;
   signal Tx_fifo_rst    : std_logic;
   signal Tx_fifo_full   : std_logic;
   signal Tx_addr        : std_logic_vector(0 to TX_FIFO_BITS - 1);
   signal Rc_fifo_data   : std_logic_vector(0 to 7);
   signal Rc_fifo_wr     : std_logic;
   signal Rc_fifo_wr_i   : std_logic;
   signal Rc_fifo_wr_d   : std_logic;
   signal Rc_fifo_rd     : std_logic;
   signal Rc_fifo_rd_i   : std_logic;
   signal Rc_fifo_rd_d   : std_logic;
   signal Rc_fifo_full   : std_logic;
   signal Rc_Data_Exists : std_logic;
   signal Rc_addr        : std_logic_vector(0 to RC_FIFO_BITS -1);
   signal Bus2IIC_Clk    : std_logic;
   signal Bus2IIC_Reset  : std_logic;
   signal IIC2Bus_Data   : std_logic_vector(0 to C_S_AXI_DATA_WIDTH - 1) :=
                           (others => '0');
   signal IIC2Bus_IntrEvent : std_logic_vector(0 to 7) := (others => '0');
   signal Bus2IIC_Addr   : std_logic_vector(0 to C_S_AXI_ADDR_WIDTH - 1);
   signal Bus2IIC_Data   : std_logic_vector(0 to C_S_AXI_DATA_WIDTH - 1);
   signal Bus2IIC_RNW    : std_logic;
   signal Bus2IIC_RdCE   : std_logic_vector(0 to C_NUM_IIC_REGS - 1);
   signal Bus2IIC_WrCE   : std_logic_vector(0 to C_NUM_IIC_REGS - 1);

   -- signals for dynamic start/stop
   signal ctrlFifoDin         : std_logic_vector(0 to 1);
   signal dynamic_MSMS        : std_logic_vector(0 to 1);
   signal dynRstaSet          : std_logic;
   signal dynMsmsSet          : std_logic;
   signal txak                : std_logic;
   signal earlyAckDataState   : std_logic;
   signal ackDataState        : std_logic;
   signal earlyAckHdr         : std_logic;
   signal cr_txModeSelect_set : std_logic;
   signal cr_txModeSelect_clr : std_logic;
   signal txFifoRd            : std_logic;
   signal Msms_rst_r          : std_logic;
   signal ctrl_fifo_wr_i      : std_logic;

   -- Cleaned up inputs
   signal scl_clean : std_logic;
   signal sda_clean : std_logic;

   -- Timing Parameters
   signal Timing_param_tsusta   : std_logic_vector(C_SIZE-1 downto 0);
   signal Timing_param_tsusto   : std_logic_vector(C_SIZE-1 downto 0);
   signal Timing_param_thdsta   : std_logic_vector(C_SIZE-1 downto 0);
   signal Timing_param_tsudat   : std_logic_vector(C_SIZE-1 downto 0);
   signal Timing_param_tbuf     : std_logic_vector(C_SIZE-1 downto 0);
   signal Timing_param_thigh    : std_logic_vector(C_SIZE-1 downto 0);
   signal Timing_param_tlow     : std_logic_vector(C_SIZE-1 downto 0);
   signal Timing_param_thddat   : std_logic_vector(C_SIZE-1 downto 0);
----------Mathew
-- signal transfer_done : std_logic;
 signal reg_empty     : std_logic;
----------Mathew
begin

   ----------------------------------------------------------------------------
   -- axi_ipif_ssp1 instantiation
   ----------------------------------------------------------------------------

   X_AXI_IPIF_SSP1 : entity axi_iic_v2_0_21.axi_ipif_ssp1
      generic map (
         C_NUM_IIC_REGS => C_NUM_IIC_REGS,


         C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH,
         --  width of the AXI Address Bus (in bits)

         C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
         --  Width of AXI Data Bus (in bits) Must be 32

         C_FAMILY => C_FAMILY)
      port map (

         -- System signals ----------------------------------------------------
        S_AXI_ACLK          =>  S_AXI_ACLK,
        S_AXI_ARESETN       =>  S_AXI_ARESETN,
        IIC2Bus_IntrEvent   => IIC2Bus_IntrEvent,  -- IIC Interrupt events
        IIC2INTC_Irpt       => IIC2INTC_Irpt,

         -- AXI Interface signals --------------
        S_AXI_AWADDR        =>  S_AXI_AWADDR,
        S_AXI_AWVALID       =>  S_AXI_AWVALID,
        S_AXI_AWREADY       =>  S_AXI_AWREADY,
        S_AXI_WDATA         =>  S_AXI_WDATA,
        S_AXI_WSTRB         =>  S_AXI_WSTRB,
        S_AXI_WVALID        =>  S_AXI_WVALID,
        S_AXI_WREADY        =>  S_AXI_WREADY,
        S_AXI_BRESP         =>  S_AXI_BRESP,
        S_AXI_BVALID        =>  S_AXI_BVALID,
        S_AXI_BREADY        =>  S_AXI_BREADY,
        S_AXI_ARADDR        =>  S_AXI_ARADDR,
        S_AXI_ARVALID       =>  S_AXI_ARVALID,
        S_AXI_ARREADY       =>  S_AXI_ARREADY,
        S_AXI_RDATA         =>  S_AXI_RDATA,
        S_AXI_RRESP         =>  S_AXI_RRESP,
        S_AXI_RVALID        =>  S_AXI_RVALID,
        S_AXI_RREADY        =>  S_AXI_RREADY,

         -- IP Interconnect (IPIC) port signals used by the IIC registers. ----
         Bus2IIC_Clk         => Bus2IIC_Clk,
         Bus2IIC_Reset       => Bus2IIC_Reset,
         Bus2IIC_Addr        => Bus2IIC_Addr,
         Bus2IIC_Data        => Bus2IIC_Data,
         Bus2IIC_RNW         => Bus2IIC_RNW,
         Bus2IIC_RdCE        => Bus2IIC_RdCE,
         Bus2IIC_WrCE        => Bus2IIC_WrCE,
         IIC2Bus_Data        => IIC2Bus_Data
         );

   ----------------------------------------------------------------------------
   -- reg_interface instantiation
   ----------------------------------------------------------------------------

   REG_INTERFACE_I : entity axi_iic_v2_0_21.reg_interface
      generic map (
         C_SCL_INERTIAL_DELAY => C_SCL_INERTIAL_DELAY, -- [range 0 to 255]
         C_S_AXI_ACLK_FREQ_HZ => C_S_AXI_ACLK_FREQ_HZ,
         C_IIC_FREQ           => C_IIC_FREQ,
         C_SMBUS_PMBUS_HOST   => C_SMBUS_PMBUS_HOST,
         C_TX_FIFO_EXIST      => C_TX_FIFO_EXIST ,
         C_TX_FIFO_BITS       => 4               ,
         C_RC_FIFO_EXIST      => C_RC_FIFO_EXIST ,
         C_RC_FIFO_BITS       => 4               ,
         C_TEN_BIT_ADR        => C_TEN_BIT_ADR   ,
         C_GPO_WIDTH          => C_GPO_WIDTH     ,
         C_S_AXI_ADDR_WIDTH   => C_S_AXI_ADDR_WIDTH  ,
         C_S_AXI_DATA_WIDTH   => C_S_AXI_DATA_WIDTH  ,
         C_SIZE               => C_SIZE             ,
         C_NUM_IIC_REGS       => C_NUM_IIC_REGS     ,
         C_DEFAULT_VALUE      => C_DEFAULT_VALUE
         )
      port map (
         Clk                 => Bus2IIC_Clk,
         Rst                 => Bus2IIC_Reset,
         Bus2IIC_Addr        => Bus2IIC_Addr,
         Bus2IIC_Data        => Bus2IIC_Data(0 to C_S_AXI_DATA_WIDTH - 1),
         Bus2IIC_RdCE        => Bus2IIC_RdCE,
         Bus2IIC_WrCE        => Bus2IIC_WrCE,
         IIC2Bus_Data        => IIC2Bus_Data(0 to C_S_AXI_DATA_WIDTH - 1),
         IIC2Bus_IntrEvent   => IIC2Bus_IntrEvent,
         Gpo                 => Gpo(0 to C_GPO_WIDTH-1),
         Cr                  => Cr,
         Dtr                 => Dtr,
         Drr                 => Drr,
         Adr                 => Adr,
         Ten_adr             => Ten_adr,
         Msms_set            => Msms_set,
         Msms_rst            => Msms_rst,
         DynMsmsSet          => dynMsmsSet,
         DynRstaSet          => dynRstaSet,
         Cr_txModeSelect_set => cr_txModeSelect_set,
         Cr_txModeSelect_clr => cr_txModeSelect_clr,
         Rsta_rst            => Rsta_rst,
         Rdy_new_xmt         => Rdy_new_xmt,
         New_rcv_dta         => New_rcv_dta,
         Ro_prev             => Ro_prev,
         Dtre                => Dtre,
         Aas                 => Aas,
         Bb                  => Bb,
         Srw                 => Srw,
         Al                  => Al,
         Txer                => Txer,
         Tx_under_prev       => Tx_under_prev,
         Abgc                => Abgc,
         Data_i2c            => Data_i2c,
         Timing_param_tsusta => Timing_param_tsusta,
         Timing_param_tsusto => Timing_param_tsusto,
         Timing_param_thdsta => Timing_param_thdsta,
         Timing_param_tsudat => Timing_param_tsudat,
         Timing_param_tbuf   => Timing_param_tbuf  ,
         Timing_param_thigh  => Timing_param_thigh ,
         Timing_param_tlow   => Timing_param_tlow  ,
         Timing_param_thddat => Timing_param_thddat,
         Tx_fifo_data        => Tx_fifo_data(0 to 7),
         Tx_data_exists      => Tx_data_exists,
         Tx_fifo_wr          => Tx_fifo_wr,
         Tx_fifo_rd          => Tx_fifo_rd,
         Tx_fifo_full        => Tx_fifo_full,
         Tx_fifo_rst         => Tx_fifo_rst,
         Tx_addr             => Tx_addr(0 to TX_FIFO_BITS - 1),
         Rc_fifo_data        => Rc_fifo_data(0 to 7),
         Rc_fifo_wr          => Rc_fifo_wr,
         Rc_fifo_rd          => Rc_fifo_rd,
         Rc_fifo_full        => Rc_fifo_full,
         Rc_Data_Exists      => Rc_Data_Exists,
         Rc_addr             => Rc_addr(0 to RC_FIFO_BITS - 1),
         reg_empty           => reg_empty
         );

   ----------------------------------------------------------------------------
   -- The V5 inputs are so fast that they typically create glitches longer then
   -- the clock period due to the extremely slow rise/fall times on SDA/SCL
   -- signals. The inertial delay filter removes these.
   ----------------------------------------------------------------------------

   FILTER_I: entity axi_iic_v2_0_21.filter
      generic map (
         SCL_INERTIAL_DELAY  => C_SCL_INERTIAL_DELAY, -- [range 0 to 255]
         SDA_INERTIAL_DELAY  => C_SDA_INERTIAL_DELAY  -- [range 0 to 255]
         )
      port map
         (
         Sysclk         => Bus2IIC_Clk,
         Rst            => Bus2IIC_Reset,
         Scl_noisy      => Scl_I,
         Scl_clean      => scl_clean,
         Sda_noisy      => Sda_I,
         Sda_clean      => sda_clean
         );

   ----------------------------------------------------------------------------
   -- iic_control instantiation
   ----------------------------------------------------------------------------

   IIC_CONTROL_I : entity axi_iic_v2_0_21.iic_control
      generic map
         (
         C_SCL_INERTIAL_DELAY   => C_SCL_INERTIAL_DELAY,
         C_S_AXI_ACLK_FREQ_HZ   => C_S_AXI_ACLK_FREQ_HZ,
         C_IIC_FREQ             => C_IIC_FREQ,
         C_SIZE                 => C_SIZE    ,
         C_TEN_BIT_ADR          => C_TEN_BIT_ADR,
         C_SDA_LEVEL            => C_SDA_LEVEL,
         C_SMBUS_PMBUS_HOST     => C_SMBUS_PMBUS_HOST
         )
      port map
         (
         Sys_clk               => Bus2IIC_Clk,
         Reset                 => Cr(7),
         Sda_I                 => sda_clean,
         Sda_O                 => Sda_O,
         Sda_T                 => Sda_T,
         Scl_I                 => scl_clean,
         Scl_O                 => Scl_O,
         Scl_T                 => Scl_T,

         Timing_param_tsusta   => Timing_param_tsusta,
         Timing_param_tsusto   => Timing_param_tsusto,
         Timing_param_thdsta   => Timing_param_thdsta,
         Timing_param_tsudat   => Timing_param_tsudat,
         Timing_param_tbuf     => Timing_param_tbuf  ,
         Timing_param_thigh    => Timing_param_thigh ,
         Timing_param_tlow     => Timing_param_tlow  ,
         Timing_param_thddat   => Timing_param_thddat,

         Txak                  => txak,
         Msms                  => Cr(5),
         Msms_set              => Msms_set,
         Msms_rst              => Msms_rst_r,
         Rsta                  => Cr(2),
         Rsta_rst              => Rsta_rst,
         Tx                    => Cr(4),
         Gc_en                 => Cr(1),
         Dtr                   => Dtr,
         Adr                   => Adr,
         Ten_adr               => Ten_adr,
         Bb                    => Bb,
         Dtc                   => Dtc,
         Aas                   => Aas,
         Al                    => Al,
         Srw                   => Srw,
         Txer                  => Txer,
         Tx_under_prev         => Tx_under_prev,
         Abgc                  => Abgc,
         Data_i2c              => Data_i2c,
         New_rcv_dta           => New_rcv_dta,
         Ro_prev               => Ro_prev,
         Dtre                  => Dtre,
         Rdy_new_xmt           => Rdy_new_xmt,
         EarlyAckHdr           => earlyAckHdr,
         EarlyAckDataState     => earlyAckDataState,
         AckDataState          => ackDataState,
         reg_empty             => reg_empty 
         );

   ----------------------------------------------------------------------------
   -- Transmitter FIFO instantiation
   ----------------------------------------------------------------------------

   WRITE_FIFO_I : entity axi_iic_v2_0_21.srl_fifo
      generic map (
         C_DATA_BITS    => DATA_BITS,
         C_DEPTH        => TX_FIFO_BITS
         )
      port map
         (
         Clk            => Bus2IIC_Clk,
         Reset          => Tx_fifo_rst,
         FIFO_Write     => Tx_fifo_wr_i,
         Data_In        => Bus2IIC_Data(24 to 31),
         FIFO_Read      => txFifoRd,
         Data_Out       => Tx_fifo_data(0 to 7),
         FIFO_Full      => Tx_fifo_full,
         Data_Exists    => Tx_data_exists,
         Addr           => Tx_addr(0 to TX_FIFO_BITS - 1)
         );
-------Mathew
   --  transfer_done <= '1' when Tx_data_exists = '0' and reg_empty ='1' else '0';
-------Mathew
   ----------------------------------------------------------------------------
   -- Receiver FIFO instantiation
   ----------------------------------------------------------------------------

   READ_FIFO_I : entity axi_iic_v2_0_21.srl_fifo
      generic map (
         C_DATA_BITS    => DATA_BITS,
         C_DEPTH        => RC_FIFO_BITS
         )
      port map (
         Clk            => Bus2IIC_Clk,
         Reset          => Bus2IIC_Reset,
         FIFO_Write     => Rc_fifo_wr_i,
         Data_In        => Data_i2c(0 to 7),
         FIFO_Read      => Rc_fifo_rd_i,
         Data_Out       => Rc_fifo_data(0 to 7),
         FIFO_Full      => Rc_fifo_full,
         Data_Exists    => Rc_Data_Exists,
         Addr           => Rc_addr(0 to RC_FIFO_BITS - 1)
         );

   ----------------------------------------------------------------------------
   -- PROCESS: TX_FIFO_WR_GEN
   -- purpose: generate TX FIFO write control signals
   ----------------------------------------------------------------------------

   TX_FIFO_WR_GEN : process(Bus2IIC_Clk)
   begin
      if(Bus2IIC_Clk'event and Bus2IIC_Clk = '1') then
         if(Bus2IIC_Reset = '1') then
            Tx_fifo_wr_d <= '0';
            Tx_fifo_rd_d <= '0';
         else
            Tx_fifo_wr_d <= Tx_fifo_wr;
            Tx_fifo_rd_d <= Tx_fifo_rd;
         end if;
      end if;
   end process TX_FIFO_WR_GEN;

   ----------------------------------------------------------------------------
   -- PROCESS: RC_FIFO_WR_GEN
   -- purpose: generate TX FIFO write control signals
   ----------------------------------------------------------------------------

   RC_FIFO_WR_GEN : process(Bus2IIC_Clk)
   begin
      if(Bus2IIC_Clk'event and Bus2IIC_Clk = '1') then
         if(Bus2IIC_Reset = '1') then
            Rc_fifo_wr_d <= '0';
            Rc_fifo_rd_d <= '0';
         else
            Rc_fifo_wr_d <= Rc_fifo_wr;
            Rc_fifo_rd_d <= Rc_fifo_rd;
         end if;
      end if;
   end process RC_FIFO_WR_GEN;

   Tx_fifo_wr_i <= Tx_fifo_wr and (not Tx_fifo_wr_d);
   Rc_fifo_wr_i <= Rc_fifo_wr and (not Rc_fifo_wr_d);

   Tx_fifo_rd_i <= Tx_fifo_rd and (not Tx_fifo_rd_d);
   Rc_fifo_rd_i <= Rc_fifo_rd and (not Rc_fifo_rd_d);

   ----------------------------------------------------------------------------
   -- Dynamic master interface
   -- Dynamic master start/stop and control logic
   ----------------------------------------------------------------------------

   DYN_MASTER_I : entity axi_iic_v2_0_21.dynamic_master
      port map (
         Clk                 => Bus2IIC_Clk ,
         Rst                 => Tx_fifo_rst ,
         dynamic_MSMS        => dynamic_MSMS ,
         Cr                  => Cr ,
         Tx_fifo_rd_i        => Tx_fifo_rd_i ,
         Tx_data_exists      => Tx_data_exists ,
         ackDataState        => ackDataState ,
         Tx_fifo_data        => Tx_fifo_data ,
         earlyAckHdr         => earlyAckHdr ,
         earlyAckDataState   => earlyAckDataState ,
         Bb                  => Bb ,
         Msms_rst_r          => Msms_rst_r ,
         dynMsmsSet          => dynMsmsSet ,
         dynRstaSet          => dynRstaSet ,
         Msms_rst            => Msms_rst ,
         txFifoRd            => txFifoRd ,
         txak                => txak ,
         cr_txModeSelect_set => cr_txModeSelect_set,
         cr_txModeSelect_clr => cr_txModeSelect_clr
         );

   -- virtual reset. Since srl fifo address is rst at the same time, only the
   -- first entry in the srl fifo needs to have a value of '00' to appear
   -- reset. Also, force data to 0 if a byte write is done to the txFifo.
   ctrlFifoDin <= Bus2IIC_Data(22 to 23) when (Tx_fifo_rst = '0' and
                                               Bus2IIC_Reset = '0') else
                  "00";

   -- continuously write srl fifo while reset active
   ctrl_fifo_wr_i <= Tx_fifo_rst or Bus2IIC_Reset or Tx_fifo_wr_i;

   ----------------------------------------------------------------------------
   -- Control FIFO instantiation
   -- fifo used to set/reset MSMS bit in control register to create automatic
   -- START/STOP conditions
   ----------------------------------------------------------------------------

   WRITE_FIFO_CTRL_I : entity axi_iic_v2_0_21.srl_fifo
      generic map (
         C_DATA_BITS => 2,
         C_DEPTH     => TX_FIFO_BITS
         )
      port map
         (
         Clk         => Bus2IIC_Clk,
         Reset       => Tx_fifo_rst,
         FIFO_Write  => ctrl_fifo_wr_i,
         Data_In     => ctrlFifoDin,
         FIFO_Read   => txFifoRd,
         Data_Out    => dynamic_MSMS,
         FIFO_Full   => open,
         Data_Exists => open,
         Addr        => open
         );

end architecture RTL;


-------------------------------------------------------------------------------
-- axi_iic.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--  ***************************************************************************
--  ** DISCLAIMER OF LIABILITY                                               **
--  **                                                                       **
--  **  This file contains proprietary and confidential information of       **
--  **  Xilinx, Inc. ("Xilinx"), that is distributed under a license         **
--  **  from Xilinx, and may be used, copied and/or disclosed only           **
--  **  pursuant to the terms of a valid license agreement with Xilinx.      **
--  **                                                                       **
--  **  XILINX is PROVIDING THIS DESIGN, CODE, OR INFORMATION                **
--  **  ("MATERIALS") "AS is" WITHOUT WARRANTY OF ANY KIND, EITHER           **
--  **  EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                  **
--  **  LIMITATION, ANY WARRANTY WITH RESPECT to NONINFRINGEMENT,            **
--  **  MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx        **
--  **  does not warrant that functions included in the Materials will       **
--  **  meet the requirements of Licensee, or that the operation of the      **
--  **  Materials will be uninterrupted or error-free, or that defects       **
--  **  in the Materials will be corrected. Furthermore, Xilinx does         **
--  **  not warrant or make any representations regarding use, or the        **
--  **  results of the use, of the Materials in terms of correctness,        **
--  **  accuracy, reliability or otherwise.                                  **
--  **                                                                       **
--  **  Xilinx products are not designed or intended to be fail-safe,        **
--  **  or for use in any application requiring fail-safe performance,       **
--  **  such as life-support or safety devices or systems, Class III         **
--  **  medical devices, nuclear facilities, applications related to         **
--  **  the deployment of airbags, or any other applications that could      **
--  **  lead to death, personal injury or severe property or                 **
--  **  environmental damage (individually and collectively, "critical       **
--  **  applications"). Customer assumes the sole risk and liability         **
--  **  of any use of Xilinx products in critical applications,              **
--  **  subject only to applicable laws and regulations governing            **
--  **  limitations on product liability.                                    **
--  **                                                                       **
--  **  Copyright 2011 Xilinx, Inc.                                          **
--  **  All rights reserved.                                                 **
--  **                                                                       **
--  **  This disclaimer and copyright notice must be retained as part        **
--  **  of this file at all times.                                           **
--  ***************************************************************************
-------------------------------------------------------------------------------
-- Filename:        axi_iic.vhd
-- Version:         v1.01.b
-- Description:
--                  This file is the top level file that contains the IIC AXI
--                  Interface.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--           axi_iic.vhd
--              -- iic.vhd
--                  -- axi_ipif_ssp1.vhd
--                      -- axi_lite_ipif.vhd
--                      -- interrupt_control.vhd
--                      -- soft_reset.vhd
--                  -- reg_interface.vhd
--                  -- filter.vhd
--                      -- debounce.vhd
--                  -- iic_control.vhd
--                      -- upcnt_n.vhd
--                      -- shift8.vhd
--                  -- dynamic_master.vhd
--                  -- iic_pkg.vhd
--
-------------------------------------------------------------------------------
-- Author:          USM
--
--  USM     10/15/09
-- ^^^^^^
--  - Initial release of v1.00.a
-- ~~~~~~
--
--  USM     09/06/10
-- ^^^^^^
--  - Release of v1.01.a
--  - Added function calc_tbuf in iic_control to calculate the TBUF delay
-- ~~~~~~
--
--  NLR     01/07/11
-- ^^^^^^
--  - Fixed the CR#613282 and CR#613486
--  - Release of v1.01.b 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi_iic_v2_0_21;
use axi_iic_v2_0_21.iic_pkg.all;

-------------------------------------------------------------------------------
-- Definition of Generics:
--   C_IIC_FREQ             -- Maximum frequency of Master Mode in Hz
--   C_TEN_BIT_ADR          -- 10 bit slave addressing
--   C_GPO_WIDTH            -- Width of General purpose output vector
--   C_S_AXI_ACLK_FREQ_HZ   -- Specifies AXI clock frequency
--   C_SCL_INERTIAL_DELAY   -- SCL filtering
--   C_SDA_INERTIAL_DELAY   -- SDA filtering
--   C_SDA_LEVEL            -- SDA level
--   C_SMBUS_PMBUS_HOST     -- Acts as SMBus/PMBus host when enabled
--   C_S_AXI_DATA_WIDTH     -- Width of the AXI Data Bus (in bits)
--   C_FAMILY               -- XILINX FPGA family
-------------------------------------------------------------------------------
-- Definition of ports:
--
--   System Signals
--      s_axi_aclk            -- AXI Clock
--      s_axi_aresetn         -- AXI Reset
--      IP2INTC_Irpt          -- System interrupt output
--
--AXI signals
--      s_axi_awaddr          -- AXI Write address
--      s_axi_awvalid         -- Write address valid
--      s_axi_awready         -- Write address ready
--      s_axi_wdata           -- Write data
--      s_axi_wstrb           -- Write strobes
--      s_axi_wvalid          -- Write valid
--      s_axi_wready          -- Write ready
--      s_axi_bresp           -- Write response
--      s_axi_bvalid          -- Write response valid
--      s_axi_bready          -- Response ready
--      s_axi_araddr          -- Read address
--      s_axi_arvalid         -- Read address valid
--      s_axi_arready         -- Read address ready
--      s_axi_rdata           -- Read data
--      s_axi_rresp           -- Read response
--      s_axi_rvalid          -- Read valid
--      s_axi_rready          -- Read ready
--   IIC Signals
--      sda_i                 -- IIC serial data input
--      sda_o                 -- IIC serial data output
--      sda_t                 -- IIC seral data output enable
--      scl_i                 -- IIC serial clock input
--      scl_o                 -- IIC serial clock output
--      scl_t                 -- IIC serial clock output enable
--      gpo                   -- General purpose outputs
--
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity axi_iic is

   generic (

      -- FPGA Family Type specification
      C_FAMILY              : string := "virtex7";
      -- Select the target architecture type

    -- AXI Parameters
      --C_S_AXI_ADDR_WIDTH    : integer range 32 to 36        := 32; --9
      C_S_AXI_ADDR_WIDTH    : integer                       := 9; --9
      C_S_AXI_DATA_WIDTH    : integer range 32 to 32        := 32;

      -- AXI IIC Feature generics
      C_IIC_FREQ            : integer    := 100E3;
      C_TEN_BIT_ADR         : integer    := 0;
      C_GPO_WIDTH           : integer    := 1;
      C_S_AXI_ACLK_FREQ_HZ  : integer    := 25E6;
      C_SCL_INERTIAL_DELAY  : integer    := 0;  -- delay in nanoseconds
      C_SDA_INERTIAL_DELAY  : integer    := 0;  -- delay in nanoseconds
      C_SDA_LEVEL           : integer    := 1;  -- delay in nanoseconds
      C_SMBUS_PMBUS_HOST    : integer    := 0;   -- SMBUS/PMBUS support
      C_DEFAULT_VALUE       : std_logic_vector(7 downto 0) := X"FF"
      );

   port (

-- System signals
      s_axi_aclk            : in  std_logic;
      s_axi_aresetn         : in  std_logic := '1';
      iic2intc_irpt         : out std_logic;

-- AXI signals
      s_axi_awaddr          : in  std_logic_vector (8 downto 0);
                              --(C_S_AXI_ADDR_WIDTH-1 downto 0);
      s_axi_awvalid         : in  std_logic;
      s_axi_awready         : out std_logic;
      s_axi_wdata           : in  std_logic_vector (31 downto 0);
                              --(C_S_AXI_DATA_WIDTH-1 downto 0);
      s_axi_wstrb           : in  std_logic_vector (3 downto 0);
                              --((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
      s_axi_wvalid          : in  std_logic;
      s_axi_wready          : out std_logic;
      s_axi_bresp           : out std_logic_vector(1 downto 0);
      s_axi_bvalid          : out std_logic;
      s_axi_bready          : in  std_logic;
      s_axi_araddr          : in  std_logic_vector(8 downto 0);
                              --(C_S_AXI_ADDR_WIDTH-1 downto 0);
      s_axi_arvalid         : in  std_logic;
      s_axi_arready         : out std_logic;
      s_axi_rdata           : out std_logic_vector (31 downto 0);
                              --(C_S_AXI_DATA_WIDTH-1 downto 0);
      s_axi_rresp           : out std_logic_vector(1 downto 0);
      s_axi_rvalid          : out std_logic;
      s_axi_rready          : in  std_logic;

      -- IIC interface signals
      sda_i            : in  std_logic;
      sda_o            : out std_logic;
      sda_t            : out std_logic;
      scl_i            : in  std_logic;
      scl_o            : out std_logic;
      scl_t            : out std_logic;
      gpo              : out std_logic_vector(C_GPO_WIDTH-1 downto 0)
      );

end entity axi_iic;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture RTL of axi_iic is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";


 
   constant C_NUM_IIC_REGS       : integer := 18;

begin

   X_IIC: entity axi_iic_v2_0_21.iic
      generic map (

         -- System Generics
         C_NUM_IIC_REGS        => C_NUM_IIC_REGS,   -- Number of IIC Registers

         --iic Generics to be set by user
         C_S_AXI_ACLK_FREQ_HZ  => C_S_AXI_ACLK_FREQ_HZ,
         C_IIC_FREQ            => C_IIC_FREQ,  --  default iic Serial 100KHz
         C_TEN_BIT_ADR         => C_TEN_BIT_ADR,  -- [integer]
         C_GPO_WIDTH           => C_GPO_WIDTH,    -- [integer]
         C_SCL_INERTIAL_DELAY  => C_SCL_INERTIAL_DELAY, -- delay in nanoseconds
         C_SDA_INERTIAL_DELAY  => C_SDA_INERTIAL_DELAY, -- delay in nanoseconds
         C_SDA_LEVEL           => C_SDA_LEVEL,
         C_SMBUS_PMBUS_HOST    => C_SMBUS_PMBUS_HOST,

         -- Transmit FIFO Generic
         -- Removed as user input 10/08/01
         -- Software will not be tested without FIFO's
         C_TX_FIFO_EXIST      => TRUE,  -- [boolean]

         -- Recieve FIFO Generic
         -- Removed as user input 10/08/01
         -- Software will not be tested without FIFO's
         C_RC_FIFO_EXIST     => TRUE,  -- [boolean]

         -- AXI interface generics

         C_S_AXI_ADDR_WIDTH  => C_S_AXI_ADDR_WIDTH, -- [integer 9]
         --  width of the AXI Address Bus (in bits)

         C_S_AXI_DATA_WIDTH  => C_S_AXI_DATA_WIDTH, -- [integer range 32 to 32]
         --  Width of the AXI Data Bus (in bits)

         C_FAMILY            => C_FAMILY,  -- [string]
         C_DEFAULT_VALUE     => C_DEFAULT_VALUE

         )
      port map
        (
         -- System signals
        S_AXI_ACLK          =>  s_axi_aclk,
        S_AXI_ARESETN       =>  s_axi_aresetn,
        IIC2INTC_IRPT       =>  iic2intc_iRPT,

         -- AXI Interface signals
        S_AXI_AWADDR        =>  s_axi_awaddr,
        S_AXI_AWVALID       =>  s_axi_awvalid,
        S_AXI_AWREADY       =>  s_axi_awready,
        S_AXI_WDATA         =>  s_axi_wdata,
        S_AXI_WSTRB         =>  s_axi_wstrb,
        S_AXI_WVALID        =>  s_axi_wvalid,
        S_AXI_WREADY        =>  s_axi_wready,
        S_AXI_BRESP         =>  s_axi_bresp,
        S_AXI_BVALID        =>  s_axi_bvalid,
        S_AXI_BREADY        =>  s_axi_bready,
        S_AXI_ARADDR        =>  s_axi_araddr,
        S_AXI_ARVALID       =>  s_axi_arvalid,
        S_AXI_ARREADY       =>  s_axi_arready,
        S_AXI_RDATA         =>  s_axi_rdata,
        S_AXI_RRESP         =>  s_axi_rresp,
        S_AXI_RVALID        =>  s_axi_rvalid,
        S_AXI_RREADY        =>  s_axi_rready,

         -- IIC Bus Signals
        SDA_I               => sda_i,
        SDA_O               => sda_o,
        SDA_T               => sda_t,
        SCL_I               => scl_i,
        SCL_O               => scl_o,
        SCL_T               => scl_t,
        GPO                 => gpo
        );
end architecture RTL;


