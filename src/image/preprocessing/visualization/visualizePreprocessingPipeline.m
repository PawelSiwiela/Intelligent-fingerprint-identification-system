function visualizePreprocessingPipeline(outputDir, logFile)
% VISUALIZEPREPROCESSINGPIPELINE Pokazuje kompletny pipeline preprocessingu
%
% Argumenty:
%   outputDir - katalog wyjściowy dla wizualizacji
%   logFile - plik logów

if nargin < 1, outputDir = fullfile(pwd, 'output', 'figures'); end
if nargin < 2, logFile = []; end

try
    logInfo('Generowanie wizualizacji pipeline preprocessingu...', logFile);
    
    % Znajdź przykładowy obraz
    config = loadConfig();
    [originalImage, fingerName] = findExampleImage(config);
    
    if isempty(originalImage)
        logWarning('Nie znaleziono obrazu dla pipeline demo', logFile);
        return;
    end
    
    % Przygotuj obraz
    if size(originalImage, 3) == 3
        grayImage = rgb2gray(originalImage);
    else
        grayImage = originalImage;
    end
    grayImage = im2double(grayImage);
    
    % Wykonaj wszystkie kroki pipeline
    orientation = computeRidgeOrientation(grayImage, 16);
    orientationViz = visualizeOrientation(grayImage, orientation);
    
    frequency = computeRidgeFrequency(grayImage, orientation, 32);
    frequencyViz = visualizeFrequency(frequency);
    
    gaborFiltered = applyGaborFilter(grayImage, orientation, frequency);
    
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    
    skeletonImage = ridgeThinning(binaryImage);
    
    % Finalne przetwarzanie
    finalImage = skeletonImage & mask;
    finalImage = bwmorph(finalImage, 'clean');
    finalCoverage = sum(finalImage(:)) / numel(finalImage) * 100;
    
    % Wizualizacja 9 kroków
    figure('Visible', 'off', 'Position', [0, 0, 1800, 1200]);
    
    subplot(3, 3, 1); imshow(originalImage);
    title('1. ORYGINALNY', 'FontWeight', 'bold');
    
    subplot(3, 3, 2); imshow(grayImage);
    title('2. SKALA SZAROŚCI', 'FontWeight', 'bold');
    
    subplot(3, 3, 3); imshow(orientationViz);
    title('3. ORIENTACJA', 'FontWeight', 'bold');
    
    subplot(3, 3, 4); imshow(frequencyViz, []); colormap(gca, 'jet');
    title('4. CZĘSTOTLIWOŚĆ', 'FontWeight', 'bold');
    
    subplot(3, 3, 5); imshow(gaborFiltered, []);
    title('5. GABOR', 'FontWeight', 'bold');
    
    subplot(3, 3, 6); imshow(segmentedImage);
    title('6. SEGMENTACJA', 'FontWeight', 'bold');
    
    subplot(3, 3, 7); imshow(binaryImage);
    title('7. BINARYZACJA', 'FontWeight', 'bold');
    
    subplot(3, 3, 8); imshow(skeletonImage);
    title('8. SZKIELET', 'FontWeight', 'bold');
    
    subplot(3, 3, 9); imshow(finalImage);
    title(sprintf('9. WYNIK\n%.1f%% pokrycia', finalCoverage), 'FontWeight', 'bold', 'Color', [0, 0.6, 0]);
    
    sgtitle(sprintf('PIPELINE PREPROCESSING - %s', upper(fingerName)), 'FontSize', 16, 'FontWeight', 'bold');
    
    % Zapisz
    savePath = fullfile(outputDir, 'preprocessing_pipeline.png');
    print(gcf, savePath, '-dpng', '-r300');
    close(gcf);
    
    logSuccess('Pipeline preprocessing wizualizowany', logFile);
    fprintf('   📊 Pipeline zapisany: %s\n', savePath);
    
catch ME
    logError(sprintf('Błąd wizualizacji pipeline: %s', ME.message), logFile);
end
end

function [originalImage, fingerName] = findExampleImage(config)
% Znajdź pierwszy dostępny obraz do demonstracji

originalImage = [];
fingerName = '';
dataDir = config.dataPath;
fingerFolders = {'kciuk', 'wskazujący', 'środkowy', 'serdeczny', 'mały'};

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
                return;
            end
        end
    end
end
end

function orientationViz = visualizeOrientation(image, orientation)
% Wizualizuje orientację jako linie na obrazie

orientationViz = repmat(image, [1, 1, 3]); % RGB
[rows, cols] = size(image);

% Narysuj linie orientacji
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
            
            % Narysuj czerwoną linię
            try
                orientationViz = insertShape(orientationViz, 'Line', [x1, y1, x2, y2], ...
                    'Color', 'red', 'LineWidth', 2);
            catch
                % Fallback jeśli insertShape nie działa
                continue;
            end
        end
    end
end
end

function frequencyViz = visualizeFrequency(frequency)
% Wizualizuje częstotliwość jako mapę ciepła

frequencyViz = frequency;
% Normalizuj do zakresu [0,1]
frequencyViz = (frequencyViz - min(frequencyViz(:))) / (max(frequencyViz(:)) - min(frequencyViz(:)));
end