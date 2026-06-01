#!/bin/sh

# Usage
if [ $# -lt 1 ]; then
  echo "Usage: $0 <testbench_name> [wave]"
  echo "Example:"
  echo "  $0 tb_pl"
  echo "  $0 tb_soc_mm wave"
  exit 1
fi

TB_NAME=$1
WAVE_FLAG=$2
OUT=sim_${TB_NAME}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DOCKER_IMAGE=${VERILATOR_IMAGE:-verilator}
DOCKER_MOUNT="${SCRIPT_DIR}:/work"
QUIET_BUILD=${VERILATOR_QUIET_BUILD:-1}
SHOW_WARNINGS_ALWAYS=${VERILATOR_SHOW_WARNINGS_ALWAYS:-1}

# 1) Find testbench file (flat OR nested, .v OR .sv)
TB_FILE=$(find "$SCRIPT_DIR" -type f \
  \( -path "*/Verilog/test/${TB_NAME}.v" \
  -o -path "*/Verilog/test/${TB_NAME}.sv" \
  -o -path "*/Verilog/*/test/${TB_NAME}.v" \
  -o -path "*/Verilog/*/test/${TB_NAME}.sv" \
  -o -path "*/Verilog/${TB_NAME}.v" \
  -o -path "*/Verilog/${TB_NAME}.sv" \) | head -n 1)

if [ -z "$TB_FILE" ]; then
  echo "ERROR: Testbench ${TB_NAME}.v/.sv not found"
  exit 1
fi

TB_FILE_CONTAINER=$(echo "$TB_FILE" | sed "s#^${SCRIPT_DIR}#/work#")

echo "Testbench     : $TB_FILE"
echo "Docker image  : $DOCKER_IMAGE"

# 2) Optional COE file and HEX file
TB_COE=$(dirname "$TB_FILE")/test_vector.coe
COE_ARG=""
if [ -f "$TB_COE" ]; then
  echo "Using COE file: $TB_COE"
  COE_ARG="+COE=$(echo "$TB_COE" | sed "s#^${SCRIPT_DIR}#/work#")"
fi

case "$TB_NAME" in
tb_pl) HEX_ARG="+HEX=/work/compiler/bin/rv32i_test.hex" ;;
tb_program) HEX_ARG="+HEX=/work/compiler/bin/matrix_mul.hex" ;;
tb_exception) HEX_ARG="+HEX=/work/compiler/bin/exception.hex" ;;
tb_interrupt) HEX_ARG="+HEX=/work/compiler/bin/interrupt.hex" ;;
tb_soc) HEX_ARG="+HEX=/work/compiler/bin/soc_test.hex" ;;
tb_soc_timer) HEX_ARG="+HEX=/work/compiler/bin/mtimer_test.hex" ;;
tb_soc_mm) HEX_ARG="+HEX=/work/compiler/bin/sw_matrix_mul.hex" ;;
tb_free_run) HEX_ARG="+HEX=/work/compiler/bin/blink_test.hex" ;;
*) HEX_ARG="" ;;
esac

# 3) Compile + Run in container
CONTAINER_CMD=$(
  cat <<EOF
set -e
find /work/Verilog -type f \( -name '*.v' -o -name '*.sv' \) \
  ! -path '*/test/*' ! -path '*/dumps/*' ! -path '*/obj_dir/*' \
  | sort > /tmp/verilator_sources.f
echo '$TB_FILE_CONTAINER' >> /tmp/verilator_sources.f

if [ -f /work/verilator/verilator.f ]; then
  VERILATOR_ARGS_FILE='-F /work/verilator/verilator.f'
elif [ -f /work/Verilog/verilator.f ]; then
  VERILATOR_ARGS_FILE='-F /work/Verilog/verilator.f'
else
  VERILATOR_ARGS_FILE='--timing --trace -Wall -Wno-fatal'
fi

if [ "\${VERILATOR_SHOW_WARNINGS_ALWAYS}" = "1" ]; then
  if ! verilator \
    --lint-only \
    --top-module '$TB_NAME' \
    \$VERILATOR_ARGS_FILE \
    -f /tmp/verilator_sources.f > /tmp/verilator_lint.log 2>&1; then
    cat /tmp/verilator_lint.log
    exit 1
  fi
  grep -E '^%Warning-|^%Error' /tmp/verilator_lint.log || true
fi

if [ "\${VERILATOR_QUIET_BUILD}" = "1" ]; then
  if ! verilator \
    --binary \
    --top-module '$TB_NAME' \
    \$VERILATOR_ARGS_FILE \
    -f /tmp/verilator_sources.f \
    --Mdir /work/Verilog/obj_dir \
    -o /work/Verilog/obj_dir/$OUT > /tmp/verilator_build.log 2>&1; then
    cat /tmp/verilator_build.log
    exit 1
  fi
  grep -E '^%Warning-|^%Error' /tmp/verilator_build.log || true
else
  verilator \
    --binary \
    --top-module '$TB_NAME' \
    \$VERILATOR_ARGS_FILE \
    -f /tmp/verilator_sources.f \
    --Mdir /work/Verilog/obj_dir \
    -o /work/Verilog/obj_dir/$OUT
fi

/work/Verilog/obj_dir/$OUT $COE_ARG $HEX_ARG
EOF
)

docker run \
  --rm \
  --entrypoint sh \
  -e VERILATOR_QUIET_BUILD="$QUIET_BUILD" \
  -e VERILATOR_SHOW_WARNINGS_ALWAYS="$SHOW_WARNINGS_ALWAYS" \
  -v "$DOCKER_MOUNT" \
  -w /work \
  "$DOCKER_IMAGE" \
  -lc "$CONTAINER_CMD"

if [ $? -ne 0 ]; then
  echo "Simulation failed"
  exit 1
fi

# 4) Open waveform ONLY if requested
if [ "$WAVE_FLAG" = "wave" ]; then
  VCD_FILE="$SCRIPT_DIR/Verilog/dumps/${TB_NAME}.vcd"
  if [ -f "$VCD_FILE" ]; then
    echo "Opening waveform: $VCD_FILE"
    gtkwave "$VCD_FILE" &
  else
    echo "ERROR: VCD not found: $VCD_FILE"
  fi
fi
