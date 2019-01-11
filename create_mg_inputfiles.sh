#!/bin/bash -eu

# Purpose: This file is intended to generate input files for the mg implementations in both grid and ddaamg
# Author:  Daniel Richtmann

# Define some paths
declare -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r config_dir=~/configs
declare -r template_dir=$script_dir/templates
declare -r params_dir=$script_dir/params
declare -r output_dir_base=$script_dir/output

# Define some global variables
declare -ar a_codebase=("grid" "ddaamg")
declare -ai a_global_lattsize_x=()
declare -ai a_global_lattsize_y=()
declare -ai a_global_lattsize_z=()
declare -ai a_global_lattsize_t=()
declare -ai a_local_lattsize_x=()
declare -ai a_local_lattsize_y=()
declare -ai a_local_lattsize_z=()
declare -ai a_local_lattsize_t=()
declare -i  mpi_decomposition_x
declare -i  mpi_decomposition_y
declare -i  mpi_decomposition_z
declare -i  mpi_decomposition_t
declare -i  n_levels

function print_usage() {
    local -r text="
USAGE:
    $(basename "$0") <global_lattice> <mpi_decomposition> <levels>

PARAMETERS (NECESSARY)
    <global_lattice>    Global lattice in the form \"X.Y.Z.T\"
    <mpi_decomposition> MPI decomposition of the lattice in the form \"X.Y.Z.T\"
    <levels>            Number of levels to be used (must be ∈ {2,3,4})
"

    echo "$text" >> /dev/stderr
}

function calculate_lattice_sizes() {
    a_local_lattsize_x[0]=$((a_global_lattsize_x[0] / mpi_decomposition_x))
    a_local_lattsize_y[0]=$((a_global_lattsize_y[0] / mpi_decomposition_y))
    a_local_lattsize_z[0]=$((a_global_lattsize_z[0] / mpi_decomposition_z))
    a_local_lattsize_t[0]=$((a_global_lattsize_t[0] / mpi_decomposition_t))

    for (( lvl=1; lvl<n_levels; lvl++ )); do
        a_global_lattsize_x[$lvl]=$((a_global_lattsize_x[$((lvl-1))] / a_blocksize_x[$((lvl-1))]))
        a_global_lattsize_y[$lvl]=$((a_global_lattsize_y[$((lvl-1))] / a_blocksize_y[$((lvl-1))]))
        a_global_lattsize_z[$lvl]=$((a_global_lattsize_z[$((lvl-1))] / a_blocksize_z[$((lvl-1))]))
        a_global_lattsize_t[$lvl]=$((a_global_lattsize_t[$((lvl-1))] / a_blocksize_t[$((lvl-1))]))

        a_local_lattsize_x[$lvl]=$((a_global_lattsize_x[lvl] / mpi_decomposition_x))
        a_local_lattsize_y[$lvl]=$((a_global_lattsize_y[lvl] / mpi_decomposition_y))
        a_local_lattsize_z[$lvl]=$((a_global_lattsize_z[lvl] / mpi_decomposition_z))
        a_local_lattsize_t[$lvl]=$((a_global_lattsize_t[lvl] / mpi_decomposition_t))
    done
}

function replace_parameters_in_file() {
    local -r output_file="$1"; shift

    if [[ ! -w "$output_file" ]]; then
        echo "${FUNCNAME[0]}: output file \"output_file\" not present or not writable" >> /dev/stderr
        return 1
    fi

    for (( lvl=0; lvl<n_levels; lvl++ )); do
        sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_X%|'"${a_global_lattsize_x[$lvl]}"'|g' "$output_file"
        sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_Y%|'"${a_global_lattsize_y[$lvl]}"'|g' "$output_file"
        sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_Z%|'"${a_global_lattsize_z[$lvl]}"'|g' "$output_file"
        sed -ri 's|%GLOBAL_LATTSIZE_'"$lvl"'_T%|'"${a_global_lattsize_t[$lvl]}"'|g' "$output_file"

        sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_X%|'"${a_local_lattsize_x[$lvl]}"'|g'   "$output_file"
        sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_Y%|'"${a_local_lattsize_y[$lvl]}"'|g'   "$output_file"
        sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_Z%|'"${a_local_lattsize_z[$lvl]}"'|g'   "$output_file"
        sed -ri 's|%LOCAL_LATTSIZE_'"$lvl"'_T%|'"${a_local_lattsize_t[$lvl]}"'|g'   "$output_file"
    done
    for (( lvl=0; lvl<$((n_levels - 1)); lvl++ )); do
        sed -ri 's|%BLOCKSIZE_'"$lvl"'_X%|'"${a_blocksize_x[$lvl]}"'|g'                         "$output_file"
        sed -ri 's|%BLOCKSIZE_'"$lvl"'_Y%|'"${a_blocksize_y[$lvl]}"'|g'                         "$output_file"
        sed -ri 's|%BLOCKSIZE_'"$lvl"'_Z%|'"${a_blocksize_z[$lvl]}"'|g'                         "$output_file"
        sed -ri 's|%BLOCKSIZE_'"$lvl"'_T%|'"${a_blocksize_t[$lvl]}"'|g'                         "$output_file"

        sed -ri 's|%SETUP_ITERS_'"$lvl"'%|'"${a_setup_iters[$lvl]}"'|g'                         "$output_file"
        sed -ri 's|%SMOOTHER_TOL_'"$lvl"'%|'"${a_smoother_tol[$lvl]}"'|g'                       "$output_file"
        sed -ri 's|%SMOOTHER_MAX_OUTER_ITER_'"$lvl"'%|'"${a_smoother_max_outer_iter[$lvl]}"'|g' "$output_file"
        sed -ri 's|%SMOOTHER_MAX_INNER_ITER_'"$lvl"'%|'"${a_smoother_max_inner_iter[$lvl]}"'|g' "$output_file"
    done

    sed -ri 's|%KCYCLE%|'"${kcycle}"'|g'                                              "$output_file"
    sed -ri 's|%KCYCLE_TOL%|'"${kcycle_tol}"'|g'                                      "$output_file"
    sed -ri 's|%KCYCLE_MAX_OUTER_ITER%|'"${kcycle_max_outer_iter}"'|g'                "$output_file"
    sed -ri 's|%KCYCLE_MAX_INNER_ITER%|'"${kcycle_max_inner_iter}"'|g'                "$output_file"
    sed -ri 's|%COARSE_SOLVER_TOL%|'"${coarse_solver_tol}"'|g'                        "$output_file"
    sed -ri 's|%COARSE_SOLVER_MAX_OUTER_ITER%|'"${coarse_solver_max_outer_iter}"'|g'  "$output_file"
    sed -ri 's|%COARSE_SOLVER_MAX_INNER_ITER%|'"${coarse_solver_max_inner_iter}"'|g'  "$output_file"
    sed -ri 's|%OUTER_SOLVER_TOL%|'"${outer_solver_tol}"'|g'                          "$output_file"
    sed -ri 's|%OUTER_SOLVER_MAX_OUTER_ITER%|'"${outer_solver_max_outer_iter}"'|g'    "$output_file"
    sed -ri 's|%OUTER_SOLVER_MAX_INNER_ITER%|'"${outer_solver_max_inner_iter}"'|g'    "$output_file"
    sed -ri 's|%MASS%|'"${mass}"'|g'                                                  "$output_file"
    sed -ri 's|%CSW%|'"${csw}"'|g'                                                    "$output_file"
    sed -ri 's|%CONFIG%|'"${config}"'|g'                                              "$output_file"
}

function create_mg_inputfiles() {
    if [[ $# != 3 ]]; then
        print_usage
        return 1
    fi

    local -r global_lattice="$1"; shift
    local -r mpi_decomposition="$1"; shift
    n_levels="$1"; shift

    local -r OLD_IFS=$IFS
    IFS='.' read -r a_global_lattsize_x[0] a_global_lattsize_y[0] a_global_lattsize_z[0] a_global_lattsize_t[0] <<< "$global_lattice"
    IFS='.' read -r mpi_decomposition_x mpi_decomposition_y mpi_decomposition_z mpi_decomposition_t             <<< "$mpi_decomposition"
    IFS="$OLD_IFS"

    if [[ $n_levels -lt 2 || $n_levels -gt 4 ]]; then
        echo "${FUNCNAME[0]}: number of levels must be ∈ {2,3,4}" >> /dev/stderr
        return 1
    fi

    local -r params_file=$params_dir/${n_levels}_lvls.src

    . "$params_file"

    local -r lattsize_string=${a_global_lattsize_x[0]}x${a_global_lattsize_y[0]}x${a_global_lattsize_z[0]}x${a_global_lattsize_t[0]}
    local -r config=$config_dir/grid_gauge_config_hot.sequence_1.latt_size_${lattsize_string}.seeds_1x2x3x4

    if [[ ! -r $config ]]; then
        echo "${FUNCNAME[0]}: gauge configuration \"$config\" not present or not readable" >> /dev/stderr
        return 1
    fi

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

        local template=$template_dir/$codebase/${n_levels}_lvls.$file_extension
        local output_dir=$output_dir_base/$codebase
        local output_file=$output_dir/mg_params.${n_levels}_lvls.$file_extension

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

        replace_parameters_in_file "$output_file"

        echo "Done with file $output_file"
    done
}

create_mg_inputfiles "$@"
