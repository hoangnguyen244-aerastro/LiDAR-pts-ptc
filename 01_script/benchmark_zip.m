% zip_all_pts.m
% Chay ZIP benchmark cho tat ca cac file .pts trong 02_raw_data
% Xuat rieng tung file CSV vao 04_analyst/benchmark/

clear; clc; close all;

%% Cau hinh duong dan
scriptDir = fileparts(mfilename('fullpath'));
projRoot = fileparts(scriptDir);
rawDir = fullfile(projRoot, '02_raw_data');
benchmarkDir = fullfile(projRoot, '04_analyst', 'benchmark');
if ~exist(benchmarkDir, 'dir'), mkdir(benchmarkDir); end

% Danh sach file .pts
ptsFiles = dir(fullfile(rawDir, '*.pts'));
if isempty(ptsFiles), error('No .pts files found'); end

fprintf('========== ZIP BENCHMARK FOR ALL FILES ==========\n');

for f = 1:length(ptsFiles)
    input_pts = fullfile(rawDir, ptsFiles(f).name);
    [~, name, ~] = fileparts(ptsFiles(f).name);
    fprintf('\n=== Processing: %s ===\n', name);
    
    info_orig = dir(input_pts);
    [points_orig, ~] = readPTS(input_pts);
    
    % Bang ket qua rieng
    Results = table();
    
    %% ZIP compression
    zip_file = fullfile(benchmarkDir, sprintf('%s.zip', name));
    tic; zip(zip_file, input_pts); comp_time = toc;
    
    % Giai nen vao temp
    temp_dir = fullfile(benchmarkDir, 'temp_zip');
    if ~exist(temp_dir, 'dir'), mkdir(temp_dir); end
    tic; unzip(zip_file, temp_dir); dec_time = toc;
    restored_pts = fullfile(temp_dir, ptsFiles(f).name);
    
    % Tinh CR
    info_zip = dir(zip_file);
    cr = info_orig.bytes / info_zip.bytes;
    
    % Tinh RMSE
    [points_zip, ~] = readPTS(restored_pts);
    N = min(size(points_orig,1), size(points_zip,1));
    diff = points_orig(1:N,:) - points_zip(1:N,:);
    errors = sqrt(sum(diff.^2, 2));
    rmse = sqrt(mean(errors.^2));
    
    % Luu vao bang
    row = table({name}, cr, rmse, comp_time, dec_time, ...
        'VariableNames', {'File', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'});
    Results = [Results; row];
    
    fprintf('  ZIP: CR=%.2f, RMSE=%.3f mm, comp=%.2fs, decomp=%.2fs\n', cr, rmse, comp_time, dec_time);
    
    %% Xuat ket qua rieng
    outputFile = fullfile(benchmarkDir, sprintf('%s_zip_benchmark.xlsx', name));
    csvFile = fullfile(benchmarkDir, sprintf('%s_zip_benchmark.csv', name));
    writetable(Results, outputFile);
    writetable(Results, csvFile);
    fprintf('  Results saved to: %s, %s\n', outputFile, csvFile);
    
    % Xoa file tam
    delete(zip_file);
    rmdir(temp_dir, 's');
end

fprintf('\n========== ALL ZIP BENCHMARKS COMPLETED ==========\n');