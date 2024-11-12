//////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Kikyoko
// https://github.com/Kikyoko
// 
// Module   : UART_TX
// Device   : Xilinx/Altera
// Author   : Kikyoko
// Contact  : Kikyoko@outlook.com
// Date     : 2020/8/13 14:39:28
// Revision : 1.00 - Simulation correct
//
// Description  : user UART bus TX interface
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

module UART_TX # (
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
    output                      o_user_tx_ready         ,
    input   [DATA_WIDTH-1:0]    i_user_tx_data          ,
    input                       i_user_tx_valid         ,
    
    //uart interface
    output                      uart_txd                             
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
localparam LP_CNT_WIDTH = FUNC_N2W(LP_END_LEN);

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
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

//get tx data
logic   [DATA_WIDTH-1:0]    r_tx_data   ;
logic   [  3:0]             r_bit1_cnt  ;

//uart_txd generate
logic                       r_txd       ;

// =========================================================================================================================================
// output generate
// =========================================================================================================================================
assign o_user_tx_ready  = s_end_bit & s_cnt_down;
assign uart_txd         = r_txd;

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//bit flag generate
generate
    if (CHECK_BIT == "none") begin
        always @ (posedge clk) begin
            if (rst) begin
                r_bit_flag  <= {1'b1,{(DATA_WIDTH+1){1'b0}}};
            end else begin
                if (s_cnt_down) begin
                    if ((s_end_bit & o_user_tx_ready & i_user_tx_valid) | ~s_end_bit) begin
                        r_bit_flag  <= {r_bit_flag[DATA_WIDTH:0],r_bit_flag[DATA_WIDTH+1]};
                    end
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
                if (s_cnt_down) begin
                    if ((s_end_bit & o_user_tx_ready & i_user_tx_valid) | ~s_end_bit) begin
                        r_bit_flag  <= {r_bit_flag[DATA_WIDTH+1:0],r_bit_flag[DATA_WIDTH+2]};
                    end
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
        r_baud_cnt  <= LP_BIT_LEN;  //max baud_cnt: 300M/9600
    end else begin
        if (s_cnt_down) begin
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
assign s_cnt_down = ~|r_baud_cnt;

//get tx data
always @ (posedge clk) begin
    if (rst) begin
        r_tx_data   <= 'd0;
        r_bit1_cnt  <= 4'd0;
    end else begin
        if (o_user_tx_ready & i_user_tx_valid) begin
            r_tx_data   <= i_user_tx_data;
            r_bit1_cnt  <= i_user_tx_data[0];
        end else if (s_cnt_down & |s_data_bit) begin
            r_tx_data   <= (r_tx_data >> 1);
            r_bit1_cnt  <= r_bit1_cnt + r_tx_data[1];
        end
    end
end

//uart_txd generate
generate
    if (CHECK_BIT == "none") begin
        always @ (posedge clk) begin
            if (rst) begin
                r_txd   <= 1'b1;
            end else begin
                case ({s_end_bit,|s_data_bit,s_start_bit})
                    3'b001  : r_txd <= 1'b0;
                    3'b010  : r_txd <= r_tx_data[0];
                    3'b100  : r_txd <= 1'b1;
                    default : r_txd <= 1'b1;
                endcase
            end
        end
    end else begin
        wire    s_check_res;
        always @ (posedge clk) begin
            if (rst) begin
                r_txd   <= 1'b1;
            end else begin
                case ({s_end_bit,s_check_bit,|s_data_bit,s_start_bit})
                    4'b0001 : r_txd <= 1'b0;
                    4'b0010 : r_txd <= r_tx_data[0];
                    4'b0100 : r_txd <= s_check_res;
                    4'b1000 : r_txd <= 1'b1;
                    default : r_txd <= 1'b1;
                endcase
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


endmodule

