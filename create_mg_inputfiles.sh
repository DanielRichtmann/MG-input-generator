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
    local -r text="
USAGE:
    $(basename "$0") <params_file>

PARAMETERS (NECESSARY)
    <params_file>    Parameter file to source
"

    echo "$text" >> /dev/stderr
}

function calculate_lattice_sizes() {
    for (( lvl=1; lvl<nlevels; lvl++ )); do
        a_global_lattsize_x[$lvl]=$((a_global_lattsize_x[$((lvl-1))] / a_blocksize_x[$((lvl-1))]))
        a_global_lattsize_y[$lvl]=$((a_global_lattsize_y[$((lvl-1))] / a_blocksize_y[$((lvl-1))]))
        a_global_lattsize_z[$lvl]=$((a_global_lattsize_z[$((lvl-1))] / a_blocksize_z[$((lvl-1))]))
        a_global_lattsize_t[$lvl]=$((a_global_lattsize_t[$((lvl-1))] / a_blocksize_t[$((lvl-1))]))
        a_local_lattsize_x[$lvl]=${a_global_lattsize_x[$lvl]}
        a_local_lattsize_y[$lvl]=${a_global_lattsize_y[$lvl]}
        a_local_lattsize_z[$lvl]=${a_global_lattsize_z[$lvl]}
        a_local_lattsize_t[$lvl]=${a_global_lattsize_t[$lvl]}
    done
}

function create_mg_inputfiles() {
    if [[ $# != 1 ]]; then
        print_usage
        return 1
    fi

    local -r params_file=$1; shift

    . "$params_file"

    local -r lattsize=${a_global_lattsize_x[0]}x${a_global_lattsize_y[0]}x${a_global_lattsize_z[0]}x${a_global_lattsize_t[0]}
    local -r config=$config_folder/grid_gauge_config_hot.sequence_1.latt_size_${lattsize}.seeds_1x2x3x4

    calculate_lattice_sizes

    for codebase in "${a_codebase[@]}"; do
        case $codebase in
            "grid")
                local file_extension="xml"
                ;;
            "ddaamg")
                local file_extension="ini"
                ;;
            *)
                return 1
                ;;
        esac

        local template=$template_dir/$codebase/mg_params_template.${nlevels}lvl.$file_extension
        local output_dir=$output_dir_base/$codebase
        local output_file=$output_dir/mg_params.${nlevels}lvl.$file_extension

        mkdir -p "$output_dir"
        cp "$template" "$output_file"

        if [[ ${codebase} == "ddaamg" ]]; then
            if [[ ${kcycle} == "true" ]]; then
                kcycle=1
            elif [[ ${kcycle} == "false" ]]; then
                kcycle=0
            else
                return 1
            fi
        fi

        for (( lvl=0; lvl<nlevels; lvl++ )); do
            sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_X%|'"${a_global_lattsize_x[$lvl]}"'|g' " $output_file"
            sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_Y%|'"${a_global_lattsize_y[$lvl]}"'|g' " $output_file"
            sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_Z%|'"${a_global_lattsize_z[$lvl]}"'|g' " $output_file"
            sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_T%|'"${a_global_lattsize_t[$lvl]}"'|g' " $output_file"
            sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_X%|'"${a_local_lattsize_x[$lvl]}"'|g' "   $output_file"
            sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_Y%|'"${a_local_lattsize_y[$lvl]}"'|g' "   $output_file"
            sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_Z%|'"${a_local_lattsize_z[$lvl]}"'|g' "   $output_file"
            sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_T%|'"${a_local_lattsize_t[$lvl]}"'|g' "   $output_file"
        done
        for (( lvl=0; lvl<$((nlevels - 1)); lvl++ )); do
            sed -ri 's|%BLOCKSIZE_'"$lvl"'_X%|'"${a_blocksize_x[$lvl]}"'|g' "                         $output_file"
            sed -ri 's|%BLOCKSIZE_'"$lvl"'_Y%|'"${a_blocksize_y[$lvl]}"'|g' "                         $output_file"
            sed -ri 's|%BLOCKSIZE_'"$lvl"'_Z%|'"${a_blocksize_z[$lvl]}"'|g' "                         $output_file"
            sed -ri 's|%BLOCKSIZE_'"$lvl"'_T%|'"${a_blocksize_t[$lvl]}"'|g' "                         $output_file"
            sed -ri 's|%SETUP_ITERS_'"$lvl"'%|'"${a_setup_iters[$lvl]}"'|g' "                         $output_file"
            sed -ri 's|%SMOOTHER_TOL_'"$lvl"'%|'"${a_smoother_tol[$lvl]}"'|g' "                       $output_file"
            sed -ri 's|%SMOOTHER_MAX_OUTER_ITER_'"$lvl"'%|'"${a_smoother_max_outer_iter[$lvl]}"'|g' " $output_file"
            sed -ri 's|%SMOOTHER_MAX_INNER_ITER_'"$lvl"'%|'"${a_smoother_max_inner_iter[$lvl]}"'|g' " $output_file"
        done

        sed -ri 's|%KCYCLE%|'"${kcycle}"'|g' "                                             $output_file"
        sed -ri 's|%KCYCLE_TOL%|'"${kcycle_tol}"'|g' "                                     $output_file"
        sed -ri 's|%KCYCLE_MAX_OUTER_ITER%|'"${kcycle_max_outer_iter}"'|g' "               $output_file"
        sed -ri 's|%KCYCLE_MAX_INNER_ITER%|'"${kcycle_max_inner_iter}"'|g' "               $output_file"
        sed -ri 's|%COARSE_SOLVER_TOL%|'"${coarse_solver_tol}"'|g' "                       $output_file"
        sed -ri 's|%COARSE_SOLVER_MAX_OUTER_ITER%|'"${coarse_solver_max_outer_iter}"'|g' " $output_file"
        sed -ri 's|%COARSE_SOLVER_MAX_INNER_ITER%|'"${coarse_solver_max_inner_iter}"'|g' " $output_file"
        sed -ri 's|%OUTER_SOLVER_TOL%|'"${outer_solver_tol}"'|g' "                         $output_file"
        sed -ri 's|%OUTER_SOLVER_MAX_OUTER_ITER%|'"${outer_solver_max_outer_iter}"'|g' "   $output_file"
        sed -ri 's|%OUTER_SOLVER_MAX_INNER_ITER%|'"${outer_solver_max_inner_iter}"'|g' "   $output_file"
        sed -ri 's|%MASS%|'"${mass}"'|g' "                                                 $output_file"
        sed -ri 's|%CSW%|'"${csw}"'|g' "                                                   $output_file"
        sed -ri 's|%CONFIG%|'"${config}"'|g' "                                             $output_file"

        echo "Done with file $output_file"
    done
}

create_mg_inputfiles "$@"
