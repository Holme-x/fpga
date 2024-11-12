//////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Kikyoko
// https://github.com/Kikyoko
// 
// Module   : UART_IF
// Device   : Xilinx/Altera
// Author   : Kikyoko
// Contact  : Kikyoko@outlook.com
// Date     : 2020/8/13 14:38:11
// Revision : 1.00 - Simulation correct
//
// Description  : user UART bus interface
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

module UART_IF # (
    parameter       CLK_FRAC    = 50            , //unit: 100KHz
    parameter       BAUD        = 19200         ,
    parameter       DATA_WIDTH  = 8             ,
    parameter       CHECK_BIT   = "even"        , //"even", "odd", "mask", "space", "none"
    parameter       END_WIDTH   = 1               //end bit width
) (
    //global clock & reset
    input                       clk                     ,
    input                       rst                     ,
    
    //user data interface
    output                      o_user_tx_ready         ,
    input   [DATA_WIDTH-1:0]    i_user_tx_data          ,
    input                       i_user_tx_valid         ,
    output  [DATA_WIDTH-1:0]    o_user_rx_data          ,
    output                      o_user_rx_valid         ,
    output                      o_user_rx_err           ,
    
    //UART interface
    output                      uart_txd                ,
    input                       uart_rxd                
);


// =========================================================================================================================================
// Logic
// =========================================================================================================================================
UART_TX # (
    .CLK_FRAC           ( CLK_FRAC          ), //unit: 100KHz
    .BAUD               ( BAUD              ),
    .DATA_WIDTH         ( DATA_WIDTH        ),
    .CHECK_BIT          ( CHECK_BIT         ), //"even", "odd", "mask", "space", "none"
    .END_WIDTH          ( END_WIDTH         )  //end bit width
) u_UART_TX (
    //global clock & reset
    .clk                ( clk               ),
    .rst                ( rst               ),
    
    //user data interface
    .o_user_tx_ready    ( o_user_tx_ready   ),
    .i_user_tx_data     ( i_user_tx_data    ),
    .i_user_tx_valid    ( i_user_tx_valid   ),
    
    //uart interface
    .uart_txd           ( uart_txd          )
);

UART_RX # (
    .CLK_FRAC           ( CLK_FRAC          ), //unit: 100KHz
    .BAUD               ( BAUD              ),
    .DATA_WIDTH         ( DATA_WIDTH        ),
    .CHECK_BIT          ( CHECK_BIT         ), //"even", "odd", "mask", "space", "none"
    .END_WIDTH          ( END_WIDTH         )  //end bit width
) u_UART_RX (
    //global clock & reset
    .clk                ( clk               ),
    .rst                ( rst               ),
    
    //user data interface
    .o_user_rx_data     ( o_user_rx_data    ),
    .o_user_rx_valid    ( o_user_rx_valid   ),
    .o_user_rx_err      ( o_user_rx_err     ),
    
    //uart interface
    .uart_rxd           ( uart_rxd          )
);


endmodule

