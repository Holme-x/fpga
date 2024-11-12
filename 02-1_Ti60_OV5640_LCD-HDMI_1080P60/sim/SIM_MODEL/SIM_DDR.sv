
module SIM_DDR # (
    parameter           ADDR_WIDTH      = 32                        ,
    parameter           DATA_WIDTH      = 32                        ,
    parameter string    INIT_FILE[7:0]  = '{"memory_initial.log"    , 
                                            "memory_initial.log"    , 
                                            "memory_initial.log"    , 
                                            "memory_initial.log"    , 
                                            "memory_initial.log"    , 
                                            "memory_initial.log"    , 
                                            "memory_initial.log"    , 
                                            "memory_initial.log"    },
    parameter int       INIT_EN[7:0]    = '{0,0,0,0,0,0,0,0}        ,
    parameter int       DATA_ADDR[7:0]  = '{0,0,0,0,0,0,0,0}        ,
    parameter           DATA_MAX_SIZE   = 0
) (
    input                       axi_wclk            ,
    input                       axi_wrst            ,
    input                       axi_rclk            ,
    input                       axi_rrst            ,
    
    //axi bus error
    output                      axi_bus_err         ,
    
    //AXI write interface
    output                      AXI_AWREADY         , // Write Address Channel Ready
    input                       AXI_AWVALID         , // Write Address Channel Valid
    input   [ADDR_WIDTH-1:0]    AXI_AWADDR          , // Write Address Channel Address
    input   [  7:0]             AXI_AWLEN           , // Write Address Channel Burst Length code
    input   [  5:0]             AXI_AWID            , // Write Address Channel Transaction ID
    input   [  2:0]             AXI_AWSIZE          , // Write Address Channel Transfer Size code
    input   [  1:0]             AXI_AWBURST         , // Write Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP
    input                       AXI_AWLOCK          , // Write Address Channel Atomic Access Type, Xilinx_IP not supported
    input   [  3:0]             AXI_AWCACHE         , // Write Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
    input   [  2:0]             AXI_AWPROT          , // Write Address Channel Protection Bits
    input   [  3:0]             AXI_AWQOS           , // Write Address Channel Quality of Service
                                
    output                      AXI_WREADY          , // Write Data Channel Ready
    input                       AXI_WVALID          , // Write Data Channel Valid
    input   [DATA_WIDTH-1:0]    AXI_WDATA           , // Write Data Channel Data
    input   [ 15:0]             AXI_WSTRB           , // Write Data Channel Data Byte Strobes
    input                       AXI_WLAST           , // Write Data Channel Last Data Beat
    input   [  5:0]             AXI_WID             , // Write Data Channel ID, for AXI3
                                
    input                       AXI_BREADY          , // Write Response Channel Ready
    output                      AXI_BVALID          , // Write Response Channel Valid
    output  [  5:0]             AXI_BID             , // Write Response Channel Transaction ID
    output  [  1:0]             AXI_BRESP           , // Write Response Channel Response Code

    //AXI read interface
    output                      AXI_ARREADY         , // Read Address Channel Ready                
    input                       AXI_ARVALID         , // Read Address Channel Valid                
    input   [ADDR_WIDTH-1:0]    AXI_ARADDR          , // Read Address Channel Address              
    input   [  7:0]             AXI_ARLEN           , // Read Address Channel Burst Length code    
    input   [  5:0]             AXI_ARID            , // Read Address Channel Transaction ID       
    input   [  2:0]             AXI_ARSIZE          , // Read Address Channel Transfer Size code   
    input   [  1:0]             AXI_ARBURST         , // Read Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
    input                       AXI_ARLOCK          , // Read Address Channel Atomic Access Type, Xilinx_IP not supported   
    input   [  3:0]             AXI_ARCACHE         , // Read Address Channel Cache Characteristics, 0-Non-bufferable, 3-Non-cacheable Bufferable
    input   [  2:0]             AXI_ARPROT          , // Read Address Channel Protection Bits      
    input   [  3:0]             AXI_ARQOS           , // Read Address Channel Quality of Service   
    
    input                       AXI_RREADY          , // Read Data Channel Ready     
    output                      AXI_RVALID          , // Read Data Channel Valid            
    output  [DATA_WIDTH-1:0]    AXI_RDATA           , // Read Data Channel Data             
    output                      AXI_RLAST           , // Read Data Channel Last Data Beat       
    output  [  5:0]             AXI_RID             , // Read Data Channel Transaction ID
    output  [  1:0]             AXI_RRESP             // Read Data Channel Response Code
);

`include "DEFINE_FUNC.vh"
localparam LP_WIDTH     = FUNC_LOG2(DATA_WIDTH/8);

localparam DATA0_START  = DATA_ADDR[0]/(DATA_WIDTH/8);
localparam DATA1_START  = DATA_ADDR[1]/(DATA_WIDTH/8);
localparam DATA2_START  = DATA_ADDR[2]/(DATA_WIDTH/8);
localparam DATA3_START  = DATA_ADDR[3]/(DATA_WIDTH/8);
localparam DATA4_START  = DATA_ADDR[4]/(DATA_WIDTH/8);
localparam DATA5_START  = DATA_ADDR[5]/(DATA_WIDTH/8);
localparam DATA6_START  = DATA_ADDR[6]/(DATA_WIDTH/8);
localparam DATA7_START  = DATA_ADDR[7]/(DATA_WIDTH/8);

localparam DATA0_END    = DATA0_START + DATA_MAX_SIZE/(DATA_WIDTH/8);
localparam DATA1_END    = DATA1_START + DATA_MAX_SIZE/(DATA_WIDTH/8);
localparam DATA2_END    = DATA2_START + DATA_MAX_SIZE/(DATA_WIDTH/8);
localparam DATA3_END    = DATA3_START + DATA_MAX_SIZE/(DATA_WIDTH/8);
localparam DATA4_END    = DATA4_START + DATA_MAX_SIZE/(DATA_WIDTH/8);
localparam DATA5_END    = DATA5_START + DATA_MAX_SIZE/(DATA_WIDTH/8);
localparam DATA6_END    = DATA6_START + DATA_MAX_SIZE/(DATA_WIDTH/8);
localparam DATA7_END    = DATA7_START + DATA_MAX_SIZE/(DATA_WIDTH/8);

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
// init file to ddr
logic   [DATA_WIDTH-1:0]    DATA[0:7][0:DATA_MAX_SIZE/(DATA_WIDTH/8)-1];

// write data to ddr
logic   [ADDR_WIDTH+13-LP_WIDTH:0]  s_WCBUF_wdata   ;
logic                               s_WCBUF_we      ;
logic                               s_WCBUF_re      ;
logic   [ADDR_WIDTH+13-LP_WIDTH:0]  s_WCBUF_rdata   ;
logic                               s_WCBUF_rvld    ;
logic                               s_WCBUF_pfull   ;

logic   [DATA_WIDTH+6:0]            s_WDBUF_wdata   ;
logic                               s_WDBUF_we      ;
logic                               s_WDBUF_re      ;
logic   [DATA_WIDTH+6:0]            s_WDBUF_rdata   ;
logic                               s_WDBUF_rvld    ;
logic                               s_WDBUF_pfull   ;
logic                               WDBUF_rready    ;

logic   [  5:0]                     ddr_awid        ;
logic   [  7:0]                     ddr_wlen        ;
logic   [ADDR_WIDTH-LP_WIDTH-1:0]   ddr_wbase_addr  ;
logic   [  5:0]                     ddr_wid         ;
logic                               ddr_wlast       ;
logic   [DATA_WIDTH-1:0]            ddr_wdata       ;
  
logic   [ADDR_WIDTH-LP_WIDTH-1:0]   data_wbase      ;
logic   [  2:0]                     data_wid        ;
logic                               err_wbase_addr  ;
logic                               err_wid         ;
logic                               err_wlast       ;

logic   [  5:0]                     r_AXI_BID       ;
logic                               r_AXI_BVALID    ;

// read data from ddr
logic   [ADDR_WIDTH+13-LP_WIDTH:0]  s_RCBUF_wdata   ;
logic                               s_RCBUF_we      ;
logic                               s_RCBUF_re      ;
logic   [ADDR_WIDTH+13-LP_WIDTH:0]  s_RCBUF_rdata   ;
logic                               s_RCBUF_rvld    ;
logic                               s_RCBUF_pfull   ;

logic   [  5:0]                     ddr_arid        ;
logic   [  7:0]                     ddr_rlen        ;
logic   [ADDR_WIDTH-LP_WIDTH-1:0]   ddr_rbase_addr  ; 

logic   [ADDR_WIDTH-LP_WIDTH-1:0]   data_rbase      ; 
logic   [  2:0]                     data_rid        ; 
logic                               err_rbase_addr  ;

logic                               r_AXI_RVALID    ;
logic   [DATA_WIDTH-1:0]            r_AXI_RDATA     ;
logic   [  5:0]                     r_AXI_RID       ;
logic                               r_AXI_RLAST     ;

// =========================================================================================================================================
// Output generate
// =========================================================================================================================================
assign axi_bus_err  = err_wbase_addr | err_wid | err_wlast | err_rbase_addr;

assign AXI_AWREADY  = ~s_WCBUF_pfull;
assign AXI_WREADY   = ~s_WDBUF_pfull;
assign AXI_BVALID   = r_AXI_BVALID;
assign AXI_BID      = r_AXI_BID;
assign AXI_BRESP    = 0;

assign AXI_ARREADY  = ~s_RCBUF_pfull    ;
assign AXI_RVALID   = r_AXI_RVALID      ;
assign AXI_RDATA    = r_AXI_RDATA       ;
assign AXI_RLAST    = r_AXI_RLAST       ;
assign AXI_RID      = r_AXI_RID         ;
assign AXI_RRESP    = 0;

// =========================================================================================================================================
// init file to ddr
// =========================================================================================================================================
initial begin
    for (int i=0; i<8; i++) begin
        if (INIT_EN[i]) begin
            $readmemh(INIT_FILE[i],DATA[i]);
        end
    end
end

// =========================================================================================================================================
// write data to ddr
// =========================================================================================================================================
//CBUF instance
DRAM_SYNC_FIFO # (
    .WIDTH      ( ADDR_WIDTH+14-LP_WIDTH    ),
    .PF_VALUE   ( 28                )
) u_WCBUF (
    .clk        ( axi_wclk          ),
    .rst        ( axi_wrst          ),
    .din        ( s_WCBUF_wdata     ),
    .wr_en      ( s_WCBUF_we        ),
    .rd_en      ( s_WCBUF_re        ),
    .dout       ( s_WCBUF_rdata     ),
    .valid      ( s_WCBUF_rvld      ),
    .prog_full  ( s_WCBUF_pfull     ),
    .full       (                   ),
    .empty      (                   )
);
assign s_WCBUF_wdata    = {AXI_AWID,AXI_AWLEN,AXI_AWADDR[ADDR_WIDTH-1:LP_WIDTH]};
assign s_WCBUF_we       = AXI_AWREADY & AXI_AWVALID;
assign s_WCBUF_re       = s_WDBUF_re & ddr_wlast;

//DBUF instance
DRAM_SYNC_FIFO # (
    .WIDTH      ( DATA_WIDTH+7      ),
    .PF_VALUE   ( 28                )
) u_WDBUF (
    .clk        ( axi_wclk          ),
    .rst        ( axi_wrst          ),
    .din        ( s_WDBUF_wdata     ),
    .wr_en      ( s_WDBUF_we        ),
    .rd_en      ( s_WDBUF_re        ),
    .dout       ( s_WDBUF_rdata     ),
    .valid      ( s_WDBUF_rvld      ),
    .prog_full  ( s_WDBUF_pfull     ),
    .full       (                   ),
    .empty      (                   )
);
assign s_WDBUF_wdata    = {AXI_WID,AXI_WLAST,AXI_WDATA};
assign s_WDBUF_we       = AXI_WREADY & AXI_WVALID;
assign s_WDBUF_re       = WDBUF_rready & s_WCBUF_rvld & s_WDBUF_rvld;

assign {ddr_awid,ddr_wlen,ddr_wbase_addr}   = s_WCBUF_rdata;
assign {ddr_wid,ddr_wlast,ddr_wdata}        = s_WDBUF_rdata;

always @ * begin
    if ((ddr_wbase_addr>=DATA0_START) & (ddr_wbase_addr<DATA0_END)) begin
        data_wbase  = ddr_wbase_addr - DATA0_START;
        data_wid    = 0;
        err_wbase_addr = 0;
    end else if ((ddr_wbase_addr>=DATA1_START) & (ddr_wbase_addr<DATA1_END)) begin
        data_wbase  = ddr_wbase_addr - DATA1_START;
        data_wid    = 1;
        err_wbase_addr = 0;
    end else if ((ddr_wbase_addr>=DATA2_START) & (ddr_wbase_addr<DATA2_END)) begin
        data_wbase  = ddr_wbase_addr - DATA2_START;
        data_wid    = 2;
        err_wbase_addr = 0;
    end else if ((ddr_wbase_addr>=DATA3_START) & (ddr_wbase_addr<DATA3_END)) begin
        data_wbase  = ddr_wbase_addr - DATA3_START;
        data_wid    = 3;
        err_wbase_addr = 0;
    end else if ((ddr_wbase_addr>=DATA4_START) & (ddr_wbase_addr<DATA4_END)) begin
        data_wbase  = ddr_wbase_addr - DATA4_START;
        data_wid    = 4;
        err_wbase_addr = 0;
    end else if ((ddr_wbase_addr>=DATA5_START) & (ddr_wbase_addr<DATA5_END)) begin
        data_wbase  = ddr_wbase_addr - DATA5_START;
        data_wid    = 5;
        err_wbase_addr = 0;
    end else if ((ddr_wbase_addr>=DATA6_START) & (ddr_wbase_addr<DATA6_END)) begin
        data_wbase  = ddr_wbase_addr - DATA6_START;
        data_wid    = 6;
        err_wbase_addr = 0;
    end else if ((ddr_wbase_addr>=DATA7_START) & (ddr_wbase_addr<DATA7_END)) begin
        data_wbase  = ddr_wbase_addr - DATA7_START;
        data_wid    = 7;
        err_wbase_addr = 0;
    end else begin
        err_wbase_addr = 1;
    end
end

initial begin
    r_AXI_BID       = 0;
    r_AXI_BVALID    = 0;
    WDBUF_rready    = 0;
    
    wait(axi_wrst);
    
    forever begin
        @(posedge axi_wclk);
        #1;
        r_AXI_BID       = 0;
        r_AXI_BVALID    = 0;
        WDBUF_rready    = 0;
        
        if (s_WCBUF_rvld) begin
            TASK_WDATA;
        end
    end
end

task TASK_WDATA;
    int         data_wcnt   ;
    int         data_waddr  ;
    
    data_wcnt       = 0;
    while (data_wcnt<=ddr_wlen) begin
        @(posedge axi_wclk);
        #1;
        WDBUF_rready    = 1;
        #0;
        data_waddr      = data_wbase + data_wcnt;
        
        if (s_WDBUF_re) begin
            DATA[data_wid][data_waddr]  = ddr_wdata;
            err_wid = (ddr_awid != ddr_wid);
            if (data_wcnt==ddr_wlen) begin
                err_wlast   = (ddr_wlast == 0);
            end
            data_wcnt++;
        end
    end
    r_AXI_BID       = ddr_awid;
    r_AXI_BVALID    = 1;
endtask

// =========================================================================================================================================
// read data from ddr
// =========================================================================================================================================
//CBUF instance
DRAM_SYNC_FIFO # (
    .WIDTH      ( ADDR_WIDTH+14-LP_WIDTH    ),
    .PF_VALUE   ( 28                )
) u_RCBUF (
    .clk        ( axi_rclk          ),
    .rst        ( axi_rrst          ),
    .din        ( s_RCBUF_wdata     ),
    .wr_en      ( s_RCBUF_we        ),
    .rd_en      ( s_RCBUF_re        ),
    .dout       ( s_RCBUF_rdata     ),
    .valid      ( s_RCBUF_rvld      ),
    .prog_full  ( s_RCBUF_pfull     ),
    .full       (                   ),
    .empty      (                   )
);
assign s_RCBUF_wdata    = {AXI_ARID,AXI_ARLEN,AXI_ARADDR[ADDR_WIDTH-1:LP_WIDTH]};
assign s_RCBUF_we       = AXI_ARREADY & AXI_ARVALID;
assign s_RCBUF_re       = AXI_RREADY & AXI_RVALID & AXI_RLAST;

assign {ddr_arid,ddr_rlen,ddr_rbase_addr}   = s_RCBUF_rdata;

always @ * begin
    if ((ddr_rbase_addr>=DATA0_START) & (ddr_rbase_addr<DATA0_END)) begin
        data_rbase  = ddr_rbase_addr - DATA0_START;
        data_rid    = 0;
        err_rbase_addr = 0;
    end else if ((ddr_rbase_addr>=DATA1_START) & (ddr_rbase_addr<DATA1_END)) begin
        data_rbase  = ddr_rbase_addr - DATA1_START;
        data_rid    = 1;
        err_rbase_addr = 0;
    end else if ((ddr_rbase_addr>=DATA2_START) & (ddr_rbase_addr<DATA2_END)) begin
        data_rbase  = ddr_rbase_addr - DATA2_START;
        data_rid    = 2;
        err_rbase_addr = 0;
    end else if ((ddr_rbase_addr>=DATA3_START) & (ddr_rbase_addr<DATA3_END)) begin
        data_rbase  = ddr_rbase_addr - DATA3_START;
        data_rid    = 3;
        err_rbase_addr = 0;
    end else if ((ddr_rbase_addr>=DATA4_START) & (ddr_rbase_addr<DATA4_END)) begin
        data_rbase  = ddr_rbase_addr - DATA4_START;
        data_rid    = 4;
        err_rbase_addr = 0;
    end else if ((ddr_rbase_addr>=DATA5_START) & (ddr_rbase_addr<DATA5_END)) begin
        data_rbase  = ddr_rbase_addr - DATA5_START;
        data_rid    = 5;
        err_rbase_addr = 0;
    end else if ((ddr_rbase_addr>=DATA6_START) & (ddr_rbase_addr<DATA6_END)) begin
        data_rbase  = ddr_rbase_addr - DATA6_START;
        data_rid    = 6;
        err_rbase_addr = 0;
    end else if ((ddr_rbase_addr>=DATA7_START) & (ddr_rbase_addr<DATA7_END)) begin
        data_rbase  = ddr_rbase_addr - DATA7_START;
        data_rid    = 7;
        err_rbase_addr = 0;
    end else begin
        err_rbase_addr = 1;
    end
end

initial begin
    r_AXI_RVALID    = 0;
    
    wait(axi_rrst);
    
    forever begin
        @(posedge axi_rclk);
        #1;
        r_AXI_RVALID    = 0;
        r_AXI_RLAST     = 0;
        
        if (s_RCBUF_rvld) begin
            TASK_RDATA;
        end
    end
end

logic   [127:0]     test_data;
initial begin
    test_data = 128'h00030303000202020001010100000000;
    for (int i=0; i<640*480/4; i++) begin
         DATA[0][i] = test_data;
         test_data[    7:    0] = test_data[    7:    0] + 4;
         test_data[   15:    8] = test_data[    7:    0];
         test_data[   23:   16] = test_data[   15:    8];
         test_data[32+ 7:32+ 0] = test_data[32+ 7:32+ 0] + 4;
         test_data[32+15:32+ 8] = test_data[32+ 7:32+ 0];
         test_data[32+23:32+16] = test_data[32+15:32+ 8];
         test_data[64+ 7:64+ 0] = test_data[64+ 7:64+ 0] + 4;
         test_data[64+15:64+ 8] = test_data[64+ 7:64+ 0];
         test_data[64+23:64+16] = test_data[64+15:64+ 8];
         test_data[96+ 7:96+ 0] = test_data[96+ 7:96+ 0] + 4;
         test_data[96+15:96+ 8] = test_data[96+ 7:96+ 0];
         test_data[96+23:96+16] = test_data[96+15:96+ 8];
    end
end

task TASK_RDATA;
    int         data_rcnt;
    int         data_raddr;
    
    data_rcnt   = 0;
    while (data_rcnt<=ddr_rlen) begin
        @(posedge axi_rclk);
        #1;
        data_raddr      = data_rbase + data_rcnt;
//        r_AXI_RDATA     = DATA[data_rid][data_raddr];
        r_AXI_RDATA     = DATA[0][data_raddr];
        r_AXI_RID       = ddr_arid;
        r_AXI_RLAST     = (data_rcnt==ddr_rlen);
        r_AXI_RVALID    = 1;
        
        #0;
        if (AXI_RREADY & AXI_RVALID) begin
            data_rcnt++;
        end
    end
endtask

endmodule