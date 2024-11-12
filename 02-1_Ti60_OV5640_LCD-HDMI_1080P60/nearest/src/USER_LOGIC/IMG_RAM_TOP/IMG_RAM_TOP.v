
module IMG_RAM_TOP (
    //clock & reset
    input               clk             ,
    input               rst             ,
    input               frst            ,
    
    //rate_coe interface
    input   [ 10:0]     i_fix_rate      ,
    input   [ 10:0]     i_rate_coe      , //fix(32*32/fix_rate)
    input               i_rate_coe_vld  ,
    
    //resize param
    output  [ 10:0]     o_rate_coe      ,
    output  [ 15:0]     o_roi_bw        ,
    output  [ 15:0]     o_roi_ew        ,
    
    //双线性插值读取定点的img的h坐标
    output  [ 14:0]     o_fix_h         , //{10-int,5-frac}
    output              o_fix_h_vld     ,
    output              o_fix_h_empty   ,
    input               i_fix_h_re      ,
    
    //使用双线性插值需要用到的图像行号查询对应8行img空间的行号
    output  [  2:0]     o_8row_id       ,
    output  [  8:0]     o_8row_h        ,
    output              o_8row_empty    ,
    input               i_8row_re       ,
    
    //BRAM 2 channel read interface
    input   [ 11:0]     i_ch0_raddr     , //{2-row_id 0 2 4 6, 10-w}, w only use 0~639
    input   [ 11:0]     i_ch1_raddr     , //{2-row_id 1 3 5 7, 10-w}, w only use 0~639
    input               i_bram_re       ,
    output  [ 31:0]     o_ch0_rdata     ,
    output  [ 31:0]     o_ch1_rdata     ,
    output              o_bram_rvld     ,
    
    //AXI read interface                    
    input               AXI_ARREADY     , // Read Address Channel Ready                
    output              AXI_ARVALID     , // Read Address Channel Valid                
    output  [ 31:0]     AXI_ARADDR      , // Read Address Channel Address              
    output  [  7:0]     AXI_ARLEN       , // Read Address Channel Burst Length code    
    output  [  3:0]     AXI_ARID        , // Read Address Channel Transaction ID       
    output  [  2:0]     AXI_ARSIZE      , // Read Address Channel Transfer Size code   
    output  [  1:0]     AXI_ARBURST     , // Read Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
    output  [  1:0]     AXI_ARLOCK      , // Read Address Channel Atomic Access Type, Xilinx_IP not supported   
                                        
    output              AXI_RREADY      , // Read Data Channel Ready            
    input               AXI_RVALID      , // Read Data Channel Valid            
    input   [127:0]     AXI_RDATA       , // Read Data Channel Data             
    input               AXI_RLAST       , // Read Data Channel Last Data Beat       
    input   [  3:0]     AXI_RID         , // Read Data Channel Transaction ID
    input   [  1:0]     AXI_RRESP         // Read Data Channel Response Code
);

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
//IMG_H_RAM instance 
wire    [ 10:0]     s_h_ram_raddr       ;
wire                s_h_ram_re          ;
wire                s_org_h_vld         ;
wire    [ 14:0]     s_org_h             ;
wire                s_h_ram_vld         ;

//IMG_RCTL instance
wire                s_read_req_ready    ;
wire    [  8:0]     s_read_req_h        ;
wire                s_read_req_vld      ;

//BRAM write interface
wire    [  2:0]     s_bram_wcnt         ; //8 rows
wire    [  7:0]     s_bram_waddr        ; //only use (0~639)/4 = 0~159
wire    [127:0]     s_bram_wdata        ;
wire                s_bram_we           ;

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//IMG_H_RAM instance
IMG_H_RAM u_IMG_H_RAM (
    //clock & reset
    .clk                ( clk               ),
    .rst                ( rst               ),
    
    //rate_coe interface
    .i_fix_rate         ( i_fix_rate        ),
    .i_rate_coe         ( i_rate_coe        ), //fix(32*32/fix_rate)
    .i_rate_coe_vld     ( i_rate_coe_vld    ),
    
    //resize param
    .o_rate_coe         ( o_rate_coe        ),
    .o_roi_bw           ( o_roi_bw          ),
    .o_roi_ew           ( o_roi_ew          ),
    
    //H_RAM read interface
    .i_h_ram_raddr      ( s_h_ram_raddr     ),
    .i_h_ram_re         ( s_h_ram_re        ),
    .o_org_h_vld        ( s_org_h_vld       ),
    .o_org_h            ( s_org_h           ), //{10-int,5-frac}
    .o_h_ram_vld        ( s_h_ram_vld       )
);

//IMG_RCTL instance
IMG_RCTL u_IMG_RCTL (
    //clock & reset
    .clk                ( clk               ),
    .frst               ( frst              ),
                                            
    //H_RAM read interface                  
    .o_h_ram_raddr      ( s_h_ram_raddr     ),
    .o_h_ram_re         ( s_h_ram_re        ),
    .i_org_h_vld        ( s_org_h_vld       ),
    .i_org_h            ( s_org_h           ), //{10-int,5-frac}
    .i_h_ram_vld        ( s_h_ram_vld       ),
    
    //img read request
    .i_read_req_ready   ( s_read_req_ready  ),
    .o_read_req_h       ( s_read_req_h      ),
    .o_read_req_vld     ( s_read_req_vld    ), //依赖于ready，单拍有效
    
    //双线性插值读取定点的img的h坐标
    .o_fix_h            ( o_fix_h           ), //{10-int,5-frac}
    .o_fix_h_vld        ( o_fix_h_vld       ),
    .o_fix_h_empty      ( o_fix_h_empty     ),
    .i_fix_h_re         ( i_fix_h_re        ),
    
    //使用双线性插值需要用到的图像行号查询对应8行img空间的行号
    .o_8row_id          ( o_8row_id         ),
    .o_8row_h           ( o_8row_h          ),
    .o_8row_empty       ( o_8row_empty      ),
    .i_8row_re          ( i_8row_re         )
);

//AXIR_BRAMW instance
AXIR_BRAMW u_AXIR_BRAMW (
    .clk                ( clk               ),
    .frst               ( frst              ),
    
    //img read request
    .o_read_req_ready   ( s_read_req_ready  ),
    .i_read_req_h       ( s_read_req_h      ),
    .i_read_req_vld     ( s_read_req_vld    ), //依赖于ready，单拍有效
    
    //BRAM write interface
    .o_bram_wcnt        ( s_bram_wcnt       ), //8 rows
    .o_bram_waddr       ( s_bram_waddr      ), //only use (0~639)/4 = 0~159
    .o_bram_wdata       ( s_bram_wdata      ),
    .o_bram_we          ( s_bram_we         ),
                                            
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

//BRAM_RW_CTL instance
BRAM_RW_CTL u_BRAM_RW_CTL (
    .clk                ( clk               ),
    .frst               ( frst              ),
    
    //BRAM write interface
    .i_bram_wcnt        ( s_bram_wcnt       ), //8 rows
    .i_bram_waddr       ( s_bram_waddr      ), //only use (0~639)/4 = 0~159
    .i_bram_wdata       ( s_bram_wdata      ),
    .i_bram_we          ( s_bram_we         ),

    //BRAM 2 channel read interface
    .i_ch0_raddr        ( i_ch0_raddr       ), //{2-row_id 0 2 4 6, 9-w}, w only use 0~639
    .i_ch1_raddr        ( i_ch1_raddr       ), //{2-row_id 1 3 5 7, 9-w}, w only use 0~639
    .i_bram_re          ( i_bram_re         ),
    .o_ch0_rdata        ( o_ch0_rdata       ),
    .o_ch1_rdata        ( o_ch1_rdata       ),
    .o_bram_rvld        ( o_bram_rvld       )
);

endmodule