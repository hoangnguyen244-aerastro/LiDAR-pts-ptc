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

% Luu ket qua vao bang
Results = table();

fprintf('========== START PROCESSING .PTS FILES ==========\n');

for f = 1:length(ptsFiles)
    input_pts = fullfile(rawDir, ptsFiles(f).name);
    [~, name, ~] = fileparts(ptsFiles(f).name);
    fprintf('\n--- Processing file: %s ---\n', name);
    
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
        row = table({name}, s, cr, MAE_mm, RMSE_mm, comp_time, dec_time, ...
            'VariableNames', {'File', 'ScaleFactor', 'CR', 'MAE_mm', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'});
        Results = [Results; row];
        
        fprintf('  s=%.4f: CR=%.2f, RMSE=%.3f mm, MAE=%.3f mm, comp=%.2fs, decomp=%.2fs\n', ...
            s, cr, RMSE_mm, MAE_mm, comp_time, dec_time);
        
        % Xoa file tam (neu muon giu lai de kiem tra, hay comment dong nay)
        % delete(output_ptc);
        % delete(output_restored);
    end
end

%% Display summary table
disp('========== SUMMARY RESULTS ==========');
disp(Results);

%% Save results to CSV
csvFile = fullfile(analystDir, 'ket_qua_nen.csv');
writetable(Results, csvFile);
fprintf('Results saved to CSV: %s\n', csvFile);

%% Plot CR and RMSE vs scale factor
if height(Results) > 0
    figure('Visible', 'off');
    files_list = unique(Results.File);
    for i = 1:length(files_list)
        idx = strcmp(Results.File, files_list{i});
        subplot(2,1,1);
        semilogx(Results.ScaleFactor(idx), Results.CR(idx), '-o', 'LineWidth', 2); hold on;
        subplot(2,1,2);
        loglog(Results.ScaleFactor(idx), Results.RMSE_mm(idx), '-s', 'LineWidth', 2); hold on;
    end
    subplot(2,1,1);
    xlabel('Scale factor s (m)'); ylabel('Compression Ratio CR');
    title('CR vs s'); grid on; legend(files_list, 'Location', 'best');
    subplot(2,1,2);
    xlabel('Scale factor s (m)'); ylabel('RMSE (mm)');
    title('RMSE vs s'); grid on; legend(files_list, 'Location', 'best');
    saveas(gcf, fullfile(analystDir, 'CR_RMSE_plot.png'));
    close(gcf);
    fprintf('Plot saved to: %s\n', fullfile(analystDir, 'CR_RMSE_plot.png'));
end

fprintf('\n========== DONE ==========\n');