#!/bin/bash -eu

# Purpose: This file is intended to generate input files for the mg implementations in both grid and ddaamg
# Author:  Daniel Richtmann

declare -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -r config_folder=~
declare -ar a_codebase=("grid" "ddaamg")
declare -r template_dir=$script_dir/templates
declare -r output_dir_base=$script_dir/output

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
    for(( lvl=1; lvl<$nlevels; lvl++)); do
        a_glattsize_x[$lvl]=$((a_glattsize_x[$((lvl-1))] / a_blocksize_x[$((lvl-1))]))
        a_glattsize_y[$lvl]=$((a_glattsize_y[$((lvl-1))] / a_blocksize_y[$((lvl-1))]))
        a_glattsize_z[$lvl]=$((a_glattsize_z[$((lvl-1))] / a_blocksize_z[$((lvl-1))]))
        a_glattsize_t[$lvl]=$((a_glattsize_t[$((lvl-1))] / a_blocksize_t[$((lvl-1))]))
        a_llattsize_x[$lvl]=${a_glattsize_x[$lvl]}
        a_llattsize_y[$lvl]=${a_glattsize_y[$lvl]}
        a_llattsize_z[$lvl]=${a_glattsize_z[$lvl]}
        a_llattsize_t[$lvl]=${a_glattsize_t[$lvl]}
    done
}

function main() {

    if [[ $# != 1 ]]; then
        print_usage
        exit -1
    fi

    declare -r source_file=$1; shift

    . $source_file

    declare -r lattsize=${a_glattsize_x[0]}x${a_glattsize_y[0]}x${a_glattsize_z[0]}x${a_glattsize_t[0]}
    declare -r config=$config_folder/grid_gauge_config_hot.sequence_1.latt_size_${lattsize}.seeds_1x2x3x4

    calculate_lattice_sizes

    for codebase in "${a_codebase[@]}"; do
        case $codebase in
            "grid")
                file_extension="xml"
                ;;
            "ddaamg")
                file_extension="ini"
                ;;
            *)
                exit -1
                ;;
        esac

        declare template=$template_dir/$codebase/mg_params_template.${nlevels}lvl.$file_extension
        declare output_dir=$output_dir_base/$codebase
        declare output_file=$output_dir/mg_params.${nlevels}lvl.$file_extension

        mkdir -p $output_dir
        cp $template $output_file

        if [[ ${codebase} == "ddaamg" ]]; then
            if [[ ${kcycle} == "true" ]]; then
                kcycle=1
            elif [[ ${kcycle} == "false" ]]; then
                kcycle=0
            else
                exit -1
            fi
        fi

        for(( lvl=0; lvl<$nlevels; lvl++ )); do
            sed -ri 's|%GLATTSIZE_'$lvl'_X%|'${a_glattsize_x[$lvl]}'|g' $output_file
            sed -ri 's|%GLATTSIZE_'$lvl'_Y%|'${a_glattsize_y[$lvl]}'|g' $output_file
            sed -ri 's|%GLATTSIZE_'$lvl'_Z%|'${a_glattsize_z[$lvl]}'|g' $output_file
            sed -ri 's|%GLATTSIZE_'$lvl'_T%|'${a_glattsize_t[$lvl]}'|g' $output_file
            sed -ri 's|%LLATTSIZE_'$lvl'_X%|'${a_llattsize_x[$lvl]}'|g' $output_file
            sed -ri 's|%LLATTSIZE_'$lvl'_Y%|'${a_llattsize_y[$lvl]}'|g' $output_file
            sed -ri 's|%LLATTSIZE_'$lvl'_Z%|'${a_llattsize_z[$lvl]}'|g' $output_file
            sed -ri 's|%LLATTSIZE_'$lvl'_T%|'${a_llattsize_t[$lvl]}'|g' $output_file
        done
        for(( lvl=0; lvl<$((nlevels - 1)); lvl++ )); do
            sed -ri 's|%BLOCKSIZE_'$lvl'_X%|'${a_blocksize_x[$lvl]}'|g' $output_file
            sed -ri 's|%BLOCKSIZE_'$lvl'_Y%|'${a_blocksize_y[$lvl]}'|g' $output_file
            sed -ri 's|%BLOCKSIZE_'$lvl'_Z%|'${a_blocksize_z[$lvl]}'|g' $output_file
            sed -ri 's|%BLOCKSIZE_'$lvl'_T%|'${a_blocksize_t[$lvl]}'|g' $output_file
            sed -ri 's|%SETUP_ITERS_'$lvl'%|'${a_setup_iters[$lvl]}'|g' $output_file
            sed -ri 's|%SMOOTHER_TOL_'$lvl'%|'${a_smoother_tol[$lvl]}'|g' $output_file
            sed -ri 's|%SMOOTHER_MAX_OUTER_ITER_'$lvl'%|'${a_smoother_max_outer_iter[$lvl]}'|g' $output_file
            sed -ri 's|%SMOOTHER_MAX_INNER_ITER_'$lvl'%|'${a_smoother_max_inner_iter[$lvl]}'|g' $output_file
        done

        sed -ri 's|%KCYCLE%|'${kcycle}'|g' $output_file
        sed -ri 's|%KCYCLE_TOL%|'${kcycle_tol}'|g' $output_file
        sed -ri 's|%KCYCLE_MAX_OUTER_ITER%|'${kcycle_max_outer_iter}'|g' $output_file
        sed -ri 's|%KCYCLE_MAX_INNER_ITER%|'${kcycle_max_inner_iter}'|g' $output_file
        sed -ri 's|%COARSE_SOLVER_TOL%|'${coarse_solver_tol}'|g' $output_file
        sed -ri 's|%COARSE_SOLVER_MAX_OUTER_ITER%|'${coarse_solver_max_outer_iter}'|g' $output_file
        sed -ri 's|%COARSE_SOLVER_MAX_INNER_ITER%|'${coarse_solver_max_inner_iter}'|g' $output_file
        sed -ri 's|%OUTER_SOLVER_TOL%|'${outer_solver_tol}'|g' $output_file
        sed -ri 's|%OUTER_SOLVER_MAX_OUTER_ITER%|'${outer_solver_max_outer_iter}'|g' $output_file
        sed -ri 's|%OUTER_SOLVER_MAX_INNER_ITER%|'${outer_solver_max_inner_iter}'|g' $output_file
        sed -ri 's|%MASS%|'${mass}'|g' $output_file
        sed -ri 's|%CSW%|'${csw}'|g' $output_file
        sed -ri 's|%CONFIG%|'${config}'|g' $output_file

        echo "Done with file $output_file"
    done
}

main "$@"
