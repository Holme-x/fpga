
module AXIR_BRAMW (
    input               clk                 ,
    input               frst                ,
    
    //img read request
    output              o_read_req_ready    ,
    input   [  8:0]     i_read_req_h        ,
    input               i_read_req_vld      , //依赖于ready，单拍有效
    
    //BRAM write interface
    output  [  2:0]     o_bram_wcnt         , //8 rows
    output  [  7:0]     o_bram_waddr        , //only use (0~639)/4 = 0~159
    output  [127:0]     o_bram_wdata        ,
    output              o_bram_we           ,
                                            
    //AXI read interface                    
    input               AXI_ARREADY         , // Read Address Channel Ready                
    output              AXI_ARVALID         , // Read Address Channel Valid                
    output  [ 31:0]     AXI_ARADDR          , // Read Address Channel Address              
    output  [  7:0]     AXI_ARLEN           , // Read Address Channel Burst Length code    
    output  [  3:0]     AXI_ARID            , // Read Address Channel Transaction ID       
    output  [  2:0]     AXI_ARSIZE          , // Read Address Channel Transfer Size code   
    output  [  1:0]     AXI_ARBURST         , // Read Address Channel Burst Type, 0-FIXED, 1-INCR, 2-WRAP     
    output  [  1:0]     AXI_ARLOCK          , // Read Address Channel Atomic Access Type, Xilinx_IP not supported   
                                            
    output              AXI_RREADY          , // Read Data Channel Ready            
    input               AXI_RVALID          , // Read Data Channel Valid            
    input   [127:0]     AXI_RDATA           , // Read Data Channel Data             
    input               AXI_RLAST           , // Read Data Channel Last Data Beat       
    input   [  3:0]     AXI_RID             , // Read Data Channel Transaction ID
    input   [  1:0]     AXI_RRESP             // Read Data Channel Response Code
);

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
//AXI read request generate
reg                 r_axi_rbusy     ;
reg     [  2:0]     r_rc_size       ;
reg     [ 19:0]     r_rc_pixel_id   ;
wire                s_req_vld       ;
wire                s_axi_req       ;
wire                s_axi_rdone     ;

//bram write generate
reg     [  7:0]     r_bram_waddr    ;
reg     [  2:0]     r_bram_wcnt     ;
reg                 r_bram_we       ;
reg     [127:0]     r_bram_wdata    ;

// =========================================================================================================================================
// Output generate
// =========================================================================================================================================
assign o_read_req_ready = ~r_axi_rbusy;

assign o_bram_wcnt      = r_bram_wcnt    ;
assign o_bram_waddr     = r_bram_waddr   ;
assign o_bram_wdata     = r_bram_wdata   ;
assign o_bram_we        = r_bram_we      ;

assign AXI_ARSIZE       = 3'd4;     
assign AXI_ARBURST      = 2'b01;
assign AXI_ARLOCK       = 2'd0;
assign AXI_ARLEN        = 8'd31;                                //4*32 = 128 pixel

assign AXI_ARID[3:1]    = 3'd0;
assign AXI_ARID[0]      = (r_rc_size == 'd1);
assign AXI_ARADDR       = {10'd0, r_rc_pixel_id, 2'd0};         //1 pixel 4 byte
assign AXI_ARVALID      = |r_rc_size;

assign AXI_RREADY       = 1'b1;

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//AXI read request generate
always @ (posedge clk) begin
    if (frst) begin
        r_axi_rbusy     <= 1'b0;
        r_rc_size       <= 3'd0;
        r_rc_pixel_id   <= 20'd0;
    end else begin
        if (s_req_vld) begin
            r_axi_rbusy <= 1'b1;
        end else if (s_axi_rdone) begin
            r_axi_rbusy <= 1'b0;
        end
        if (s_req_vld) begin
            r_rc_size       <= 3'd5;        //5 = 640 / 128
            r_rc_pixel_id   <= {2'd0,i_read_req_h,9'd0} + {4'd0,i_read_req_h,7'd0}; //h*640 = h*512 + h*128
        end else if (s_axi_req) begin
            r_rc_size       <= r_rc_size - 1'b1;
            r_rc_pixel_id   <= r_rc_pixel_id + 128;
        end
    end
end
assign s_req_vld    = i_read_req_vld & o_read_req_ready;
assign s_axi_req    = AXI_ARREADY & AXI_ARVALID;
assign s_axi_rdone  = AXI_RVALID & AXI_RLAST & AXI_RID[0];

//bram write generate
always @ (posedge clk) begin
    if (frst) begin
        r_bram_waddr    <= 8'd0;
        r_bram_wcnt     <= 3'd0;
        r_bram_we       <= 1'b0;
    end else begin
        if (r_bram_we) begin
            if (r_bram_waddr == 'd159) begin    //(0~639)/4 = 0~159
                r_bram_waddr    <= 'd0;
                r_bram_wcnt     <= r_bram_wcnt + 1'b1;
            end else begin
                r_bram_waddr    <= r_bram_waddr + 1'b1;
            end
        end
        r_bram_we   <= AXI_RVALID;
    end
    r_bram_wdata <= AXI_RDATA;
end


endmodule