function preprocessedImage = preprocessing(image, logFile)
% PREPROCESSING Główna funkcja preprocessingu odcisków palców
%
% Argumenty:
%   image - obraz wejściowy
%   logFile - plik logów (opcjonalny)
%
% Output:
%   preprocessedImage - obraz po preprocessingu

if nargin < 2, logFile = []; end

try
    % Konwersja do skali szarości jeśli potrzeba
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    image = im2double(image);
    
    % KROK 1: Orientacja linii papilarnych
    orientation = computeRidgeOrientation(image, 16);
    
    % KROK 2: Częstotliwość linii papilarnych
    frequency = computeRidgeFrequency(image, orientation, 32);
    
    % KROK 3: Filtracja Gabora
    gaborFiltered = applyGaborFilter(image, orientation, frequency);
    
    % KROK 4: Segmentacja
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    
    % KROK 5: Binaryzacja zorientowana na orientację
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    
    % KROK 6: Szkieletyzacja
    skeletonImage = ridgeThinning(binaryImage);
    
    % Finalne czyszczenie
    preprocessedImage = skeletonImage & mask;
    preprocessedImage = bwmorph(preprocessedImage, 'clean');
    
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