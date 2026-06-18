database -open ddr_waves -into ./ddr_waves.shm -default
probe -create tb_top -all -depth all
run
exit
