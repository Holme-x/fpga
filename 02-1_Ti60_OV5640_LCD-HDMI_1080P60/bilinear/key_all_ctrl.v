module key_all_ctrl #(
    parameter   CLK_FRAC    = 148  // Unit: MHz
) (
    input               clk             ,
    input               rst             ,
    input               key_small       , // i_key_n[1]
    input               key_big         , // i_key_n[0]
    input               o_uart_tx_done  , // 串口使能信号
    output reg          s_small_n       , // 缩小信号
    output reg          s_big_n         , // 放大信号
    output reg          s_timer_done    , // 表示计时是否完成
    input   [7:0]      i_user_rx_data,  // UART接收到的数据
    input               i_user_rx_valid // UART接收到的数据有效信号
);

// State definitions
parameter  IDLE        = 3'd0,
           UART_CTRL   = 3'd1, // 按键每隔10s翻转
           KEY_SM_CTRL = 3'd2, // 缩小控制
           KEY_BI_CTRL = 3'd3, // 放大控制
           TRAG_KEY    = 3'd4;

// Timer logic
parameter TIMER_10S = CLK_FRAC * 1000 * 1000 * 10; // 10 seconds timer value

reg [2:0] state;

// Signal
reg [31:0] cnt_time_1s;
reg [3:0] key_sync_ff;
wire sync_key;
wire key_change;
reg key_valid;
reg [LP_CNT_WIDTH-1:0] key_timer;
wire key_timeout;
reg key_pos;
reg key_neg;
reg key_state;

// Function to calculate the number of bits required to represent a number
function integer FUNC_N2W;
    input integer NUM;
    integer WIDTH;
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

// Output logic
assign sync_key = key_sync_ff[3];
assign key_change = (key_sync_ff[2] != key_sync_ff[3]);

always @(posedge clk) begin
    if (rst) begin
        key_sync_ff <= 4'b1111;
        key_valid <= 1'b0;
        key_timer <= LP_20MS_LEN;
    end else begin
        key_sync_ff <= {key_sync_ff[2:0], i_user_rx_data[7]}; // Use the 8th bit of UART data as the key input
        key_valid <= key_change ? 1'b0 : (key_timeout ? 1'b1 : key_valid);
        key_timer <= key_change ? LP_20MS_LEN : (key_timer != 0 ? key_timer - 1'b1 : key_timer);
    end
end

assign key_timeout = (key_timer == 0);

// Stable key output generate
always @(posedge clk) begin
    if (rst) begin
        key_pos <= 1'b0;
        key_neg <= 1'b0;
        key_state <= 1'b0;
    end else begin
        key_pos <= key_valid & (sync_key & ~key_sync_ff[2]);
        key_neg <= key_valid & (!sync_key & key_sync_ff[2]);
        key_state <= key_valid & key_sync_ff[2];
    end
end

// Main state machine logic
always @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (o_uart_tx_done) begin
                    state <= TRAG_KEY;
                end else if (~key_small) begin
                    state <= KEY_SM_CTRL;
                end else if (~key_big) begin
                    state <= KEY_BI_CTRL;
                end
            end
            TRAG_KEY: begin
                state <= UART_CTRL;
            end
            UART_CTRL: begin
                if (~o_uart_tx_done || ~key_small || ~key_big) begin
                    state <= IDLE;
                end
            end
            KEY_SM_CTRL: begin
                if (~key_small) begin
                    state <= KEY_SM_CTRL;
                end else begin
                    state <= IDLE;
                end
            end
            KEY_BI_CTRL: begin
                if (~key_big) begin
                    state <= KEY_BI_CTRL;
                end else begin
                    state <= IDLE;
                end
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Output logic based on state
always @(*) begin
    case (state)
        IDLE: begin
            s_small_n = 1'b1;
            s_big_n = 1'b1;
        end
        TRAG_KEY: begin
            s_small_n = 1'b0;
            s_big_n = 1'b1;
        end
        UART_CTRL: begin
            if (cnt_time_1s == TIMER_10S - 1'b1) begin
                s_small_n = s_big_n;
                s_big_n = ~s_small_n;
            end else begin
                s_small_n = s_small_n;
                s_big_n = s_big_n;
            end
        end
        KEY_SM_CTRL: begin
            s_small_n = 1'b0;
            s_big_n = 1'b1;
        end
        KEY_BI_CTRL: begin
            s_small_n = 1'b1;
            s_big_n = 1'b0;
        end
        default: begin
            s_small_n = 1'b1;
            s_big_n = 1'b1;
        end
    endcase
end

// Timer logic for UART_CTRL state
always @(posedge clk) begin
    if (rst) begin
        cnt_time_1s <= 32'd0;
    end else if (state == UART_CTRL) begin
        cnt_time_1s <= (cnt_time_1s == TIMER_10S - 1'b1) ? 32'd0 : cnt_time_1s + 1'b1;
    end else begin
        cnt_time_1s <= 32'd0;
    end
end

// Indicate timer completion
always @(posedge clk) begin
    if (rst) begin
        s_timer_done <= 1'b0;
    end else if (cnt_time_1s == TIMER_10S - 1'b1) begin
        s_timer_done <= 1'b1;
    end else begin
        s_timer_done <= 1'b0;
    end
end

endmodule