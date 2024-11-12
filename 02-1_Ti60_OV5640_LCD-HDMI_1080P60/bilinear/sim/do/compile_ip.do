set IP_PATH L:/32-Gitea/OD/02-1_Ti60_OV5640_LCD-HDMI_1080P60/ip

vlog +incr -work work ${IP_PATH}/ASYNC_BBUF_16x1024_16x1024/Testbench/*.v
vlog +incr -work work ${IP_PATH}/BRAM_16x2048/Testbench/*.v      
vlog +incr -work work ${IP_PATH}/BRAM_128x1024_32x4096/Testbench/*.v
vlog +incr -work work ${IP_PATH}/SYNC_BBUF_32x256_128x64/Testbench/*.v
vlog +incr -work work ${IP_PATH}/SYNC_DBUF_16x32_16x32/Testbench/*.v

cd ${IP_PATH}
cd ../sim
