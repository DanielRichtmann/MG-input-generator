#!/bin/bash -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Purpose: This file is intended to generate input files for the mg implementations in both grid and ddaamg
# Author:  Daniel Richtmann

declare -r CONFIG_FOLDER=~
declare -ar A_CODEBASE=("grid" "ddaamg")
declare -r TEMPLATE_DIR=$SCRIPT_DIR/templates
declare -r OUTPUT_DIR_BASE=/tmp/mg_input_files

function print_usage()
{
    local text="
USAGE:
    $(basename "$0") <source_file>

PARAMETERS (NECESSARY)
    <source_file>    File to source
"

    echo "$text" >> /dev/stderr
}

function calculate_lattice_sizes() {
    for(( lvl=1; lvl<$NLEVELS; lvl++)); do
        A_GLATTSIZE_X[$lvl]=$((A_GLATTSIZE_X[$((lvl-1))] / A_BLOCKSIZE_X[$((lvl-1))]))
        A_GLATTSIZE_Y[$lvl]=$((A_GLATTSIZE_Y[$((lvl-1))] / A_BLOCKSIZE_Y[$((lvl-1))]))
        A_GLATTSIZE_Z[$lvl]=$((A_GLATTSIZE_Z[$((lvl-1))] / A_BLOCKSIZE_Z[$((lvl-1))]))
        A_GLATTSIZE_T[$lvl]=$((A_GLATTSIZE_T[$((lvl-1))] / A_BLOCKSIZE_T[$((lvl-1))]))
        A_LLATTSIZE_X[$lvl]=${A_GLATTSIZE_X[$lvl]}
        A_LLATTSIZE_Y[$lvl]=${A_GLATTSIZE_Y[$lvl]}
        A_LLATTSIZE_Z[$lvl]=${A_GLATTSIZE_Z[$lvl]}
        A_LLATTSIZE_T[$lvl]=${A_GLATTSIZE_T[$lvl]}
    done
}

function main() {

    if [[ $# != 1 ]]; then
        print_usage
        exit -1
    fi

    declare -r SOURCE_FILE=$1; shift

    . $SOURCE_FILE

    declare -r LATTSIZE=${A_GLATTSIZE_X[0]}x${A_GLATTSIZE_Y[0]}x${A_GLATTSIZE_Z[0]}x${A_GLATTSIZE_T[0]}
    declare -r CONFIG=$CONFIG_FOLDER/grid_gauge_config_hot.sequence_1.latt_size_${LATTSIZE}.seeds_1x2x3x4

    calculate_lattice_sizes

    for CODEBASE in "${A_CODEBASE[@]}"; do
        case $CODEBASE in
            "grid")
                FILE_EXTENSION="xml"
                ;;
            "ddaamg")
                FILE_EXTENSION="ini"
                ;;
            *)
                exit -1
                ;;
        esac

        declare TEMPLATE=$TEMPLATE_DIR/$CODEBASE/mg_params_template.${NLEVELS}lvl.$FILE_EXTENSION
        declare OUTPUT_DIR=$OUTPUT_DIR_BASE/$CODEBASE
        declare OUTPUT_FILE=$OUTPUT_DIR/mg_params.${NLEVELS}lvl.$FILE_EXTENSION

        mkdir -p $OUTPUT_DIR
        cp $TEMPLATE $OUTPUT_FILE

        if [[ ${CODEBASE} == "ddaamg" ]]; then
            if [[ ${KCYCLE} == "true" ]]; then
                KCYCLE=1
            elif [[ ${KCYCLE} == "false" ]]; then
                KCYCLE=0
            else
                exit -1
            fi
        fi

        for(( lvl=0; lvl<$NLEVELS; lvl++ )); do
            sed -ri 's|%GLATTSIZE_'$lvl'_X%|'${A_GLATTSIZE_X[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%GLATTSIZE_'$lvl'_Y%|'${A_GLATTSIZE_Y[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%GLATTSIZE_'$lvl'_Z%|'${A_GLATTSIZE_Z[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%GLATTSIZE_'$lvl'_T%|'${A_GLATTSIZE_T[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%LLATTSIZE_'$lvl'_X%|'${A_LLATTSIZE_X[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%LLATTSIZE_'$lvl'_Y%|'${A_LLATTSIZE_Y[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%LLATTSIZE_'$lvl'_Z%|'${A_LLATTSIZE_Z[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%LLATTSIZE_'$lvl'_T%|'${A_LLATTSIZE_T[$lvl]}'|g' $OUTPUT_FILE
        done
        for(( lvl=0; lvl<$((NLEVELS - 1)); lvl++ )); do
            sed -ri 's|%BLOCKSIZE_'$lvl'_X%|'${A_BLOCKSIZE_X[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%BLOCKSIZE_'$lvl'_Y%|'${A_BLOCKSIZE_Y[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%BLOCKSIZE_'$lvl'_Z%|'${A_BLOCKSIZE_Z[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%BLOCKSIZE_'$lvl'_T%|'${A_BLOCKSIZE_T[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%SETUP_ITERS_'$lvl'%|'${A_SETUP_ITERS[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%SMOOTHER_TOL_'$lvl'%|'${A_SMOOTHER_TOL[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%SMOOTHER_MAX_OUTER_ITER_'$lvl'%|'${A_SMOOTHER_MAX_OUTER_ITER[$lvl]}'|g' $OUTPUT_FILE
            sed -ri 's|%SMOOTHER_MAX_INNER_ITER_'$lvl'%|'${A_SMOOTHER_MAX_INNER_ITER[$lvl]}'|g' $OUTPUT_FILE
        done

        sed -ri 's|%KCYCLE%|'${KCYCLE}'|g' $OUTPUT_FILE
        sed -ri 's|%KCYCLE_TOL%|'${KCYCLE_TOL}'|g' $OUTPUT_FILE
        sed -ri 's|%KCYCLE_MAX_OUTER_ITER%|'${KCYCLE_MAX_OUTER_ITER}'|g' $OUTPUT_FILE
        sed -ri 's|%KCYCLE_MAX_INNER_ITER%|'${KCYCLE_MAX_INNER_ITER}'|g' $OUTPUT_FILE
        sed -ri 's|%COARSE_SOLVER_TOL%|'${COARSE_SOLVER_TOL}'|g' $OUTPUT_FILE
        sed -ri 's|%COARSE_SOLVER_MAX_OUTER_ITER%|'${COARSE_SOLVER_MAX_OUTER_ITER}'|g' $OUTPUT_FILE
        sed -ri 's|%COARSE_SOLVER_MAX_INNER_ITER%|'${COARSE_SOLVER_MAX_INNER_ITER}'|g' $OUTPUT_FILE
        sed -ri 's|%OUTER_SOLVER_TOL%|'${OUTER_SOLVER_TOL}'|g' $OUTPUT_FILE
        sed -ri 's|%OUTER_SOLVER_MAX_OUTER_ITER%|'${OUTER_SOLVER_MAX_OUTER_ITER}'|g' $OUTPUT_FILE
        sed -ri 's|%OUTER_SOLVER_MAX_INNER_ITER%|'${OUTER_SOLVER_MAX_INNER_ITER}'|g' $OUTPUT_FILE
        sed -ri 's|%MASS%|'${MASS}'|g' $OUTPUT_FILE
        sed -ri 's|%CSW%|'${CSW}'|g' $OUTPUT_FILE
        sed -ri 's|%CONFIG%|'${CONFIG}'|g' $OUTPUT_FILE

        echo "Done with file $OUTPUT_FILE"
    done
}

main "$@"
