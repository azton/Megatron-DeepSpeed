#!/bin/bash --login
#
# Run complete test of
# https://github.com/argonne-lcf/Megatron-DeepSpeed
# on Polaris @ ALCF
# to launch (inside an interactive `qsub -I` job) on Polaris:
#
# ```bash`
# $ git clone https://github.com/argonne-lcf/Megatron-DeepSpeed
# $ cd Megatron-DeepSpeed/ALCF
# $ bash test_polaris.sh
# ````

# EXIT ON ERROR(s)
set -euxo pipefail

NOW="$(date "+%Y-%m-%d-%H%M%S")"

########################################################
# Setup / activate conda environment,
# mine is called q4-drop
########################################################
setup_conda() {
    if [[ -z "${CONDA_PREFIX}" && -z "${VIRTUAL_ENV}" ]]; then
        export MAMBA_ROOT_PREFIX=/eagle/argonne_tpc/micromamba 
        shell_name=$(echo "${SHELL}" | tr "\/" "\t" | awk '{print $NF}')
        eval "$("${MAMBA_ROOT_PREFIX}/bin/micromamba" shell hook -s posix)"
        micromamba activate 2024-04-25
    else
        echo "Found existing python at: $(which python3)"
    fi
}


########################################
# Make sure ./tmp/Megatron-DeepSpeed
# does not already exist
########################################
setup_megatron_deepspeed() {
    OUTDIR="OUTPUTS/test-polaris-${NOW}" && mkdir -p "${OUTDIR}" && cd "${OUTDIR}"
    echo "Running test in: ${OUTDIR}"
    echo "WORKING DIRECTORY: $(realpath $(pwd .))"
    if [[ -d "Megatron-DeepSpeed" ]]; then
        echo "Found existing Megatron-DeepSpeed in ${OUTDIR}"
        echo "Remove Megatron-DeepSpeed from ${OUTDIR} to run test."
        exit
    fi
    git clone https://github.com/argonne-lcf/Megatron-DeepSpeed && cd Megatron-DeepSpeed
    if [[ -z "${GIT_BRANCH-}" ]]; then
        git checkout "${GIT_BRANCH}"
    fi
}


main() {
    local virtual_env="${VIRTUAL_ENV-}"
    local conda_prefix="${CONDA_PREFIX}"
    if [[ -n "${conda_prefix}" && -z "${virtual_env}" ]]; then
        echo "Using conda from: ${conda_prefix}"
    elif [[ -n "${virtual_env}" && -z "${conda_prefix}" ]]; then
        echo "Using virtual_env from: ${virtual_env}"
    elif [[ -n "${virtual_env}" && -n "${conda_prefix}" ]]; then
        echo "Using virtual_env: ${virtual_env} on top of CONDA: ${conda_prefix}"
    elif [[ -z "${conda_prefix}" && -z "${virtual_env}" ]]; then
        echo "No conda_prefix or virtual_env found in environment..."
        echo "Setting up conda"
        setup_conda
    else
        echo "Unable to setup python. Exiting"
        exit 1
    fi
    setup_megatron_deepspeed
    export DEBUG=1
    export PBS_O_WORKDIR="$(pwd)"
    export DATA_FILE_LIST=./ALCF/data-lists/polaris/books.txt
    export ZERO_STAGE=1
    export NUM_LAYERS=10
    export MICRO_BATCH=8
    export TRAIN_ITER=20
    export TIMING_LOG_LEVEL=1
    bash train_llama_alcf.sh |& tee "test-polaris-${NOW}".log
}

main
