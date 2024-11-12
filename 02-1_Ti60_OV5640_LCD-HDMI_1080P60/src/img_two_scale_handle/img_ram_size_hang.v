module img_ram_size_hang (
    //clock & reset
    input               clk                 ,
    input               rst                 ,
                                              
    //H_RAM read interface                  
    output  [ 10:0]     h_ram_addr         ,
    output              h_ram_rd           ,
    input               img_h_vld          ,
    input   [ 14:0]     img_h_data         , //{10-int,5-frac}
    input               h_ram_data_vld     ,
    
    //img read request
    input               read_req_rdy       ,
    output  [  8:0]     read_req_h        ,
    output              read_req_vld       , //Dependent on ready, single-shot valid
    
    //
    output  [ 14:0]     fix_h             , //{10-int,5-frac}
    output              fix_h_vld         ,
    output              fix_h_empty       ,
    input               fix_h_rdy         ,
    
    //
    output  [  2:0]     row_id            ,
    output  [  8:0]     row_h             ,
    output              row_empty         ,
    input               row_rdy
);

// Signal
reg     [ 10:0]     h_count            ;
reg                 h_rd              ;
reg                 h_rdy             ;

reg     [  8:0]     req_h             ;
reg     [ 14:0]     fix_h_data        ;
reg     [  1:0]     h_vld             ;
reg     [  1:0]     req_vld           ;

wire    [  5:0]     fix_h_buf_cnt     ;
wire                fix_h_buf_full    ;

wire                req_h_vld_out     ; 
wire    [  8:0]      req_h_out         ;
wire                req_h_rd          ;
wire                req_h_buf_empty   ;
wire    [  5:0]      req_h_buf_cnt     ;
wire                req_h_buf_full    ;

reg     [  9:0]     max_h_stored      ;

reg     [  3:0]     row_space          ;
reg     [  2:0]     row_id_reg         ;

// Output generate
assign h_ram_addr    = h_count;
assign h_ram_rd       = h_rd & h_rdy & ~fix_h_buf_full & ~req_h_buf_full;

assign read_req_h     = req_h_out;
assign read_req_vld   = req_h_rd & req_h_vld_out & (max_h_stored[9] | (req_h_out > max_h_stored[8:0]));

// HDMI h counter
always @ (posedge clk) begin
    if (rst) begin
        h_count        <= 11'd0;
        h_rd           <= 1'b0;
        h_rdy         <= 1'b0;
    end else begin
        h_rd <= (h_count == 11'd0);
        if (h_rd & (h_count == 1080-1)) begin
            h_rd <= 1'b0;
        end
        h_count <= h_count + h_rd;
        h_rdy <= ~h_rdy;
    end
end

//img read request generate
always @ (posedge clk) begin
    if (rst) begin
        req_h     <= 9'd0;
        fix_h_data <= 15'd0;
        h_vld     <= 2'd0;
        req_vld   <= 2'd0;
    end else begin
        if (h_ram_data_vld) begin
            req_h <= img_h_data[14:5];
            fix_h_data <= img_h_data;
        end
        if (req_vld[0] & (req_h < 9'd479)) begin
            req_h <= req_h + 1'b1;
        end
        h_vld <= {h_vld[0], img_h_vld};
        req_vld <= {req_vld[0], h_ram_data_vld};
    end
end

assign req_h_buf_full    = (req_h_buf_cnt > 6'd16);
assign req_h_rd       = read_req_rdy & |row_space & ~req_h_buf_empty;

// Calculate the current maximum row number stored in the 8-row img space
always @ (posedge clk) begin
    if (rst) begin
        max_h_stored <= 10'h3FF;
    end else if (read_req_vld) begin
        max_h_stored <= {1'b0, read_req_h};
    end
end

// Calculate the available space in the 8-row img space
always @ (posedge clk) begin
    if (rst) begin
        row_space    <= 4'd8;
        row_id_reg  <= 3'd0;
    end else begin
        if (read_req_vld) begin
            row_space <= row_space - 1'b1;
        end
        if (row_rdy) begin
            row_space <= row_space + 1'b1;
        end
        if (read_req_vld) begin
            row_id_reg <= row_id_reg + 1'b1;
        end
    end
end

assign fix_h_buf_full    = (fix_h_buf_cnt > 6'd24);

//fix image h_buf instance
BARM_GET_hang_Handle BARM_GET_hang_Handle_inst_A (
    .clk_i          ( clk                       ),
    .a_rst_i        ( rst                      ),
    .rst_busy       (                           ),
    .wdata          ( {h_vld[0], fix_h_data} ),
    .wr_en_i        ( req_vld[0]            ),
    .rdata          ( {fix_h_vld, fix_h}    ),
    .rd_en_i        ( fix_h_rdy                ),
    .full_o         (                           ),
    .empty_o        ( fix_h_empty             ),
    .datacount_o    ( fix_h_buf_cnt               )
);

//RREQ_BUF instance
BARM_GET_hang_Handle BARM_GET_hang_Handle_inst_B (
    .clk_i          ( clk                       ),
    .a_rst_i        ( rst                      ),
    .rst_busy       (                           ),
    .wdata          ( {|h_vld, req_h}   ),
    .wr_en_i        ( |req_vld              ),
    .rdata          ( {req_h_vld_out, req_h_out}    ),
    .rd_en_i        ( req_h_rd                ),
    .full_o         (                           ),
    .empty_o        ( req_h_buf_empty             ),
    .datacount_o    ( req_h_buf_cnt               )
);

//8行图像空间内存放数据行号的buf
BARM_GET_hang_Handle BARM_GET_hang_Handle_inst_C (
    .clk_i          ( clk                   ),
    .a_rst_i        ( rst                  ),
    .rst_busy       (                       ),
    .wdata          ( {row_id_reg, read_req_h} ),
    .wr_en_i        ( read_req_vld        ),
    .rdata          ( {row_id, row_h} ),
    .rd_en_i        ( row_rdy             ),
    .full_o         (                       ),
    .empty_o        ( row_empty          ),
    .datacount_o    (                       )
);

endmodule