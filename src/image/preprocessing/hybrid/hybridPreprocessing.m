% filepath: src/image/preprocessing/hybridPreprocessing.m
function processedImage = hybridPreprocessing(image, logFile)
% HYBRIDPREPROCESSING Hybrydowy preprocessing (Basic + Gabor)

try
    if nargin < 2, logFile = []; end
    
    % Walidacja obrazu
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    if ~isa(image, 'double')
        image = im2double(image);
    end
    
    logInfo('  Hybrid: Running BASIC preprocessing...', logFile);
    % ETAP 1: Uruchom BASIC preprocessing
    basicResult = basicPreprocessing(image, logFile);
    
    logInfo('  Hybrid: Running GABOR preprocessing...', logFile);
    % ETAP 2: Spróbuj GABOR preprocessing (używając funkcji z shared/)
    try
        % Użyj funkcji z shared/
        logInfo('    Hybrid: Computing ridge orientation...', logFile);
        orientation = computeRidgeOrientation(image);
        
        logInfo('    Hybrid: Computing ridge frequency...', logFile);
        frequency = computeRidgeFrequency(image, orientation);
        
        logInfo('    Hybrid: Applying Gabor filters...', logFile);
        gaborFiltered = applyGaborFilter(image, orientation, frequency);
        
        % Prosta binaryzacja wyniku Gabora
        gaborResult = imbinarize(gaborFiltered, 'adaptive', 'Sensitivity', 0.4);
        
        logInfo('  Hybrid: Combining BASIC and GABOR results...', logFile);
        % ETAP 3: Proste kombinowanie - maksimum z obu
        processedImage = basicResult | gaborResult;
        
        % Finalne czyszczenie
        processedImage = bwareaopen(processedImage, 25);
        processedImage = bwmorph(processedImage, 'clean');
        
    catch gaborError
        logWarning(sprintf('Gabor preprocessing failed: %s. Using BASIC only.', gaborError.message), logFile);
        processedImage = basicResult;
    end
    
catch ME
    if ~isempty(logFile)
        logError(sprintf('Error in hybridPreprocessing: %s', ME.message), logFile);
    end
    
    % Ultimate fallback - prosta binaryzacja
    if size(image, 3) == 3
        image = rgb2gray(image);
    end
    processedImage = imbinarize(image);
    warning('Hybrid preprocessing failed, using simple binarization');
end
end