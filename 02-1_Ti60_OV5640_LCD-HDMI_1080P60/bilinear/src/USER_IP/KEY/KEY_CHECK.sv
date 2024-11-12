module KEY_CHECK #(
    parameter   CLK_FRAC    =   50        // Unit: MHz
) (
    input               clk             ,
    input               rst             ,
    
    input               i_key           , // FPGA port
    
    output              o_key_pos       ,
    output              o_key_neg       ,
    output              o_key        
);

function integer FUNC_N2W  ;
    input integer   NUM    ;
    integer         WIDTH  ;
    
    begin
        WIDTH = 1;
        while (NUM > (2**WIDTH-1)) begin
            WIDTH = WIDTH + 1;
        end
        FUNC_N2W = WIDTH;
    end
endfunction

localparam LP_20MS_LEN  = CLK_FRAC * 1000 * 20 - 1;
localparam LP_CNT_WIDTH = FUNC_N2W(LP_20MS_LEN);

reg  [3:0]     key_sync_ff;
wire          sync_key;
wire          key_change;

reg                key_valid;
reg  [LP_CNT_WIDTH-1:0]  key_timer;
wire                key_timeout;

reg                key_pos;
reg                key_neg;
reg                key_state;

assign o_key_pos = key_pos;
assign o_key_neg = key_neg;
assign o_key = key_state;

// Async to sync
always @(posedge clk) begin
    key_sync_ff <= {key_sync_ff[2:0], i_key};
end

assign sync_key = key_sync_ff[3];
assign key_change = (key_sync_ff[2] != key_sync_ff[3]);

// Key valid generate
always @(posedge clk) begin
    if (rst) begin
        key_valid <= 1'b1;
        key_timer <= LP_20MS_LEN;
    end else begin
        key_valid <= key_change ? 1'b0        : (key_timeout ? 1'b1 : key_valid);
        key_timer <= key_change ? LP_20MS_LEN : (key_timer != 0 ? key_timer - 1'b1 : key_timer);
    end
end

assign key_timeout = (key_timer == 0);

// Stable key output generate
always @(posedge clk) begin
    key_pos <= key_valid & (sync_key & ~key_sync_ff[2]) ? 1'b1 : 1'b0;
    key_neg <= key_valid & (!sync_key & key_sync_ff[2]) ? 1'b1 : 1'b0;
    key_state <= key_valid & key_sync_ff[2];
end

endmodule