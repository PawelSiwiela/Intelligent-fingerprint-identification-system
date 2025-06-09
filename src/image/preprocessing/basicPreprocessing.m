function processedImage = basicPreprocessing(image, logFile, showVisualization)
% BASICPREPROCESSING Podstawowy preprocessing odcisku palca
%
% Input:
%   image - obraz wejściowy
%   logFile - plik do logowania (opcjonalny)
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
    
    logInfo('    Basic: Enhancing contrast...', logFile);
    
    % KROK 1: Poprawa kontrastu (CLAHE)
    enhanced = adapthisteq(image, 'ClipLimit', 0.02, 'TileGridSize', [8 8]);
    enhanced = imadjust(enhanced); % Dodatkowe dostrojenie
    
    logInfo('    Basic: Reducing noise...', logFile);
    
    % KROK 2: Redukcja szumu
    denoised = medfilt2(enhanced, [3 3]); % Filtr medianowy
    gaussFilter = fspecial('gaussian', [5 5], 1.0);
    denoised = imfilter(denoised, gaussFilter, 'same', 'replicate');
    
    logInfo('    Basic: Edge detection...', logFile);
    
    % KROK 3: Wykrywanie krawędzi
    edges = edge(denoised, 'canny', [0.1 0.25], 1.0);
    
    logInfo('    Basic: Binarization...', logFile);
    
    % KROK 4: Binaryzacja adaptacyjna
    binary = imbinarize(denoised, 'adaptive', 'Sensitivity', 0.5);
    
    % Kombinuj krawędzie z binaryzacją
    processedImage = binary | edges;
    
    logInfo('    Basic: Morphological operations...', logFile);
    
    % KROK 5: Operacje morfologiczne
    se = strel('disk', 2);
    processedImage = imopen(processedImage, se);  % Usuń szum
    processedImage = imclose(processedImage, se); % Wypełnij dziury
    processedImage = imfill(processedImage, 'holes'); % Wypełnij wszystkie dziury
    
    logInfo('    Basic: Final cleanup...', logFile);
    
    % KROK 6: Finalne czyszczenie
    processedImage = bwareaopen(processedImage, 30); % Usuń małe obiekty
    processedImage = bwmorph(processedImage, 'clean'); % Usuń izolowane piksele
    
    % Na końcu - opcjonalna wizualizacja
    if showVisualization
        logInfo('    Basic: Generating visualization...', logFile);
        visualizeMethodSteps(image, 'basic', logFile);
    end
    
catch ME
    if ~isempty(logFile)
        logError(sprintf('Error in basicPreprocessing: %s', ME.message), logFile);
    end
    
    % Fallback - prosta binaryzacja
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    processedImage = imbinarize(image);
    warning('Basic preprocessing failed, using simple binarization');
end
end