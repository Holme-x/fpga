module img_ram_rsize_verti (
    //clock & reset
    input               clk             ,
    input               rst             ,
    
    //rate_coe interface
    input   [10:0]     i_fix_rate      ,
    input   [10:0]     i_rate_coe      ,
    input               i_rate_coe_vld  ,
    
    //resize param
    output  [10:0]     o_rate_coe      ,
    output  [15:0]     o_roi_bw        ,
    output  [15:0]     o_roi_ew        ,
    
    //H_RAM read interface
    input   [10:0]     i_h_ram_raddr   ,
    input               i_h_ram_re      ,
    output              o_org_h_vld     ,
    output  [14:0]     o_org_h         , //{10-int,5-frac}
    output              o_h_ram_vld
);

// Signal
reg     [20:0]     resize_width       ;
reg     [20:0]     resize_height      ;
reg     [10:0]     fix_rate          ;
reg     [10:0]     rate_coe          ;
reg                 resize_vld        ;
wire    [15:0]     resize_width_val   ;
wire    [15:0]     resize_height_val  ;

// Calculate ROI coordinates
reg     [15:0]     roi_bw            ;
reg     [15:0]     roi_ew            ;
reg     [15:0]     roi_bh            ;
reg     [15:0]     roi_eh            ;
reg                 roi_vld          ;

// Generate line numbers for HDMI
reg     [15:0]     h_count           ;
reg                 h_count_vld       ;

// Calculate the starting line number of the original image to be read
reg                 img_h_vld        ;
reg                 org_h_vld        ;
reg     [1:0]       roi_vld_h          ;
reg     [15:0]     img_h            ;
reg     [15:0]     org_h            ;
wire               s_roi_vld        ;

// IMG_H BRAM
reg     [10:0]     ram_waddr        ;
wire    [15:0]     ram_wdata       ;
wire    [15:0]     ram_rdata       ;

// RAM read output
reg                 ram_rvld         ;

// Output generate
assign o_rate_coe   = rate_coe;
assign o_roi_bw      = roi_bw;
assign o_roi_ew      = roi_ew;
assign {o_org_h_vld, o_org_h} = ram_rdata;
assign o_h_ram_vld   = ram_rvld;

// =========================================================================================================================================

// Calculate resize width and height based on rate
always @ (posedge clk) begin
    if (rst) begin
        resize_width[20:5]    <= 640;
        resize_width[4:0]     <= 5'd0;
        resize_height[20:5]   <= 480;
        resize_height[4:0]    <= 5'd0;
        fix_rate              <= 11'd0;
        rate_coe              <= 11'd0;
        resize_vld            <= 1'b0;
    end else if (i_rate_coe_vld) begin
        resize_width  <= 640 * i_fix_rate;
        resize_height <= 480 * i_fix_rate;
        fix_rate      <= i_fix_rate;
        rate_coe      <= i_rate_coe;
    end
    resize_vld    <= i_rate_coe_vld;
end

assign resize_width_val  = resize_width[20:5];
assign resize_height_val = resize_height[20:5];

// Calculate ROI coordinates
always @ (posedge clk) begin
    if (rst) begin
        roi_bw    <= 16'd0;
        roi_ew    <= 16'd0;
        roi_bh    <= 16'd0;
        roi_eh    <= 16'd0;
        roi_vld  <= 1'b0;
    end else if (resize_vld) begin
        roi_bw    <= 1920/2 - resize_width_val[15:1];
        roi_ew    <= 1920/2 + resize_width_val[15:1] - 1;
        roi_bh    <= 1080/2 - resize_height_val[15:1];
        roi_eh    <= 1080/2 + resize_height_val[15:1] - 1;
    end
    roi_vld  <= resize_vld;
end

// Generate line numbers for HDMI
always @ (posedge clk) begin
    if (rst) begin
        h_count     <= 16'd0;
        h_count_vld <= 1'b0;
    end else if (roi_vld) begin
        h_count <= 'd0;
        h_count_vld <= 1'b1;
    end else if (h_count_vld && h_count != 1080-1) begin
        h_count <= h_count + 1'b1;
    end else begin
        h_count_vld <= 1'b0;
    end
end

// Calculate the starting line number of the original image to be read
always @ (posedge clk) begin
    if (rst) begin
        img_h_vld <= 1'b0;
        org_h_vld <= 1'b0;
        roi_vld_h   <= 2'd0;
    end else if (h_count_vld) begin
        img_h_vld <= 1'b1;
        org_h_vld <= 1'b1;
        roi_vld_h   <= {roi_vld_h[0], s_roi_vld};
    end
    img_h <= h_count - roi_bh;
    org_h <= img_h * rate_coe;
end

assign s_roi_vld = (roi_bh[15] | (h_count >= roi_bh)) && (~roi_eh[15] | (h_count <= roi_eh));

// Write the line number of the image to be read into RAM
always @ (posedge clk) begin
    if (rst) begin
        ram_waddr <= 11'd0;
    end else if (roi_vld) begin
        ram_waddr <= 11'd0;
    end else if (org_h_vld) begin
        ram_waddr <= ram_waddr + 1'b1;
    end
end
assign ram_wdata = {roi_vld_h[1], org_h[14:0]};

// Instantiate BRAM
BRAM_16x2048 u_BRAM_16x2048 (
    .clk        ( clk               ),
    .reset      ( rst               ),
    .waddr      ( ram_waddr         ),
    .wdata_a    ( ram_wdata         ),
    .we         ( org_h_vld         ),
    .raddr      ( i_h_ram_raddr     ),
    .re         ( i_h_ram_re        ),
    .rdata_b    ( ram_rdata         )
);

// RAM read output
always @ (posedge clk) begin
    if (rst) begin
        ram_rvld  <= 1'b0;
    end else begin
        ram_rvld  <= i_h_ram_re;
    end
end

endmodule