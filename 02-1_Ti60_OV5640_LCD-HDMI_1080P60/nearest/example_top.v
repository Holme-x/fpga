`timescale 1ns/1ps

module example_top (
    // External Clock & Reset
    input               clk_24m             , // 24MHz Crystal
    input               clk_25m             , // 25MHz Crystal 
    input               clk_27m             ,
    
    // System Clock
    output              sys_pll_rstn_o      ,         
    input               clk_sys             , // Sys PLL 96MHz 
    input               clk_pixel           , // Sys PLL 74.25MHz
    input               clk_pixel_2x        , // Sys PLL 148.5MHz
    input               clk_pixel_10x       , // Sys PLL 742.5MHz
    input               sys_pll_lock        , // Sys PLL Lock
    
    // DDR Clock
    output              ddr_pll_rstn_o      , 
    input               tdqss_clk           ,            
    input               core_clk            , // DDR PLL 200MHz
    input               tac_clk             ,            
    input               twd_clk             ,            
    input               ddr_pll_lock        , // DDR PLL Lock
    
    // DDR PLL Phase Shift Interface
    output  [  2:0]     shift               ,
    output  [  4:0]     shift_sel           ,
    output              shift_ena           ,
    
    // DDR Interface Ports
    output  [ 15:0]     addr                ,
    output  [  2:0]     ba                  ,
    output              we                  ,
    output              reset               ,
    output              ras                 ,
    output              cas                 ,
    output              odt                 ,
    output              cke                 ,
    output              cs                  ,
    
    // DQ I/O
    input   [ 15:0]     i_dq_hi             ,
    input   [ 15:0]     i_dq_lo             ,
    output  [ 15:0]     o_dq_hi             ,
    output  [ 15:0]     o_dq_lo             ,
    output  [ 15:0]     o_dq_oe             ,
    
    // DM O
    output  [  1:0]     o_dm_hi             ,
    output  [  1:0]     o_dm_lo             ,
    
    // DQS I/O
    input   [  1:0]     i_dqs_hi            ,
    input   [  1:0]     i_dqs_lo            ,
    input   [  1:0]     i_dqs_n_hi          ,
    input   [  1:0]     i_dqs_n_lo          ,
    output  [  1:0]     o_dqs_hi            ,
    output  [  1:0]     o_dqs_lo            ,
    output  [  1:0]     o_dqs_n_hi          ,
    output  [  1:0]     o_dqs_n_lo          ,
    output  [  1:0]     o_dqs_oe            ,
    output  [  1:0]     o_dqs_n_oe          ,
    // CK
    output              clk_p_hi            , 
    output              clk_p_lo            , 
    output              clk_n_hi            , 
    output              clk_n_lo            , 
    
    //Key interface
    input   [  1:0]     i_key_n             ,
    
    // UART Interface
    input               uart_rx_i           ,
    output              uart_tx_o           ,

    // HDMI Interface
    output              hdmi_txc_oe         ,
    output              hdmi_txd0_oe        ,
    output              hdmi_txd1_oe        ,
    output              hdmi_txd2_oe        ,
    
    output              hdmi_txc_rst_o      ,
    output              hdmi_txd0_rst_o     ,
    output              hdmi_txd1_rst_o     ,
    output              hdmi_txd2_rst_o     ,
    
    output  [  9:0]     hdmi_txc_o          ,
    output  [  9:0]     hdmi_txd0_o         ,
    output  [  9:0]     hdmi_txd1_o         ,
    output  [  9:0]     hdmi_txd2_o
);

// =========================================================================================================================================
// System Reset Control 
// =========================================================================================================================================
assign sys_pll_rstn_o   = 1'b1;                 // nrst, Reset whole system when nrst (K2) is pressed. 
assign ddr_pll_rstn_o   = sys_pll_lock; 
wire w_pll_lock = sys_pll_lock && ddr_pll_lock; 
    
// Synchronize Resets. 
reg     rstn_sys = 0, rstn_pixel = 0; 
wire    rst_sys = ~rstn_sys, rst_pixel = ~rstn_pixel;

wire    sys_clk = clk_pixel_2x;
always @(posedge sys_clk or negedge w_pll_lock) begin if(~w_pll_lock) rstn_sys <= 0; else rstn_sys <= 1; end
always @(posedge clk_pixel or negedge w_pll_lock) begin if(~w_pll_lock) rstn_pixel <= 0; else rstn_pixel <= 1; end

reg     sys_rst;
wire    s_ddr_init_done;
always @ (posedge sys_clk or negedge rstn_sys) begin
    if (~rstn_sys) begin
        sys_rst <= 1'b1;
    end else begin
        if (s_ddr_init_done) begin
            sys_rst <= 1'b0;
        end
    end
end

// =========================================================================================================================================
// DDR Configuration   
// =========================================================================================================================================
// CK
assign clk_p_hi = 1'b0;    // DDR3 Clock requires 180 degree shifted. 
assign clk_p_lo = 1'b1;
assign clk_n_hi = 1'b1;
assign clk_n_lo = 1'b0;
    
//AXI interface
wire                AXI_ARREADY         ; // Read Address Channel Ready                
wire                AXI_ARVALID         ; // Read Address Channel Valid                
wire    [ 31:0]     AXI_ARADDR          ; // Read Address Channel Address              
wire    [  7:0]     AXI_ARLEN           ; // Read Address Channel Burst Length code    
wire    [  3:0]     AXI_ARID            ; // Read Address Channel Transaction ID       
wire    [  2:0]     AXI_ARSIZE          ; // Read Address Channel Transfer Size code   
wire    [  1:0]     AXI_ARBURST         ; // Read Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
wire    [  1:0]     AXI_ARLOCK          ; // Read Address Channel Atomic Access Type, Xilinx_IP not supported   
                                    
wire                AXI_RREADY          ; // Read Data Channel Ready            
wire                AXI_RVALID          ; // Read Data Channel Valid            
wire    [127:0]     AXI_RDATA           ; // Read Data Channel Data             
wire                AXI_RLAST           ; // Read Data Channel Last Data Beat       
wire    [  3:0]     AXI_RID             ; // Read Data Channel Transaction ID
wire    [  1:0]     AXI_RRESP           ; // Read Data Channel Response Code

wire                AXI_AWREADY         ; // Write Address Channel Ready                
wire                AXI_AWVALID         ; // Write Address Channel Valid                
wire    [ 31:0]     AXI_AWADDR          ; // Write Address Channel Address              
wire    [  7:0]     AXI_AWLEN           ; // Write Address Channel Burst Length code    
wire    [  3:0]     AXI_AWID            ; // Write Address Channel Transaction ID       
wire    [  2:0]     AXI_AWSIZE          ; // Write Address Channel Transfer Size code   
wire    [  1:0]     AXI_AWBURST         ; // Write Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
wire                AXI_AWLOCK          ; // Write Address Channel Atomic Access Type, Xilinx_IP not supported   
wire    [  3:0]     AXI_AWCACHE         ; // Write Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
wire    [  2:0]     AXI_AWPROT          ; // Write Address Channel Protection Bits      
wire    [  3:0]     AXI_AWQOS           ; // Write Address Channel Quality of Service   

wire                AXI_WREADY          ; // Write Data Channel Ready            
wire                AXI_WVALID          ; // Write Data Channel Valid            
wire    [127:0]     AXI_WDATA           ; // Write Data Channel Data             
wire    [ 15:0]     AXI_WSTRB           ; // Write Data Channel Data Byte Strobes
wire                AXI_WLAST           ; // Write Data Channel Last Data Beat   
wire    [  3:0]     AXI_WID             ; // Write Data Channel ID, for AXI3

wire                AXI_BREADY          ; // Write Response Channel Ready         
wire                AXI_BVALID          ; // Write Response Channel Valid         
wire    [  3:0]     AXI_BID             ; // Write Response Channel Transaction ID
wire    [  1:0]     AXI_BRESP           ; // Write Response Channel Response Code

wire                AXI_AREADY          ;
wire                AXI_AVALID          ;
wire    [ 31:0]     AXI_AADDR           ;   
wire    [  3:0]     AXI_AID             ;   
wire                AXI_ATYPE           ;

assign AXI_ATYPE    = AXI_AWVALID;
assign AXI_AWREADY  = AXI_ATYPE ? AXI_AREADY : 1'b0;
assign AXI_ARREADY  = AXI_ATYPE ? 1'b0 : AXI_AREADY;
assign AXI_AVALID   = AXI_ATYPE ? AXI_AWVALID : AXI_ARVALID;
assign AXI_AADDR    = AXI_ATYPE ? AXI_AWADDR : AXI_ARADDR;
assign AXI_AID      = AXI_ATYPE ? AXI_AWID : AXI_ARID;
     
DdrCtrl u_DDR_CTL (
    .core_clk       ( core_clk          ),
    .tac_clk        ( tac_clk           ),
    .twd_clk        ( twd_clk           ),    
    .tdqss_clk      ( tdqss_clk         ),
                                        
    .reset          ( reset             ),
    .cs             ( cs                ),
    .ras            ( ras               ),
    .cas            ( cas               ),
    .we             ( we                ),
    .cke            ( cke               ),    
    .addr           ( addr              ),
    .ba             ( ba                ),
    .odt            ( odt               ),
                                        
    .o_dm_hi        ( o_dm_hi           ),
    .o_dm_lo        ( o_dm_lo           ),
    .i_dq_hi        ( i_dq_hi           ),
    .i_dq_lo        ( i_dq_lo           ),
    .o_dq_hi        ( o_dq_hi           ),
    .o_dq_lo        ( o_dq_lo           ),
    .o_dq_oe        ( o_dq_oe           ),
    .i_dqs_hi       ( i_dqs_hi          ),
    .i_dqs_lo       ( i_dqs_lo          ),
    .i_dqs_n_hi     ( i_dqs_n_hi        ),
    .i_dqs_n_lo     ( i_dqs_n_lo        ),
    .o_dqs_hi       ( o_dqs_hi          ),
    .o_dqs_lo       ( o_dqs_lo          ),
    .o_dqs_n_hi     ( o_dqs_n_hi        ),
    .o_dqs_n_lo     ( o_dqs_n_lo        ),
    .o_dqs_oe       ( o_dqs_oe          ),
    .o_dqs_n_oe     ( o_dqs_n_oe        ),
    
    .clk            ( sys_clk           ),
    .reset_n        ( rstn_sys          ),
    
    .axi_avalid     ( AXI_AVALID        ),
    .axi_aready     ( AXI_AREADY        ),
    .axi_aaddr      ( AXI_AADDR         ),
    .axi_aid        ( AXI_AID           ),
    .axi_alen       ( AXI_ARLEN         ),
    .axi_asize      ( AXI_ARSIZE        ),
    .axi_aburst     ( AXI_ARBURST       ),
    .axi_alock      ( AXI_ARLOCK        ),
    .axi_atype      ( AXI_ATYPE         ),
                      
    .axi_wid        ( AXI_WID           ),
    .axi_wvalid     ( AXI_WVALID        ),
    .axi_wready     ( AXI_WREADY        ),
    .axi_wdata      ( AXI_WDATA         ),
    .axi_wstrb      ( AXI_WSTRB         ),
    .axi_wlast      ( AXI_WLAST         ),
                      
    .axi_bvalid     ( AXI_BVALID        ),
    .axi_bready     ( AXI_BREADY        ),
    .axi_bid        ( AXI_BID           ),
    .axi_bresp      ( AXI_BRESP         ),
                      
    .axi_rvalid     ( AXI_RVALID        ),
    .axi_rready     ( AXI_RREADY        ),
    .axi_rdata      ( AXI_RDATA         ),
    .axi_rid        ( AXI_RID           ),
    .axi_rresp      ( AXI_RRESP         ),
    .axi_rlast      ( AXI_RLAST         ),
    
    .shift          ( shift             ),
    .shift_sel      (                   ),
    .shift_ena      ( shift_ena         ),
    
    .cal_ena        ( 1'b1              ),
    .cal_done       ( s_ddr_init_done   ),
    .cal_pass       (                   )
);
assign clk_p_hi  = 1'b0;        // DDR3 Clock requires 180 degree shifted. 
assign clk_p_lo  = 1'b1;
assign clk_n_hi  = 1'b1;
assign clk_n_lo  = 1'b0;
assign shift_sel = 5'b00100;    // ddr_tac_clk always use PLLOUT[2]. 

// =========================================================================================================================================
// HDMI Configuration   
// =========================================================================================================================================
// HDMI requires specific timing, thus is not compatible with LCD & LVDS & DSI. Must implement standalone. 
    
assign hdmi_txd0_rst_o = rst_pixel; 
assign hdmi_txd1_rst_o = rst_pixel; 
assign hdmi_txd2_rst_o = rst_pixel; 
assign hdmi_txc_rst_o  = rst_pixel; 

assign hdmi_txd0_oe = 1'b1; 
assign hdmi_txd1_oe = 1'b1; 
assign hdmi_txd2_oe = 1'b1; 
assign hdmi_txc_oe  = 1'b1; 

wire                s_hdmi_vs       ;
wire                s_hdmi_hs       ;
wire                s_hdmi_de       ;
wire    [ 23:0]     s_hdmi_rgb888   ;
wire    [ 15:0]     s_hdmi_rgb565   ;

reg     [ 23:0]     r_pixel_888     ;
wire    [ 23:0]     s_pixel_rgb     ;
wire    [ 10:0]     s_pixel_xpos    ;
wire    [ 10:0]     s_pixel_ypos    ;
wire    [ 10:0]     s_h_disp        ;
wire    [ 10:0]     s_v_disp        ;
wire                s_pixel_req     ;
    
//Digilent HDMI-TX IP Modified by CB elec.
rgb2dvi #(.ENABLE_OSERDES(0)) u_rgb2dvi (
    .oe_i           ( 1             ), // Always enable output
    .bitflip_i      ( 4'b0000       ), // Reverse clock & data lanes. 
    
    .aRst           ( 1'b0          ), 
    .aRst_n         ( rstn_sys      ), 
    
    .PixelClk       ( clk_pixel     ),//pixel clk = 74.25M
    .SerialClk      (               ),//pixel clk *5 = 371.25M
    
    .vid_pVSync     ( s_hdmi_vs     ), 
    .vid_pHSync     ( s_hdmi_hs     ), 
    .vid_pVDE       ( s_hdmi_de     ), 
    .vid_pData      ( s_hdmi_rgb888 ), 
    
    .txc_o          ( hdmi_txc_o    ), 
    .txd0_o         ( hdmi_txd0_o   ), 
    .txd1_o         ( hdmi_txd1_o   ), 
    .txd2_o         ( hdmi_txd2_o   )
);

wire frst, frst_pos;
lcd_driver u_lcd_driver (
    //global clock
    .clk            ( clk_pixel     ),        
    .rst_n          ( ~sys_rst      ), 
    
    .frst           ( frst          ),      
    .frst_pos       ( frst_pos      ),
    
     //lcd interface
    .lcd_dclk       (               ),//(lcd_dclk),
    .lcd_blank      (               ),//lcd_blank
    .lcd_sync       (               ),                
    .lcd_vs         ( s_hdmi_vs     ),
    .lcd_hs         ( s_hdmi_hs     ),        
    .lcd_en         ( s_hdmi_de     ),        
    .lcd_rgb        ( s_hdmi_rgb888 ),
    
    //user interface
    .lcd_request    ( s_pixel_req   ), //Request data 1 cycle ahead.
    .lcd_data       ( r_pixel_888   ),    
    .lcd_xpos       ( s_pixel_xpos  ),    
    .lcd_ypos       ( s_pixel_ypos  )
);
always @ (posedge clk_pixel) begin
    r_pixel_888 <= s_pixel_rgb;
end

// =========================================================================================================================================
// User Signal  
// =========================================================================================================================================
//coe generate
reg                 r_init_set          ;
reg     [  3:0]     r_frst_cnt          ;
reg     [ 10:0]     r_fix_rate          ;
reg     [ 10:0]     r_rate_coe          ;
reg                 r_fix_vld           ;
reg                 r_coe_vld           ;
wire                s_coe_vld           ;

//KEY_CHECK instance
wire                s_big_n             ;
wire                s_small_n           ;

//UART_IF instance
wire    [  7:0]     s_user_rx_data      ;
wire                s_user_rx_valid     ;

//IMG_RAM_TOP instance
wire    [ 10:0]     s_rate_coe          ;
wire    [ 15:0]     s_roi_bw            ;
wire    [ 15:0]     s_roi_ew            ;

wire    [ 14:0]     s_fix_h             ;
wire                s_fix_h_vld         ;
wire                s_fix_h_empty       ;
wire                s_fix_h_re          ;

wire    [  2:0]     s_8row_id           ;
wire    [  8:0]     s_8row_h            ;
wire                s_8row_empty        ;
wire                s_8row_re           ;

wire    [ 11:0]     s_ch0_raddr         ;
wire    [ 11:0]     s_ch1_raddr         ;
wire                s_bram_re           ;
wire    [ 31:0]     s_ch0_rdata         ;
wire    [ 31:0]     s_ch1_rdata         ;
wire                s_bram_rvld         ;

// =========================================================================================================================================
// User Logic  
// =========================================================================================================================================
//coe generate
always @ (posedge sys_clk) begin
    if (sys_rst) begin
        r_init_set  <= 1'b1;
        r_frst_cnt  <= 4'd0;
        r_fix_rate  <= 11'd32;      //Ĭ  32       Ϊ48
        r_rate_coe  <= 11'd0;
        r_fix_vld   <= 1'b0;
        r_coe_vld   <= 1'b0;
    end else begin
        if (frst_pos) begin
            r_init_set  <= 1'b0;
        end
        if (~s_big_n | ~s_small_n) begin
            if (frst_pos) begin
                if (r_frst_cnt == 'd9) begin
                    r_frst_cnt  <= 'd0;
                end else begin
                    r_frst_cnt  <= r_frst_cnt + 1'b1;
                end
            end
        end else begin
            r_frst_cnt  <= 'd0;
        end
        if (s_coe_vld) begin
            if (~s_big_n) begin
                if (r_fix_rate < 'd71) begin
                    r_fix_rate  <= r_fix_rate + 'd1;
                end
            end else if (~s_small_n) begin
                if (r_fix_rate > 'd1) begin
                    r_fix_rate  <= r_fix_rate - 'd1;
                end
            end
        end
        r_rate_coe  <= 1024 / r_fix_rate;
        r_fix_vld   <= s_coe_vld | (frst_pos & r_init_set);
        r_coe_vld   <= r_fix_vld;
    end
end
assign s_coe_vld = (~s_big_n | ~s_small_n) & frst_pos & (r_frst_cnt == 'd9);
 
 wire 				o_uart_tx_done;
//KEY_CHECK instance
//KEY_CHECK # 
//(
//    .CLK_FRAC   ( 148           )//Unit: MHz
//) u_KEY_BIG (
//    .clk        ( sys_clk       ),
//    .rst        ( sys_rst       ),
//    
//    .i_key      ( i_key_n[0]    ), //FPGA port
//    
//    .o_key_pos  (               ),
//    .o_key_neg  (               ),
//    .o_key      ( s_big_n       )
//);
//
//KEY_CHECK # (
//    .CLK_FRAC   ( 148           )//Unit: MHz
//) u_KEY_SMALL (
//    .clk        ( sys_clk       ),
//    .rst        ( sys_rst       ),
//    
//    .i_key      ( i_key_n[1]    ), //FPGA port
//    
//    .o_key_pos  (               ),
//    .o_key_neg  (               ),
//    .o_key      ( s_small_n     )
//);

key_all_ctrl #(
    .CLK_FRAC      (148			    )  // Unit: MHz
) key_all_ctrl_inist(
    .clk           (	    sys_clk			) ,
    .rst           (		sys_rst		) ,
    .key_small     (	    i_key_n[1] 			) ,
    .key_big       (		i_key_n[0] 		) ,
    .s_small_n     (		s_small_n		) ,
    .s_big_n       (		s_big_n		) ,
    .s_timer_done  (				),  //   ʾ  ʱ Ƿ    
	.o_uart_tx_done(o_uart_tx_done  )
);

//UART_IF instance
UART_IF # (
    .CLK_FRAC           ( 1488              ), //unit: 100KHz
    .BAUD               ( 500000            ),
    .DATA_WIDTH         ( 8                 ),
    .CHECK_BIT          ( "none"            ), //"even", "odd", "mask", "space", "none"
    .END_WIDTH          ( 1                 )  //end bit width
) u_UART_IF (
    //global clock & reset
    .clk                ( sys_clk           ),
    .rst                ( sys_rst           ),
    
    //user data interface
    .o_user_tx_ready    (                   ),
    .i_user_tx_data     ( 'd0               ),
    .i_user_tx_valid    ( 1'b0              ),
    .o_user_rx_data     ( s_user_rx_data    ),
    .o_user_rx_valid    ( s_user_rx_valid   ),
    .o_user_rx_err      (                   ),
    
    //UART interface
    .uart_txd           ( uart_tx_o         ),
    .uart_rxd           ( uart_rx_i         )
);


//UART_DATA_WCTL instance
UART_DATA_WCTL u_UART_DATA_WCTL (
    //Clock & Reset
    .clk                ( sys_clk           ),
    .rst                ( sys_rst           ),
    
    //uart input
    .i_user_rx_data     ( s_user_rx_data    ),
    .i_user_rx_valid    ( s_user_rx_valid   ),
    
    //AXI interface
    .AXI_AWREADY        ( AXI_AWREADY       ), // Write Address Channel Ready                
    .AXI_AWVALID        ( AXI_AWVALID       ), // Write Address Channel Valid                
    .AXI_AWADDR         ( AXI_AWADDR        ), // Write Address Channel Address              
    .AXI_AWLEN          ( AXI_AWLEN         ), // Write Address Channel Burst Length code    
    .AXI_AWID           ( AXI_AWID          ), // Write Address Channel Transaction ID       
    .AXI_AWSIZE         ( AXI_AWSIZE        ), // Write Address Channel Transfer Size code   
    .AXI_AWBURST        ( AXI_AWBURST       ), // Write Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
    .AXI_AWLOCK         ( AXI_AWLOCK        ), // Write Address Channel Atomic Access Type, Xilinx_IP not supported   
    .AXI_AWCACHE        ( AXI_AWCACHE       ), // Write Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
    .AXI_AWPROT         ( AXI_AWPROT        ), // Write Address Channel Protection Bits      
    .AXI_AWQOS          ( AXI_AWQOS         ), // Write Address Channel Quality of Service   
    
    .AXI_WREADY         ( AXI_WREADY        ), // Write Data Channel Ready            
    .AXI_WVALID         ( AXI_WVALID        ), // Write Data Channel Valid            
    .AXI_WDATA          ( AXI_WDATA         ), // Write Data Channel Data             
    .AXI_WSTRB          ( AXI_WSTRB         ), // Write Data Channel Data Byte Strobes
    .AXI_WLAST          ( AXI_WLAST         ), // Write Data Channel Last Data Beat   
    .AXI_WID            ( AXI_WID           ), // Write Data Channel ID, for AXI3
    
    .AXI_BREADY         ( AXI_BREADY        ), // Write Response Channel Ready         
    .AXI_BVALID         ( AXI_BVALID        ), // Write Response Channel Valid         
    .AXI_BID            ( AXI_BID           ), // Write Response Channel Transaction ID
    .AXI_BRESP          ( AXI_BRESP         ),  // Write Response Channel Response Code
	.o_uart_tx_done     (o_uart_tx_done     )
);

//UART_DATA_WCTL u_UART_DATA_WCTL (
//    //Clock & Reset
//    .clk                ( sys_clk           ),
//    .rst                ( sys_rst           ),
//    
//    //uart input
//    .i_user_rx_data     ( s_user_rx_data    ),
//    .i_user_rx_valid    ( s_user_rx_valid   ),
//    
//    //AXI interface
//    .axi_awready,   ( AXI_AWREADY       ), // Write Address Channel Ready                
//    .axi_awvalid,   ( AXI_AWVALID       ), // Write Address Channel Valid                
//    .axi_awaddr,   ( AXI_AWADDR        ), // Write Address Channel Address              
//    .axi_awlen ,   ( AXI_AWLEN         ), // Write Address Channel Burst Length code    
//    .axi_awid  ,   ( AXI_AWID          ), // Write Address Channel Transaction ID       
//    .axi_awsize,   ( AXI_AWSIZE        ), // Write Address Channel Transfer Size code   
//    .axi_awburst,   ( AXI_AWBURST       ), // Write Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
//    .axi_awlock,   ( AXI_AWLOCK        ), // Write Address Channel Atomic Access Type, Xilinx_IP not supported   
//    .axi_awcache,   ( AXI_AWCACHE       ), // Write Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
//    .axi_awprot,   ( AXI_AWPROT        ), // Write Address Channel Protection Bits      
//    .axi_awqos,   ( AXI_AWQOS         ), // Write Address Channel Quality of Service   
//     
//    .axi_wready,   ( AXI_WREADY        ), // Write Data Channel Ready            
//    .axi_wvalid,   ( AXI_WVALID        ), // Write Data Channel Valid            
//    .axi_wdata,   ( AXI_WDATA         ), // Write Data Channel Data             
//    .axi_wstrb,   ( AXI_WSTRB         ), // Write Data Channel Data Byte Strobes
//    .axi_wlast,   ( AXI_WLAST         ), // Write Data Channel Last Data Beat   
//    .axi_wid,    ( AXI_WID           ), // Write Data Channel ID, for AXI3
//     
//    .axi_bready,   ( AXI_BREADY        ), // Write Response Channel Ready         
//    .axi_bvalid,   ( AXI_BVALID        ), // Write Response Channel Valid         
//    .axi_bid,     ( AXI_BID           ), // Write Response Channel Transaction ID
//    .axi_bresp,   ( AXI_BRESP         ),  // Write Response Channel Response Code
//	.uart_tx_done   (o_uart_tx_done     )
//);
//IMG_RAM_TOP instance
IMG_RAM_TOP u_IMG_RAM_TOP (
    //clock & reset
    .clk                ( sys_clk           ),
    .rst                ( sys_rst           ),
    .frst               ( frst              ),
    
    //rate_coe interface
    .i_fix_rate         ( r_fix_rate        ),
    .i_rate_coe         ( r_rate_coe        ),
    .i_rate_coe_vld     ( r_coe_vld         ),
    
    //resize param
    .o_rate_coe         ( s_rate_coe        ),
    .o_roi_bw           ( s_roi_bw          ),
    .o_roi_ew           ( s_roi_ew          ),
    
    //˫   Բ ֵ  ȡ     img  h    
    .o_fix_h            ( s_fix_h           ), //{10-int,5-frac}
    .o_fix_h_vld        ( s_fix_h_vld       ),
    .o_fix_h_empty      ( s_fix_h_empty     ),
    .i_fix_h_re         ( s_fix_h_re        ),
    
    //ʹ  ˫   Բ ֵ  Ҫ õ   ͼ   кŲ ѯ  Ӧ8  img ռ   к 
    .o_8row_id          ( s_8row_id         ),
    .o_8row_h           ( s_8row_h          ),
    .o_8row_empty       ( s_8row_empty      ),
    .i_8row_re          ( s_8row_re         ),
    
    //BRAM 2 channel read interface
    .i_ch0_raddr        ( s_ch0_raddr       ), //{2-row_id 0 2 4 6, 10-w}, w only use 0~639
    .i_ch1_raddr        ( s_ch1_raddr       ), //{2-row_id 1 3 5 7, 10-w}, w only use 0~639
    .i_bram_re          ( s_bram_re         ),
    .o_ch0_rdata        ( s_ch0_rdata       ),
    .o_ch1_rdata        ( s_ch1_rdata       ),
    .o_bram_rvld        ( s_bram_rvld       ),
    
    //AXI read interface                    
    .AXI_ARREADY        ( AXI_ARREADY       ), // Read Address Channel Ready                
    .AXI_ARVALID        ( AXI_ARVALID       ), // Read Address Channel Valid                
    .AXI_ARADDR         ( AXI_ARADDR        ), // Read Address Channel Address              
    .AXI_ARLEN          ( AXI_ARLEN         ), // Read Address Channel Burst Length code    
    .AXI_ARID           ( AXI_ARID          ), // Read Address Channel Transaction ID       
    .AXI_ARSIZE         ( AXI_ARSIZE        ), // Read Address Channel Transfer Size code   
    .AXI_ARBURST        ( AXI_ARBURST       ), // Read Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
    .AXI_ARLOCK         ( AXI_ARLOCK        ), // Read Address Channel Atomic Access Type, Xilinx_IP not supported   
    .AXI_RREADY         ( AXI_RREADY        ), // Read Data Channel Ready            
    .AXI_RVALID         ( AXI_RVALID        ), // Read Data Channel Valid            
    .AXI_RDATA          ( AXI_RDATA         ), // Read Data Channel Data             
    .AXI_RLAST          ( AXI_RLAST         ), // Read Data Channel Last Data Beat       
    .AXI_RID            ( AXI_RID           ), // Read Data Channel Transaction ID
    .AXI_RRESP          ( AXI_RRESP         )  // Read Data Channel Response Code
);

//HDMI_IMG_GEN instance
HDMI_IMAGE u_HDMI_IMAGE (
    //clock & reset
    .clk                ( sys_clk           ),
    .frst               ( frst              ),
    
    //resize param
    .i_rate_coe         ( s_rate_coe        ),
    .i_roi_bw           ( s_roi_bw          ),
    .i_roi_ew           ( s_roi_ew          ),
    
    .i_fix_h            ( s_fix_h           ), //{10-int,5-frac}
    .i_fix_h_vld        ( s_fix_h_vld       ),
    .i_fix_h_empty      ( s_fix_h_empty     ),
    .o_fix_h_re         ( s_fix_h_re        ),
    
    .i_8row_id          ( s_8row_id         ),
    .i_8row_h           ( s_8row_h          ),
    .i_8row_empty       ( s_8row_empty      ),
    .o_8row_re          ( s_8row_re         ),
    
    //BRAM 2 channel read interface
    .o_ch0_raddr        ( s_ch0_raddr       ), //{2-row_id 0 2 4 6, 10-w}, w only use 0~639
    .o_ch1_raddr        ( s_ch1_raddr       ), //{2-row_id 1 3 5 7, 10-w}, w only use 0~639
    .o_bram_re          ( s_bram_re         ),
    .i_ch0_rdata        ( s_ch0_rdata       ),
    .i_ch1_rdata        ( s_ch1_rdata       ),
    .i_bram_rvld        ( s_bram_rvld       ),
    
    //hdmi image interface             
    .pixel_clk          ( clk_pixel         ),
    .o_pixel_rgb        ( s_pixel_rgb       ),
    .i_pixel_re         ( s_pixel_req       )
);
    
endmodule


