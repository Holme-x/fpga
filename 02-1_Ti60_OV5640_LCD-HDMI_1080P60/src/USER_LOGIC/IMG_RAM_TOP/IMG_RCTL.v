
module IMG_RCTL (
    //clock & reset
    input               clk                 ,
    input               frst                ,
                                            
    //H_RAM read interface                  
    output  [ 10:0]     o_h_ram_raddr       ,
    output              o_h_ram_re          ,
    input               i_org_h_vld         ,
    input   [ 14:0]     i_org_h             , //{10-int,5-frac}
    input               i_h_ram_vld         ,
    
    //img read request
    input               i_read_req_ready    ,
    output  [  8:0]     o_read_req_h        ,
    output              o_read_req_vld      , //依赖于ready，单拍有效
    
    //双线性插值读取定点的img的h坐标
    output  [ 14:0]     o_fix_h             , //{10-int,5-frac}
    output              o_fix_h_vld         ,
    output              o_fix_h_empty       ,
    input               i_fix_h_re          ,
    
    //使用双线性插值需要用到的图像行号查询对应8行img空间的行号
    output  [  2:0]     o_8row_id           ,
    output  [  8:0]     o_8row_h            ,
    output              o_8row_empty        ,
    input               i_8row_re
);

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
//hdmi h counter
reg                 r_h_ram_re      ;
reg                 r_h_ram_rready  ;
reg     [ 10:0]     r_hdmi_h        ;

//img read request generate
reg     [  8:0]     r_req_h         ;
reg     [ 14:0]     r_fix_h         ;
reg     [  1:0]     r_org_h_vld     ;
reg     [  1:0]     r_req_h_vld     ;

//fix image h_buf instance
wire    [  5:0]     s_fix_h_cnt     ;
wire                s_fix_h_pfull   ;

//RREQ_BUF instance
wire                s_org_h_vld     ; 
wire    [  8:0]     s_req_h         ;
wire                s_req_h_re      ;
wire                s_req_h_empty   ;
wire    [  5:0]     s_req_h_cnt     ;
wire                s_req_h_pfull   ;

//计算8行img空间的当前已存入最大行号
reg     [  9:0]     r_now_max_h     ;

//计算8行img空间的可用空间
reg     [  3:0]     r_8row_space    ;
reg     [  2:0]     r_8row_id       ;

// =========================================================================================================================================
// Output generate
// =========================================================================================================================================
assign o_h_ram_raddr    = r_hdmi_h;
assign o_h_ram_re       = r_h_ram_re & r_h_ram_rready & ~s_fix_h_pfull & ~s_req_h_pfull;

assign o_read_req_h     = s_req_h;
assign o_read_req_vld   = s_req_h_re & s_org_h_vld & (r_now_max_h[9] | (s_req_h > r_now_max_h[8:0]));

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//hdmi h counter
always @ (posedge clk) begin
    if (frst) begin
        r_h_ram_re      <= 1'b0;
        r_h_ram_rready  <= 1'b0;
        r_hdmi_h        <= 11'd0;
    end else begin
        if (r_hdmi_h == 'd0) begin
            r_h_ram_re  <= 1'b1;
        end else if (o_h_ram_re & (r_hdmi_h == 1080-1)) begin
            r_h_ram_re  <= 1'b0;
        end
        if (r_h_ram_re) begin                   //由于读1个h会生成2个req_h，需要控制读速
            r_h_ram_rready  <= ~r_h_ram_rready;
        end
        r_hdmi_h    <= r_hdmi_h + o_h_ram_re;
    end
end

//img read request generate
always @ (posedge clk) begin
    if (frst) begin
        r_req_h     <= 9'd0;
        r_fix_h     <= 15'd0;
        r_org_h_vld <= 2'd0;
        r_req_h_vld <= 2'd0;
    end else begin
        if (i_h_ram_vld) begin
            r_req_h <= i_org_h[14:5];
        end else if (r_req_h_vld[0] & (r_req_h < 'd479)) begin
            r_req_h <= r_req_h + 1'b1;
        end
        if (i_h_ram_vld) begin
            r_fix_h <= i_org_h;
        end
        r_org_h_vld <= {r_org_h_vld[0], i_org_h_vld};
        r_req_h_vld <= {r_req_h_vld[0], i_h_ram_vld};
    end
end

//fix image h_buf instance
SYNC_DBUF_16x32_16x32 u_FIX_H_BUF (
    .clk_i          ( clk                       ),
    .a_rst_i        ( frst                      ),
    .rst_busy       (                           ),
    .wdata          ( {r_org_h_vld[0], r_fix_h} ),
    .wr_en_i        ( r_req_h_vld[0]            ),
    .rdata          ( {o_fix_h_vld, o_fix_h}    ),
    .rd_en_i        ( i_fix_h_re                ),
    .full_o         (                           ),
    .empty_o        ( o_fix_h_empty             ),
    .datacount_o    ( s_fix_h_cnt               )
);
assign s_fix_h_pfull    = (s_fix_h_cnt > 'd24);

//RREQ_BUF instance
SYNC_DBUF_16x32_16x32 u_RREQ_BUF 
(
    .clk_i          ( clk                       ),
    .a_rst_i        ( frst                      ),
    .rst_busy       (                           ),
    .wdata          ( {|r_org_h_vld, r_req_h}   ),
    .wr_en_i        ( |r_req_h_vld              ),
    .rdata          ( {s_org_h_vld, s_req_h}    ),
    .rd_en_i        ( s_req_h_re                ),
    .full_o         (                           ),
    .empty_o        ( s_req_h_empty             ),
    .datacount_o    ( s_req_h_cnt               )
);
assign s_req_h_pfull    = (s_req_h_cnt > 'd16);
assign s_req_h_re       = i_read_req_ready & |r_8row_space & ~s_req_h_empty;

//计算8行img空间的当前已存入最大行号
always @ (posedge clk) begin
    if (frst) begin
        r_now_max_h <= 10'h3FF;
    end else begin
        if (o_read_req_vld) begin
            r_now_max_h <= {1'b0,o_read_req_h};
        end
    end
end

//计算8行img空间的可用空间
always @ (posedge clk) begin
    if (frst) begin
        r_8row_space    <= 4'd8;
        r_8row_id       <= 3'd0;
    end else begin
    case ({o_read_req_vld, i_8row_re})
            2'b10   : r_8row_space <= r_8row_space - 1'b1;
            2'b01   : r_8row_space <= r_8row_space + 1'b1;
            default : ;
        endcase
        if (o_read_req_vld) begin
            r_8row_id <= r_8row_id + 1'b1;
        end
    end
end

//8行图像空间内存放数据行号的buf
SYNC_DBUF_16x32_16x32 u_8ROW_H_BUF (
    .clk_i          ( clk                   ),
    .a_rst_i        ( frst                  ),
    .rst_busy       (                       ),
    .wdata          ( {r_8row_id, o_read_req_h} ),
    .wr_en_i        ( o_read_req_vld        ),
    .rdata          ( {o_8row_id, o_8row_h} ),
    .rd_en_i        ( i_8row_re             ),
    .full_o         (                       ),
    .empty_o        ( o_8row_empty          ),
    .datacount_o    (                       )
);

endmodule