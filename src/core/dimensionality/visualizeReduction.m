function visualizeReduction(originalFeatures, reducedFeatures, reductionInfo, labels, metadata, outputDir)
% VISUALIZEREDUCTION Wizualizuj efekt redukcji wymiarowości - NAPRAWIONA

if nargin < 6
    outputDir = 'output/figures';
end

% DODANE: Sprawdź czy outputDir istnieje
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% POPRAWKA: Większa figura z poprawnym layoutem 1x2
figure('Position', [100, 100, 1400, 600]);

%% SUBPLOT 1: Porównanie wymiarowości
subplot(1, 2, 1);  % POPRAWKA: 1x2 layout zamiast 2x3

% POPRAWKA: Bezpieczne sprawdzanie pól
if isfield(reductionInfo, 'originalDims') && isfield(reductionInfo, 'reducedDims')
    dims = [reductionInfo.originalDims, reductionInfo.reducedDims];
else
    % FALLBACK: oblicz z danych
    dims = [size(originalFeatures, 2), size(reducedFeatures, 2)];
end

labels_dims = {'Original', 'Reduced'};
colors = [0.8, 0.2, 0.2; 0.2, 0.8, 0.2];

b = bar(dims);
b.FaceColor = 'flat';
b.CData = colors;

set(gca, 'XTickLabel', labels_dims);
ylabel('Number of Features');
title('Dimensionality Reduction', 'FontWeight', 'bold');

% Dodaj wartości na słupkach
for i = 1:length(dims)
    text(i, dims(i)/2, sprintf('%d', dims(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'Color', 'white', 'FontSize', 12);
end

% Dodaj procent redukcji
reduction_pct = (1 - dims(2)/dims(1)) * 100;
text(1.5, max(dims)*0.8, sprintf('%.1f%% reduction', reduction_pct), ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
    'BackgroundColor', 'yellow', 'EdgeColor', 'black');

grid on;

%% SUBPLOT 2: Explained Variance/Separability Analysis - TYLKO MDA I PCA
subplot(1, 2, 2);  % POPRAWKA: 1x2 layout zamiast 2x3

% POPRAWKA: Sprawdź metodę bezpiecznie
methodName = 'unknown';
if isfield(reductionInfo, 'method')
    methodName = lower(reductionInfo.method);
end

try
    switch methodName
        case 'mda'
            plotMDADiscriminantAnalysis(reductionInfo);
            
        case 'pca'
            % POPRAWKA: Sprawdź czy explained istnieje
            if isfield(reductionInfo, 'explained') && ~isempty(reductionInfo.explained)
                explained = reductionInfo.explained;
                cumExplained = cumsum(explained);
                
                yyaxis left
                bar(1:length(explained), explained, 'FaceColor', [0.3, 0.6, 0.9]);
                ylabel('Individual Variance %', 'Color', [0.3, 0.6, 0.9]);
                ylim([0, max(explained)*1.1]);
                
                yyaxis right
                plot(1:length(explained), cumExplained, 'ro-', 'LineWidth', 2, 'MarkerSize', 6);
                ylabel('Cumulative Variance %', 'Color', 'red');
                ylim([0, 100]);
                
                xlabel('Principal Component');
                title('PCA Variance Explained', 'FontWeight', 'bold');
                grid on;
            else
                % FALLBACK dla PCA bez explained
                text(0.5, 0.5, 'PCA analysis data not available', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12);
                title('PCA Analysis', 'FontWeight', 'bold');
                axis off;
            end
            
        case 'none'
            text(0.5, 0.5, 'No dimensionality reduction applied', ...
                'HorizontalAlignment', 'center', 'FontSize', 12);
            title('Original Features', 'FontWeight', 'bold');
            axis off;
            
        otherwise
            text(0.5, 0.5, sprintf('Analysis for %s not available', upper(methodName)), ...
                'HorizontalAlignment', 'center', 'FontSize', 12);
            title('Component Analysis', 'FontWeight', 'bold');
            axis off;
    end
catch ME
    % FALLBACK jeśli cokolwiek się nie uda
    text(0.5, 0.5, sprintf('Analysis failed: %s', ME.message), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
    title('Component Analysis', 'FontWeight', 'bold');
    axis off;
end

% TYTUŁ GŁÓWNY
sgtitle(sprintf('Dimensionality Reduction Analysis (%s)', upper(methodName)), ...
    'FontSize', 16, 'FontWeight', 'bold');

% ZAPISZ
try
    saveas(gcf, fullfile(outputDir, 'dimensionality_reduction_analysis.png'));
    close(gcf);
    fprintf('📊 Dimensionality reduction visualization saved\n');
catch ME
    fprintf('⚠️  Failed to save visualization: %s\n', ME.message);
    close(gcf);
end
end

%% HELPER FUNCTIONS - POPRAWIONE

function plotMDADiscriminantAnalysis(reductionInfo)
% PLOTMDADISCRIMINANTANALYSIS - BEZPIECZNA WERSJA

try
    if isfield(reductionInfo, 'eigenValues') && ~isempty(reductionInfo.eigenValues)
        eigenValues = reductionInfo.eigenValues;
        
        % Upewnij się że eigenValues to liczby dodatnie
        eigenValues = abs(eigenValues);
        eigenValues = eigenValues(eigenValues > 0);
        
        if ~isempty(eigenValues)
            bar(1:length(eigenValues), eigenValues, 'FaceColor', [0.2, 0.8, 0.4]);
            xlabel('MDA Component');
            ylabel('Eigenvalue');
            title('MDA Discriminant Analysis', 'FontWeight', 'bold');
            grid on;
            
            % Dodaj wartości na słupkach
            for i = 1:length(eigenValues)
                if eigenValues(i) > 0
                    text(i, eigenValues(i)/2, sprintf('%.2f', eigenValues(i)), ...
                        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'white');
                end
            end
            
            % Separability score jeśli dostępny
            if isfield(reductionInfo, 'separabilityScore') && ~isempty(reductionInfo.separabilityScore)
                text(length(eigenValues)/2, max(eigenValues)*0.8, ...
                    sprintf('Separability: %.3f', reductionInfo.separabilityScore), ...
                    'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
                    'BackgroundColor', 'yellow', 'EdgeColor', 'black');
            end
        else
            text(0.5, 0.5, 'No valid eigenvalues found', 'HorizontalAlignment', 'center');
            title('MDA Analysis - No Data', 'FontWeight', 'bold');
            axis off;
        end
    else
        text(0.5, 0.5, 'MDA eigenvalues not available', 'HorizontalAlignment', 'center');
        title('MDA Analysis - No Data', 'FontWeight', 'bold');
        axis off;
    end
catch ME
    text(0.5, 0.5, sprintf('MDA analysis failed: %s', ME.message), 'HorizontalAlignment', 'center');
    title('MDA Analysis - Error', 'FontWeight', 'bold');
    axis off;
end
end

function cmap = redblue(n)
% REDBLUE Niebiesko-biało-czerwona mapa kolorów
if nargin < 1, n = 256; end
if n == 1, cmap = [1 1 1]; return; end

half = floor(n/2);
blue_to_white = [linspace(0, 1, half)', linspace(0, 1, half)', ones(half, 1)];
white_to_red = [ones(n-half, 1), linspace(1, 0, n-half)', linspace(1, 0, n-half)'];
cmap = [blue_to_white; white_to_red];
end