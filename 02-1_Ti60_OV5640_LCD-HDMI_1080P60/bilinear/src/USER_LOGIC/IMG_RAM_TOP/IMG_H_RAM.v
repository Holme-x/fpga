
module IMG_H_RAM (
    //clock & reset
    input               clk             ,
    input               rst             ,
    
    //rate_coe interface
    input   [ 10:0]     i_fix_rate      ,
    input   [ 10:0]     i_rate_coe      , //fix(32*32/fix_rate)
    input               i_rate_coe_vld  ,
    
    //resize param
    output  [ 10:0]     o_rate_coe      ,
    output  [ 15:0]     o_roi_bw        ,
    output  [ 15:0]     o_roi_ew        ,
    
    //H_RAM read interface
    input   [ 10:0]     i_h_ram_raddr   ,
    input               i_h_ram_re      ,
    output              o_org_h_vld     ,
    output  [ 14:0]     o_org_h         , //{10-int,5-frac}
    output              o_h_ram_vld
);

//加载缩放系数，计算缩放后的size
reg     [ 20:0]     r_resize_width  ;
reg     [ 20:0]     r_resize_height ;
reg     [ 10:0]     r_fix_rate      ;
reg     [ 10:0]     r_rate_coe      ;
reg                 r_resize_vld    ;
wire    [ 15:0]     s_resize_width  ;
wire    [ 15:0]     s_resize_height ;

//计算图像在hdmi图像中的起止坐标
reg     [ 15:0]     r_roi_bw        ;
reg     [ 15:0]     r_roi_ew        ;
reg     [ 15:0]     r_roi_bh        ;
reg     [ 15:0]     r_roi_eh        ;
reg                 r_bw_vld        ;

//遍历hmid的每一行，生成行号
reg     [ 15:0]     r_h             ;
reg                 r_h_vld         ;

//由行号计算需要读取的原图起始行号
reg                 r_img_h_vld     ;
reg                 r_org_h_vld     ;
reg     [  1:0]     r_roi_vld       ;
reg     [ 15:0]     r_img_h         ;
reg     [ 15:0]     r_org_h         ;
wire                s_roi_vld       ;

//IMG_H bram
reg     [ 10:0]     r_ram_waddr     ;
wire    [ 15:0]     s_ram_wdata     ;
wire    [ 15:0]     s_ram_rdata     ;

//ram read output
reg                 r_ram_rvld      ;

// =========================================================================================================================================
// Output generate
// =========================================================================================================================================
assign o_rate_coe   = r_rate_coe;
assign o_roi_bw     = r_roi_bw;
assign o_roi_ew     = r_roi_ew;
assign {o_org_h_vld, o_org_h} = s_ram_rdata;
assign o_h_ram_vld  = r_ram_rvld;

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//加载缩放系数，计算缩放后的size
always @ (posedge clk) begin
    if (rst) begin
        r_resize_width[20:5]    <= 640;
        r_resize_width[4:0]     <= 5'd0;
        r_resize_height[20:5]   <= 480;
        r_resize_height[4:0]    <= 5'd0;
        r_fix_rate              <= 11'd0;
        r_rate_coe              <= 11'd0;
        r_resize_vld            <= 1'b0;
    end else begin
        if (i_rate_coe_vld) begin
            r_resize_width  <= 640 * i_fix_rate;
            r_resize_height <= 480 * i_fix_rate;
            r_fix_rate      <= i_fix_rate;
            r_rate_coe      <= i_rate_coe;
        end
        r_resize_vld    <= i_rate_coe_vld;
    end
end
assign s_resize_width  = r_resize_width[20:5];
assign s_resize_height = r_resize_height[20:5];

//计算图像在hdmi图像中的起止坐标
always @ (posedge clk) begin
    if (rst) begin
        r_roi_bw    <= 16'd0;
        r_roi_ew    <= 16'd0;
        r_roi_bh    <= 16'd0;
        r_roi_eh    <= 16'd0;
        r_bw_vld    <= 1'b0;
    end else begin
        if (r_resize_vld) begin
            r_roi_bw    <= 1920/2 - s_resize_width[15:1];
            r_roi_ew    <= 1920/2 + s_resize_width[15:1] - 1;
            r_roi_bh    <= 1080/2 - s_resize_height[15:1];
            r_roi_eh    <= 1080/2 + s_resize_height[15:1] - 1;
        end
        r_bw_vld    <= r_resize_vld;
    end
end

//遍历hmid的每一行，生成行号
always @ (posedge clk) begin
    if (rst) begin
        r_h     <= 16'd0;
        r_h_vld <= 1'b0;
    end else begin
        if (r_bw_vld) begin
            r_h <= 'd0;
        end else if (r_h_vld) begin
            r_h <= r_h + 1'b1;
        end
        if (r_bw_vld) begin
            r_h_vld <= 1'b1;
        end else if (r_h == 1080-1) begin
            r_h_vld <= 1'b0;
        end
    end
end

//由行号计算需要读取的原图起始行号
always @ (posedge clk) begin
    if (rst) begin
        r_img_h_vld <= 1'b0;
        r_org_h_vld <= 1'b0;
        r_roi_vld   <= 2'd0;
    end else begin
        r_img_h_vld <= r_h_vld;
        r_org_h_vld <= r_img_h_vld;
        r_roi_vld   <= {r_roi_vld[0], s_roi_vld};
    end
    r_img_h <= r_h - r_roi_bh;
    r_org_h <= r_img_h * r_rate_coe;
end
assign s_roi_vld = (r_roi_bh[15] | (r_h >= r_roi_bh)) && (~r_roi_eh[15] & (r_h <= r_roi_eh));

//把读取img图像的行号写入ram
always @ (posedge clk) begin
    if (rst) begin
        r_ram_waddr <= 11'd0;
    end else begin
        if (r_bw_vld) begin
            r_ram_waddr <= 11'd0;
        end else if (r_org_h_vld) begin
            r_ram_waddr <= r_ram_waddr + 1'b1;
        end
    end
end
assign s_ram_wdata = {r_roi_vld[1], r_org_h[14:0]};

//IMG_H bram
BRAM_16x2048 u_BRAM_16x2048 
(
    .clk        ( clk               ),
    .reset      ( rst               ),
    .waddr      ( r_ram_waddr       ),
    .wdata_a    ( s_ram_wdata       ),
    .we         ( r_org_h_vld       ),
    .raddr      ( i_h_ram_raddr     ),
    .re         ( i_h_ram_re        ),
    .rdata_b    ( s_ram_rdata       )
);

//ram read output
always @ (posedge clk) begin
    if (rst) begin
        r_ram_rvld  <= 1'b0;
    end else begin
        r_ram_rvld  <= i_h_ram_re;
    end
end

endmodule