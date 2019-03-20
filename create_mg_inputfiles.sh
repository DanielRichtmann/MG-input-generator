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

function file_extension() {
    local -r usage="
Usage: ${FUNCNAME[0]} <codebase>

PARAMETERS (NECESSARY)
    <codebase> must be ∈ (grid, ddaamg)"

    if [[ $# != 1 ]]; then
        echo "$usage" >> /dev/stderr
        return 1
    else
        local -r codebase=$1
        case $codebase in
            grid)
                echo "xml"
            ;;
            ddaamg)
                echo "ini"
            ;;
            *)
                echo "$usage" >> /dev/stderr
                return 1
        esac
    fi
}

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

function convert_to_int() {
    local -r boolean="$1"; shift
    if [[ "$boolean" == true ]] ; then
        echo 1
    else
        echo 0
    fi
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
    local -r codebase="$1"; shift

    if [[ ! -w "$output_file" ]]; then
        echo "${FUNCNAME[0]}: output file \"$output_file\" not present or not writable" >> /dev/stderr
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

    if [[ ${codebase} == "grid" ]]; then
        sed -ri 's|%START_SUBSPACE_FROM_RANDOM%|'"${start_subspace_from_random}"'|g'                   "$output_file"
        sed -ri 's|%USE_ANTIPERIODIC_BC%|'"${use_antiperiodic_bc}"'|g'                                 "$output_file"
        sed -ri 's|%KCYCLE%|'"${kcycle}"'|g'                                                           "$output_file"
    elif [[ ${codebase} == "ddaamg" ]]; then
        sed -ri 's|%START_SUBSPACE_FROM_RANDOM%|'"$(convert_to_int ${start_subspace_from_random})"'|g' "$output_file"
        sed -ri 's|%USE_ANTIPERIODIC_BC%|'"$(convert_to_int ${use_antiperiodic_bc})"'|g'               "$output_file"
        sed -ri 's|%KCYCLE%|'"$(convert_to_int ${kcycle})"'|g'                                         "$output_file"
    else
        echo "${FUNCNAME[0]}: codebase \"$codebase\" not element of {${a_codebase[@]}}" >> /dev/stderr
        exit 1
    fi

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

    if [[ ${codebase} == "ddaamg" ]]; then
        case "${source_type}" in
            "ones")
                source_type=0
            ;;
            "random")
                source_type=2
            ;;
            *)
                echo "${FUNCNAME[0]}: source_type \"$source_type\" not element of {ones,random}" >> /dev/stderr
                exit 1
                ;;
        esac
    fi
    sed -ri 's|%SOURCE_TYPE%|'"${source_type}"'|g'                                    "$output_file"
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
        local template=$template_dir/$codebase/${n_levels}_lvls."$(file_extension $codebase)"
        local output_dir=$output_dir_base/$codebase
        local output_file=$output_dir/mg_params.${n_levels}_lvls."$(file_extension $codebase)"

        mkdir -p "$output_dir"
        cp "$template" "$output_file"

        replace_parameters_in_file "$output_file" "$codebase"

        echo "Done with file $output_file"
    done
}

create_mg_inputfiles "$@"
