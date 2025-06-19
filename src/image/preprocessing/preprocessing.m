function preprocessedImage = preprocessing(image, logFile)
% PREPROCESSING Główny pipeline preprocessingu obrazów odcisków palców
%
% Funkcja implementuje kompletny 6-etapowy pipeline przetwarzania obrazów
% odcisków palców, przekształcając surowy obraz w szkielet binarny gotowy
% do detekcji minucji. Każdy etap jest zoptymalizowany dla specyfiki
% struktur papilarnych z mechanizmami fallback dla różnych jakości obrazów.
%
% Parametry wejściowe:
%   image - surowy obraz odcisku palca (RGB lub skala szarości)
%   logFile - uchwyt pliku logów (opcjonalny, może być [])
%
% Parametry wyjściowe:
%   preprocessedImage - szkielet binarny linii papilarnych (logical)
%                      true = linie papilarne, false = tło/doliny
%
% Pipeline preprocessingu (6 etapów):
%   1. ORIENTACJA: Analiza lokalnej orientacji linii papilarnych (tensor struktury)
%   2. CZĘSTOTLIWOŚĆ: Estymacja gęstości linii metodą FFT projekcji
%   3. FILTRACJA GABORA: Wzmocnienie struktur zgodnych z lokalną orientacją/częstotliwością
%   4. SEGMENTACJA: Wydzielenie obszaru odcisku od tła (analiza wariancji lokalnej)
%   5. BINARYZACJA: Adaptacyjne progowanie z uwzględnieniem orientacji
%   6. SZKIELETYZACJA: Sprowadzenie linii papilarnych do pojedynczych pikseli
%
% Mechanizm fallback:
%   W przypadku błędu pipeline przechodzi na prostą binaryzację globalną
%   z automatycznym progiem Otsu jako bezpieczną alternatywę.
%
% Przykład użycia:
%   skeltonImg = preprocessing(rawFingerprintImage, logFile);

if nargin < 2, logFile = []; end

try
    % ETAP 0: PRZYGOTOWANIE OBRAZU
    % Konwersja do skali szarości jeśli obraz kolorowy (RGB → Grayscale)
    if size(image, 3) == 3
        image = rgb2gray(image);
        logInfo('RGB image converted to grayscale', logFile);
    end
    
    % Normalizacja do zakresu [0,1] typu double dla stabilności numerycznej
    image = im2double(image);
    logInfo('Image normalized to double precision [0,1]', logFile);
    
    % ETAP 1: ANALIZA ORIENTACJI LINII PAPILARNYCH
    % Tensor struktury z gradientów Sobela w blokach 16×16
    logInfo('Step 1/6: Computing ridge orientation using structure tensor', logFile);
    orientation = computeRidgeOrientation(image, 16);
    
    % ETAP 2: ANALIZA CZĘSTOTLIWOŚCI LINII PAPILARNYCH
    % FFT projekcji prostopadłej do orientacji w blokach 32×32
    logInfo('Step 2/6: Estimating ridge frequency using FFT projection', logFile);
    frequency = computeRidgeFrequency(image, orientation, 32);
    
    % ETAP 3: FILTRACJA GABORA ADAPTACYJNA
    % Lokalne filtry Gabora dostosowane do orientacji i częstotliwości
    logInfo('Step 3/6: Applying orientation-adaptive Gabor filtering', logFile);
    gaborFiltered = applyGaborFilter(image, orientation, frequency);
    
    % ETAP 4: SEGMENTACJA OBSZARU ODCISKU
    % Wydzielenie regionu odcisku od tła na podstawie lokalnej wariancji
    logInfo('Step 4/6: Segmenting fingerprint area from background', logFile);
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    
    % ETAP 5: BINARYZACJA ZORIENTOWANA NA ORIENTACJĘ
    % Adaptacyjne progowanie w blokach z uwzględnieniem mapy orientacji
    logInfo('Step 5/6: Orientation-aware adaptive binarization', logFile);
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    
    % ETAP 6: SZKIELETYZACJA LINII PAPILARNYCH
    % Sprowadzenie grubych linii do szkieletu jednopikselowego
    logInfo('Step 6/6: Ridge thinning to single-pixel skeleton', logFile);
    skeletonImage = ridgeThinning(binaryImage);
    
    % FINALIZACJA: CZYSZCZENIE I MASKOWANIE
    % Zastosowanie maski segmentacji dla usunięcia artefaktów poza odciskiem
    preprocessedImage = skeletonImage & mask;
    
    % Końcowe czyszczenie małych izolowanych pikseli (operacja 'clean')
    preprocessedImage = bwmorph(preprocessedImage, 'clean');
    
    logSuccess('Preprocessing pipeline completed successfully', logFile);
    
    % Statystyki końcowe dla diagnostyki
    skeletonDensity = sum(preprocessedImage(:)) / numel(preprocessedImage) * 100;
    logInfo(sprintf('Final skeleton density: %.2f%% of image area', skeletonDensity), logFile);
    
catch ME
    % MECHANIZM FALLBACK W PRZYPADKU BŁĘDU
    % Zapisz szczegóły błędu w logach (zawsze, niezależnie od logFile)
    errorMsg = sprintf('Preprocessing pipeline failed: %s', ME.message);
    logError(errorMsg, logFile);
    
    % Wyświetl ostrzeżenie w konsoli
    warning('Preprocessing failed, using simple binarization fallback');
    
    try
        % FALLBACK: Prosta binaryzacja globalna metodą Otsu
        % Konwersja do skali szarości jeśli konieczna
        if size(image, 3) == 3
            image = rgb2gray(image);
        end
        
        % Binaryzacja z automatycznym progiem
        preprocessedImage = imbinarize(image);
        
        logInfo('Fallback: Simple Otsu binarization applied', logFile);
        
        % Podstawowe czyszczenie fallback
        preprocessedImage = bwmorph(preprocessedImage, 'clean');
        
    catch fallbackError
        % OSTATECZNY FALLBACK: Zwróć pustą macierz logiczną
        logError(sprintf('Even fallback failed: %s', fallbackError.message), logFile);
        preprocessedImage = false(size(image, 1), size(image, 2));
        warning('Complete preprocessing failure - returning empty logical array');
    end
end
end