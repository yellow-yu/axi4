// AXI4 VIP File List for QuestaSim
// Compile order matters!

// Interface definition
../axi4_interface.sv

// VIP Package
+incdir+../vip
../vip/axi4_vip_pkg.sv

// Test Package
+incdir+../test
../test/axi4_test_pkg.sv

// RTL Memory Slave
../rtl/axi4_mem_slave.sv

// Testbench Top
../tb/axi4_tb_top.sv
