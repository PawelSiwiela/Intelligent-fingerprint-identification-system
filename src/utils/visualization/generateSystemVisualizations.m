function generateSystemVisualizations(trainData, valData, testData, outputDir, logFile, minutiaeData, featuresData)
% GENERATESYSTEMVISUALIZATIONS Generuje najważniejsze wizualizacje systemu

if nargin < 6, minutiaeData = []; end
if nargin < 7, featuresData = []; end

% ======================================================================
% 1. PIPELINE DEMO - pokazuje jak działa preprocessing ✅ KLUCZOWE
% ======================================================================
if ~isempty(trainData.images)
    logInfo('Generowanie pipeline demo...', logFile);
    createFullPipelineDemo(outputDir, logFile);
end

% ======================================================================
% 2. MINUCJE - po jednym przykładzie z każdego palca ✅ KLUCZOWE
% ======================================================================
if ~isempty(minutiaeData)
    logInfo('Generowanie wizualizacji minucji...', logFile);
    createMinutiaeExamples(trainData, valData, testData, minutiaeData, outputDir, logFile);
end

% ======================================================================
% 3. CECHY - tylko najważniejsze ✅ KLUCZOWE
% ======================================================================
if ~isempty(featuresData)
    logInfo('Generowanie wizualizacji cech...', logFile);
    createEssentialFeaturesVisualizations(featuresData.trainFeatures, featuresData.valFeatures, featuresData.testFeatures, outputDir, logFile);
end

logInfo('Wygenerowano kluczowe wizualizacje systemowe', logFile);
end

% ======================================================================
% ZACHOWANE FUNKCJE (bez zmian)
% ======================================================================
function createFullPipelineDemo(outputDir, logFile)
% Kompletny pipeline preprocessing - 9 kroków ✅ KLUCZOWE
% [CAŁA FUNKCJA BEZ ZMIAN]
try
    config = loadConfig();
    dataDir = config.dataPath;
    fingerFolders = {'kciuk', 'wskazujący', 'środkowy', 'serdeczny', 'mały'};
    
    originalImage = [];
    fingerName = '';
    
    for i = 1:length(fingerFolders)
        currentFolder = fingerFolders{i};
        possiblePaths = {
            fullfile(dataDir, currentFolder, upper(config.imageFormat)),
            fullfile(dataDir, currentFolder, lower(config.imageFormat)),
            fullfile(dataDir, currentFolder)
            };
        
        for j = 1:length(possiblePaths)
            if exist(possiblePaths{j}, 'dir')
                files = dir(fullfile(possiblePaths{j}, ['*.' config.imageFormat]));
                if ~isempty(files)
                    imagePath = fullfile(possiblePaths{j}, files(1).name);
                    originalImage = imread(imagePath);
                    fingerName = currentFolder;
                    break;
                end
            end
        end
        
        if ~isempty(originalImage)
            break;
        end
    end
    
    if isempty(originalImage)
        logWarning('Nie znaleziono oryginalnego obrazu dla pipeline demo', logFile);
        return;
    end
    
    % Przygotuj obraz
    if size(originalImage, 3) == 3
        grayImage = rgb2gray(originalImage);
    else
        grayImage = originalImage;
    end
    if ~isa(grayImage, 'double')
        grayImage = im2double(grayImage);
    end
    
    logInfo(sprintf('Pipeline demo na obrazie: %s', fingerName), logFile);
    
    % WYKONAJ WSZYSTKIE KROKI PIPELINE
    orientation = computeRidgeOrientation(grayImage, 16);
    orientationViz = visualizeOrientation(grayImage, orientation);
    frequency = computeRidgeFrequency(grayImage, orientation, 32);
    frequencyViz = visualizeFrequency(frequency);
    gaborFiltered = applyGaborFilter(grayImage, orientation, frequency);
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    skeletonImage = ridgeThinning(binaryImage);
    finalImage = skeletonImage & mask;
    finalImage = bwmorph(finalImage, 'clean');
    
    % WIZUALIZACJA 9 KROKÓW
    figure('Visible', 'off', 'Position', [0, 0, 1800, 1200]);
    
    subplot(3, 3, 1); imshow(originalImage); title('1. ORYGINALNY OBRAZ', 'FontSize', 12, 'FontWeight', 'bold');
    subplot(3, 3, 2); imshow(grayImage); title('2. SKALA SZAROŚCI', 'FontSize', 12, 'FontWeight', 'bold');
    subplot(3, 3, 3); imshow(orientationViz); title('3. ORIENTACJA LINII', 'FontSize', 12, 'FontWeight', 'bold');
    subplot(3, 3, 4); imshow(frequencyViz, []); colormap(gca, 'jet'); title('4. CZĘSTOTLIWOŚĆ', 'FontSize', 12, 'FontWeight', 'bold');
    subplot(3, 3, 5); imshow(gaborFiltered, []); title('5. FILTR GABORA', 'FontSize', 12, 'FontWeight', 'bold');
    subplot(3, 3, 6); imshow(segmentedImage); title('6. SEGMENTACJA', 'FontSize', 12, 'FontWeight', 'bold');
    subplot(3, 3, 7); imshow(binaryImage); title('7. BINARYZACJA', 'FontSize', 12, 'FontWeight', 'bold');
    subplot(3, 3, 8); imshow(skeletonImage); title('8. SZKIELETYZACJA', 'FontSize', 12, 'FontWeight', 'bold');
    
    subplot(3, 3, 9);
    imshow(finalImage);
    finalCoverage = sum(finalImage(:)) / numel(finalImage) * 100;
    title(sprintf('9. WYNIK KOŃCOWY\nPokrycie: %.2f%%', finalCoverage), 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0.6, 0]);
    
    sgtitle(sprintf('KOMPLETNY PIPELINE PREPROCESSING - %s', upper(fingerName)), 'FontSize', 16, 'FontWeight', 'bold');
    
    savePath = fullfile(outputDir, 'complete_preprocessing_pipeline.png');
    print(gcf, savePath, '-dpng', '-r300');
    close(gcf);
    
    logInfo('Pipeline demo utworzony', logFile);
    
catch ME
    logWarning(sprintf('Błąd podczas tworzenia pipeline demo: %s', ME.message), logFile);
end
end

function orientationViz = visualizeOrientation(image, orientation)
% Wizualizuje orientację jako linie na obrazie

orientationViz = repmat(image, [1, 1, 3]); % RGB
[rows, cols] = size(image);

% Narysuj linie orientacji co kilka pikseli
step = 20;
lineLength = 10;

for i = step:step:rows-step
    for j = step:step:cols-step
        if i <= rows && j <= cols
            angle = orientation(i, j);
            
            % Oblicz końce linii
            dx = lineLength * cos(angle);
            dy = lineLength * sin(angle);
            
            x1 = max(1, min(cols, round(j - dx/2)));
            y1 = max(1, min(rows, round(i - dy/2)));
            x2 = max(1, min(cols, round(j + dx/2)));
            y2 = max(1, min(rows, round(i + dy/2)));
            
            % Narysuj linię (czerwoną)
            orientationViz = insertShape(orientationViz, 'Line', [x1, y1, x2, y2], ...
                'Color', 'red', 'LineWidth', 1);
        end
    end
end
end

function frequencyViz = visualizeFrequency(frequency)
% Wizualizuje częstotliwość jako mapę kolorów

% Normalizuj częstotliwość do zakresu 0-1
frequencyViz = frequency;
frequencyViz = (frequencyViz - min(frequencyViz(:))) / (max(frequencyViz(:)) - min(frequencyViz(:)));
end

function createMinutiaeExamples(trainData, valData, testData, minutiaeData, outputDir, logFile)
% Minucje - po jednym przykładzie z każdego palca ✅ KLUCZOWE

dataArrays = {trainData, valData, testData};
minutiaeArrays = {minutiaeData.trainMinutiae, minutiaeData.valMinutiae, minutiaeData.testMinutiae};
fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};

for finger = 1:5
    bestExample = findBestMinutiaeExample(finger, dataArrays, minutiaeArrays);
    
    if isempty(bestExample)
        logWarning(sprintf('Brak danych dla palca %d (%s)', finger, fingerNames{finger}), logFile);
        continue;
    end
    
    % Utwórz figurę dla tego palca
    figure('Visible', 'off', 'Position', [0, 0, 800, 600]);
    imshow(bestExample.image, 'Border', 'tight');
    hold on;
    
    if ~isempty(bestExample.minutiae) && ~isempty(bestExample.minutiae.all)
        if ~isempty(bestExample.minutiae.endpoints)
            endpoints = bestExample.minutiae.endpoints;
            plot(endpoints(:,1), endpoints(:,2), 'ro', 'MarkerSize', 10, 'LineWidth', 3, 'DisplayName', 'Punkty końcowe');
        end
        
        if ~isempty(bestExample.minutiae.bifurcations)
            bifurcations = bestExample.minutiae.bifurcations;
            plot(bifurcations(:,1), bifurcations(:,2), 'bs', 'MarkerSize', 10, 'LineWidth', 3, 'DisplayName', 'Rozwidlenia');
        end
        
        totalMinutiae = size(bestExample.minutiae.all, 1);
        endpointCount = size(bestExample.minutiae.endpoints, 1);
        bifurcationCount = size(bestExample.minutiae.bifurcations, 1);
        
        title(sprintf('%s (Palec %d)\nMinucje: %d (Końcówki: %d, Rozwidlenia: %d)', ...
            fingerNames{finger}, finger, totalMinutiae, endpointCount, bifurcationCount), ...
            'FontSize', 14, 'FontWeight', 'bold');
        
        legend('Location', 'southoutside', 'Orientation', 'horizontal');
    else
        title(sprintf('%s (Palec %d) - Brak Minucji', fingerNames{finger}, finger), 'FontSize', 14, 'FontWeight', 'bold');
    end
    
    savePath = fullfile(outputDir, sprintf('palec_%d_%s_minutiae.png', finger, lower(fingerNames{finger})));
    print(gcf, savePath, '-dpng', '-r300');
    close(gcf);
    
    fprintf('  📊 Minucje dla palca %d (%s) zapisane\n', finger, fingerNames{finger});
end

logInfo('Wizualizacje minucji wygenerowane', logFile);
end

function bestExample = findBestMinutiaeExample(finger, dataArrays, minutiaeArrays)
% Znajduje najlepszy przykład minucji dla danego palca

bestExample = [];
bestMinutiaeCount = 0;

for d = 1:length(dataArrays)
    data = dataArrays{d};
    minutiae = minutiaeArrays{d};
    
    if isempty(data.images) || isempty(minutiae)
        continue;
    end
    
    fingerIndices = find(data.labels == finger);
    
    for i = 1:length(fingerIndices)
        idx = fingerIndices(i);
        imageMinutiae = minutiae{idx};
        
        if ~isempty(imageMinutiae) && ~isempty(imageMinutiae.all)
            minutiaeCount = size(imageMinutiae.all, 1);
            
            if minutiaeCount > 10 && minutiaeCount < 300 && minutiaeCount > bestMinutiaeCount
                bestExample = struct();
                bestExample.image = data.images{idx};
                bestExample.minutiae = imageMinutiae;
                bestExample.dataset = d;
                bestMinutiaeCount = minutiaeCount;
            end
        end
    end
end
end

% ======================================================================
% UPROSZCZONE WIZUALIZACJE CECH - tylko 3 najważniejsze ✅ KLUCZOWE
% ======================================================================
function createEssentialFeaturesVisualizations(trainFeatures, valFeatures, testFeatures, outputDir, logFile)
% Tylko 3 najważniejsze wizualizacje cech

fprintf('   📊 Generowanie kluczowych wizualizacji cech...\n');

allFeatures = [trainFeatures; valFeatures; testFeatures];
datasetLabels = [ones(size(trainFeatures,1),1); 2*ones(size(valFeatures,1),1); 3*ones(size(testFeatures,1),1)];

featuresDir = fullfile(outputDir, 'features_analysis');
if ~exist(featuresDir, 'dir'), mkdir(featuresDir); end

% 1. Podstawowe statystyki - boxploty ✅ NAJWAŻNIEJSZE
createBasicStatsPlot(allFeatures, datasetLabels, featuresDir);

% 2. Mapa gęstości - heatmapa 8x8 ✅ WAŻNE
createDensityHeatmap(allFeatures, featuresDir);

% 3. PCA - separowalność zbiorów ✅ KLUCZOWE DLA ML
createPCAVisualization(allFeatures, datasetLabels, featuresDir);

fprintf('   ✅ Kluczowe wizualizacje cech zapisane w: %s\n', featuresDir);
logInfo(sprintf('Kluczowe wizualizacje cech zapisane w: %s', featuresDir), logFile);
end

function createBasicStatsPlot(features, labels, outputDir)
% ✅ ZACHOWANE BEZ ZMIAN - najważniejsze!

figure('Visible', 'off', 'Position', [0, 0, 1200, 800]);

statNames = {'Endpoints', 'Bifurcations', 'Total', 'Endpoint Ratio', 'Bifurcation Ratio', 'Density'};
datasetNames = {'Training', 'Validation', 'Test'};
colors = [0.8, 0.2, 0.2; 0.2, 0.8, 0.2; 0.2, 0.2, 0.8];

for i = 1:6
    subplot(2, 3, i);
    
    data = [];
    groups = [];
    
    for d = 1:3
        subset = features(labels == d, i);
        data = [data; subset];
        groups = [groups; d * ones(length(subset), 1)];
    end
    
    boxplot(data, groups, 'Labels', datasetNames, 'Colors', colors);
    title(statNames{i}, 'FontWeight', 'bold');
    ylabel('Wartość');
    grid on;
end

sgtitle('Podstawowe statystyki cech minucji', 'FontSize', 16, 'FontWeight', 'bold');

savePath = fullfile(outputDir, 'features_basic_statistics.png');
print(gcf, savePath, '-dpng', '-r200');
close(gcf);
end

function createDensityHeatmap(features, outputDir)
% ✅ ZACHOWANE BEZ ZMIAN - pokazuje rozkład przestrzenny!

figure('Visible', 'off', 'Position', [0, 0, 800, 600]);

densityFeatures = features(:, 7:70);
avgDensity = mean(densityFeatures, 1);
avgDensityMap = reshape(avgDensity, [8, 8]);

imagesc(avgDensityMap);
colormap(hot);
colorbar;
title('Średnia mapa gęstości minucji (8x8)', 'FontWeight', 'bold');
xlabel('Kolumny siatki');
ylabel('Wiersze siatki');

for i = 1:8
    for j = 1:8
        text(j, i, sprintf('%.3f', avgDensityMap(i,j)), ...
            'HorizontalAlignment', 'center', 'Color', 'white', 'FontWeight', 'bold');
    end
end

savePath = fullfile(outputDir, 'features_density_heatmap.png');
print(gcf, savePath, '-dpng', '-r200');
close(gcf);
end

function createPCAVisualization(features, labels, outputDir)
% ✅ ZACHOWANE BEZ ZMIAN - kluczowe dla ML!

figure('Visible', 'off', 'Position', [0, 0, 1200, 500]);

% Wykonaj PCA
[coeff, score, latent, ~, explained] = pca(features);

datasetNames = {'Training', 'Validation', 'Test'};
colors = [0.8, 0.2, 0.2; 0.2, 0.8, 0.2; 0.2, 0.2, 0.8];

% 1. Wykres 2D PCA
subplot(1, 2, 1);
for d = 1:3
    subset = score(labels == d, :);
    scatter(subset(:, 1), subset(:, 2), 100, colors(d,:), 'filled', 'DisplayName', datasetNames{d});
    hold on;
end
title('PCA - Pierwsze 2 składowe główne', 'FontWeight', 'bold');
xlabel(sprintf('PC1 (%.1f%% wariancji)', explained(1)));
ylabel(sprintf('PC2 (%.1f%% wariancji)', explained(2)));
legend;
grid on;

% 2. Wykres explained variance
subplot(1, 2, 2);
cumExplained = cumsum(explained);
plot(1:20, cumExplained(1:20), 'bo-', 'LineWidth', 2, 'MarkerSize', 8);
title('Skumulowana wariancja wyjaśniona', 'FontWeight', 'bold');
xlabel('Liczba składowych głównych');
ylabel('Skumulowana wariancja (%)');
grid on;

% Dodaj linię dla 95% wariancji
line([1, 20], [95, 95], 'Color', 'red', 'LineStyle', '--', 'LineWidth', 2);
text(10, 90, '95% wariancji', 'Color', 'red', 'FontWeight', 'bold');

savePath = fullfile(outputDir, 'features_pca_analysis.png');
print(gcf, savePath, '-dpng', '-r200');
close(gcf);
end

function cmap = bluewhitered(m)
% Kolorowa mapa niebiesko-biało-czerwona dla korelacji

if nargin < 1, m = 256; end

% Utworz mapę kolorów
blue = [0, 0, 1];
white = [1, 1, 1];
red = [1, 0, 0];

half = floor(m/2);
cmap = [linspace(blue(1), white(1), half)', linspace(blue(2), white(2), half)', linspace(blue(3), white(3), half)';
    linspace(white(1), red(1), m-half)', linspace(white(2), red(2), m-half)', linspace(white(3), red(3), m-half)'];
end