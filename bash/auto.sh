#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/init.sh"

# -------------------------
# Register functions and descriptions here (index assigned automatically)
# Format: "function_name:Short description"
# Add new functions by adding a new line to this array.
FUNCS=(
  "build_opencv_aarch64:Build OpenCV for aarch64"
  "build_test:Build test on Orange Pi 5 Pro"
)

# -------------------------
# Define your functions here
# Each function must be defined with a valid shell function name.
# Example functions:
build_opencv_aarch64() {
  echo "Building OpenCV for aarch64..."
  local lvar_dir_opencv=${HOME}/3rdparty/opencv
  local lvar_dir_build=${GVAR_DIR_OUTPUT}/opencv_aarch64_build
  # export PATH=${HOME}/compilers/aarch64/arm-gnu-toolchain-15.2.rel1-x86_64-aarch64-none-linux-gnu/bin:$PATH
  export PATH=${HOME}/compilers/aarch64/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bin:$PATH
  # rm -rf ${lvar_dir_build}/*
  cmake -G Ninja \
    -D CMAKE_CXX_STANDARD=11 \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_TOOLCHAIN_FILE=${lvar_dir_opencv}/platforms/linux/aarch64-gnu.toolchain.cmake \
    -D WITH_OPENCL=ON \
    -D WITH_VULKAN=ON \
    -D WITH_GSTREAMER=ON \
    -S ${lvar_dir_opencv} -B ${lvar_dir_build}
    # -D OPENCV_EXTRA_MODULES_PATH=${lvar_dir_opencv}/../opencv_contrib/modules \
    # -D GNU_MACHINE=aarch64-none-linux-gnu \
    # -D CMAKE_ASM_COMPILER=${HOME}/compilers/aarch64/arm-gnu-toolchain-15.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-gcc \
  ninja -C ${lvar_dir_build}
  cmake --install ${lvar_dir_build} --prefix ${lvar_dir_build}/install
}

build_test() {
  echo "Building test on Orange Pi 5 Pro..."
  # local lvar_dir_test=/home/huynq/face-recognition-gst/test08/
  # local lvar_dir_test=/home/huynq/face-recognition-gst/test09/
  # local lvar_dir_test=/home/huynq/face-recognition-gst/test10/
  # local lvar_dir_test=/home/huynq/face-recognition-gst/test11/
  # local lvar_dir_test=/home/huynq/face-recognition-gst/test12/
  local lvar_dir_test=/home/huynq/face-recognition-gst/test13/
  local lvar_name_test=$(basename ${lvar_dir_test})
  # rm -rf ${GVAR_DIR_OUTPUT}/test_build
  # cmake -S ${lvar_dir_test} -B ${GVAR_DIR_OUTPUT}/test_build
  cmake -DTARGET_SOC=rk3588 \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_ASAN=OFF \
    -DDISABLE_RGA=OFF \
    -DDISABLE_LIBJPEG=OFF \
    -S ${lvar_dir_test} -B ${GVAR_DIR_OUTPUT}/build/${lvar_name_test} 
  cmake --build ${GVAR_DIR_OUTPUT}/build/${lvar_name_test}
  rm -f ${GVAR_DIR_OUTPUT}/test
  ln -s ${GVAR_DIR_OUTPUT}/build/${lvar_name_test}/${lvar_name_test} ${GVAR_DIR_OUTPUT}/test
}

# -------------------------
# Helpers
print_help() {
  echo "Usage: $0 [-h|--help] <indexes>"
  echo
  echo "Indexes can be single numbers, ranges, or comma-separated lists."
  echo "Examples:"
  echo "  $0 -h"
  echo "  $0 0"
  echo "  $0 0-2,4"
  echo
  echo "Available functions:"
  for i in "${!FUNCS[@]}"; do
    entry="${FUNCS[$i]}"
    name="${entry%%:*}"
    desc="${entry#*:}"
    printf "  %2d  %s  %s\n" "$i" "$name" "$desc"
  done
}

# Trim whitespace
_trim() { printf '%s' "$1" | awk '{$1=$1;print}'; }

# Parse a token (single index or range) and append indices to array
append_indices_from_token() {
  local token="$1"
  token="$(_trim "$token")"
  if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    local a=${BASH_REMATCH[1]}
    local b=${BASH_REMATCH[2]}
    if (( a <= b )); then
      for ((i=a;i<=b;i++)); do
        INDICES+=("$i")
      done
    else
      for ((i=a;i>=b;i--)); do
        INDICES+=("$i")
      done
    fi
  elif [[ "$token" =~ ^[0-9]+$ ]]; then
    INDICES+=("$token")
  else
    echo "Invalid token: '$token'" >&2
    exit 2
  fi
}

# Validate and deduplicate indices preserving order
normalize_indices() {
  local -A seen=()
  local out=()
  for idx in "${INDICES[@]}"; do
    if ! [[ "$idx" =~ ^[0-9]+$ ]]; then
      echo "Invalid index: $idx" >&2
      exit 2
    fi
    if (( idx < 0 || idx >= ${#FUNCS[@]} )); then
      echo "Index out of range: $idx" >&2
      exit 2
    fi
    if [[ -z "${seen[$idx]:-}" ]]; then
      out+=("$idx")
      seen[$idx]=1
    fi
  done
  INDICES=("${out[@]}")
}

# -------------------------
# Main
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${#:-0}" -eq 0 ]]; then
  print_help
  exit 0
fi

ARG="$1"

# Split by commas and parse tokens
IFS=',' read -r -a TOKENS <<< "$ARG"
INDICES=()
for t in "${TOKENS[@]}"; do
  append_indices_from_token "$t"
done

normalize_indices

# Execute functions in order
for idx in "${INDICES[@]}"; do
  entry="${FUNCS[$idx]}"
  name="${entry%%:*}"
  if ! declare -f "$name" >/dev/null; then
    echo "Function '$name' (index $idx) is not defined." >&2
    exit 3
  fi
  echo "=== Running [$idx] $name ==="
  "$name"
done

