% run_compression.m
% Chay nen/giai nen toan bo cac file .pts trong folder 02_raw_data
% Su dung Python de xu ly Huffman
% Ket qua duoc luu vao folder 03_ptc va 04_analyst

clear; clc; close all;

%% Cau hinh duong dan (tuong doi)
scriptDir = fileparts(mfilename('fullpath')); % thu muc cua script nay
projRoot = fileparts(scriptDir); % thu muc me (LiDAR-pts-ptc)

rawDir = fullfile(projRoot, '02_raw_data');
ptcDir = fullfile(projRoot, '03_ptc');
analystDir = fullfile(projRoot, '04_analyst');

% Tao cac thu muc neu chua ton tai
if ~exist(rawDir, 'dir'), mkdir(rawDir); end
if ~exist(ptcDir, 'dir'), mkdir(ptcDir); end
if ~exist(analystDir, 'dir'), mkdir(analystDir); end

% Tim tat ca file .pts trong rawDir
ptsFiles = dir(fullfile(rawDir, '*.pts'));
if isempty(ptsFiles)
    error('No .pts files found in folder %s', rawDir);
end

% Cac scale factor can test
scale_factors = [0.1, 0.01, 0.001, 0.0001];

% Python command (co the thay bang duong dan tuyet doi neu can)
python_cmd = 'python';

% Kiem tra file Python
compressPy = fullfile(scriptDir, 'ptc_compress.py');
decompressPy = fullfile(scriptDir, 'ptc_decompress.py');
if ~exist(compressPy, 'file') || ~exist(decompressPy, 'file')
    error('Missing Python files in script folder');
end

fprintf('========== START PROCESSING .PTS FILES ==========\n');

% Luu ket qua tong hop de ve bieu do sau
all_results = [];

for f = 1:length(ptsFiles)
    input_pts = fullfile(rawDir, ptsFiles(f).name);
    [~, name, ~] = fileparts(ptsFiles(f).name);
    fprintf('\n--- Processing file: %s ---\n', name);
    
    % Tao bang ket qua rieng cho file nay
    Results = table();
    
    for s_idx = 1:length(scale_factors)
        s = scale_factors(s_idx);
        output_ptc = fullfile(ptcDir, sprintf('%s_s%.4f.ptc', name, s));
        output_restored = fullfile(ptcDir, sprintf('%s_restored_s%.4f.pts', name, s));
        
        % 1. Compress using Python
        tic;
        cmd_compress = sprintf('%s "%s" "%s" "%s" %.10f', python_cmd, compressPy, input_pts, output_ptc, s);
        [status, cmdout] = system(cmd_compress);
        if status ~= 0
            warning('Compression error for %s, s=%.4f: %s', name, s, cmdout);
            continue;
        end
        comp_time = toc;
        
        if ~exist(output_ptc, 'file')
            warning('.ptc file not created: %s', output_ptc);
            continue;
        end
        
        % Compute CR
        info_orig = dir(input_pts);
        info_comp = dir(output_ptc);
        cr = info_orig.bytes / info_comp.bytes;
        
        % 2. Decompress using Python
        tic;
        cmd_decompress = sprintf('%s "%s" "%s" "%s"', python_cmd, decompressPy, output_ptc, output_restored);
        [status, cmdout] = system(cmd_decompress);
        if status ~= 0
            warning('Decompression error for %s, s=%.4f: %s', name, s, cmdout);
            continue;
        end
        dec_time = toc;
        
        if ~exist(output_restored, 'file')
            warning('Restored file does not exist: %s', output_restored);
            continue;
        end
        
        % 3. Compute errors
        [points_orig, ~] = readPTS(input_pts);
        [points_rec, ~] = readPTS(output_restored);
        N = min(size(points_orig,1), size(points_rec,1));
        diff = points_orig(1:N,:) - points_rec(1:N,:);
        errors = sqrt(sum(diff.^2, 2));
        MAE_mm = mean(errors);
        RMSE_mm = sqrt(mean(errors.^2));
        
        % Save to table
        row = table(s, cr, MAE_mm, RMSE_mm, comp_time, dec_time, ...
            'VariableNames', {'ScaleFactor', 'CR', 'MAE_mm', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'});
        Results = [Results; row];
        
        % Luu de ve bieu do tong hop sau
        all_results = [all_results; {name, s, cr, RMSE_mm}];
        
        fprintf('  s=%.4f: CR=%.2f, RMSE=%.3f mm, MAE=%.3f mm, comp=%.2fs, decomp=%.2fs\n', ...
            s, cr, RMSE_mm, MAE_mm, comp_time, dec_time);
    end
    
    %% Xuat ket qua rieng cho tung file
    if height(Results) > 0
        csvFile = fullfile(analystDir, sprintf('analyst_%s.csv', name));
        writetable(Results, csvFile);
        fprintf('Results saved to: %s\n', csvFile);
    end
end

fprintf('\n========== ALL FILES PROCESSED ==========\n');
fprintf('Individual CSV files saved in: %s\n', analystDir);