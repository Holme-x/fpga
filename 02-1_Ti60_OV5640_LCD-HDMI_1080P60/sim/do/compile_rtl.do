vlog +define+_SIM -cover bcest +incr -work work     "../example_top.v"
vlog +define+_SIM -cover bcest +incr -work work     "../src/hdmi_ip/*.v"
vlog +define+_SIM -cover bcest +incr -work work     "../src/USER_IP/KEY/*.sv"
vlog +define+_SIM -cover bcest +incr -work work     "../src/USER_IP/opendv_ip/*.v"
vlog +define+_SIM -cover bcest +incr -work work     "../src/USER_IP/UART/*.sv"
vlog +define+_SIM -cover bcest +incr -work work     "../src/USER_LOGIC/*.v"
vlog +define+_SIM -cover bcest +incr -work work     "../src/USER_LOGIC/IMG_RAM_TOP/*.v"