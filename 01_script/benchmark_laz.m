% benchmark_all_pts.m
% Chay LAZ benchmark cho tat ca cac file .pts trong 02_raw_data
% Xuat rieng tung file CSV vao 04_analyst/benchmark/

clear; clc; close all;

%% Cau hinh duong dan
scriptDir = fileparts(mfilename('fullpath'));
projRoot = fileparts(scriptDir);
rawDir = fullfile(projRoot, '02_raw_data');
benchmarkDir = fullfile(projRoot, '04_analyst', 'benchmark');
if ~exist(benchmarkDir, 'dir'), mkdir(benchmarkDir); end

% Duong dan den cac exe
toolsBinDir = fullfile(scriptDir, 'tools', 'LAStools', 'bin');
txt2las_exe = fullfile(toolsBinDir, 'txt2las64.exe');
laszip_exe = fullfile(toolsBinDir, 'laszip.exe');
las2las_exe = fullfile(toolsBinDir, 'las2las64.exe');

% Kiem tra tools
fprintf('Checking tools...\n');
if ~exist(txt2las_exe, 'file'), error('txt2las64.exe not found'); end
if ~exist(laszip_exe, 'file'), error('laszip.exe not found'); end
if ~exist(las2las_exe, 'file'), warning('las2las64.exe not found. Lossy skipped.'); end
fprintf('All tools found.\n');

% Danh sach file .pts
ptsFiles = dir(fullfile(rawDir, '*.pts'));
if isempty(ptsFiles), error('No .pts files found'); end

% Scale factors cho lossy
lossy_scales = [0.1, 0.01, 0.001, 0.0001];

fprintf('========== LAZ BENCHMARK FOR ALL FILES ==========\n');

for f = 1:length(ptsFiles)
    input_pts = fullfile(rawDir, ptsFiles(f).name);
    [~, name, ~] = fileparts(ptsFiles(f).name);
    fprintf('\n=== Processing: %s ===\n', name);
    
    info_orig = dir(input_pts);
    [points_orig, ~] = readPTS(input_pts);
    
    % Bang ket qua rieng cho file nay
    Results = table();
    
    %% Buoc 1: .pts -> .las
    las_file = fullfile(benchmarkDir, sprintf('%s_temp.las', name));
    fprintf('  Step 1: Converting .pts to .las...\n');
    cmd_txt2las = sprintf('"%s" -i "%s" -o "%s" -parse xyzRGB -set_version 1.2 -set_scale 0.001 0.001 0.001', ...
        txt2las_exe, input_pts, las_file);
    [status, cmdout] = system(cmd_txt2las);
    if status ~= 0 || ~exist(las_file, 'file')
        warning('Failed to convert %s', name);
        continue;
    end
    fprintf('  -> Created: %s\n', las_file);
    
    %% Buoc 2: LAZ lossless
    fprintf('  Step 2: Creating LAZ lossless...\n');
    laz_lossless = fullfile(benchmarkDir, sprintf('%s_lossless.laz', name));
    tic; system(sprintf('"%s" -i "%s" -o "%s"', laszip_exe, las_file, laz_lossless)); comp_lossless = toc;
    if ~exist(laz_lossless, 'file'), continue; end
    
    % Giai nen lossless
    restored_las = fullfile(benchmarkDir, sprintf('%s_lossless_restored.las', name));
    tic; system(sprintf('"%s" -i "%s" -o "%s"', laszip_exe, laz_lossless, restored_las)); dec_lossless = toc;
    
    % Chuyen .las -> .pts
    if exist(las2las_exe, 'file')
        restored_pts = fullfile(benchmarkDir, sprintf('%s_lossless_restored.pts', name));
        system(sprintf('"%s" -i "%s" -o "%s" -otxt -oparse xyzRGB', las2las_exe, restored_las, restored_pts));
    end
    
    % Tinh CR va RMSE lossless
    info_laz = dir(laz_lossless);
    cr_lossless = info_orig.bytes / info_laz.bytes;
    if exist('restored_pts', 'var') && exist(restored_pts, 'file')
        [points_laz, ~] = readPTS(restored_pts);
        N = min(size(points_orig,1), size(points_laz,1));
        diff = points_orig(1:N,:) - points_laz(1:N,:);
        rmse_lossless = sqrt(mean(sum(diff.^2, 2)));
    else
        rmse_lossless = 0;
    end
    
    row = table({name}, {'LAZ lossless'}, {NaN}, cr_lossless, rmse_lossless, comp_lossless, dec_lossless, ...
        'VariableNames', {'File', 'Method', 'ScaleFactor', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'});
    Results = [Results; row];
    fprintf('    Lossless: CR=%.2f, RMSE=%.3f mm, comp=%.2fs, decomp=%.2fs\n', cr_lossless, rmse_lossless, comp_lossless, dec_lossless);
    
    % Xoa tam
    delete(restored_las);
    if exist('restored_pts', 'var') && exist(restored_pts, 'file'), delete(restored_pts); end
    
    %% Buoc 3: LAZ lossy
    if exist(las2las_exe, 'file')
        fprintf('  Step 3: Creating LAZ lossy...\n');
        for s_idx = 1:length(lossy_scales)
            s = lossy_scales(s_idx);
            las_lossy = fullfile(benchmarkDir, sprintf('%s_lossy_s%.4f.las', name, s));
            system(sprintf('"%s" -i "%s" -o "%s" -rescale %.10f %.10f %.10f', las2las_exe, las_file, las_lossy, s, s, s));
            if ~exist(las_lossy, 'file'), continue; end
            
            laz_lossy = fullfile(benchmarkDir, sprintf('%s_lossy_s%.4f.laz', name, s));
            tic; system(sprintf('"%s" -i "%s" -o "%s"', laszip_exe, las_lossy, laz_lossy)); comp_lossy = toc;
            if ~exist(laz_lossy, 'file'), delete(las_lossy); continue; end
            
            restored_las_lossy = fullfile(benchmarkDir, sprintf('%s_lossy_s%.4f_restored.las', name, s));
            tic; system(sprintf('"%s" -i "%s" -o "%s"', laszip_exe, laz_lossy, restored_las_lossy)); dec_lossy = toc;
            
            restored_pts_lossy = fullfile(benchmarkDir, sprintf('%s_lossy_s%.4f_restored.pts', name, s));
            system(sprintf('"%s" -i "%s" -o "%s" -otxt -oparse xyzRGB', las2las_exe, restored_las_lossy, restored_pts_lossy));
            
            info_laz = dir(laz_lossy);
            cr_lossy = info_orig.bytes / info_laz.bytes;
            
            if exist(restored_pts_lossy, 'file')
                [points_laz, ~] = readPTS(restored_pts_lossy);
                N = min(size(points_orig,1), size(points_laz,1));
                diff = points_orig(1:N,:) - points_laz(1:N,:);
                rmse_lossy = sqrt(mean(sum(diff.^2, 2)));
            else
                rmse_lossy = NaN;
            end
            
            row = table({name}, {'LAZ lossy'}, s, cr_lossy, rmse_lossy, comp_lossy, dec_lossy, ...
                'VariableNames', {'File', 'Method', 'ScaleFactor', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'});
            Results = [Results; row];
            fprintf('      s=%.4f: CR=%.2f, RMSE=%.3f mm, comp=%.2fs, decomp=%.2fs\n', s, cr_lossy, rmse_lossy, comp_lossy, dec_lossy);
            
            % Xoa file tam
            delete(las_lossy); delete(laz_lossy); delete(restored_las_lossy);
            if exist(restored_pts_lossy, 'file'), delete(restored_pts_lossy); end
        end
    end
    
    %% Xuat ket qua rieng cho file nay
    outputFile = fullfile(benchmarkDir, sprintf('%s_laz_benchmark.xlsx', name));
    writetable(Results, outputFile);
    % Cung xuat CSV de tien dung
    csvFile = fullfile(benchmarkDir, sprintf('%s_laz_benchmark.csv', name));
    writetable(Results, csvFile);
    fprintf('  Results saved to: %s, %s\n', outputFile, csvFile);
    
    % Xoa file trung gian
    delete(las_file);
    delete(laz_lossless);
end

fprintf('\n========== ALL LAZ BENCHMARKS COMPLETED ==========\n');