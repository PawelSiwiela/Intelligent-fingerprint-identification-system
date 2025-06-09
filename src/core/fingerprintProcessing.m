function results = fingerprintProcessing(config)
% FINGERPRINTPROCESSING Główna funkcja przetwarzania odcisków palców
%
% Input:
%   config - struktura konfiguracji z app()
%
% Output:
%   results - struktura z wynikami

% Setup
currentDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(currentDir, '..')));

% Załaduj konfigurację systemu
systemConfig = loadConfig();

% Setup logowania
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
logFile = fullfile(systemConfig.logsPath, sprintf('processing_%s.log', timestamp));

if ~exist(systemConfig.logsPath, 'dir')
    mkdir(systemConfig.logsPath);
end

logInfo('=== FINGERPRINT PROCESSING START ===', logFile);

% Inicjalizuj wyniki
results = struct();
results.config = config;
results.timestamp = timestamp;

% Wykonaj przetwarzanie w zależności od trybu
switch config.mode
    case 'quick'
        results = processQuickTest(config, results, logFile, systemConfig);
    case 'single'
        results = processSingleImage(config, results, logFile, systemConfig);
    case 'small'
        results = processSmallDataset(config, results, logFile, systemConfig);
    case 'full'
        results = processFullDataset(config, results, logFile, systemConfig);
end

logInfo('=== FINGERPRINT PROCESSING COMPLETED ===', logFile);
end

function results = processQuickTest(config, results, logFile, systemConfig)
% Test z syntetycznymi danymi
fprintf('🚀 Uruchamiam test szybki...\n');

% Stwórz syntetyczny obraz
testImage = createSyntheticFingerprint(100, 100);
fprintf('   Utworzono syntetyczny odcisk 100x100\n');

% Przetwarzanie
results = processSingleImageData(testImage, config, results, logFile, systemConfig);
results.processed_images = 1;

fprintf('✅ Test szybki zakończony\n');
end

function results = processSingleImage(config, results, logFile, systemConfig)
% Test na pojedynczym obrazie z dataset
fprintf('📸 Wczytywanie pojedynczego obrazu...\n');

try
    [images, labels] = loadImages(systemConfig, logFile);
    testImage = images{1};
    
    fprintf('   Wczytano obraz: %dx%d\n', size(testImage, 1), size(testImage, 2));
    
    results = processSingleImageData(testImage, config, results, logFile, systemConfig);
    results.processed_images = 1;
    
    fprintf('✅ Test pojedynczego obrazu zakończony\n');
    
catch ME
    fprintf('❌ Błąd wczytywania obrazu: %s\n', ME.message);
    logError(sprintf('Single image test failed: %s', ME.message), logFile);
    
    % Fallback na syntetyczny obraz
    fprintf('⚠ Używam syntetycznego obrazu...\n');
    results = processQuickTest(config, results, logFile, systemConfig);
end
end

function results = processSmallDataset(config, results, logFile, systemConfig)
% Test na małym dataset (10 obrazów)
fprintf('📦 Przetwarzanie małego dataset...\n');

try
    [images, labels] = loadImages(systemConfig, logFile);
    numImages = min(10, length(images));
    
    fprintf('   Będę przetwarzać %d obrazów\n', numImages);
    
    totalMinutiae = 0;
    
    for i = 1:numImages
        fprintf('   Przetwarzam obraz %d/%d... ', i, numImages);
        
        imageResults = processSingleImageData(images{i}, config, results, logFile, systemConfig);
        
        if isfield(imageResults, 'total_minutiae')
            totalMinutiae = totalMinutiae + imageResults.total_minutiae;
        end
        
        fprintf('✅\n');
    end
    
    results.processed_images = numImages;
    results.total_minutiae = totalMinutiae;
    results.avg_minutiae = totalMinutiae / numImages;
    
    fprintf('✅ Mały dataset zakończony\n');
    fprintf('   Średnia liczba minucji: %.1f\n', results.avg_minutiae);
    
catch ME
    fprintf('❌ Błąd przetwarzania dataset: %s\n', ME.message);
    logError(sprintf('Small dataset test failed: %s', ME.message), logFile);
    
    % Fallback
    results = processQuickTest(config, results, logFile, systemConfig);
end
end

function results = processFullDataset(config, results, logFile, systemConfig)
% Test na pełnym dataset
fprintf('🗂️ Przygotowywanie pełnego dataset...\n');

try
    [trainData, valData, testData, dataInfo] = prepareData(systemConfig, logFile);
    
    fprintf('   Dane treningowe: %d obrazów\n', length(trainData.labels));
    fprintf('   Dane walidacyjne: %d obrazów\n', length(valData.labels));
    fprintf('   Dane testowe: %d obrazów\n', length(testData.labels));
    
    % Twórz macierz cech
    fprintf('   Tworzę macierz cech...\n');
    [featureMatrix, labels] = createFeatureDataset(trainData, config.feature_method, logFile);
    
    results.processed_images = length(trainData.labels);
    results.feature_matrix_size = size(featureMatrix);
    results.feature_count = size(featureMatrix, 2);
    
    fprintf('✅ Pełny dataset zakończony\n');
    fprintf('   Macierz cech: %dx%d\n', size(featureMatrix, 1), size(featureMatrix, 2));
    
catch ME
    fprintf('❌ Błąd przetwarzania pełnego dataset: %s\n', ME.message);
    logError(sprintf('Full dataset test failed: %s', ME.message), logFile);
    
    % Fallback
    results = processSmallDataset(config, results, logFile, systemConfig);
end
end

function results = processSingleImageData(image, config, results, logFile, systemConfig)
% Przetwarza pojedynczy obraz

% Setup outputu tylko jeśli potrzebny zapis wizualizacji
outputDir = [];
if config.save_results && config.show_visualizations
    timestamp = results.timestamp;
    outputDir = fullfile(systemConfig.figuresPath, sprintf('minutiae_%s', timestamp));
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
end

if strcmp(config.preprocessing_method, 'all')
    % Porównaj wszystkie metody
    methods = {'basic', 'hybrid', 'advanced'};
    totalMinutiae = 0;
    
    for i = 1:length(methods)
        processed = applyPreprocessing(image, methods{i}, logFile);
        minutiae = detectMinutiae(processed, logFile);
        totalMinutiae = totalMinutiae + minutiae.count;
        
        % Wizualizuj i zapisz w figures/
        titleText = sprintf('%s Method', upper(methods{i}));
        
        if config.show_visualizations
            if config.save_results && ~isempty(outputDir)
                savePath = fullfile(outputDir, sprintf('minutiae_%s.png', methods{i}));
                visualizeMinutiae(processed, minutiae, titleText, savePath);
            else
                visualizeMinutiae(processed, minutiae, titleText);
            end
        end
    end
    
    results.total_minutiae = totalMinutiae;
    results.preprocessing_method = 'all';
    
else
    % Pojedyncza metoda
    processed = applyPreprocessing(image, config.preprocessing_method, logFile);
    minutiae = detectMinutiae(processed, logFile);
    
    % Ekstraktuj cechy
    features = extractMinutiaeFeatures(minutiae, size(image), config.feature_method, logFile);
    
    results.total_minutiae = minutiae.count;
    results.feature_count = length(features);
    results.preprocessing_method = config.preprocessing_method;
    
    % Wizualizuj i zapisz w figures/
    if config.show_visualizations
        titleText = sprintf('%s Preprocessing', upper(config.preprocessing_method));
        
        if config.save_results && ~isempty(outputDir)
            savePath = fullfile(outputDir, sprintf('minutiae_%s.png', config.preprocessing_method));
            visualizeMinutiae(processed, minutiae, titleText, savePath);
        else
            visualizeMinutiae(processed, minutiae, titleText);
        end
    end
end

% Zapisz ścieżkę figures (nie app_results)
if config.save_results && ~isempty(outputDir)
    results.figures_path = outputDir;
end
end

function processed = applyPreprocessing(image, method, logFile)
% Zastosuj wybraną metodę preprocessing
switch method
    case 'basic'
        processed = basicPreprocessing(image, logFile);
    case 'hybrid'
        processed = hybridPreprocessing(image, logFile);
    case 'advanced'
        processed = advancedPreprocessing(image, logFile);
    otherwise
        processed = basicPreprocessing(image, logFile);
end
end

function img = createSyntheticFingerprint(height, width)
% Tworzy syntetyczny odcisk palca
[X, Y] = meshgrid(1:width, 1:height);
freq = 0.1;

% Ridge pattern
ridges = sin(2*pi*freq*X) .* cos(2*pi*freq*Y);
noise = 0.1 * randn(height, width);
ridges = ridges + noise;

% Binary threshold
img = ridges > 0;

% Add gaps for minutiae
img(20:22, 30:32) = false;
img(70:72, 60:62) = false;

img = double(img);
end