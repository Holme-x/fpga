
module DdrCtrl (
    input clk,
    input core_clk,
    input twd_clk,
    input tdqss_clk,
    input tac_clk,
    input reset_n,
    output reset,
    output cs,
    output ras,
    output cas,
    output we,
    output cke,
    output [15:0] addr,
    output [2:0] ba,
    output odt,
    output [2:0] shift,
    output [4:0] shift_sel,
    output shift_ena,
    input cal_ena,
    output cal_done,
    output cal_pass,
    output [2:0] cal_shift_val,
    output [1:0] o_dm_hi,
    output [1:0] o_dm_lo,
    input [1:0] i_dqs_hi,
    input [1:0] i_dqs_lo,
    input [1:0] i_dqs_n_hi,
    input [1:0] i_dqs_n_lo,
    output [1:0] o_dqs_hi,
    output [1:0] o_dqs_lo,
    output [1:0] o_dqs_n_hi,
    output [1:0] o_dqs_n_lo,
    output [1:0] o_dqs_oe,
    output [1:0] o_dqs_n_oe,
    input [15:0] i_dq_hi,
    input [15:0] i_dq_lo,
    output [15:0] o_dq_hi,
    output [15:0] o_dq_lo,
    output [15:0] o_dq_oe,
    input [7:0] axi_aid,
    input [31:0] axi_aaddr,
    input [7:0] axi_alen,
    input [2:0] axi_asize,
    input [1:0] axi_aburst,
    input [1:0] axi_alock,
    input axi_avalid,
    output axi_aready,
    input axi_atype,
    input [7:0] axi_wid,
    input [127:0] axi_wdata,
    input [15:0] axi_wstrb,
    input axi_wlast,
    input axi_wvalid,
    output axi_wready,
    output [7:0] axi_rid,
    output [127:0] axi_rdata,
    output axi_rlast,
    output axi_rvalid,
    input axi_rready,
    output [1:0] axi_rresp,
    output [7:0] axi_bid,
    output [1:0] axi_bresp,
    output axi_bvalid,
    input axi_bready,
    output [7:0] cal_fail_log
);

logic r_cal_done;
initial begin
    r_cal_done = 0;
    
    wait(~reset_n);
    #1000; 
    r_cal_done = 1;
end
assign cal_done = r_cal_done;

wire                AXI_ARVALID ;
wire                AXI_ARREADY ;
wire    [ 31:0]     AXI_ARADDR  ;
wire    [  3:0]     AXI_ARID    ;
wire    [  7:0]     AXI_ARLEN   ;
wire    [  3:0]     AXI_ARSIZE  ;
wire    [  1:0]     AXI_ARBURST ;
wire    [  1:0]     AXI_ARLOCK  ;

wire                AXI_AWVALID ;  
wire                AXI_AWREADY ; 
wire    [ 31:0]     AXI_AWADDR  ; 
wire    [  3:0]     AXI_AWID    ; 
wire    [  7:0]     AXI_AWLEN   ; 
wire    [  3:0]     AXI_AWSIZE  ; 
wire    [  1:0]     AXI_AWBURST ; 
wire    [  1:0]     AXI_AWLOCK  ;

assign axi_aready   = AXI_ARREADY & AXI_AWREADY;

assign AXI_ARVALID  = ~axi_atype & axi_avalid   ; 
assign AXI_ARADDR   = axi_aaddr                 ;
assign AXI_ARID     = axi_aid                   ;
assign AXI_ARLEN    = axi_alen                  ;
assign AXI_ARSIZE   = axi_asize                 ;
assign AXI_ARBURST  = axi_aburst                ;
assign AXI_ARLOCK   = axi_alock                 ;

assign AXI_AWVALID  = axi_atype & axi_avalid    ;  
assign AXI_AWADDR   = axi_aaddr                 ;
assign AXI_AWID     = axi_aid                   ;
assign AXI_AWLEN    = axi_alen                  ;
assign AXI_AWSIZE   = axi_asize                 ;
assign AXI_AWBURST  = axi_aburst                ;
assign AXI_AWLOCK   = axi_alock                 ;

SIM_DDR # (
    .ADDR_WIDTH         ( 32            ),
    .DATA_WIDTH         ( 128           ),
    .DATA_MAX_SIZE      ( 4*1024*1024   )
) u_SIM_DDR (
    .axi_wclk           ( clk           ),
    .axi_wrst           ( ~reset_n      ),
    .axi_rclk           ( clk           ),
    .axi_rrst           ( ~reset_n      ),

    //axi bus error
    .axi_bus_err        (               ),
    
    //AXI write interface
    .AXI_AWREADY        ( AXI_AWREADY   ), // Write Address Channel Ready
    .AXI_AWVALID        ( AXI_AWVALID   ), // Write Address Channel Valid
    .AXI_AWADDR         ( AXI_AWADDR    ), // Write Address Channel Address
    .AXI_AWLEN          ( AXI_AWLEN     ), // Write Address Channel Burst Length code
    .AXI_AWID           ( AXI_AWID      ), // Write Address Channel Transaction ID
    .AXI_AWSIZE         ( AXI_AWSIZE    ), // Write Address Channel Transfer Size code
    .AXI_AWBURST        ( AXI_AWBURST   ), // Write Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP
    .AXI_AWLOCK         ( AXI_AWLOCK    ), // Write Address Channel Atomic Access Type, Xilinx_IP not supported
    .AXI_AWCACHE        ( 'd0           ), // Write Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
    .AXI_AWPROT         ( 'd0           ), // Write Address Channel Protection Bits
    .AXI_AWQOS          ( 'd0           ), // Write Address Channel Quality of Service
                                
    .AXI_WREADY         ( axi_wready    ), // Write Data Channel Ready
    .AXI_WVALID         ( axi_wvalid    ), // Write Data Channel Valid
    .AXI_WDATA          ( axi_wdata     ), // Write Data Channel Data
    .AXI_WSTRB          ( axi_wstrb     ), // Write Data Channel Data Byte Strobes
    .AXI_WLAST          ( axi_wlast     ), // Write Data Channel Last Data Beat
    .AXI_WID            ( axi_wid       ), // Write Data Channel ID, for AXI3
                                
    .AXI_BREADY         ( axi_bready    ), // Write Response Channel Ready
    .AXI_BVALID         ( axi_bvalid    ), // Write Response Channel Valid
    .AXI_BID            ( axi_bid       ), // Write Response Channel Transaction ID
    .AXI_BRESP          ( axi_bresp     ), // Write Response Channel Response Code

    //AXI read interface
    .AXI_ARREADY        ( AXI_ARREADY   ), // Read Address Channel Ready                
    .AXI_ARVALID        ( AXI_ARVALID   ), // Read Address Channel Valid                
    .AXI_ARADDR         ( AXI_ARADDR    ), // Read Address Channel Address              
    .AXI_ARLEN          ( AXI_ARLEN     ), // Read Address Channel Burst Length code    
    .AXI_ARID           ( AXI_ARID      ), // Read Address Channel Transaction ID       
    .AXI_ARSIZE         ( AXI_ARSIZE    ), // Read Address Channel Transfer Size code   
    .AXI_ARBURST        ( AXI_ARBURST   ), // Read Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
    .AXI_ARLOCK         ( AXI_ARLOCK    ), // Read Address Channel Atomic Access Type, Xilinx_IP not supported   
    .AXI_ARCACHE        ( 'd0           ), // Read Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
    .AXI_ARPROT         ( 'd0           ), // Read Address Channel Protection Bits      
    .AXI_ARQOS          ( 'd0           ), // Read Address Channel Quality of Service   
    
    .AXI_RREADY         ( axi_rready    ), // Read Data Channel Ready     
    .AXI_RVALID         ( axi_rvalid    ), // Read Data Channel Valid            
    .AXI_RDATA          ( axi_rdata     ), // Read Data Channel Data             
    .AXI_RLAST          ( axi_rlast     ), // Read Data Channel Last Data Beat       
    .AXI_RID            ( axi_rid       ), // Read Data Channel Transaction ID
    .AXI_RRESP          ( axi_rresp     )  // Read Data Channel Response Code
);


endmodule