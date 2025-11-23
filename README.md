# DOS Plotting Script for VASP

A bash script for visualizing Density of States (DOS) data from VASP quantum chemistry calculations.

## Requirements

- VASP output files: `vasprun.xml`, `OUTCAR`
- gnuplot
- Standard Unix tools: awk, sed, grep

## Basic Usage

```bash
./dosplot-spin.sh <x_min> <x_max> [OPTIONS]
```

### Arguments

- `x_min`, `x_max` - Energy range for X-axis (relative to Fermi level)
- If not provided, defaults to -10 to 10 eV

## Examples

### 1. Simple total DOS plot
```bash
./dosplot-spin.sh -4 4
```
Plots total spin-up and spin-down DOS from -4 to 4 eV.

### 2. Redraw existing data
```bash
./dosplot-spin.sh -4 4 redraw
```
Regenerates plots without reprocessing raw data (faster).

### 3. Plot specific atoms
```bash
# Individual atoms
./dosplot-spin.sh -4 4 atoms 1 2 3 4 12

# Atom ranges (combined)
./dosplot-spin.sh -4 4 atoms 1-4 12

# Default grouping by atom type
./dosplot-spin.sh -4 4 atoms default
```

### 4. Plot specific orbitals
```bash
# Specific orbitals for atoms
./dosplot-spin.sh -4 4 orbitals 1dxy 2s 3all

# Orbital ranges
./dosplot-spin.sh -4 4 orbitals 1-2all 3-4dxy
```

### 5. Custom Y-axis limits
```bash
./dosplot-spin.sh -4 4 ylim 0 50
./dosplot-spin.sh -4 4 atoms 1-3 ylim -20 20
```

## Output Files

The script generates:
- `dos_tot_all.png/svg` - Total DOS (spin-up and spin-down)
- `dos_tot_pdos_all_<args>.png/svg` - Total + projected DOS
- `dos_tot_pdos_up_<args>.png/svg` - Spin-up only
- `dos_tot_pdos_stack_up.png` - Stacked area chart (spin-up)
- `dos_tot_pdos_stack_down.png` - Stacked area chart (spin-down)

## Supported Orbitals

**d-orbitals**: s, py, pz, px, dxy, dyz, dz2, dxz, x2-y2, all

**f-orbitals**: s, py, pz, px, dxy, dyz, dz2, dxz, fy3x2, fxyz, fyz2, fz3, fxz2, fzx2, fx3, all

## Batch Processing

```bash
# Plot DOS for multiple directories
list="dir1 dir2 dir3"
for i in $list; do 
    cd $i
    dosplot-spin.sh -4 4 redraw
    cd ..
done

# Copy output to parent directory
for i in $list; do 
    cp $i/dos_tot_pdos_all.png ${i}-dos.png
done
```

## How It Works

1. Extracts DOS data from `vasprun.xml`
2. Identifies atomic types and groups
3. Processes spin-up and spin-down components separately
4. Generates gnuplot scripts for visualization
5. Creates PNG and SVG output files

## Notes

- Energy is always plotted relative to the Fermi level (E - E_F)
- Spin-down DOS is plotted as negative values
- The script caches processed data for faster replotting
- Temporary files are stored in `gnu-tmp-<dirname>/`

## Troubleshooting

**"orbital problem - ERROR"**: Your VASP calculation doesn't have orbital projection data. Ensure LORBIT is set in INCAR.

**"too much atoms"**: You specified an atom number higher than the total atoms in your system.

**No output files**: Check that `vasprun.xml` and `OUTCAR` exist in the current directory.
