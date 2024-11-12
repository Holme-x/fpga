
module HDMI_IMAGE (
    //clock & reset
    input               clk             ,
    input               frst            ,
    
    //resize param
    input   [ 10:0]     i_rate_coe      ,
    input   [ 15:0]     i_roi_bw        ,
    input   [ 15:0]     i_roi_ew        ,
    
    input   [ 14:0]     i_fix_h         , //{10-int,5-frac}
    input               i_fix_h_vld     ,
    input               i_fix_h_empty   ,
    output              o_fix_h_re      ,

    input   [  2:0]     i_8row_id       ,
    input   [  8:0]     i_8row_h        ,
    input               i_8row_empty    ,
    output              o_8row_re       ,
    
    //BRAM 2 channel read interface
    output  [ 11:0]     o_ch0_raddr     , //{2-row_id 0 2 4 6, 10-w}, w only use 0~639
    output  [ 11:0]     o_ch1_raddr     , //{2-row_id 1 3 5 7, 10-w}, w only use 0~639
    output              o_bram_re       ,
    input   [ 31:0]     i_ch0_rdata     ,
    input   [ 31:0]     i_ch1_rdata     ,
    input               i_bram_rvld     ,
    
    //hdmi image interface
    input               pixel_clk       ,
    output  [ 23:0]     o_pixel_rgb     ,
    input               i_pixel_re
);

localparam  ST_IDLE     = 4'b0001   ,
            ST_WR_0     = 4'b0010   ,
            ST_WR_RGB   = 4'b0100   ,
            ST_WAIT     = 4'b1000   ;

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
//读取定点h坐标，启动生成1行hdmi图像
reg                 r_module_busy   ;
reg     [  8:0]     r_int_h         ;
reg     [  4:0]     r_frac_h        ;
reg                 r_fix_h_vld     ;
wire                s_0_wdone       ;

//hdmi一行都不需要读img图时的置0操作
reg     [ 10:0]     r_wr0_size      ;
reg                 r_wr0_en        ;
wire                s_wr0_en        ;

//hdmi需要读img时的状态机
reg     [  3:0]     r_state         ;

//wait counter
reg     [  3:0]     r_wait_cnt      ;
reg                 r_wait_done     ;
reg     [  3:0]     r_last_state    ;
reg                 r_rgb_wdone     ;

//hdmi检查读取8行img空间的行号
reg                 r_8row_rreq         ;
reg                 r_8row_id_vld       ;
reg     [  2:0]     r_up_id             ;
reg     [  2:0]     r_dn_id             ;
reg     [  1:0]     r_ch0_id            ;
reg     [  1:0]     r_ch1_id            ;
wire                s_8row_check        ;
wire                s_8row_check_done   ;

//hdmi需要读img时，每个像素从bram中读取同时上下两行，1个像素需要读2个值，合计4个像素
reg     [ 10:0]     r_hdmi_w            ;
reg                 r_pixel2_en         ;
reg     [  2:0]     r_pixel2_flag       ;
reg     [  2:0]     r_bram_re           ;
reg     [ 10:0]     r_img_w             ;
reg     [ 15:0]     r_org_w             ;
reg     [  9:0]     r_int_w             ;
reg     [  4:0]     r_frac_w            ;
reg     [  9:0]     r_int_w1            ;
wire                s_rgb_wr0           ;
wire                s_rgb_wr            ;
wire                s_hdmi_en           ;
wire    [  9:0]     s_bram_raddr        ;
wire                s_rgb_rlast         ;

//rgb读回数据处理
reg                 r_dn_vld            ;
reg                 r_4pixel_vld        ;
reg     [  4:0]     r_frac_w_d0         ;
reg     [  4:0]     r_frac_w_d1         ;
reg     [  4:0]     r_frac_w_d2         ;
reg     [  7:0]     r_up_b0, r_up_g0, r_up_r0;
reg     [  7:0]     r_dn_b0, r_dn_g0, r_dn_r0;
reg     [  7:0]     r_up_b1, r_up_g1, r_up_r1;
reg     [  7:0]     r_dn_b1, r_dn_g1, r_dn_r1;

//INTERPOLATION RGB
wire    [  7:0]     s_r, s_g, s_b       ;
wire                s_rgb_vld           ;

//rgb obuf
reg     [ 23:0]     r_rgb_wdata         ;
reg                 r_rgb_we            ;
wire    [  9:0]     s_rgb_cnt           ;
wire                s_rgb_pfull         ;
reg                 r_rgb_pfull         ;

// =========================================================================================================================================
// Output generate
// =========================================================================================================================================
assign o_fix_h_re   = ~i_fix_h_empty & ~r_module_busy;

assign o_8row_re    = s_8row_check & (r_int_h > i_8row_h);

assign o_ch0_raddr  = {r_ch0_id, s_bram_raddr};
assign o_ch1_raddr  = {r_ch1_id, s_bram_raddr};
assign o_bram_re    = r_bram_re[2];

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//读取定点h坐标，启动生成1行hdmi图像
always @ (posedge clk) begin
    if (frst) begin
        r_module_busy   <= 1'b0;
        r_int_h         <= 9'd0;
        r_frac_h        <= 5'd0;
        r_fix_h_vld     <= 1'b0;
    end else begin
        if (o_fix_h_re) begin
            r_module_busy   <= 1'b1;
        end else if (s_0_wdone | r_rgb_wdone) begin
            r_module_busy   <= 1'b0;
        end
        if (o_fix_h_re & i_fix_h_vld) begin
            r_int_h     <= i_fix_h[13:5];
            r_frac_h    <= (i_fix_h[13:5] == 'd479) ? 'd0 : i_fix_h[4:0];
            {r_int_h,r_frac_h}  <= i_fix_h;
        end
        r_fix_h_vld <= o_fix_h_re & i_fix_h_vld;
    end
end
assign s_0_wdone = s_wr0_en & (r_wr0_size == 'd1);

//hdmi一行都不需要读img图时的置0操作
always @ (posedge clk) begin
    if (frst) begin
        r_wr0_size  <= 11'd0;
        r_wr0_en    <= 1'b0;
    end else begin
        if (o_fix_h_re & ~i_fix_h_vld) begin
            r_wr0_size  <= 11'd1920;
        end else if (s_wr0_en) begin
            r_wr0_size  <= r_wr0_size - 1'b1;
        end
    end
end
assign s_wr0_en = |r_wr0_size & ~r_rgb_pfull;

//hdmi需要读img时的状态机
always @ (posedge clk) begin
    if (frst) begin
        r_state <= ST_IDLE;
    end else begin
        case (r_state)
            ST_IDLE     : begin
                if (s_8row_check_done) begin
                    if (i_roi_bw[15] | (i_roi_bw == 'd0)) begin //bw <= 0
                        r_state <= ST_WR_RGB;
                    end else begin
                        r_state <= ST_WR_0;
                    end
                end
            end
            ST_WR_0     : begin
                if (s_rgb_wr0) begin
                    if (r_hdmi_w == i_roi_bw-1) begin
                        r_state <= ST_WR_RGB;
                    end else if (r_hdmi_w == 'd1919) begin
                        r_state <= ST_IDLE;
                    end
                end
            end
            ST_WR_RGB   : begin
                if (s_rgb_rlast) begin
                    r_state <= ST_WAIT;
                end
            end
            ST_WAIT     : begin
                if (r_wait_done) begin
                    r_state <= (r_hdmi_w == 'd1920) ? ST_IDLE : ST_WR_0;
                end
            end
            default     : ;
        endcase
    end
end

//wait counter
always @ (posedge clk) begin
    if (frst) begin
        r_wait_cnt      <= 4'd0;
        r_wait_done     <= 1'b0;
        r_last_state    <= ST_IDLE;
        r_rgb_wdone     <= 1'b0;
    end else begin
        if (r_state == ST_WAIT) begin
            r_wait_cnt  <= r_wait_cnt + 1'b1;
        end else begin
            r_wait_cnt  <= 4'd0;
        end
        r_wait_done     <= &r_wait_cnt;
        r_last_state    <= r_state;
        r_rgb_wdone     <= (r_last_state != ST_IDLE) & (r_state == ST_IDLE);
    end
end

//hdmi检查读取8行img空间的行号
always @ (posedge clk) begin
    if (frst) begin
        r_8row_rreq     <= 1'b0;
        r_8row_id_vld   <= 1'b0;
    end else begin
        if (r_fix_h_vld) begin
            r_8row_rreq <= 1'b1;
        end else if (s_8row_check_done) begin
            r_8row_rreq <= 1'b0;
        end
        r_8row_id_vld   <= s_8row_check_done;
    end
    if (s_8row_check_done) begin
        r_up_id <= i_8row_id;
        r_dn_id <= i_8row_id + 1'b1;
    end
    r_ch0_id    <= r_up_id[0] ? r_dn_id[2:1] : r_up_id[2:1];
    r_ch1_id    <= r_dn_id[0] ? r_up_id[2:1] : r_dn_id[2:1];
end
assign s_8row_check         = r_8row_rreq & ~i_8row_empty;
assign s_8row_check_done    = s_8row_check & (r_int_h == i_8row_h);

//hdmi需要读img时，每个像素从bram中读取同时上下两行，1个像素需要读2个值，合计4个像素
always @ (posedge clk) begin
    if (frst) begin
        r_hdmi_w        <= 11'd0;
        r_pixel2_en     <= 1'b0;
        r_pixel2_flag   <= 3'd0;
        r_bram_re       <= 3'd0;
    end else begin
        if (s_8row_check_done) begin
            r_hdmi_w    <= 'd0;
        end else if (s_hdmi_en) begin
            r_hdmi_w    <= r_hdmi_w + 1'b1;
        end
        if (s_rgb_wr) begin
            r_pixel2_en <= ~r_pixel2_en;
        end
        r_pixel2_flag   <= {r_pixel2_flag[1:0],r_pixel2_en};
        r_bram_re       <= {r_bram_re[1:0], s_rgb_wr};
    end
    r_img_w         <= r_hdmi_w - i_roi_bw;             //r_pixel2_flag[0]
    r_org_w         <= r_img_w * i_rate_coe;            //r_pixel2_flag[1]
    r_int_w         <= r_org_w[14:5];                   //r_pixel2_flag[2]
    r_frac_w        <= (r_org_w[14:5] == 'd639) ? 'd0 : r_org_w[4:0];
    r_int_w1        <= r_int_w + 1'b1;                  //r_pixel2_flag[2]
end
assign s_rgb_wr0    = (r_state == ST_WR_0) & ~r_rgb_pfull;
assign s_rgb_wr     = (r_state == ST_WR_RGB) & ~r_rgb_pfull;
assign s_hdmi_en    = s_rgb_wr0 | (s_rgb_wr & r_pixel2_en);
assign s_bram_raddr = r_pixel2_flag[2] ? r_int_w1 : r_int_w;
assign s_rgb_rlast  = r_pixel2_en & ((r_hdmi_w == i_roi_ew) | (r_hdmi_w == 'd1919));

//rgb读回数据处理
always @ (posedge clk) begin
    if (frst) begin
        r_dn_vld        <= 1'b0;
        r_4pixel_vld    <= 1'b0;
    end else begin
        if (s_8row_check_done) begin
            r_dn_vld    <= 1'b0;
        end else if (i_bram_rvld) begin
            r_dn_vld    <= ~r_dn_vld;
        end
        r_4pixel_vld    <= i_bram_rvld & r_dn_vld;
    end
    r_frac_w_d0 <= r_frac_w;            //i_bram_rvld
    if (i_bram_rvld) begin
        r_frac_w_d1 <= r_frac_w_d0;     //r_dn_vld
        r_frac_w_d2 <= r_frac_w_d1;     //r_4pixel_vld
    end
    if (~r_dn_vld) begin
        {r_up_r0, r_up_g0, r_up_b0} <= r_up_id[0] ? i_ch1_rdata[23:0] : i_ch0_rdata[23:0];
        {r_dn_r0, r_dn_g0, r_dn_b0} <= r_dn_id[0] ? i_ch1_rdata[23:0] : i_ch0_rdata[23:0];
    end
    if (r_dn_vld) begin
        {r_up_r1, r_up_g1, r_up_b1} <= r_up_id[0] ? i_ch1_rdata[23:0] : i_ch0_rdata[23:0];
        {r_dn_r1, r_dn_g1, r_dn_b1} <= r_dn_id[0] ? i_ch1_rdata[23:0] : i_ch0_rdata[23:0];
    end
end

//INTERPOLATION RGB
nearest u_R (
    .clk        ( clk           ),
    .rst        ( frst          ),
    .frac_h     ( r_frac_h      ),
    .frac_w     ( r_frac_w_d2   ),
    .d0         ( r_up_r0       ),
    .d1         ( r_up_r1       ),
    .d2         ( r_dn_r0       ),
    .d3         ( r_dn_r1       ),
    .i_vld      ( r_4pixel_vld  ),
    .o_d        ( s_r           ),
    .o_vld      ( s_rgb_vld     )
);

nearest u_G (
    .clk        ( clk           ),
    .rst        ( frst          ),
    .frac_h     ( r_frac_h      ),
    .frac_w     ( r_frac_w_d2   ),
    .d0         ( r_up_g0       ),
    .d1         ( r_up_g1       ),
    .d2         ( r_dn_g0       ),
    .d3         ( r_dn_g1       ),
    .i_vld      ( r_4pixel_vld  ),
    .o_d        ( s_g           ),
    .o_vld      (               )
);

nearest u_B (
    .clk        ( clk           ),
    .rst        ( frst          ),
    .frac_h     ( r_frac_h      ),
    .frac_w     ( r_frac_w_d2   ),
    .d0         ( r_up_b0       ),
    .d1         ( r_up_b1       ),
    .d2         ( r_dn_b0       ),
    .d3         ( r_dn_b1       ),
    .i_vld      ( r_4pixel_vld  ),
    .o_d        ( s_b           ),
    .o_vld      (               )
);

//rgb write generate
always @ (posedge clk) begin
    if (frst) begin
        r_rgb_wdata <= 24'd0;
        r_rgb_we    <= 1'b0;
    end else begin
        if (s_rgb_vld) begin
            r_rgb_wdata <= {s_r, s_g, s_b};
        end else begin
            r_rgb_wdata <= 'd0;
        end
        r_rgb_we    <= s_wr0_en | s_rgb_wr0 | s_rgb_vld;
    end
end

//rgb obuf
ASYNC_BBUF_16x1024_16x1024 u_OBUF (
    .wr_clk_i       ( clk                   ),
    .rd_clk_i       ( pixel_clk             ),
    .a_rst_i        ( frst                  ),
    .rst_busy       (                       ),
    .wdata          ( r_rgb_wdata           ),
    .wr_en_i        ( r_rgb_we              ),
    .rdata          ( o_pixel_rgb           ),
    .rd_en_i        ( i_pixel_re            ),
    .full_o         (                       ),
    .empty_o        (                       ),
    .wr_datacount_o ( s_rgb_cnt             ),
    .rd_datacount_o (                       )
);
//注意：实际调试发现此处必须打拍使用才行，直接使用s_rgb_cnt[9]作为pfull信号会出现异常
//抓取信号时，在state从ST_WR_0变为IDLE时，hdmi_w=1918，怀疑是时序问题，但是时序未报错
always @ (posedge clk) begin
    r_rgb_pfull <= s_rgb_cnt[9];        //s_obuf_cnt >= 512
end

//debug
reg     [ 10:0]     r_o_h;
reg     [ 10:0]     r_o_w;
reg     [  7:0]     r_debug_data;
reg     [ 31:0]     r_sum;
always @ (posedge clk) begin
    if (frst) begin
        r_o_h           <= 11'd0;
        r_o_w           <= 11'd0;
        r_debug_data    <= 8'd0;
        r_sum           <= 32'd0;
    end else begin
        if (r_rgb_we) begin
            if (r_o_w == 'd1919) begin
                r_o_w   <= 'd0;
                r_o_h   <= r_o_h + 1'b1;
            end else begin
                r_o_w   <= r_o_w + 1'b1;
            end
        end
        if (s_rgb_vld) begin
            r_debug_data <= s_r;
        end else begin
            r_debug_data <= 8'd0;
        end
        if (r_rgb_we) begin
            r_sum   <= r_sum + r_debug_data;
        end
    end
end


endmodule

module nearest (
    input               clk     ,
    input               rst     ,
    input   [  4:0]     frac_h  ,
    input   [  4:0]     frac_w  ,
    input   [  7:0]     d0      , // 上左
    input   [  7:0]     d1      , // 上右
    input   [  7:0]     d2      , // 下左
    input   [  7:0]     d3      , // 下右
    input               i_vld   ,
    output  [  7:0]     o_d     , // 输出最近邻插值结果
    output              o_vld
);

reg [7:0] nearest_pixel;

// 使用最近邻插值的条件判断
always @ (posedge clk) begin
    if (rst) begin
        nearest_pixel <= 8'd0;
    end else if (i_vld) begin
        if (frac_h < 16) begin
            // 水平偏移较小，选择上方像素
            if (frac_w < 16) begin
                nearest_pixel <= d0; // 左侧像素
            end else begin
                nearest_pixel <= d1; // 右侧像素
            end
        end else begin
            // 水平偏移较大，选择下方像素
            if (frac_w < 16) begin
                nearest_pixel <= d2; // 左侧像素
            end else begin
                nearest_pixel <= d3; // 右侧像素
            end
        end
    end
end

assign o_d = nearest_pixel;
assign o_vld = i_vld;

endmodule