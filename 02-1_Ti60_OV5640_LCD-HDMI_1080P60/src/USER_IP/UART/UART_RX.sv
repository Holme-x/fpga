//////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Kikyoko
// https://github.com/Kikyoko
// 
// Module   : UART_RX
// Device   : Xilinx/Altera
// Author   : Kikyoko
// Contact  : Kikyoko@outlook.com
// Date     : 2020/8/13 14:39:06
// Revision : 1.00 - Simulation correct
//
// Description  : user UART bus RX interface
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//////////////////////////////////////////////////////////////////////////////////////////

module UART_RX # (
    parameter       CLK_FRAC    = 50            , //unit: 100KHz
    parameter       BAUD        = 19200         , //max 10M
    parameter       DATA_WIDTH  = 8             ,
    parameter       CHECK_BIT   = "none"        , //"even", "odd", "mask", "space", "none"
    parameter       END_WIDTH   = 1               //end bit width
) (
    //global clock & reset
    input                       clk                     ,
    input                       rst                     ,
    
    //user data interface
    output  [DATA_WIDTH-1:0]    o_user_rx_data          ,
    output                      o_user_rx_valid         ,
    output                      o_user_rx_err           ,
    
    //uart interface
    input                       uart_rxd                             
);

function integer FUNC_N2W;
    input integer   NUM    ;
    integer         WIDTH  ;
    
    begin
        WIDTH = 1;
        while (NUM > (2**WIDTH-1)) begin
            WIDTH = WIDTH + 1;
        end
        FUNC_N2W = WIDTH;
    end
endfunction

localparam LP_BIT_LEN   = CLK_FRAC*100000/BAUD-1;
localparam LP_END_LEN   = CLK_FRAC*END_WIDTH*100000/BAUD-1;
localparam LP_START_LEN = CLK_FRAC*50000/BAUD-1;
localparam LP_CNT_WIDTH = FUNC_N2W(LP_END_LEN);

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
//rx negedge check
logic   [  2:0]             r_rxd_3ff   ;
logic                       r_rxd_neg   ;

//bit flag generate
logic   [DATA_WIDTH+2:0]    r_bit_flag  ;
logic                       s_start_bit ;
logic   [DATA_WIDTH-1:0]    s_data_bit  ;
logic                       s_check_bit ;
logic                       s_next_end  ;
logic                       s_end_bit   ;

//BAUD counter
logic   [LP_CNT_WIDTH-1:0]  r_baud_cnt  ;
logic                       s_cnt_down  ;

//get rx data
logic   [DATA_WIDTH-1:0]    r_rx_data   ;
logic   [  3:0]             r_bit1_cnt  ;

//rx check & data valid generate
logic                       r_check_err ;
logic                       r_rxd_valid ;

// =========================================================================================================================================
// output generate
// =========================================================================================================================================
assign o_user_rx_data   = r_rx_data;
assign o_user_rx_valid  = r_rxd_valid;
assign o_user_rx_err    = r_check_err;

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//rx negedge check
always @ (posedge clk) begin
    if (rst) begin
        r_rxd_3ff   <= 3'h7;
        r_rxd_neg   <= 1'b0;
    end else begin
        r_rxd_3ff   <= {r_rxd_3ff[1:0],uart_rxd};
        r_rxd_neg   <= (r_rxd_3ff[2:1] == 2'b10);
    end
end

//bit flag generate
generate
    if (CHECK_BIT == "none") begin
        always @ (posedge clk) begin
            if (rst) begin
                r_bit_flag  <= {1'b1,{(DATA_WIDTH+1){1'b0}}};
            end else begin
                if ((s_end_bit & r_rxd_neg) | (~s_end_bit & s_cnt_down)) begin
                    r_bit_flag  <= {r_bit_flag[DATA_WIDTH:0],r_bit_flag[DATA_WIDTH+1]};
                end
            end
        end
        assign s_next_end   = r_bit_flag[DATA_WIDTH];
        assign s_end_bit    = r_bit_flag[DATA_WIDTH+1];
    end else begin
        always @ (posedge clk) begin
            if (rst) begin
                r_bit_flag  <= {1'b1,{(DATA_WIDTH+2){1'b0}}};
            end else begin
                if ((s_end_bit & r_rxd_neg) | (~s_end_bit & s_cnt_down)) begin
                    r_bit_flag  <= {r_bit_flag[DATA_WIDTH+1:0],r_bit_flag[DATA_WIDTH+2]};
                end
            end
        end
        assign s_check_bit  = r_bit_flag[DATA_WIDTH+1];
        assign s_next_end   = s_check_bit;
        assign s_end_bit    = r_bit_flag[DATA_WIDTH+2];
    end
endgenerate
assign s_start_bit  = r_bit_flag[0];
assign s_data_bit   = r_bit_flag[DATA_WIDTH:1];

//BAUD counter
always @ (posedge clk) begin
    if (rst) begin
        r_baud_cnt  <= LP_BIT_LEN;
    end else begin
        if (s_end_bit & r_rxd_neg) begin
            r_baud_cnt  <= LP_START_LEN;
        end else begin
            if (s_cnt_down & ~s_end_bit) begin
                if (s_next_end) begin
                    r_baud_cnt  <= LP_END_LEN;
                end else begin
                    r_baud_cnt  <= LP_BIT_LEN;
                end
            end else begin
                r_baud_cnt  <= r_baud_cnt - 1'b1;
            end
        end
    end
end
assign s_cnt_down = ~|r_baud_cnt;

//get rx data
always @ (posedge clk) begin
    if (s_cnt_down & |s_data_bit) begin
        r_rx_data   <= {r_rxd_3ff[2],r_rx_data[DATA_WIDTH-1:1]};
    end
    if (s_start_bit) begin
        r_bit1_cnt  <= 4'd0;
    end else if (s_cnt_down & |s_data_bit) begin
        r_bit1_cnt   <= r_bit1_cnt + r_rxd_3ff[2];
    end
end

//rx check & data valid generate
generate
    if (CHECK_BIT == "none") begin
        always @ (posedge clk) begin
            if (rst) begin
                r_check_err <= 1'b0;
            end
        end
    end else begin
        logic   s_check_res;
        always @ (posedge clk) begin
            if (rst) begin
                r_check_err <= 1'b0;
            end else begin
                r_check_err <= (s_cnt_down & s_check_bit) & (s_check_res ^ r_rxd_3ff[2]);
            end
        end
        
        if (CHECK_BIT == "even") begin
            assign s_check_res = r_bit1_cnt[0];
        end
        if (CHECK_BIT == "odd") begin
            assign s_check_res = ~r_bit1_cnt[0];
        end
        if (CHECK_BIT == "mask") begin
            assign s_check_res = 1'b1;
        end
        if (CHECK_BIT == "space") begin
            assign s_check_res = 1'b0;
        end
    end
endgenerate

always @ (posedge clk) begin
    if (rst) begin
        r_rxd_valid <= 1'b0;
    end else begin
        r_rxd_valid <= (s_cnt_down & s_next_end);
    end
end


endmodule

