% run_compression_with_rgb.m
% Chay nen/giai nen co nen RGB (Huffman) tren tat ca file .pts trong 02_raw_data
% Tuong thich MATLAB R2015b

clear; clc; close all;

%% Cau hinh duong dan
scriptDir = fileparts(mfilename('fullpath'));  % .../01_script/test_include_rgb
projRoot = fileparts(fileparts(scriptDir));    % .../LiDAR-pts-ptc

% Them thu muc cha (01_script) vao path de tim readPTS.m va writePTS.m
parentDir = fileparts(scriptDir);  % .../01_script
addpath(parentDir);

rawDir = fullfile(projRoot, '02_raw_data');
ptcDir = fullfile(projRoot, '03_ptc');
analystDir = fullfile(projRoot, '04_analyst');
benchmarkDir = fullfile(analystDir, 'benchmark');
if ~exist(benchmarkDir, 'dir'), mkdir(benchmarkDir); end

%% === TIM PYTHON ===
fprintf('Searching for Python...\n');
python_cmd = '';

% Danh sach cac lenh va duong dan can thu
python_attempts = {
    'py',           % Python launcher (Windows)
    'python',       % Python default
    'python3',      % Python 3
    'C:\Users\nguye\AppData\Local\Programs\Python\Python313\python.exe',
    'C:\Users\nguye\AppData\Local\Programs\Python\Python314\python.exe'
};

for i = 1:length(python_attempts)
    cmd = python_attempts{i};
    % Kiem tra neu la duong dan tuyet doi (co chua dau \ hoac :)
    if ~isempty(strfind(cmd, '\')) || ~isempty(strfind(cmd, ':'))
        if exist(cmd, 'file')
            python_cmd = cmd;
            fprintf('Found Python at: %s\n', python_cmd);
            break;
        end
    else
        % Neu la lenh (python, py, python3)
        [status, ~] = system([cmd ' --version']);
        if status == 0
            python_cmd = cmd;
            fprintf('Found Python: %s\n', python_cmd);
            break;
        end
    end
end

if isempty(python_cmd)
    fprintf('Python not found. Please enter full path to python.exe\n');
    fprintf('Example: C:\\Users\\nguye\\AppData\\Local\\Programs\\Python\\Python313\\python.exe\n');
    python_cmd = input('Path: ', 's');
    if ~exist(python_cmd, 'file')
        error('Python not found at: %s', python_cmd);
    end
end

% Kiem tra lai Python
[status, ver_out] = system(sprintf('"%s" --version', python_cmd));
if status == 0
    fprintf('Python version: %s\n', ver_out);
else
    error('Python cannot run with: "%s" --version', python_cmd);
end

%% Duong dan den Python scripts
compressPy = fullfile(scriptDir, 'ptc_compress_with_rgb.py');
decompressPy = fullfile(scriptDir, 'ptc_decompress_with_rgb.py');

% Kiem tra file Python ton tai
if ~exist(compressPy, 'file')
    error('Missing Python script: %s', compressPy);
end
if ~exist(decompressPy, 'file')
    error('Missing Python script: %s', decompressPy);
end

%% Danh sach file .pts
ptsFiles = dir(fullfile(rawDir, '*.pts'));
if isempty(ptsFiles)
    error('No .pts files found in %s', rawDir);
end

% Chi chay voi scale factor s=0.001 (de so sanh voi bang cu)
s = 0.001;

Results = table();

fprintf('========== COMPRESSION WITH RGB HUFFMAN (s=0.001) ==========\n');

for f = 1:length(ptsFiles)
    input_pts = fullfile(rawDir, ptsFiles(f).name);
    [~, name, ~] = fileparts(ptsFiles(f).name);
    fprintf('\nProcessing: %s\n', name);

    output_ptc = fullfile(ptcDir, sprintf('%s_rgb.ptc', name));
    output_restored = fullfile(ptcDir, sprintf('%s_rgb_restored.pts', name));

    % Nen
    tic;
    cmd_compress = sprintf('"%s" "%s" "%s" "%s" %.10f', python_cmd, compressPy, input_pts, output_ptc, s);
    [status, cmdout] = system(cmd_compress);
    if status ~= 0
        warning('Compression error for %s: %s', name, cmdout);
        continue;
    end
    comp_time = toc;

    if ~exist(output_ptc, 'file')
        warning('Output .ptc not created: %s', output_ptc);
        continue;
    end

    % Giai nen
    tic;
    cmd_decompress = sprintf('"%s" "%s" "%s" "%s"', python_cmd, decompressPy, output_ptc, output_restored);
    [status, cmdout] = system(cmd_decompress);
    if status ~= 0
        warning('Decompression error for %s: %s', name, cmdout);
        continue;
    end
    dec_time = toc;

    if ~exist(output_restored, 'file')
        warning('Restored file not found: %s', output_restored);
        continue;
    end

    % Tinh CR
    info_orig = dir(input_pts);
    info_comp = dir(output_ptc);
    cr = info_orig.bytes / info_comp.bytes;

    % Tinh RMSE (so sanh voi file goc)
    [points_orig, ~] = readPTS(input_pts);
    [points_rec, ~] = readPTS(output_restored);
    N_pts = min(size(points_orig,1), size(points_rec,1));
    diff = points_orig(1:N_pts,:) - points_rec(1:N_pts,:);
    errors = sqrt(sum(diff.^2, 2));
    rmse = sqrt(mean(errors.^2));

    % Luu ket qua
    row = table({name}, s, cr, rmse, comp_time, dec_time, ...
        'VariableNames', {'File', 'ScaleFactor', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'});
    Results = [Results; row];

    fprintf('  CR=%.2f, RMSE=%.3f mm, comp=%.2fs, decomp=%.2fs\n', cr, rmse, comp_time, dec_time);
end

%% Xuat ket qua ra Excel
outputExcel = fullfile(benchmarkDir, 'rgb_compression_results.xlsx');
writetable(Results, outputExcel);
fprintf('\nResults with RGB Huffman saved to: %s\n', outputExcel);

%% So sanh voi ket qua khong nen RGB (lay tu cac file analyst_*.csv)
ptcFiles = dir(fullfile(analystDir, 'analyst_*.csv'));
if ~isempty(ptcFiles)
    noRgbResults = [];
    for i = 1:length(ptcFiles)
        data = readtable(fullfile(analystDir, ptcFiles(i).name));
        idx = abs(data.ScaleFactor - s) < 1e-6;
        if any(idx)
            row = data(idx, {'ScaleFactor', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'});
            [~, name] = fileparts(ptcFiles(i).name);
            name = strrep(name, 'analyst_', '');
            row.File = {name};
            noRgbResults = [noRgbResults; row];
        end
    end
    if ~isempty(noRgbResults)
        Comparison = table();
        for i = 1:height(noRgbResults)
            file = noRgbResults.File{i};
            idx = strcmp(Results.File, file);
            if any(idx)
                comp_row = table({file}, ...
                    noRgbResults.CR(i), Results.CR(idx), ...
                    noRgbResults.CompTime_s(i), Results.CompTime_s(idx), ...
                    noRgbResults.DecompTime_s(i), Results.DecompTime_s(idx), ...
                    'VariableNames', {'File', 'CR_noRGB', 'CR_withRGB', ...
                    'CompTime_noRGB', 'CompTime_withRGB', ...
                    'DecompTime_noRGB', 'DecompTime_withRGB'});
                Comparison = [Comparison; comp_row];
            end
        end
        compExcel = fullfile(benchmarkDir, 'comparison_rgb_vs_norgb.xlsx');
        writetable(Comparison, compExcel);
        fprintf('Comparison table saved to: %s\n', compExcel);
        
        % Hien thi bang so sanh trong command window (tieng Anh)
        fprintf('\n========== COMPARISON: WITHOUT RGB vs WITH RGB ==========\n');
        for i = 1:height(Comparison)
            fprintf('File: %s\n', Comparison.File{i});
            fprintf('  CR: %.2f (no RGB) -> %.2f (with RGB)\n', Comparison.CR_noRGB(i), Comparison.CR_withRGB(i));
            fprintf('  CompTime: %.2f s (no RGB) -> %.2f s (with RGB)\n', Comparison.CompTime_noRGB(i), Comparison.CompTime_withRGB(i));
            fprintf('  DecompTime: %.2f s (no RGB) -> %.2f s (with RGB)\n', Comparison.DecompTime_noRGB(i), Comparison.DecompTime_withRGB(i));
            fprintf('\n');
        end
    end
end

fprintf('\n========== DONE ==========\n');