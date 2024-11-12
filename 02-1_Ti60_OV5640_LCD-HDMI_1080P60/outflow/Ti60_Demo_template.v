
// Efinity Top-level template
// Version: 2023.2.307
// Date: 2024-11-12 16:55

// Copyright (C) 2013 - 2023 Efinix Inc. All rights reserved.

// This file may be used as a starting point for Efinity synthesis top-level target.
// The port list here matches what is expected by Efinity constraint files generated
// by the Efinity Interface Designer.

// To use this:
//     #1)  Save this file with a different name to a different directory, where source files are kept.
//              Example: you may wish to save as D:\Efinity\project\nearest\02-1_Ti60_OV5640_LCD-HDMI_1080P60\Ti60_Demo.v
//     #2)  Add the newly saved file into Efinity project as design file
//     #3)  Edit the top level entity in Efinity project to:  Ti60_Demo
//     #4)  Insert design content.


module Ti60_Demo
(
  input clk_24m,
  input clk_25m,
  input cmos_ctl1_i,
  input cmos_ctl2_i,
  input [7:0] cmos_data,
  input cmos_href,
  input cmos_sdat_IN,
  input cmos_vsync,
  input sys_pll_lock,
  input ddr_pll_lock,
  input core_clk,
  input tdqss_clk,
  input tac_clk,
  input twd_clk,
  input clk_pixel,
  input clk_sys,
  input clk_pixel_2x,
  input clk_pixel_10x,
  input cmos_pclk,
  input cmos_ctl3_i,
  input [15:0] i_dq_hi,
  input [15:0] i_dq_lo,
  input [1:0] i_dqs_hi,
  input [1:0] i_dqs_lo,
  input [1:0] i_dqs_n_hi,
  input [1:0] i_dqs_n_lo,
  input [1:0] i_key_n,
  input uart_rx_i,
  output cmos_ctl1_o,
  output cmos_ctl1_oe,
  output cmos_ctl2_o,
  output cmos_ctl2_oe,
  output cmos_sclk,
  output cmos_sdat_OUT,
  output cmos_sdat_OE,
  output sys_pll_rstn_o,
  output ddr_pll_rstn_o,
  output [2:0] shift,
  output shift_ena,
  output [4:0] shift_sel,
  output hdmi_txc_oe,
  output [9:0] hdmi_txc_o,
  output hdmi_txc_rst_o,
  output hdmi_txd0_oe,
  output [9:0] hdmi_txd0_o,
  output hdmi_txd0_rst_o,
  output hdmi_txd1_oe,
  output [9:0] hdmi_txd1_o,
  output hdmi_txd1_rst_o,
  output hdmi_txd2_oe,
  output [9:0] hdmi_txd2_o,
  output hdmi_txd2_rst_o,
  output [15:0] addr,
  output [2:0] ba,
  output cas,
  output cke,
  output clk_n_hi,
  output clk_n_lo,
  output clk_p_hi,
  output clk_p_lo,
  output cmos_ctl3_o,
  output cmos_ctl3_oe,
  output cs,
  output [1:0] o_dm_hi,
  output [1:0] o_dm_lo,
  output [15:0] o_dq_hi,
  output [15:0] o_dq_lo,
  output [15:0] o_dq_oe,
  output [1:0] o_dqs_hi,
  output [1:0] o_dqs_lo,
  output [1:0] o_dqs_oe,
  output [1:0] o_dqs_n_hi,
  output [1:0] o_dqs_n_lo,
  output [1:0] o_dqs_n_oe,
  output odt,
  output ras,
  output reset,
  output uart_tx_o,
  output we
);


endmodule

