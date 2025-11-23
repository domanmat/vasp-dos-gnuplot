#!/bin/bash

################################################################################
# DOS Plotting Script for VASP Calculations
# Usage: dosplot-spin.sh x_min x_max [OPTIONS]
# 
# Options:
#   redraw                  - Redraw using previously prepared data
#   atoms <list>           - Plot DOS for specific atoms (e.g., "1 2 3" or "1-3")
#   orbitals <list>        - Plot DOS for specific orbitals (e.g., "1dxy 2s")
#   ylim <y_min> <y_max>   - Set Y-axis limits
################################################################################

# Configuration
SCRIPT_DIR="$(pwd)"
SCRIPT_NAME="$(basename "$SCRIPT_DIR")"
TEMP_DIR="./gnu-tmp-${SCRIPT_NAME}"

# Color schemes
LINECOLORS="red web-green blue goldenrod cyan magenta"
RESOLUTION="1920x1080"
FONT_AXIS=28
FONT_KEY=21

################################################################################
# Helper Functions
################################################################################

print_usage() {
    cat << EOF

!DOS Plotting Script
!===================
!Necessary options are: x_min x_max {Modes}'
!Additional options are: x_min x_max {Styles} {Modes}'
!{Styles} are: YLIM y_min y_max ; dos=mode(not yet) ; stack(not yet) '
!{Modes} are: redraw (no options)'
!             atoms (e.g. "1 2 3" or "1-3" or "default")'
!             orbitals (e.g. "1dxy 2s 3all" or "1-2all 3-4dxy")'

EOF
}


setup_directories() {
    rm -f plotfile*
    
    if [ -d "$TEMP_DIR" ]; then
        mv "$TEMP_DIR" "${TEMP_DIR}_old"
    fi
    mkdir -p "$TEMP_DIR"
    
    if [ -d ./gnu-tmp-* ]; then
        rm -rf ./gnu-tmp-*
    fi
    
    if [ -d "${TEMP_DIR}_old" ]; then
        mv "${TEMP_DIR}_old" "$TEMP_DIR"
    fi
}

parse_arguments() {
    local args="$*"
    echo "$args"
    
    # Set x-axis range
    if [ $# -gt 0 ]; then
        X_MIN=$1
        X_MAX=$2
    else
        X_MIN=-10
        X_MAX=10
    fi
    
    echo "x_min=$X_MIN"
    echo "x_max=$X_MAX"
    
    # Parse y-axis limits
    if echo "$args" | grep -iq 'ylim'; then
        Y_MIN=$(echo "$args" | awk -F "ylim" '{print $2}' | awk '{print $1}')
        Y_MAX=$(echo "$args" | awk -F "ylim" '{print $2}' | awk '{print $2}')
        echo "y_min=$Y_MIN"
        echo "y_max=$Y_MAX"
    else
        unset Y_MIN Y_MAX
    fi
}

detect_orbital_configuration() {
    if grep -q 'fxyz' vasprun.xml; then
        echo '!f-orbitals detected: s py pz px dxy dyz dz2 dxz fy3x2 fxyz fyz2 fz3 fxz2 fzx2 fx3 all'
        ORBITAL_LIST='s py pz px dxy dyz dz2 dxz fy3x2 fxyz fyz2 fz3 fxz2 fzx2 fx3 all'
        ORBITAL_NUMBERS='1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17'
        MAX_COLUMN=18
        COLUMNS='3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18'
    elif grep -q 'dxy' vasprun.xml; then
        echo '!d-orbitals detected: s py pz px dxy dyz dz2 dxz x2-y2 all'
        ORBITAL_LIST='s py pz px dxy dyz dz2 dxz x2-y2 all'
        ORBITAL_NUMBERS='1 2 3 4 5 6 7 8 9 10'
        MAX_COLUMN=11
        COLUMNS='3 4 5 6 7 8 9 10 11'
    fi
}

extract_total_dos() {
    awk 'BEGIN{i=1}
         /<total>/{flag=1; next}
         /<\/total>/{flag=0}
         flag {a[i]=$2; b[i]=$3; i++}
         END {for(j=8; j<i-3; j++) print a[j], b[j]}' \
         vasprun.xml > "${TEMP_DIR}/dos_all.dat"
}

read_system_info() {
    N_ATOMS=$(awk '/<atoms>/ {print $2}' vasprun.xml)
    N_TYPES=$(awk '/<types>/ {print $2}' vasprun.xml)
    NEDOS=$(awk '/NEDOS/ {print $6}' OUTCAR)
    EFERMI=$(awk '/efermi/ {print $3}' vasprun.xml)
    
    echo "Number of atoms: $N_ATOMS"
    echo "Atomic types: $N_TYPES"
    
    # Extract atom types
    sed -n "/atomtype/,/atomtypes/p" vasprun.xml | \
        head -n -3 | sed '1,2d' | cut -c 12-13 | \
        awk '{print $1}' > "${TEMP_DIR}/atomtypes"
    
    sed -n "/atomtype/,/atomtypes/p" vasprun.xml | \
        head -n -3 | sed '1,2d' | cut -c 22-24 | \
        awk '{print $1}' > "${TEMP_DIR}/atomgroup"
}

identify_atomic_groups() {
    local atom_count=0
    local group_count=0
    local first_atom=1
    local last_atom=0
    local prev_type=""
    
    unset ATOM_GROUP_RANGES ATOM_GROUP_TYPES
    declare -ga ATOM_GROUP_RANGES ATOM_GROUP_TYPES
    
    while IFS= read -r atom_type; do
        ((atom_count++))
        
        if [[ "$atom_type" == "$prev_type" ]] || [ -z "$prev_type" ]; then
            ((group_count++))
        elif [[ "$atom_type" != "$prev_type" ]]; then
            last_atom=$((atom_count - 1))
            ATOM_GROUP_RANGES+=("$first_atom-$last_atom")
            ATOM_GROUP_TYPES+=("$prev_type")
            first_atom=$atom_count
            group_count=1
        fi
        
        prev_type=$atom_type
        
        if [[ $atom_count -eq $N_ATOMS ]]; then
            last_atom=$atom_count
            ATOM_GROUP_RANGES+=("$first_atom-$last_atom")
            ATOM_GROUP_TYPES+=("$prev_type")
        fi
    done < "${TEMP_DIR}/atomtypes"
    
    echo "!Atomic types: ${ATOM_GROUP_TYPES[*]}"
    echo "!Atom ranges: ${ATOM_GROUP_RANGES[*]}"
}

process_atom_dos() {
    local atom_list="$1"
    local mode="$2"  # 'atoms' or 'orbitals'
    local group_num=0
    
    echo "!Processing DOS for atoms: $atom_list"
    
    rm -f "${TEMP_DIR}"/dos-at*
    rm -f gr-*atoms*type*
    
    for atom_spec in $atom_list; do
        ((group_num++))
        
        if [[ "$atom_spec" =~ ^[0-9]+-[0-9]+$ ]]; then
            # Range of atoms (e.g., "1-4")
            process_atom_range "$atom_spec" "$group_num" "$mode"
        elif [[ "$atom_spec" =~ ^[0-9]+$ ]]; then
            # Single atom (e.g., "5")
            process_single_atom "$atom_spec" "$group_num" "$mode"
        else
            echo "!Warning: Invalid atom specification: $atom_spec"
        fi
    done
}

process_single_atom() {
    local atom=$1
    local group_num=$2
    local mode=$3
    
    if [ $atom -gt $N_ATOMS ]; then
        echo "!Error: Atom $atom exceeds total atoms ($N_ATOMS)"
        return 1
    fi
    
    local next_atom=$((atom + 1))
    local atom_type=$(sed -n "${atom}p" "${TEMP_DIR}/atomtypes")
    
    echo "!Processing atom $atom ($atom_type)"
    echo "$atom_type" >> "${TEMP_DIR}/atomtypes_list"
    
    # Extract DOS data for this atom
    if [ $atom -eq $N_ATOMS ]; then
        sed -n "/ion ${atom}\"/,/dos/p" vasprun.xml | head -n -3 > "${TEMP_DIR}/dos-at${atom}"
    else
        sed -n "/ion ${atom}\"/,/ion ${next_atom}\"/p" vasprun.xml > "${TEMP_DIR}/dos-at${atom}"
    fi
    
    # Extract spin-up and spin-down components
    sed -n '/spin 1/,/spin 2/p' "${TEMP_DIR}/dos-at${atom}" | \
        sed '1d' | head -n -2 > "${TEMP_DIR}/dos-at${atom}-up"
    
    sed -n '/spin 2/,$p' "${TEMP_DIR}/dos-at${atom}" | \
        sed '1d' | head -n -3 > "${TEMP_DIR}/dos-at${atom}-down"
    
    # Sum over all orbitals
    awk -v max=$MAX_COLUMN \
        '{sum=0; for(i=3; i<=max; ++i) sum+=$i; print $2, sum}' \
        "${TEMP_DIR}/dos-at${atom}-up" > "${TEMP_DIR}/dos-at${atom}-up-sum"
    
    awk -v max=$MAX_COLUMN \
        '{sum=0; for(i=3; i<=max; ++i) sum+=$i; print $2, sum}' \
        "${TEMP_DIR}/dos-at${atom}-down" > "${TEMP_DIR}/dos-at${atom}-down-sum"
    
    # Copy to output files
    cp "${TEMP_DIR}/dos-at${atom}-up-sum" "gr-up${group_num}-atoms-${atom}-type-${atom_type}"
    cp "${TEMP_DIR}/dos-at${atom}-down-sum" "gr-dn${group_num}-atoms-${atom}-type-${atom_type}"
}

process_atom_range() {
    local range=$1
    local group_num=$2
    local mode=$3
    
    local first=$(echo "$range" | cut -d'-' -f1)
    local last=$(echo "$range" | cut -d'-' -f2)
    
    local first_type=$(sed -n "${first}p" "${TEMP_DIR}/atomtypes")
    local last_type=$(sed -n "${last}p" "${TEMP_DIR}/atomtypes")
    
    if [ "$first_type" != "$last_type" ]; then
        echo "!Error: Atom range has inconsistent types ($first_type vs $last_type)"
        return 1
    fi
    
    echo "$first_type" >> "${TEMP_DIR}/atomtypes_list"
    
    # Process each atom in range and sum
    for ((atom=first; atom<=last; atom++)); do
        process_single_atom "$atom" "$group_num" "$mode"
        
        # Sum DOS from multiple atoms
        if [ $atom -eq $first ]; then
            cp "${TEMP_DIR}/dos-at${first}-up-sum" "${TEMP_DIR}/dos-at${range}-up-sum"
            cp "${TEMP_DIR}/dos-at${first}-down-sum" "${TEMP_DIR}/dos-at${range}-down-sum"
            rm -f "${TEMP_DIR}/dos-at${atom}-up-sum" "${TEMP_DIR}/dos-at${atom}-down-sum"
        else
            awk 'FNR==NR {a[FNR]=$2} NR!=FNR {$2 += a[FNR]; print}' \
                "${TEMP_DIR}/dos-at${atom}-up-sum" \
                "${TEMP_DIR}/dos-at${range}-up-sum" > temp_up
            
            awk 'FNR==NR {a[FNR]=$2} NR!=FNR {$2 += a[FNR]; print}' \
                "${TEMP_DIR}/dos-at${atom}-down-sum" \
                "${TEMP_DIR}/dos-at${range}-down-sum" > temp_down
            
            mv temp_up "${TEMP_DIR}/dos-at${range}-up-sum"
            mv temp_down "${TEMP_DIR}/dos-at${range}-down-sum"
            
            rm -f "${TEMP_DIR}/dos-at${atom}-up-sum" "${TEMP_DIR}/dos-at${atom}-down-sum"
        fi
    done
    
    # Copy final summed data
    cp "${TEMP_DIR}/dos-at${range}-up-sum" "gr-up${group_num}-atoms-${range}-type-${first_type}"
    cp "${TEMP_DIR}/dos-at${range}-down-sum" "gr-dn${group_num}-atoms-${range}-type-${first_type}"
}

generate_gnuplot_script() {
    local output_file=$1
    local format=$2  # 'png' or 'svg'
    local plot_type=$3  # 'total', 'pdos_all', 'pdos_up', 'stack_up', 'stack_down'
    
    local term_settings
    if [ "$format" = "svg" ]; then
        term_settings="set term svg size 960,540 font \"Arial,14\" fontscale 1.3333"
    else
        term_settings="set term pngcairo font \"Arial,${FONT_AXIS}\" size ${RESOLUTION/x/,}"
    fi
    
    cat > "$output_file" << EOF
$term_settings
set output "${plot_type}.${format}"

set xrange [$X_MIN:$X_MAX]
$([ -n "$Y_MIN" ] && echo "set yrange [$Y_MIN:$Y_MAX]")
set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
set termoption enhanced
set ylabel "DOS"
set xlabel 'E - E_F / eV'

LINECOLORS = "$LINECOLORS"
myLinecolor(i) = word(LINECOLORS, i)

list_up = system('ls -1B gr-up*atoms*type*')
list_down = system('ls -1B gr-dn*atoms*type*')

set linetype cycle words(list_up)

EOF

    # Add plot commands based on type
    case "$plot_type" in
        total)
            cat >> "$output_file" << EOF
plot "${TEMP_DIR}/dos_tot_up" using (\$1-$EFERMI):(\$2) w lines title "spin-up", \\
     "${TEMP_DIR}/dos_tot_down" using (\$1-$EFERMI):(\$2*-1) w lines title "spin-down"
EOF
            ;;
        pdos_all)
            cat >> "$output_file" << EOF
plot for [i=1:words(list_up)] word(list_up, i) using (\$1-$EFERMI):(\$2) w lines lc rgb myLinecolor(i) title word(list_up, i), \\
     for [i=1:words(list_down)] word(list_down, i) using (\$1-$EFERMI):(\$2*-1) w lines lc rgb myLinecolor(i) notitle, \\
     "${TEMP_DIR}/dos_tot_up" using (\$1-$EFERMI):(\$2) w lines lt rgb "black" title "total dos", \\
     "${TEMP_DIR}/dos_tot_down" using (\$1-$EFERMI):(\$2*-1) w lines lt rgb "black" notitle
EOF
            ;;
    esac
}

plot_total_dos() {
    csplit -z "${TEMP_DIR}/dos_all.dat" /spin/ '{*}' > /dev/null
    cp xx00 "${TEMP_DIR}/dos_tot_up"
    cp xx01 "${TEMP_DIR}/dos_tot_down"
    rm -f xx??
    
    generate_gnuplot_script "${TEMP_DIR}/plot_total.gp" "svg" "total"
    generate_gnuplot_script "${TEMP_DIR}/plot_total.gp" "png" "total"
    
    gnuplot -persist "${TEMP_DIR}/plot_total.gp"
}

################################################################################
# Main Script
################################################################################

main() {
    print_usage
    setup_directories
    parse_arguments "$@"
    detect_orbital_configuration
    
    # Check for redraw mode
    if [[ "$*" == *"redraw"* ]]; then
        echo "!Redraw mode: Using existing data"
        MODE='redraw'
    else
        extract_total_dos
        read_system_info
        identify_atomic_groups
        
        # Check signature to avoid reprocessing
        local sig_new=$(echo *.out | rev | cut -d- -f1 | rev | cut -d. -f1)
        local sig_old=$(echo xsignature-* | rev | cut -d- -f1 | rev | cut -d. -f1)
        
        if [[ "$sig_new" == *"$sig_old"* ]]; then
            echo "!Re-using previously prepared DOS data"
        else
            rm -f signature-*
            echo "$sig_new" > "xsignature-${sig_new}"
            echo "!Preparing new DOS data"
        fi
    fi
    
    # Process based on mode
    if [[ "$*" == *"atoms"* ]]; then
        MODE='atoms'
        local atom_list=$(echo "$@" | awk -F 'atoms' '{print $2}')
        
        if echo "$atom_list" | grep -qE 'def|all'; then
            echo "!Using default atom groups"
            atom_list="${ATOM_GROUP_RANGES[*]}"
        fi
        
        process_atom_dos "$atom_list" "atoms"
        
    elif [[ "$*" == *"orbital"* ]]; then
        MODE='orbitals'
        local orbital_list=$(echo "$@" | awk -F 'orbitals' '{print $2}')
        echo "!Orbital mode not fully implemented in this version"
    fi
    
    # Generate plots
    plot_total_dos
    
    # Cleanup
    echo "!Plots generated successfully"
}

# Run main function
main "$@"
