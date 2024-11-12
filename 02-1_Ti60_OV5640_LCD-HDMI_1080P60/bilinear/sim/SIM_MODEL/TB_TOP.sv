
`timescale 100ps/10ps
`include "ddr3_controller.vh"
`define den4096Mb
`define x16

module TB_TOP();

// =========================================================================================================================================
// clock & reset
// =========================================================================================================================================
logic               core_clk        ;
logic               clk_pixel       ;
logic               clk_pixel_2x    ;
logic               sys_pll_lock    ;
logic               ddr_pll_lock    ;

//clock generate
initial begin : core_clk_gen           //200
    core_clk  = 0;
    forever begin
        #25 core_clk = ~core_clk;
    end
end

initial begin : clk_pixel_gen           //74.25
    clk_pixel  = 0;
    forever begin
        #68 clk_pixel = ~clk_pixel;
    end
end

initial begin : clk_pixel_2x_gen        //148.5
    clk_pixel_2x = 1;
    forever begin
        #34 clk_pixel_2x = ~clk_pixel_2x;
    end
end

initial begin : lock_gen
    sys_pll_lock = 0;
    ddr_pll_lock = 0;
    #1000;
    sys_pll_lock = 1;
    ddr_pll_lock = 1;
end

// =========================================================================================================================================
// Main Function
// =========================================================================================================================================
initial begin
    #100000;
    $stop;
end

// =========================================================================================================================================
// Link RTL module
// =========================================================================================================================================
example_top u_example_top (
    .clk_pixel          ( clk_pixel             ),
    .clk_pixel_2x       ( clk_pixel_2x          ),
    .sys_pll_lock       ( sys_pll_lock          ),
    .core_clk           ( core_clk              ),
    .ddr_pll_lock       ( ddr_pll_lock          ),
    .i_key_n            ( 2'b11                 )
);

endmodule
