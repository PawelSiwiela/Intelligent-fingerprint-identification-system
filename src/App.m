function App()
% APP Główna aplikacja terminowa dla systemu identyfikacji odcisków palców
%
% Przeprowadza użytkownika przez cały pipeline:
% 1. Wybór formatu (PNG/TIFF)
% 2. Wczytywanie danych
% 3. Preprocessing
% 4. Detekcja minucji
% 5. Ekstrakcja cech

fprintf('\n');
fprintf('=================================================================\n');
fprintf('              FINGERPRINT IDENTIFICATION SYSTEM                 \n');
fprintf('=================================================================\n');
fprintf('\n');

try
    %% KROK 1: Inicjalizacja
    fprintf('🔧 Initializing system...\n');
    
    % Wczytaj konfigurację
    config = loadConfig();
    
    % Utwórz katalogi wyjściowe
    createOutputDirectories(config);
    
    % Utwórz plik logów
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    logFile = fullfile(config.logging.outputDir, sprintf('fingerprint_processing_%s.log', timestamp));
    
    % Rozpocznij logowanie
    logInfo('=============================================================', logFile);
    logInfo('           FINGERPRINT IDENTIFICATION SYSTEM STARTED         ', logFile);
    logInfo('=============================================================', logFile);
    logInfo(sprintf('Session started: %s', datestr(now)), logFile);
    
    startTime = tic;
    
    %% KROK 2: Wybór formatu danych
    fprintf('\n📂 Data format selection...\n');
    selectedFormat = selectDataFormat();
    
    % Zaktualizuj konfigurację
    config.dataLoading.format = selectedFormat;
    logInfo(sprintf('Selected data format: %s', selectedFormat), logFile);
    
    %% KROK 3: Wczytywanie danych
    fprintf('\n📥 Loading image data...\n');
    
    % Używaj domyślnej ścieżki danych
    dataPath = 'data';
    
    fprintf('Loading %s images from: %s\n', selectedFormat, dataPath);
    [imageData, labels, metadata] = loadImages(dataPath, config, logFile);
    
    if isempty(imageData)
        error('No images loaded. Please check data path and format.');
    end
    
    fprintf('✅ Loaded %d images from %d fingers\n', metadata.totalImages, metadata.actualFingers);
    
    %% KROK 4: Wyświetl podsumowanie danych
    displayDataSummary(metadata);
    
    %% KROK 5: Preprocessing pipeline
    fprintf('\n🔄 Starting preprocessing pipeline...\n');
    
    % Inicjalizacja wyników preprocessing
    preprocessedImages = cell(size(imageData));
    
    % Progress bar setup
    numImages = length(imageData);
    fprintf('Processing %d images:\n', numImages);
    
    for i = 1:numImages
        % Progress indicator
        if mod(i, max(1, floor(numImages/10))) == 0 || i == 1
            fprintf('  Progress: %d/%d (%.1f%%)\n', i, numImages, (i/numImages)*100);
        end
        
        try
            % Preprocessing dla każdego obrazu
            preprocessedImages{i} = preprocessing(imageData{i}, logFile);
            
        catch ME
            logWarning(sprintf('Preprocessing failed for image %d: %s', i, ME.message), logFile);
            % Fallback - pusty obraz
            preprocessedImages{i} = [];
        end
    end
    
    fprintf('✅ Preprocessing completed\n');
    
    %% KROK 6: Detekcja i ekstrakcja minucji z wizualizacją
    fprintf('\n🔍 Starting minutiae detection and feature extraction...\n');
    
    % Inicjalizacja wyników
    allMinutiae = cell(size(preprocessedImages));
    allFeatures = [];
    validImageIndices = [];
    
    fprintf('Detecting minutiae and extracting features:\n');
    
    for i = 1:numImages
        % Progress indicator
        if mod(i, max(1, floor(numImages/10))) == 0 || i == 1
            fprintf('  Progress: %d/%d (%.1f%%)\n', i, numImages, (i/numImages)*100);
        end
        
        if isempty(preprocessedImages{i})
            continue; % Pomiń obrazy które nie zostały przetworzone
        end
        
        try
            % 1. Detekcja minucji
            [minutiae, ~] = detectMinutiae(preprocessedImages{i}, config, logFile);
            
            if isempty(minutiae)
                logWarning(sprintf('No minutiae detected for image %d', i), logFile);
                continue;
            end
            
            % 2. Filtracja minucji
            filteredMinutiae = filterMinutiae(minutiae, config, logFile);
            
            if isempty(filteredMinutiae)
                logWarning(sprintf('No minutiae remained after filtering for image %d', i), logFile);
                continue;
            end
            
            % 3. Ekstrakcja cech
            features = extractMinutiaeFeatures(filteredMinutiae, config, logFile);
            
            if isempty(features)
                logWarning(sprintf('Feature extraction failed for image %d', i), logFile);
                continue;
            end
            
            % 4. WIZUALIZACJA (dla pierwszych 5 obrazów)
            if i <= 5 && config.visualization.enabled
                visualizeProcessingSteps(imageData{i}, preprocessedImages{i}, ...
                    filteredMinutiae, i, config.visualization.outputDir);
            end
            
            % Zapisz wyniki
            allMinutiae{i} = filteredMinutiae;
            allFeatures(end+1, :) = features;
            validImageIndices(end+1) = i;
            
        catch ME
            logError(sprintf('Minutiae processing failed for image %d: %s', i, ME.message), logFile);
        end
    end
    
    fprintf('✅ Minutiae detection and feature extraction completed\n');
    
    %% KROK 7: Podsumowanie wyników
    fprintf('\n📊 Processing Results Summary:\n');
    fprintf('=================================\n');
    
    numValidImages = length(validImageIndices);
    validLabels = labels(validImageIndices);
    
    fprintf('Total images processed: %d\n', numImages);
    fprintf('Successfully processed: %d (%.1f%%)\n', numValidImages, (numValidImages/numImages)*100);
    fprintf('Failed to process: %d\n', numImages - numValidImages);
    fprintf('Feature vector size: %d features per image\n', size(allFeatures, 2));
    
    % Statystyki per palec
    fprintf('\nPer-finger statistics:\n');
    uniqueLabels = unique(validLabels);
    for finger = uniqueLabels'
        fingerCount = sum(validLabels == finger);
        fingerName = metadata.fingerNames{finger};
        fprintf('  %s: %d images\n', fingerName, fingerCount);
    end
    
    %% KROK 8: Zapisz wyniki z automatyczną normalizacją
    fprintf('\n💾 Saving results...\n');
    
    resultsFile = fullfile('output', sprintf('fingerprint_results_%s.mat', timestamp));
    
    % Przygotuj strukturę wyników
    results = struct();
    results.metadata = metadata;
    results.config = config;
    results.features = allFeatures;
    results.labels = validLabels;
    results.validImageIndices = validImageIndices;
    results.minutiae = allMinutiae(validImageIndices);
    results.processingTimestamp = timestamp;
    results.selectedFormat = selectedFormat;
    results.dataPath = dataPath;
    
    % Automatyczna normalizacja cech (Min-Max)
    fprintf('Normalizing features using Min-Max method...\n');
    normalizedFeatures = normalizeFeatures(allFeatures, 'minmax');
    results.normalizedFeatures = normalizedFeatures;
    results.normalizationMethod = 'minmax';
    
    logInfo('Features automatically normalized using Min-Max method', logFile);
    
    % Zapisz do pliku
    save(resultsFile, 'results');
    fprintf('✅ Results saved to: %s\n', resultsFile);
    logInfo(sprintf('Results saved to: %s', resultsFile), logFile);
    
    %% KROK 9: Zakończenie
    executionTime = toc(startTime);
    
    fprintf('\n🎉 Processing completed successfully!\n');
    fprintf('Total execution time: %.2f seconds\n', executionTime);
    fprintf('Feature vector size: %d features per image\n', size(allFeatures, 2));
    fprintf('Normalized features range: [0, 1]\n');
    
    % Zamknij log
    closeLog(logFile, executionTime);
    
    fprintf('\nLog file saved to: %s\n', logFile);
    fprintf('\n=================================================================\n');
    
catch ME
    % Obsługa błędów globalnych
    fprintf('\n❌ Application error: %s\n', ME.message);
    
    if exist('logFile', 'var') && ~isempty(logFile)
        logError(sprintf('Application error: %s', ME.message), logFile);
        logError(sprintf('Stack trace: %s', getReport(ME)), logFile);
        
        if exist('startTime', 'var')
            executionTime = toc(startTime);
            closeLog(logFile, executionTime);
        end
    end
    
    fprintf('Check log file for details: %s\n', logFile);
    rethrow(ME);
end
end

%% HELPER FUNCTIONS

function selectedFormat = selectDataFormat()
% SELECTDATAFORMAT Pozwala użytkownikowi wybrać format danych
fprintf('Available data formats:\n');
fprintf('  1. PNG files\n');
fprintf('  2. TIFF files\n');

while true
    choice = input('Select format (1 or 2): ');
    
    if choice == 1
        selectedFormat = 'PNG';
        break;
    elseif choice == 2
        selectedFormat = 'TIFF';
        break;
    else
        fprintf('Invalid choice. Please enter 1 or 2.\n');
    end
end
end

function displayDataSummary(metadata)
% DISPLAYDATASUMMARY Wyświetla podsumowanie wczytanych danych
fprintf('\n📋 Data Summary:\n');
fprintf('================\n');
fprintf('Total images: %d\n', metadata.totalImages);
fprintf('Number of fingers: %d\n', metadata.actualFingers);
fprintf('Format: %s\n', metadata.selectedFormat);
fprintf('Load timestamp: %s\n', metadata.loadTimestamp);

fprintf('\nFinger breakdown:\n');
for i = 1:length(metadata.fingerNames)
    fingerName = metadata.fingerNames{i};
    % Policz obrazy dla tego palca
    fingerImageCount = sum(strcmp(metadata.imagePaths, fingerName) | ...
        contains(metadata.imagePaths, fingerName));
    fprintf('  %s: %d images\n', fingerName, fingerImageCount);
end
end

function createOutputDirectories(config)
% CREATEOUTPUTDIRECTORIES Tworzy niezbędne katalogi wyjściowe
dirs = {
    config.logging.outputDir,
    config.visualization.outputDir,
    'output'
    };

for i = 1:length(dirs)
    if ~exist(dirs{i}, 'dir')
        mkdir(dirs{i});
    end
end
end