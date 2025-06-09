function processedImage = advancedPreprocessing(image, logFile, showVisualization)
% ADVANCEDPREPROCESSING Zaawansowany preprocessing dla odcisków palców
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
    
    logInfo('  Advanced: Computing ridge orientation...', logFile);
    % KROK 1: Orientacja linii papilarnych
    orientation = computeRidgeOrientation(image, 16);
    
    logInfo('  Advanced: Computing ridge frequency...', logFile);
    % KROK 2: Częstotliwość linii papilarnych
    frequency = computeRidgeFrequency(image, orientation, 32);
    
    logInfo('  Advanced: Applying Gabor filters...', logFile);
    % KROK 3: Filtracja Gabora
    gaborFiltered = applyGaborFilter(image, orientation, frequency);
    
    logInfo('  Advanced: Segmenting ROI...', logFile);
    % KROK 4: Segmentacja ROI (Region of Interest)
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    
    logInfo('  Advanced: Orientation-aware binarization...', logFile);
    % KROK 5: Binaryzacja adaptacyjna z użyciem orientacji
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    
    logInfo('  Advanced: Ridge thinning...', logFile);
    % KROK 6: Szkieletyzacja i wygładzanie
    skeletonImage = ridgeThinning(binaryImage);
    
    logInfo('  Advanced: Removing artifacts...', logFile);
    % KROK 7: Filtracja artefaktów
    processedImage = removeArtifacts(skeletonImage, mask);
    
    logInfo('  Advanced: Final quality enhancement...', logFile);
    % KROK 8: Finalne ulepszenia jakości
    processedImage = finalQualityEnhancement(processedImage, mask);
    
    % Na końcu - opcjonalna wizualizacja
    if showVisualization
        logInfo('  Advanced: Generating visualization...', logFile);
        visualizeMethodSteps(image, 'advanced', logFile);
    end
    
catch ME
    if ~isempty(logFile)
        logError(sprintf('Error in advancedPreprocessing: %s', ME.message), logFile);
    end
    
    % Ultimate fallback - próbuj z podstawowym podejściem
    try
        logWarning('Advanced preprocessing failed, trying basic approach...', logFile);
        processedImage = basicFallback(image);
    catch
        % Last resort - prosta binaryzacja
        if size(image, 3) == 3
            image = rgb2gray(image);
        end
        processedImage = imbinarize(image);
        warning('Advanced preprocessing completely failed, using simple binarization');
    end
end
end

function processedImage = finalQualityEnhancement(skeletonImage, mask)
% FINALQUALITYENHANCEMENT Finalne ulepszenia jakości

% Usuń fragmenty poza maską
processedImage = skeletonImage & mask;

% Usuń bardzo małe komponenty
processedImage = bwareaopen(processedImage, 5);

% Napraw przerwy w liniach
processedImage = bwmorph(processedImage, 'bridge');
processedImage = bwmorph(processedImage, 'fill');

% Usuń krótkie odnogi
processedImage = bwmorph(processedImage, 'spur', 2);

% Wygładź linie
processedImage = bwmorph(processedImage, 'clean');

% Sprawdź jakość wyniku
whiteRatio = sum(processedImage(:)) / numel(processedImage);
if whiteRatio < 0.05 || whiteRatio > 0.8
    % Jeśli wynik wygląda podejrzanie, zastosuj dodatkowe czyszczenie
    processedImage = bwmorph(processedImage, 'majority');
end
end

function processedImage = basicFallback(image)
% BASICFALLBACK Podstawowy fallback gdy advanced zawodzi

% Poprawa kontrastu
enhanced = adapthisteq(image, 'ClipLimit', 0.03);

% Redukcja szumu
denoised = medfilt2(enhanced, [3 3]);

% Binaryzacja
binary = imbinarize(denoised, 'adaptive', 'Sensitivity', 0.5);

% Podstawowe czyszczenie
se = strel('disk', 2);
processedImage = imopen(binary, se);
processedImage = bwareaopen(processedImage, 20);
processedImage = bwmorph(processedImage, 'clean');
end