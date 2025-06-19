function visualizeReduction(originalFeatures, reducedFeatures, reductionInfo, labels, metadata, outputDir)
% VISUALIZEREDUCTION Wizualizuje efekty redukcji wymiarowości cech
%
% Funkcja generuje kompleksową wizualizację procesu redukcji wymiarowości,
% porównując cechy oryginalne z zredukowanymi. Tworzy wykresy przedstawiające
% zmianę liczby wymiarów oraz analizę komponentów dla różnych metod redukcji
% (PCA, MDA). Wyniki zapisywane są jako pliki PNG dla dokumentacji.
%
% Parametry wejściowe:
%   originalFeatures - macierz oryginalnych cech [samples × original_dims]
%   reducedFeatures - macierz zredukowanych cech [samples × reduced_dims]
%   reductionInfo - struktura z informacjami o redukcji (method, explained, eigenValues)
%   labels - etykiety klas dla próbek [samples × 1]
%   metadata - metadane z nazwami klas
%   outputDir - katalog wyjściowy dla wykresów (domyślnie: 'output/figures')
%
% Generowane wykresy:
%   1. Porównanie wymiarowości (słupki przed/po redukcji + % redukcji)
%   2. Analiza komponentów (explained variance dla PCA, eigenvalues dla MDA)
%
% Obsługiwane metody redukcji:
%   - PCA: wykresy explained variance (indywidualnej i kumulatywnej)
%   - MDA: wykresy eigenvalues i separability score
%   - NONE: placeholder dla brak redukcji
%
% Przykład użycia:
%   visualizeReduction(origFeats, redFeats, reductionInfo, labels, meta);

if nargin < 6
    outputDir = 'output/figures';
end

% Zapewnienie istnienia katalogu wyjściowego
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Utworzenie figury z optymalnym layoutem 1x2
figure('Position', [100, 100, 1400, 600]);

%% SUBPLOT 1: Porównanie wymiarowości - wizualizacja efektu redukcji
subplot(1, 2, 1);

% Bezpieczne pobranie informacji o wymiarach z fallback
if isfield(reductionInfo, 'originalDims') && isfield(reductionInfo, 'reducedDims')
    dims = [reductionInfo.originalDims, reductionInfo.reducedDims];
else
    % Fallback - oblicz bezpośrednio z macierzy cech
    dims = [size(originalFeatures, 2), size(reducedFeatures, 2)];
end

labels_dims = {'Original', 'Reduced'};
colors = [0.8, 0.2, 0.2; 0.2, 0.8, 0.2]; % Czerwony vs Zielony

% Wykres słupkowy z kolorami
b = bar(dims);
b.FaceColor = 'flat';
b.CData = colors;

set(gca, 'XTickLabel', labels_dims);
ylabel('Number of Features');
title('Dimensionality Reduction', 'FontWeight', 'bold');

% Dodanie wartości liczbowych na słupkach
for i = 1:length(dims)
    text(i, dims(i)/2, sprintf('%d', dims(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'Color', 'white', 'FontSize', 12);
end

% Obliczenie i wyświetlenie procentu redukcji
reduction_pct = (1 - dims(2)/dims(1)) * 100;
text(1.5, max(dims)*0.8, sprintf('%.1f%% reduction', reduction_pct), ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
    'BackgroundColor', 'yellow', 'EdgeColor', 'black');

grid on;

%% SUBPLOT 2: Analiza komponentów - specyficzna dla metody redukcji
subplot(1, 2, 2);

% Bezpieczne pobranie nazwy metody z fallback
methodName = 'unknown';
if isfield(reductionInfo, 'method')
    methodName = lower(reductionInfo.method);
end

try
    switch methodName
        case 'mda'
            plotMDADiscriminantAnalysis(reductionInfo);
            
        case 'pca'
            % Analiza explained variance dla PCA
            if isfield(reductionInfo, 'explained') && ~isempty(reductionInfo.explained)
                explained = reductionInfo.explained;
                cumExplained = cumsum(explained);
                
                % Wykres z podwójną osią Y
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
                % Fallback dla PCA bez danych explained variance
                text(0.5, 0.5, 'PCA analysis data not available', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12);
                title('PCA Analysis', 'FontWeight', 'bold');
                axis off;
            end
            
        case 'none'
            % Placeholder dla braku redukcji wymiarowości
            text(0.5, 0.5, 'No dimensionality reduction applied', ...
                'HorizontalAlignment', 'center', 'FontSize', 12);
            title('Original Features', 'FontWeight', 'bold');
            axis off;
            
        otherwise
            % Obsługa nieznanych metod redukcji
            text(0.5, 0.5, sprintf('Analysis for %s not available', upper(methodName)), ...
                'HorizontalAlignment', 'center', 'FontSize', 12);
            title('Component Analysis', 'FontWeight', 'bold');
            axis off;
    end
catch ME
    % Uniwersalny fallback dla błędów w analizie komponentów
    text(0.5, 0.5, sprintf('Analysis failed: %s', ME.message), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
    title('Component Analysis', 'FontWeight', 'bold');
    axis off;
end

% Główny tytuł figury
sgtitle(sprintf('Dimensionality Reduction Analysis (%s)', upper(methodName)), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Zapisanie wykresu z obsługą błędów
try
    saveas(gcf, fullfile(outputDir, 'dimensionality_reduction_analysis.png'));
    close(gcf);
    fprintf('📊 Dimensionality reduction visualization saved\n');
catch ME
    fprintf('⚠️  Failed to save visualization: %s\n', ME.message);
    close(gcf);
end
end

%% FUNKCJE POMOCNICZE

function plotMDADiscriminantAnalysis(reductionInfo)
% PLOTMDADISCRIMINANTANALYSIS Wizualizuje wyniki analizy dyskryminacyjnej MDA
%
% Funkcja tworzy wykres eigenvalues z MDA oraz separability score jeśli dostępny.
% Zapewnia bezpieczną obsługę brakujących lub nieprawidłowych danych.

try
    if isfield(reductionInfo, 'eigenValues') && ~isempty(reductionInfo.eigenValues)
        eigenValues = reductionInfo.eigenValues;
        
        % Sanityzacja eigenvalues - usuń wartości niedodatnie
        eigenValues = abs(eigenValues);
        eigenValues = eigenValues(eigenValues > 0);
        
        if ~isempty(eigenValues)
            bar(1:length(eigenValues), eigenValues, 'FaceColor', [0.2, 0.8, 0.4]);
            xlabel('MDA Component');
            ylabel('Eigenvalue');
            title('MDA Discriminant Analysis', 'FontWeight', 'bold');
            grid on;
            
            % Dodanie wartości na słupkach dla lepszej czytelności
            for i = 1:length(eigenValues)
                if eigenValues(i) > 0
                    text(i, eigenValues(i)/2, sprintf('%.2f', eigenValues(i)), ...
                        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'white');
                end
            end
            
            % Wyświetlenie separability score jeśli dostępny
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
    % Fallback dla błędów w analizie MDA
    text(0.5, 0.5, sprintf('MDA analysis failed: %s', ME.message), 'HorizontalAlignment', 'center');
    title('MDA Analysis - Error', 'FontWeight', 'bold');
    axis off;
end
end

function cmap = redblue(n)
% REDBLUE Tworzy niebiesko-biało-czerwoną mapę kolorów
%
% Funkcja pomocnicza generująca kolormap przydatną do wizualizacji
% różnic lub korelacji. Niebieski = wartości ujemne, Biały = zero,
% Czerwony = wartości dodatnie.

if nargin < 1, n = 256; end
if n == 1, cmap = [1 1 1]; return; end

half = floor(n/2);
blue_to_white = [linspace(0, 1, half)', linspace(0, 1, half)', ones(half, 1)];
white_to_red = [ones(n-half, 1), linspace(1, 0, n-half)', linspace(1, 0, n-half)'];
cmap = [blue_to_white; white_to_red];
end