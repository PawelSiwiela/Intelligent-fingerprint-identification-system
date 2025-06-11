function processedImage = preprocessing(image, logFile, showVisualization)
% PREPROCESSING Główna funkcja preprocessingu - UPROSZCZONA
%
% Input:
%   image - obraz wejściowy
%   logFile - plik do logowania (opcjonalny)
%   showVisualization - czy pokazać wizualizację kroków (opcjonalny)
%
% Output:
%   processedImage - przetworzony obraz binarny

try
    if nargin < 2, logFile = []; end
    if nargin < 3, showVisualization = false; end
    
    % Walidacja obrazu
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    if ~isa(image, 'double')
        image = im2double(image);
    end
    
    logInfo('  Preprocessing: 6-step advanced pipeline...', logFile);
    
    % KROK 1: Orientacja
    logInfo('    1/6: Ridge orientation...', logFile);
    orientation = computeRidgeOrientation(image, 16);
    
    % KROK 2: Częstotliwość
    logInfo('    2/6: Ridge frequency...', logFile);
    frequency = computeRidgeFrequency(image, orientation, 32);
    
    % KROK 3: Filtr Gabora
    logInfo('    3/6: Gabor filtering...', logFile);
    gaborFiltered = applyGaborFilter(image, orientation, frequency);
    
    % KROK 4: Segmentacja
    logInfo('    4/6: Segmentation...', logFile);
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    
    % KROK 5: Binaryzacja
    logInfo('    5/6: Binarization...', logFile);
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    
    % KROK 6: Szkieletyzacja (KOŃCOWY)
    logInfo('    6/6: Skeletonization...', logFile);
    processedImage = ridgeThinning(binaryImage);
    
    % Finalne czyszczenie
    processedImage = processedImage & mask;
    processedImage = bwmorph(processedImage, 'clean');
    
    finalCoverage = sum(processedImage(:)) / numel(processedImage) * 100;
    logInfo(sprintf('  Final coverage: %.2f%%', finalCoverage), logFile);
    
    % Wizualizacja (opcjonalna)
    if showVisualization
        visualizeSimplePipeline(image, orientation, frequency, gaborFiltered, ...
            segmentedImage, mask, binaryImage, processedImage);
    end
    
catch ME
    logError(sprintf('Preprocessing failed: %s', ME.message), logFile);
    
    % Fallback
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    processedImage = imbinarize(image, 'adaptive');
    processedImage = bwmorph(processedImage, 'clean');
end
end

function visualizeSimplePipeline(original, orientation, frequency, gabor, segmented, mask, binary, final)
% UPROSZCZONA wizualizacja pipeline

figure('Position', [50, 50, 1600, 600], ...
    'Name', 'Clean Advanced Preprocessing Pipeline', ...
    'NumberTitle', 'off');

steps = {original, orientation, frequency, gabor, segmented, mask, binary, final};
titles = {'Original', 'Orientation', 'Frequency', 'Gabor', 'Segmented', 'Mask', 'Binary', 'Final'};

for i = 1:length(steps)
    subplot(2, 4, i);
    
    result = steps{i};
    
    % Wyświetl
    if islogical(result)
        imshow(result);
    else
        imshow(result, []);
    end
    
    % Tytuł z pokryciem
    if i == 1 || i >= 4
        if islogical(result)
            coverage = sum(result(:)) / numel(result) * 100;
        else
            coverage = sum(result(:) > 0.5) / numel(result) * 100;
        end
        titleText = sprintf('%s\n%.1f%%', titles{i}, coverage);
        if i == length(steps)
            titleColor = [0 0.6 0];  % Zielony dla końcowego
        else
            titleColor = 'black';
        end
    else
        titleText = titles{i};
        titleColor = 'black';
    end
    
    title(titleText, 'FontSize', 11, 'FontWeight', 'bold', 'Color', titleColor);
    axis off;
end

sgtitle('Advanced Preprocessing - Clean 6-Step Pipeline', ...
    'FontSize', 16, 'FontWeight', 'bold');
end