vsim    -suppress 3009 -wav ./wave/tb_top.wlf/ -l ./test_data/tb_top/tb_top.log\
        -voptargs="+acc" -c -t ps\
        -L work -L verilog -L unisims_ver -L unimacro_ver -L unifast_ver -L simprims_ver -L secureip\
        work.TB_TOP

log -r /*
    
## add wave
view wave
do wave_do/wave_TB_TOP.do

radix hex
onerror {resume}
quietly WaveActivateNextPane {} 0
quietly WaveActivateNextPane

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2533055 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 278
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {11680200 ps}
    
run -all;

