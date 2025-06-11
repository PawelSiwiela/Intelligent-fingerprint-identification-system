function generateSystemVisualizations(trainData, valData, testData, outputDir, logFile)
% GENERATESYSTEMVISUALIZATIONS Generuje podstawowe wizualizacje systemu

% 1. Przykładowe obrazy z każdego zbioru
showDatasetSamples(trainData, 'Training', outputDir);
showDatasetSamples(valData, 'Validation', outputDir);
showDatasetSamples(testData, 'Test', outputDir);

% 2. PIPELINE DEMO - pokaż wszystkie kroki preprocessing
if ~isempty(trainData.images)
    logInfo('Generowanie kompletnego pipeline demo...', logFile);
    
    % Potrzebujemy oryginalnego obrazu - weźmy z loadImages
    % Na razie użyjemy pierwszego dostępnego obrazu i przeprowadzimy przez pipeline
    createFullPipelineDemo(outputDir, logFile);
end

logInfo('Wygenerowano wizualizacje systemowe', logFile);
end

function showDatasetSamples(data, datasetName, outputDir)
% Pokazuje przykładowe obrazy z danego zbioru

if isempty(data.images), return; end

figure('Visible', 'off', 'Position', [0, 0, 1000, 600]);

% Pokaż po jednym przykładzie z każdego palca
sampleCount = 0;
for finger = 1:5
    fingerIndices = find(data.labels == finger);
    if ~isempty(fingerIndices)
        sampleCount = sampleCount + 1;
        subplot(2, 3, sampleCount);
        
        idx = fingerIndices(1);
        imshow(data.images{idx});
        
        coverage = sum(data.images{idx}(:)) / numel(data.images{idx}) * 100;
        title(sprintf('Palec %d\nPokrycie: %.1f%%', finger, coverage), ...
            'FontSize', 12, 'FontWeight', 'bold');
    end
end

sgtitle(sprintf('%s Dataset Samples (%d images)', datasetName, length(data.images)), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Zapisz
savePath = fullfile(outputDir, sprintf('%s_samples.png', lower(datasetName)));
print(gcf, savePath, '-dpng', '-r150');
close(gcf);
end

function createFullPipelineDemo(outputDir, logFile)
% Tworzy kompletne demo pipeline - wszystkie kroki preprocessing

try
    % Wczytaj jeden przykładowy obraz (oryginalny)
    config = loadConfig();
    
    % Znajdź pierwszy dostępny obraz
    dataDir = config.dataPath;
    fingerFolders = {'kciuk', 'wskazujący', 'środkowy', 'serdeczny', 'mały'};
    
    originalImage = [];
    fingerName = '';
    
    % Szukaj pierwszego dostępnego obrazu
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
    
    % WYKONAJ WSZYSTKIE KROKI PIPELINE I ZACHOWAJ KAŻDY KROK
    
    % KROK 1: Orientacja
    orientation = computeRidgeOrientation(grayImage, 16);
    orientationViz = visualizeOrientation(grayImage, orientation);
    
    % KROK 2: Częstotliwość
    frequency = computeRidgeFrequency(grayImage, orientation, 32);
    frequencyViz = visualizeFrequency(frequency);
    
    % KROK 3: Filtr Gabora
    gaborFiltered = applyGaborFilter(grayImage, orientation, frequency);
    
    % KROK 4: Segmentacja
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    
    % KROK 5: Binaryzacja
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    
    % KROK 6: Szkieletyzacja (finał)
    skeletonImage = ridgeThinning(binaryImage);
    finalImage = skeletonImage & mask;
    finalImage = bwmorph(finalImage, 'clean');
    
    % UTWÓRZ WIZUALIZACJĘ WSZYSTKICH KROKÓW
    figure('Visible', 'off', 'Position', [0, 0, 1800, 1200]);
    
    % 1. Oryginalny obraz
    subplot(3, 3, 1);
    imshow(originalImage);
    title('1. ORYGINALNY OBRAZ', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 2. Skala szarości
    subplot(3, 3, 2);
    imshow(grayImage);
    title('2. SKALA SZAROŚCI', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 3. Orientacja
    subplot(3, 3, 3);
    imshow(orientationViz);
    title('3. ORIENTACJA LINII', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 4. Częstotliwość
    subplot(3, 3, 4);
    imshow(frequencyViz, []);
    colormap(gca, 'jet');
    title('4. CZĘSTOTLIWOŚĆ', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 5. Filtr Gabora
    subplot(3, 3, 5);
    imshow(gaborFiltered, []);
    title('5. FILTR GABORA', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 6. Segmentacja
    subplot(3, 3, 6);
    imshow(segmentedImage);
    title('6. SEGMENTACJA', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 7. Binaryzacja
    subplot(3, 3, 7);
    imshow(binaryImage);
    title('7. BINARYZACJA', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 8. Szkieletyzacja
    subplot(3, 3, 8);
    imshow(skeletonImage);
    title('8. SZKIELETYZACJA', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 9. Wynik końcowy
    subplot(3, 3, 9);
    imshow(finalImage);
    finalCoverage = sum(finalImage(:)) / numel(finalImage) * 100;
    title(sprintf('9. WYNIK KOŃCOWY\nPokrycie: %.2f%%', finalCoverage), ...
        'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0.6, 0]);
    
    % Główny tytuł
    sgtitle(sprintf('KOMPLETNY PIPELINE PREPROCESSING - %s', upper(fingerName)), ...
        'FontSize', 16, 'FontWeight', 'bold');
    
    % Zapisz
    savePath = fullfile(outputDir, 'complete_preprocessing_pipeline.png');
    print(gcf, savePath, '-dpng', '-r300');
    close(gcf);
    
    logInfo('Kompletny pipeline demo utworzony', logFile);
    
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