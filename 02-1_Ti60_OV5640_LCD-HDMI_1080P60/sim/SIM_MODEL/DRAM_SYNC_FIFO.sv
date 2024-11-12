//////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Kikyoko
// https://github.com/Kikyoko
// 
// Module   : DRAM_SYNC_FIFO
// Device   : Xilinx
// Author   : Kikyoko
// Contact  : Kikyoko@outlook.com
// Date     : 2021/2/12 12:59:51
// Revision : 1.00 - Simulation correct
//
// Description  : Sync-fifo use DRAM
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

module DRAM_SYNC_FIFO # (
    parameter               WIDTH       =  6    ,
    parameter               PF_VALUE    =  28   
) (
    input                   clk                 ,
    input                   rst                 ,
    input   [WIDTH-1:0]     din                 ,
    input                   wr_en               ,
    input                   rd_en               ,
    output  [WIDTH-1:0]     dout                ,
    output                  valid               ,
    output                  prog_full           ,
    output                  full                ,
    output                  empty    
);

`ifdef _DEVICE_A7
    localparam BASE_WIDTH   = 6;
`elsif _DEVICE_ULTRA
    localparam BASE_WIDTH   = 14;     
`else
    localparam BASE_WIDTH   = WIDTH;   
    logic   [WIDTH-1:0]     r_dram[32];  
`endif

localparam DRAM_WIDTH   = ((WIDTH-1)/BASE_WIDTH+1)*BASE_WIDTH;
    
// =========================================================================================================================================
// Signal
// =========================================================================================================================================
logic   [DRAM_WIDTH-1:0]    s_din;
logic   [DRAM_WIDTH-1:0]    s_dout;

logic   [  5:0]     r_dram_waddr;
logic   [  5:0]     r_dram_raddr;
logic   [  4:0]     s_dram_wcnt ;

logic               s_dram_we   ;
logic               s_dram_re   ;
    
// =========================================================================================================================================
// Output generate
// =========================================================================================================================================
assign dout         = s_dout[WIDTH-1:0];
assign valid        = ~empty;
assign prog_full    = (s_dram_wcnt >= PF_VALUE);
assign full         = (r_dram_waddr[5] != r_dram_raddr[5]) & ~|s_dram_wcnt;
assign empty        = (r_dram_waddr == r_dram_raddr);

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//DRAM address generate
always @ (posedge clk) begin
    if (rst) begin
        r_dram_waddr    <= 6'd0;
        r_dram_raddr    <= 6'd0;
    end else begin
        r_dram_waddr    <= r_dram_waddr + s_dram_we;
        r_dram_raddr    <= r_dram_raddr + s_dram_re;
    end
end
assign s_dram_wcnt  = r_dram_waddr[4:0] - r_dram_raddr[4:0];
assign s_dram_we    = wr_en & ~full;
assign s_dram_re    = rd_en & ~empty;

//DRAM interface
genvar i;
generate
    if (DRAM_WIDTH > WIDTH) begin
        assign s_din = {{(DRAM_WIDTH-WIDTH){1'b0}},din};
    end else begin
        assign s_din = din;
    end
    
    for (i=0; i<DRAM_WIDTH/BASE_WIDTH; i=i+1) begin : DRAM_GEN
        `ifdef _DEVICE_A7
            SYNC_DRAM_6x32_6x32 u_DRAM (            //Non Registered
                .clk        ( clk                               ),
                .we         ( s_dram_we                         ),
                .a          ( r_dram_waddr[4:0]                 ),
                .d          ( s_din[i*BASE_WIDTH+:BASE_WIDTH]   ),
                .dpra       ( r_dram_raddr[4:0]                 ),
                .dpo        ( s_dout[i*BASE_WIDTH+:BASE_WIDTH]  )
            );
        `elsif _DEVICE_ULTRA
            SYNC_DRAM_14x32_14x32 u_DRAM (            //Non Registered
                .clk        ( clk                               ),
                .we         ( s_dram_we                         ),
                .a          ( r_dram_waddr[4:0]                 ),
                .d          ( s_din[i*BASE_WIDTH+:BASE_WIDTH]   ),
                .dpra       ( r_dram_raddr[4:0]                 ),
                .dpo        ( s_dout[i*BASE_WIDTH+:BASE_WIDTH]  )
            );
        `else
            always @ (posedge clk) begin
                if (s_dram_we) begin
                    r_dram[r_dram_waddr[4:0]] <= din;
                end
            end
            assign s_dout = r_dram[r_dram_raddr[4:0]];
        `endif
    end
endgenerate


endmodule