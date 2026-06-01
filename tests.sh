#!/bin/sh

ARG=$1
if [[ $ARG = "iverilog" ]]; then
  SIMULATOR="simulate.sh"
  echo "Simulator: Icarus Verilog"
else
  SIMULATOR="verilator_sim.sh"
  echo "Simulator: Verilator"
fi

# Run multiple testbenches
echo "Running testbenches..."
echo "-------------------"
echo "1) Test all instruction execution (tb_pl)"
./$SIMULATOR tb_pl

echo "-------------------"
echo "2) Test program execution (tb_program)"
./$SIMULATOR tb_program

echo "-------------------"
echo "3) Test interrupt handling (tb_interrupt)"
./$SIMULATOR tb_interrupt

echo "-------------------"
echo "4) Test exception handling (tb_exception)"
./$SIMULATOR tb_exception

echo "-------------------"
echo "5) Test SoC integration (tb_soc)"
./$SIMULATOR tb_soc

echo "-------------------"
echo "6) Test SoC matrix multiplication (tb_soc_mm)"
./$SIMULATOR tb_soc_mm

echo "-------------------"
echo "7) Test SoC timer interrupt (tb_soc_timer)"
./$SIMULATOR tb_soc_timer

echo "All testbenches executed, check outputs for verification."

