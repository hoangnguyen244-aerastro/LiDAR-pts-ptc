% plot_figure_benchmark.m
% Ve bieu do so sanh CR va RMSE giua cac phuong phap nén
% T??ng thich MATLAB R2015b (khong dung yyaxis)

clear; clc; close all;

%% Cau hinh duong dan
scriptDir = fileparts(mfilename('fullpath'));
projRoot = fileparts(scriptDir);
benchmarkDir = fullfile(projRoot, '04_analyst', 'benchmark');
analystDir = fullfile(projRoot, '04_analyst');

%% 1. Doc bang tong hop
summaryFile = fullfile(benchmarkDir, 'benchmark_summary.xlsx');
if ~exist(summaryFile, 'file')
    error('Summary file not found. Please run collect_all_results.m first.');
end
summaryTable = readtable(summaryFile);

%% 2. Lay du lieu
methods = summaryTable.Method;
CR_vals = summaryTable.Avg_CR;
RMSE_vals = summaryTable.Avg_RMSE_mm;

% Dam bao thu tu hien thi mong muon
expectedOrder = {'ZIP', 'LAZ lossless', 'LAZ lossy', 'PTC'};
[~, idx] = ismember(expectedOrder, methods);
if all(idx > 0)
    methods = methods(idx);
    CR_vals = CR_vals(idx);
    RMSE_vals = RMSE_vals(idx);
end

%% 3. Ve bieu do (cach 1: dung plotyy cho R2015b)
figure('Color', 'white', 'Position', [100, 100, 700, 500]);

% Ve cot CR bang bar
[ax, h1, h2] = plotyy(1:length(methods), CR_vals, 1:length(methods), RMSE_vals, @bar, @plot);

% Tuy chinh truc trai (CR)
set(ax(1), 'XTickLabel', methods, 'FontSize', 12, 'XTickLabelRotation', 15);
set(ax(1), 'YColor', [0 0.2 0.6], 'FontSize', 12);
ylabel(ax(1), 'Compression Ratio CR', 'FontSize', 14);
ylim(ax(1), [0 max(CR_vals)*1.2]);

% Tuy chinh cot bar
set(h1, 'FaceColor', [0 0.2 0.6], 'EdgeColor', 'k', 'LineWidth', 1.2);

% Tuy chinh truc phai (RMSE)
set(ax(2), 'YColor', [0 0 0], 'FontSize', 12);
ylabel(ax(2), 'RMSE (mm)', 'FontSize', 14);
ylim(ax(2), [0 max(RMSE_vals)*1.2]);

% Ve duong RMSE (mau den)
set(h2, 'LineWidth', 2.5, 'Color', [0 0 0], 'Marker', 'o', ...
    'MarkerFaceColor', [0 0 0], 'MarkerSize', 8);

% Tieu de
title('Comparison of Compression Ratio and RMSE', 'FontSize', 16);

% Chu thich
legend([h1, h2], {'CR', 'RMSE'}, 'Location', 'northeast', 'FontSize', 12);

% Tang kich thuoc nhan truc x
xlabel('Compression Method', 'FontSize', 14);

% Them luoi
grid(ax(1), 'on');
grid(ax(2), 'on');

%% 4. Luu hinh
outputFig = fullfile(analystDir, 'Figure3_benchmark.png');
saveas(gcf, outputFig);
fprintf('Figure 3 saved to: %s\n', outputFig);

%% 5. Xuat bang so lieu (Bang 6)
fprintf('\n========== TABLE 6: COMPARISON WITH OTHER FORMATS ==========\n');
fprintf('%-15s | %-12s | %-10s\n', 'Method', 'CR', 'RMSE (mm)');
fprintf('%s\n', repmat('-', 1, 45));
for i = 1:length(methods)
    fprintf('%-15s | %-12.2f | %-10.3f\n', methods{i}, CR_vals(i), RMSE_vals(i));
end

% Luu bang ra CSV
table6 = table(methods, CR_vals, RMSE_vals, ...
    'VariableNames', {'Method', 'CR', 'RMSE_mm'});
csvFile = fullfile(analystDir, 'Table6_comparison.csv');
writetable(table6, csvFile);
fprintf('\nTable 6 saved to: %s\n', csvFile);

fprintf('\n========== PLOT COMPLETED ==========\n');