radix ufixed
onerror {resume}
quietly WaveActivateNextPane {} 0
quietly WaveActivateNextPane

add wave -noupdate -expand -group example_top       /TB_TOP/u_example_top/*

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
