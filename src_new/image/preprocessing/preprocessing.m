function preprocessedImage = preprocessing(image, logFile, verboseLogging)
% PREPROCESSING Główna funkcja preprocessingu odcisków palców
%
% Argumenty:
%   image - obraz wejściowy
%   logFile - plik logów (opcjonalny)
%   verboseLogging - czy zapisywać szczegółowe logi (domyślnie false)
%
% Output:
%   preprocessedImage - obraz po preprocessingu

if nargin < 2, logFile = []; end
if nargin < 3, verboseLogging = false; end  % DOMYŚLNIE WYŁĄCZONE!

try
    % Tylko podstawowy log startowy
    if verboseLogging
        logInfo('Preprocessing: 6-step advanced pipeline...', logFile);
    end
    
    % Konwersja do skali szarości jeśli potrzeba
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    image = im2double(image);
    
    % KROK 1: Orientacja linii papilarnych
    if verboseLogging
        logInfo('1/6: Ridge orientation...', logFile);
    end
    orientation = computeRidgeOrientation(image, 16);
    
    % KROK 2: Częstotliwość linii papilarnych
    if verboseLogging
        logInfo('2/6: Ridge frequency...', logFile);
    end
    frequency = computeRidgeFrequency(image, orientation, 32);
    
    % KROK 3: Filtracja Gabora
    if verboseLogging
        logInfo('3/6: Gabor filtering...', logFile);
    end
    gaborFiltered = applyGaborFilter(image, orientation, frequency);
    
    % KROK 4: Segmentacja
    if verboseLogging
        logInfo('4/6: Segmentation...', logFile);
    end
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    
    % KROK 5: Binaryzacja zorientowana na orientację
    if verboseLogging
        logInfo('5/6: Binarization...', logFile);
    end
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    
    % KROK 6: Szkieletyzacja
    if verboseLogging
        logInfo('6/6: Skeletonization...', logFile);
    end
    skeletonImage = ridgeThinning(binaryImage);
    
    % Finalne czyszczenie
    preprocessedImage = skeletonImage & mask;
    preprocessedImage = bwmorph(preprocessedImage, 'clean');
    
    % Oblicz pokrycie
    coverage = sum(preprocessedImage(:)) / numel(preprocessedImage) * 100;
    
    % Log końcowy tylko jeśli verbose
    if verboseLogging
        logInfo(sprintf('Final coverage: %.2f%%', coverage), logFile);
    end
    
catch ME
    % Log błędów zawsze
    logError(sprintf('Preprocessing error: %s', ME.message), logFile);
    
    % Fallback - prosta binaryzacja
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    preprocessedImage = imbinarize(image);
end
end