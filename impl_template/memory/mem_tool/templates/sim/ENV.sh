export SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VER_DIR="${SIM_DIR}/tb/"
export TC_DIR="${SIM_DIR}/tc/"
export MEMORY_DIR="$(cd "${SIM_DIR}/../../.." && pwd)"
export IMPL_PATH="$(cd "${MEMORY_DIR}/.." && pwd)"
export COM_PATH="$(cd "${IMPL_PATH}/.." && pwd)"
export SHELL_DIR="${MEMORY_DIR}/rtl/shell"
export MODEL_DIR="${MEMORY_DIR}/rtl/model"

if [ ! -d "./bin/" ]
then
    mkdir ./bin/
fi

echo "${SIM_DIR}"
