
module BRAM_RW_CTL (
    input               clk             ,
    input               frst            ,
    
    //BRAM write interface
    input   [  2:0]     i_bram_wcnt     , //8 rows
    input   [  7:0]     i_bram_waddr    , //only use (0~639)/4 = 0~159
    input   [127:0]     i_bram_wdata    ,
    input               i_bram_we       ,
    
    //BRAM 2 channel read interface
    input   [ 11:0]     i_ch0_raddr     , //{2-row_id 0 2 4 6, 10-w}, w only use 0~639
    input   [ 11:0]     i_ch1_raddr     , //{2-row_id 1 3 5 7, 10-w}, w only use 0~639
    input               i_bram_re       ,
    output  [ 31:0]     o_ch0_rdata     ,
    output  [ 31:0]     o_ch1_rdata     ,
    output              o_bram_rvld
);

// =========================================================================================================================================
// Signal
// =========================================================================================================================================
//bram write generate
reg                 r_bram0_we      ;
reg                 r_bram1_we      ;
reg                 r_bram_rvld     ;
reg     [  9:0]     r_bram_waddr    ;
reg     [127:0]     r_bram_wdata    ;

// =========================================================================================================================================
// Output generate
// =========================================================================================================================================
assign o_bram_rvld  = r_bram_rvld;

// =========================================================================================================================================
// Logic
// =========================================================================================================================================
//bram write & rvld generate
always @ (posedge clk) begin
    if (frst) begin
        r_bram0_we  <= 1'b0;
        r_bram1_we  <= 1'b0;
        r_bram_rvld <= 1'b0;
    end else begin
        r_bram0_we  <= i_bram_we & ~i_bram_wcnt[0];
        r_bram1_we  <= i_bram_we &  i_bram_wcnt[0];
        r_bram_rvld <= i_bram_re;
    end
    r_bram_waddr <= {i_bram_wcnt[2:1], i_bram_waddr};
    r_bram_wdata <= i_bram_wdata;
end

//bram instance
BRAM_128x1024_32x4096 u_BRAM0_0246 (
    .clk        ( clk               ),
    .reset      ( rst               ),
    .waddr      ( r_bram_waddr      ),
    .wdata_a    ( r_bram_wdata      ),
    .we         ( r_bram0_we        ),
    .raddr      ( i_ch0_raddr       ),
    .re         ( i_bram_re         ),
    .rdata_b    ( o_ch0_rdata       )
);

BRAM_128x1024_32x4096 u_BRAM1_1357 (
    .clk        ( clk               ),
    .reset      ( rst               ),
    .waddr      ( r_bram_waddr      ),
    .wdata_a    ( r_bram_wdata      ),
    .we         ( r_bram1_we        ),
    .raddr      ( i_ch1_raddr       ),
    .re         ( i_bram_re         ),
    .rdata_b    ( o_ch1_rdata       )
);

endmodule