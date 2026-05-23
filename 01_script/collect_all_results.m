% collect_all_results.m
% Doc tat ca cac file CSV tu benchmark, tong hop ket qua cho 4 phuong phap
% Xuat ra 2 bang: (1) Tat ca ket qua chi tiet, (2) Bang trung binh

clear; clc; close all;

%% Cau hinh duong dan
scriptDir = fileparts(mfilename('fullpath'));
projRoot = fileparts(scriptDir);
benchmarkDir = fullfile(projRoot, '04_analyst', 'benchmark');
analystDir = fullfile(projRoot, '04_analyst');
if ~exist(benchmarkDir, 'dir')
    error('Benchmark folder not found. Please run benchmark scripts first.');
end

%% 1. Thu thap ket qua PTC tu cac file analyst_*.csv
ptcFiles = dir(fullfile(analystDir, 'analyst_*.csv'));
ptcData = [];
for i = 1:length(ptcFiles)
    data = readtable(fullfile(analystDir, ptcFiles(i).name));
    [~, name] = fileparts(ptcFiles(i).name);
    name = strrep(name, 'analyst_', '');
    data.File = repmat({name}, height(data), 1);
    data.Method = repmat({'PTC'}, height(data), 1);
    ptcData = [ptcData; data];
end
fprintf('Loaded %d PTC records\n', height(ptcData));

%% 2. Thu thap ket qua ZIP tu cac file *_zip_benchmark.csv
zipFiles = dir(fullfile(benchmarkDir, '*_zip_benchmark.csv'));
zipData = [];
for i = 1:length(zipFiles)
    data = readtable(fullfile(benchmarkDir, zipFiles(i).name));
    [~, name] = fileparts(zipFiles(i).name);
    name = strrep(name, '_zip_benchmark', '');
    data.File = repmat({name}, height(data), 1);
    data.Method = repmat({'ZIP'}, height(data), 1);
    % Them cot ScaleFactor (NaN cho ZIP)
    data.ScaleFactor = nan(height(data), 1);
    zipData = [zipData; data];
end
fprintf('Loaded %d ZIP records\n', height(zipData));

%% 3. Thu thap ket qua LAZ tu cac file *_laz_benchmark.csv
lazFiles = dir(fullfile(benchmarkDir, '*_laz_benchmark.csv'));
lazData = [];
for i = 1:length(lazFiles)
    data = readtable(fullfile(benchmarkDir, lazFiles(i).name));
    [~, name] = fileparts(lazFiles(i).name);
    name = strrep(name, '_laz_benchmark', '');
    data.File = repmat({name}, height(data), 1);
    lazData = [lazData; data];
end
fprintf('Loaded %d LAZ records\n', height(lazData));

%% 4. Chuan hoa ten cot cho tat ca cac bang
% PTC da co san: File, Method, ScaleFactor, CR, RMSE_mm, CompTime_s, DecompTime_s
% Can chuan hoa them cho PTC

% Chuan hoa PTC (dam bao ScaleFactor la double)
ptcData.ScaleFactor = double(ptcData.ScaleFactor);

% Chuan hoa ZIP (dam bao cac cot can thiet)
if ~any(strcmp(zipData.Properties.VariableNames, 'CR'))
    zipData.Properties.VariableNames{'CR'} = 'CR';
end
if ~any(strcmp(zipData.Properties.VariableNames, 'RMSE_mm'))
    zipData.Properties.VariableNames{'RMSE_mm'} = 'RMSE_mm';
end
if ~any(strcmp(zipData.Properties.VariableNames, 'CompTime_s'))
    zipData.Properties.VariableNames{'CompTime_s'} = 'CompTime_s';
end
if ~any(strcmp(zipData.Properties.VariableNames, 'DecompTime_s'))
    zipData.Properties.VariableNames{'DecompTime_s'} = 'DecompTime_s';
end
zipData.ScaleFactor = double(zipData.ScaleFactor);

% Chuan hoa LAZ
lazData.ScaleFactor = double(lazData.ScaleFactor);
if ~any(strcmp(lazData.Properties.VariableNames, 'CR'))
    lazData.Properties.VariableNames{'CR'} = 'CR';
end
if ~any(strcmp(lazData.Properties.VariableNames, 'RMSE_mm'))
    lazData.Properties.VariableNames{'RMSE_mm'} = 'RMSE_mm';
end
if ~any(strcmp(lazData.Properties.VariableNames, 'CompTime_s'))
    lazData.Properties.VariableNames{'CompTime_s'} = 'CompTime_s';
end
if ~any(strcmp(lazData.Properties.VariableNames, 'DecompTime_s'))
    lazData.Properties.VariableNames{'DecompTime_s'} = 'DecompTime_s';
end

%% 5. Chon cac cot can thiet cho moi bang
% PTC
ptc_cols = {'File', 'Method', 'ScaleFactor', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'};
if all(ismember(ptc_cols, ptcData.Properties.VariableNames))
    ptcSelected = ptcData(:, ptc_cols);
else
    error('PTC data missing required columns');
end

% ZIP
zip_cols = {'File', 'Method', 'ScaleFactor', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'};
if all(ismember(zip_cols, zipData.Properties.VariableNames))
    zipSelected = zipData(:, zip_cols);
else
    % Neu thieu cot, tao them
    for c = 1:length(zip_cols)
        if ~any(strcmp(zipData.Properties.VariableNames, zip_cols{c}))
            zipData.(zip_cols{c}) = nan(height(zipData), 1);
        end
    end
    zipSelected = zipData(:, zip_cols);
end

% LAZ
laz_cols = {'File', 'Method', 'ScaleFactor', 'CR', 'RMSE_mm', 'CompTime_s', 'DecompTime_s'};
if all(ismember(laz_cols, lazData.Properties.VariableNames))
    lazSelected = lazData(:, laz_cols);
else
    for c = 1:length(laz_cols)
        if ~any(strcmp(lazData.Properties.VariableNames, laz_cols{c}))
            lazData.(laz_cols{c}) = nan(height(lazData), 1);
        end
    end
    lazSelected = lazData(:, laz_cols);
end

%% 6. Hop nhat tat ca du lieu vao mot bang
allResults = [ptcSelected; zipSelected; lazSelected];
fprintf('Total records: %d\n', height(allResults));

%% 7. Xuat bang chi tiet
detailFile = fullfile(benchmarkDir, 'all_benchmark_results.xlsx');
writetable(allResults, detailFile);
fprintf('Detailed results saved to: %s\n', detailFile);

%% 8. Tinh bang trung binh cho tung phuong phap (voi s=0.001 cho PTC va LAZ lossy)
methods = {'ZIP', 'LAZ lossless', 'LAZ lossy', 'PTC'};
avg_cr = zeros(length(methods), 1);
avg_rmse = zeros(length(methods), 1);
avg_comp = zeros(length(methods), 1);
avg_decomp = zeros(length(methods), 1);

% ZIP (lay tat ca)
idx_zip = strcmp(allResults.Method, 'ZIP');
if sum(idx_zip) > 0
    avg_cr(1) = mean(allResults.CR(idx_zip), 'omitnan');
    avg_rmse(1) = mean(allResults.RMSE_mm(idx_zip), 'omitnan');
    avg_comp(1) = mean(allResults.CompTime_s(idx_zip), 'omitnan');
    avg_decomp(1) = mean(allResults.DecompTime_s(idx_zip), 'omitnan');
else
    avg_cr(1) = NaN; avg_rmse(1) = NaN; avg_comp(1) = NaN; avg_decomp(1) = NaN;
end

% LAZ lossless
idx_lossless = strcmp(allResults.Method, 'LAZ lossless');
if sum(idx_lossless) > 0
    avg_cr(2) = mean(allResults.CR(idx_lossless), 'omitnan');
    avg_rmse(2) = mean(allResults.RMSE_mm(idx_lossless), 'omitnan');
    avg_comp(2) = mean(allResults.CompTime_s(idx_lossless), 'omitnan');
    avg_decomp(2) = mean(allResults.DecompTime_s(idx_lossless), 'omitnan');
else
    avg_cr(2) = NaN; avg_rmse(2) = NaN; avg_comp(2) = NaN; avg_decomp(2) = NaN;
end

% LAZ lossy (lay s=0.001)
idx_lossy = strcmp(allResults.Method, 'LAZ lossy') & abs(allResults.ScaleFactor - 0.001) < 1e-6;
if sum(idx_lossy) > 0
    avg_cr(3) = mean(allResults.CR(idx_lossy), 'omitnan');
    avg_rmse(3) = mean(allResults.RMSE_mm(idx_lossy), 'omitnan');
    avg_comp(3) = mean(allResults.CompTime_s(idx_lossy), 'omitnan');
    avg_decomp(3) = mean(allResults.DecompTime_s(idx_lossy), 'omitnan');
else
    avg_cr(3) = NaN; avg_rmse(3) = NaN; avg_comp(3) = NaN; avg_decomp(3) = NaN;
end

% PTC (lay s=0.001)
idx_ptc = strcmp(allResults.Method, 'PTC') & abs(allResults.ScaleFactor - 0.001) < 1e-6;
if sum(idx_ptc) > 0
    avg_cr(4) = mean(allResults.CR(idx_ptc), 'omitnan');
    avg_rmse(4) = mean(allResults.RMSE_mm(idx_ptc), 'omitnan');
    avg_comp(4) = mean(allResults.CompTime_s(idx_ptc), 'omitnan');
    avg_decomp(4) = mean(allResults.DecompTime_s(idx_ptc), 'omitnan');
else
    avg_cr(4) = NaN; avg_rmse(4) = NaN; avg_comp(4) = NaN; avg_decomp(4) = NaN;
end

%% 9. Tao bang trung binh
summaryTable = table(methods', avg_cr, avg_rmse, avg_comp, avg_decomp, ...
    'VariableNames', {'Method', 'Avg_CR', 'Avg_RMSE_mm', 'Avg_CompTime_s', 'Avg_DecompTime_s'});

summaryFile = fullfile(benchmarkDir, 'benchmark_summary.xlsx');
writetable(summaryTable, summaryFile);
fprintf('Summary table saved to: %s\n', summaryFile);

%% 10. Hien thi bang trung binh
fprintf('\n========== AVERAGE RESULTS (over 4 datasets, s=0.001 for PTC/LAZ lossy) ==========\n');
disp(summaryTable);

fprintf('\n========== COLLECTION COMPLETED ==========\n');