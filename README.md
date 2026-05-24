================================================================================
           PTS to PTC Compression/Decompression Tool - User Guide
================================================================================

This tool compresses .pts point cloud files (from iPhone LiDAR) to .ptc format 
using Controlled Quantization + Delta Encoding + Huffman Coding, and restores 
them back. It runs on MATLAB R2015b (or newer) and Python 3.6+.

================================================================================
FOLDER STRUCTURE
================================================================================

LiDAR-pts-ptc/
│
├── 01_script/          # MATLAB scripts and Python modules
│   ├── readPTS.m
│   ├── writePTS.m
│   ├── test_all_pts.m          # main test script
│   ├── ptc_compress.py         # Python compression engine
│   └── ptc_decompress.py       # Python decompression engine
│
├── 02_raw_data/        # Place your .pts files here (e.g., Sculpture.pts, RoomScan.pts)
│
├── 03_ptc/             # Output .ptc and restored .pts files will be saved here
│
└── 04_analyst/         # Output CSV results and figures will be saved here
     ├── analyst_Facecade.csv
     ├── analyst_Funiture.csv
     ├── analyst_RoomScan.csv
     ├── analyst_Sculpture.csv
     ├── Table6_comparison.csv
     ├── Figure3_benchmark.png
     ├── CR_RMSE_plot.png
     └── benchmark/
         ├── Facecade_zip_benchmark.csv
         ├── Facecade_laz_benchmark.csv
         ├── Funiture_zip_benchmark.csv
         ├── Funiture_laz_benchmark.csv
         ├── RoomScan_zip_benchmark.csv
         ├── RoomScan_laz_benchmark.csv
         ├── Sculpture_zip_benchmark.csv
         ├── Sculpture_laz_benchmark.csv
         ├── all_benchmark_results.xlsx
         └── benchmark_summary.xlsx

================================================================================
REQUIREMENTS
================================================================================

1. MATLAB R2015b or later (no toolboxes required, but Communications Toolbox
   is optional; the code uses Python for Huffman).
2. Python 3.6 or later (no extra packages needed, only standard library).
3. Windows / Linux / macOS (tested on Windows 10/11).

================================================================================
SETUP (ONE TIME)
================================================================================

Step 1: Install MATLAB r2015b and Python ver3.14 if not already installed.
Step 2: Copy all provided files into the "01_script" folder.
Step 4: Place your .pts files (e.g., Sculpture.pts, RoomScan.pts) into the "02_raw_data" folder.

================================================================================
HOW TO RUN
================================================================================

1. Open MATLAB and navigate to the project root folder "LiDAR-pts-ptc".

2. In the folder 01_script, run: 
run_compression.m, benchmark_laz.m, benchmark_zip.m, collect_all_results.m, run_compression_with_rgb.m, plot_figure_benchmark.m 

3. The script will:
   - Automatically detect all .pts files inside "02_raw_data".
   - For each file, compress with scale factors s = 0.1, 0.01, 0.001, 0.0001.
   - Decompress and compute CR, MAE, RMSE, compression/decompression time.
   - Save compressed .ptc and restored .pts files into "03_ptc".
   - Save a CSV summary table (results.csv) and plot images into "04_analyst".

4. After execution, check the command window for live progress and final results.

================================================================================
INTERPRETING RESULTS
================================================================================

- Compression Ratio (CR) : higher is better (typical 6-12:1).
- RMSE (mm) : reconstruction error; for s=0.001, expected ~0.5 mm.
- MAE (mm) : mean absolute error; similar to RMSE.
- Time : compression and decompression speeds (points per second).

Example output for Sculpture.pts with s=0.001:
    CR = 9.08:1, RMSE = 0.50 mm, MAE = 0.48 mm
    Compression time = 1.46 s, Decompression time = 3.43 s

================================================================================
TROUBLESHOOTING
================================================================================

- "Python was not found": Add Python to system PATH or modify the variable
  "python_cmd" in test_all_pts.m to use full path (e.g., 'C:\Python310\python.exe').

- "min() iterable argument is empty": The input .pts file may have a header line
  or 7 columns (with intensity). Edit ptc_compress.py to skip header and handle
  7 columns (see comments in the script).

- Missing .pts files: Ensure file names match exactly (case-sensitive on Linux/macOS).

- Permission errors: Make sure "03_ptc" and "04_analyst" folders exist and are writable.

================================================================================
CONTACT: hoangnguyen.artist@gmail.com
================================================================================

For questions or bug reports, please contact the author.

Version 1.0 (May 2026)
================================================================================