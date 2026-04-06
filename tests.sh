
# Run multiple testbenches
echo "Running testbenches..."
echo "-------------------"
echo "1) Test all instruction execution (tb_pl)"
./simulate.sh tb_pl

echo "-------------------"
echo "2) Test program execution (tb_program)"
./simulate.sh tb_program

echo "-------------------"
echo "3) Test interrupt handling (tb_interrupt)"
./simulate.sh tb_interrupt

echo "-------------------"
echo "4) Test exception handling (tb_exception)"
./simulate.sh tb_exception

echo "-------------------"
echo "5) Test SoC integration (tb_soc)"
./simulate.sh tb_soc

echo "-------------------"
echo "6) Test SoC matrix multiplication (tb_soc_mm)"
./simulate.sh tb_soc_mm

echo "All testbenches executed, check outputs for verification."