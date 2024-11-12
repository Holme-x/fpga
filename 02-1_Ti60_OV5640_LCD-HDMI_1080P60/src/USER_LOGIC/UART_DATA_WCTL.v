`define _FREQ_SYS_CLK   148500000

module UART_DATA_WCTL (
    //Clock & Reset
    input               clk                 ,
    input               rst                 ,
    
    //uart input
    input   [  7:0]     i_user_rx_data      ,
    input               i_user_rx_valid     ,
    
    //AXI interface
    input               AXI_AWREADY         , // Write Address Channel Ready                
    output              AXI_AWVALID         , // Write Address Channel Valid                
    output  [ 31:0]     AXI_AWADDR          , // Write Address Channel Address              
    output  [  7:0]     AXI_AWLEN           , // Write Address Channel Burst Length code    
    output  [  3:0]     AXI_AWID            , // Write Address Channel Transaction ID       
    output  [  2:0]     AXI_AWSIZE          , // Write Address Channel Transfer Size code   
    output  [  1:0]     AXI_AWBURST         , // Write Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
    output              AXI_AWLOCK          , // Write Address Channel Atomic Access Type, Xilinx_IP not supported   
    output  [  3:0]     AXI_AWCACHE         , // Write Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
    output  [  2:0]     AXI_AWPROT          , // Write Address Channel Protection Bits      
    output  [  3:0]     AXI_AWQOS           , // Write Address Channel Quality of Service   
    
    input               AXI_WREADY          , // Write Data Channel Ready            
    output              AXI_WVALID          , // Write Data Channel Valid            
    output  [127:0]     AXI_WDATA           , // Write Data Channel Data             
    output  [ 15:0]     AXI_WSTRB           , // Write Data Channel Data Byte Strobes
    output              AXI_WLAST           , // Write Data Channel Last Data Beat   
    output  [  3:0]     AXI_WID             , // Write Data Channel ID, for AXI3
    
    output              AXI_BREADY          , // Write Response Channel Ready         
    input               AXI_BVALID          , // Write Response Channel Valid         
    input   [  3:0]     AXI_BID             , // Write Response Channel Transaction ID
    input   [  1:0]     AXI_BRESP           , // Write Response Channel Response Code
    output    reg       o_uart_tx_done        // UART transmission complete signal
);


// =========================================================================================================================================

// Signal
// =========================================================================================================================================

//wait counter
reg                 r_wait_en       ;
reg     [ 27:0]     r_wait_cnt      ;
wire                s_wait_end      ;

//axi write generate
reg     [  2:0]     r_rgb_flag      ;   
reg     [ 23:0]     r_i_rgb         ;
reg                 r_i_rgb_vld     ; 

//AXI_WBUF instance
wire                s_wbuf_re       ;
wire    [  8:0]     s_wbuf_cnt      ;
wire                s_wbuf_vld      ;

//axi write task generate
reg     [  1:0]     r_wbuf_rready   ;
reg     [ 31:0]     r_axi_awaddr    ;
reg     [  4:0]     r_axi_wlen      ;
 
// =========================================================================================================================================

// Output generate
// =========================================================================================================================================

assign AXI_AWVALID  = r_wbuf_rready[0];
assign AXI_AWADDR   = r_axi_awaddr;
assign AXI_AWLEN    = 8'd31;
assign AXI_AWID     = 4'd0;
assign AXI_AWSIZE   = 3'd4;
assign AXI_AWBURST  = 2'b01;
assign AXI_AWLOCK   = 1'b0;
assign AXI_AWCACHE  = 4'h0;
assign AXI_AWPROT   = 3'b000;
assign AXI_AWQOS    = 4'h0;

assign AXI_WVALID   = r_wbuf_rready[1];
assign AXI_WSTRB    = 16'hFFFF;
assign AXI_WLAST    = ~|r_axi_wlen;
assign AXI_WID      = 4'd0;

assign AXI_BREADY   = 1'b1;

// =========================================================================================================================================

// Logic
// =========================================================================================================================================

//wait counter
always @ (posedge clk) begin
    if (rst) begin
        r_wait_en       <= 1'b0;
        r_wait_cnt      <= 28'd0;
    end else begin
        if (i_user_rx_valid) begin
            r_wait_en   <= 1'b1;
        end else if (s_wait_end) begin
            r_wait_en   <= 1'b0;
        end
        if (i_user_rx_valid) begin
            r_wait_cnt  <= 'd0;
        end else if (r_wait_en) begin
            r_wait_cnt  <= r_wait_cnt + 1'b1;
        end else begin
            r_wait_cnt  <= 'd0;
        end
    end
end
assign s_wait_end = (r_wait_cnt == `_FREQ_SYS_CLK/10);   //wait 0.1 second

//axi write generate
always @ (posedge clk) begin
    if (rst) begin
        r_rgb_flag  <= 3'd1;
    end else begin
        if (i_user_rx_valid) begin 
            r_rgb_flag  	<= {r_rgb_flag[1:0], r_rgb_flag[2]};
            r_i_rgb    		<= {r_i_rgb[15:0], i_user_rx_data};
        end
    end
    r_i_rgb_vld <= i_user_rx_valid & r_rgb_flag[2];
end

//AXI_WBUF instance
SYNC_BBUF_32x256_128x64 u_WBUF (
    .clk_i          ( clk                   ),
    .a_rst_i        ( rst | s_wait_end      ),
    .rst_busy       (                       ),
    .wdata          ( {8'd0,r_i_rgb}        ),
    .wr_en_i        ( r_i_rgb_vld           ),
    .rdata          ( AXI_WDATA             ),
    .rd_en_i        ( s_wbuf_re             ),
    .full_o         (                       ),
    .empty_o        (                       ),
    .wr_datacount_o ( s_wbuf_cnt            ),
    .rd_datacount_o (                       )
);
assign s_wbuf_re    = AXI_WREADY & AXI_WVALID;
assign s_wbuf_vld   = s_wbuf_cnt[7];            // >= 128

//axi write task generate
always @ (posedge clk) begin
    if (rst | s_wait_end) begin
        r_wbuf_rready   <= 2'd0;
        r_axi_awaddr    <= 32'd0;
        r_axi_wlen      <= 5'd0;
    end else begin
        if (~|r_wbuf_rready & s_wbuf_vld) begin
            r_wbuf_rready   <= 2'd1;
        end else if (AXI_AWREADY & AXI_AWVALID) begin
            r_wbuf_rready   <= 2'd2;
        end else if (s_wbuf_re & AXI_WLAST) begin
            r_wbuf_rready   <= 2'd0;
        end
        if (AXI_AWREADY & AXI_AWVALID) begin
            r_axi_awaddr    <= r_axi_awaddr + 'd512;    // 16*32 = 512B
        end
        if (~|r_wbuf_rready & s_wbuf_vld) begin
            r_axi_wlen  <= 5'd31;
        end else if (s_wbuf_re) begin
            r_axi_wlen  <= r_axi_wlen - 1'b1;
        end
    end
end

// UART transmission complete signal generation
always @ (posedge clk) begin
    if (rst) begin
        o_uart_tx_done <= 1'b0;
    end 
	else if (i_user_rx_data ==8'HFF) begin
			 o_uart_tx_done <= 1'b1;
    end 
	else begin
			 o_uart_tx_done <= 1'b0;
    end
end

endmodule

//`define _FREQ_SYS_CLK 148500000
//
//module UART_DATA_WCTL (
//    // Clock & Reset
//    input               clk,
//    input               rst,
//    
//    // UART input
//    input   [7:0]      i_user_rx_data,
//    input               i_user_rx_valid,
//    
//    // AXI interface
//    input               AXI_AWREADY, // Write Address Channel Ready                
//    output              AXI_AWVALID, // Write Address Channel Valid                
//    output  [31:0]      AXI_AWADDR,  // Write Address Channel Address              
//    output  [7:0]       AXI_AWLEN,   // Write Address Channel Burst Length code    
//    output  [3:0]       AXI_AWID,    // Write Address Channel Transaction ID       
//    output  [2:0]       AXI_AWSIZE,  // Write Address Channel Transfer Size code   
//    output  [1:0]       AXI_AWBURST, // Write Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
//    output              AXI_AWLOCK,  // Write Address Channel Atomic Access Type, Xilinx_IP not supported   
//    output  [3:0]       AXI_AWCACHE, // Write Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
//    output  [2:0]       AXI_AWPROT,  // Write Address Channel Protection Bits      
//    output  [3:0]       AXI_AWQOS,   // Write Address Channel Quality of Service   
//    
//    input               AXI_WREADY,  // Write Data Channel Ready            
//    output              AXI_WVALID,  // Write Data Channel Valid            
//    output  [127:0]     AXI_WDATA,   // Write Data Channel Data             
//    output  [15:0]      AXI_WSTRB,   // Write Data Channel Data Byte Strobes
//    output              AXI_WLAST,   // Write Data Channel Last Data Beat   
//    output  [3:0]       AXI_WID,     // Write Data Channel ID, for AXI3
//    
//    output              AXI_BREADY,  // Write Response Channel Ready         
//    input               AXI_BVALID,  // Write Response Channel Valid         
//    input   [3:0]        AXI_BID,     // Write Response Channel Transaction ID
//    input   [1:0]        AXI_BRESP,   // Write Response Channel Response Code
//    output    reg       o_uart_tx_done // UART transmission complete signal
//);
//
//// FIFO interface
//wire fifo_full;
//wire fifo_empty;
//wire [10:0] fifo_wr_datacount;
//wire [6:0] fifo_rd_datacount;
//
//// FIFO instance
//FIFO_DATA_RX fifo_inst (
//    .full_o(fifo_full),
//    .empty_o(fifo_empty),
//    .clk_i(clk),
//    .wr_en_i(i_user_rx_valid),
//    .rd_en_i(AXI_WREADY & AXI_WVALID),
//    .wdata(i_user_rx_data),
//    .wr_datacount_o(fifo_wr_datacount),
//    .rst_busy(),
//    .rdata(AXI_WDATA),
//    .rd_datacount_o(fifo_rd_datacount),
//    .a_rst_i(rst)
//);
//
//// AXI write address channel control
//reg [31:0] axi_awaddr_reg;
//reg [7:0] axi_awlen_reg;
//reg axi_awvalid_reg;
//
//always @(posedge clk) begin
//    if (rst) begin
//        AXI_AWVALID <= 1'b0;
//        axi_awaddr_reg <= 32'd0;
//        axi_awlen_reg <= 8'd0;
//    end else if (~fifo_empty && (fifo_rd_datacount == 7'd128)) begin
//        AXI_AWVALID <= 1'b1;
//        axi_awaddr_reg <= axi_awaddr_reg + 32'd128; // Increment address by 128 bytes
//        axi_awlen_reg <= 8'd127; // Set burst length to 128
//    end else if (AXI_AWREADY && AXI_AWVALID) begin
//        AXI_AWVALID <= 1'b0;
//    end
//end
//
//assign AXI_AWADDR = axi_awaddr_reg;
//assign AXI_AWLEN = axi_awlen_reg;
//// Other AXI write address channel signals remain constant
//assign AXI_AWID = 4'd0;
//assign AXI_AWSIZE = 3'd7; // 128-bit transfer
//assign AXI_AWBURST = 2'b01; // INCR burst
//assign AXI_AWLOCK = 1'b0; // No lock
//assign AXI_AWCACHE = 4'h0;
//assign AXI_AWPROT = 3'b000;
//assign AXI_AWQOS = 4'h0;
//
//// AXI write data channel control
//reg [127:0] axi_wdata_reg;
//reg [15:0] axi_wstrb_reg;
//reg axi_wvalid_reg;
//reg axi_wlast_reg;
//
//always @(posedge clk) begin
//    if (rst) begin
//        AXI_WVALID <= 1'b0;
//        axi_wdata_reg <= 128'd0;
//        axi_wstrb_reg <= 16'hFFFF;
//        axi_wlast_reg <= 1'b0;
//    end else if (AXI_WREADY && ~fifo_empty) begin
//        AXI_WVALID <= 1'b1;
//        axi_wdata_reg <= fifo_inst.rdata; // Read data from FIFO
//        axi_wstrb_reg <= 16'hFFFF; // All bytes are valid
//        if (fifo_rd_datacount == 7'd127) begin
//            axi_wlast_reg <= 1'b1; // Last data beat
//        end
//    end else if (AXI_WREADY && axi_wlast_reg) begin
//        AXI_WVALID <= 1'b0;
//    end
//end
//
//assign AXI_WDATA = axi_wdata_reg;
//assign AXI_WSTRB = axi_wstrb_reg;
//assign AXI_WLAST = axi_wlast_reg;
//assign AXI_WID = 4'd0;
//
//// AXI write response channel control
//assign AXI_BREADY = 1'b1;
//
//// UART transmission complete signal generation
//always @(posedge clk) begin
//    if (rst) begin
//        o_uart_tx_done <= 1'b0;
//    end else if (fifo_empty && AXI_BVALID) begin
//        o_uart_tx_done <= 1'b1;
//    end else begin
//        o_uart_tx_done <= 1'b0;
//    end
//end
//
//endmodule