#!/bin/sh

# Usage
if [ $# -lt 1 ]; then
    echo "Usage: $0 <testbench_name> [wave]"
    echo "Example:"
    echo "  $0 adder_tb"
    echo "  $0 shifter_top_tb wave"
    exit 1
fi

TB_NAME=$1
WAVE_FLAG=$2
OUT=sim_${TB_NAME}

# 1) Find testbench file (flat OR nested)
TB_FILE=$(find . -type f \
    \( -path "*/Verilog/test/${TB_NAME}.v" \
       -o -path "*/Verilog/*/test/${TB_NAME}.v" \
       -o -path "*/Verilog/${TB_NAME}.v" \) )

if [ -z "$TB_FILE" ]; then
    echo "ERROR: Testbench ${TB_NAME}.v not found"
    exit 1
fi

# 2) Derive DESIGN_DIR and VERILOG_ROOT
case "$TB_FILE" in
    */Verilog/*/test/*)
        # a2_shift_mult/Verilog/shifter/test/tb.v
        DESIGN_DIR=$(dirname "$(dirname "$TB_FILE")")
        VERILOG_ROOT=$(dirname "$DESIGN_DIR")
        ;;
    */Verilog/test/*)
        # a1_adders/Verilog/test/tb.v
        DESIGN_DIR=$(dirname "$TB_FILE")
        VERILOG_ROOT=$(dirname "$DESIGN_DIR")
        ;;
esac

echo "Testbench     : $TB_FILE"
echo "Design root   : $DESIGN_DIR"
echo "Verilog root  : $VERILOG_ROOT"

# 3) Compile - find source files correctly
case "$TB_FILE" in
    */Verilog/*/test/*)
        # For nested structure (a2_shift_mult), compile only from that subfolder
        iverilog -g2012 -s "$TB_NAME" -o "$OUT" \
            $(find "$DESIGN_DIR" -type f -name "*.v" ! -path "*/dumps/*")
        ;;
    */Verilog/test/*)
        # For flat structure (a1_adders), compile from Verilog root
        iverilog -g2012 -s "$TB_NAME" -o "$OUT" \
            $(find "$VERILOG_ROOT" -type f -name "*.v" ! -path "*/dumps/*")
        ;;
esac

if [ $? -ne 0 ]; then
    echo "Compilation failed"
    exit 1
fi

echo "Compilation successful"

# 4) Locate COE file (optional)
TB_COE=$(dirname "$TB_FILE")/test_vector.coe

if [ -f "$TB_COE" ]; then
    echo "Using COE file: $TB_COE"
    COE_ARG="+COE=$TB_COE"
else
    COE_ARG=""
fi

# 5) Choose hex file based on testbench name
# add the files from the root directory of script location
case "$TB_NAME" in
    tb_pl)         HEX_ARG="+HEX=./docker/bin/rv32i_test.hex" ;;
    tb_program)    HEX_ARG="+HEX=./docker/bin/matrix_mul.hex" ;;
    tb_exception)  HEX_ARG="+HEX=./docker/bin/exception.hex" ;;
    tb_interrupt)  HEX_ARG="+HEX=./docker/bin/interrupt.hex" ;;
    tb_soc)        HEX_ARG="+HEX=./docker/bin/soc_test.hex" ;;
    tb_soc_mm)     HEX_ARG="+HEX=./docker/bin/hw_matrix_mul.hex" ;;
    tb_soc_top)    HEX_ARG="+HEX=./docker/bin/sw_matrix_mul.hex" ;;
    tb_free_run)   HEX_ARG="+HEX=./docker/bin/blink_test.hex" ;;
    *)             HEX_ARG="" ;;
esac

# 6) Run simulation
vvp "$OUT" $COE_ARG $HEX_ARG

# 7) Open waveform ONLY if requested
if [ "$WAVE_FLAG" = "wave" ]; then
    VCD_FILE="$VERILOG_ROOT/dumps/${TB_NAME}.vcd"

    if [ -f "$VCD_FILE" ]; then
        echo "Opening waveform: $VCD_FILE"
        gtkwave "$VCD_FILE" &
    else
        echo "ERROR:  VCD not found: $VCD_FILE"
    fi
fi

# 8) Cleanup
rm -f "$OUT"
