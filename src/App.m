function App()
% APP Główna aplikacja terminowa dla systemu identyfikacji odcisków palców

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
    
    %% KROK 2: WYBÓR ŹRÓDŁA DANYCH (NOWE!)
    fprintf('\n📂 Data source selection...\n');
    [useMatFiles, matFilePath, selectedFormat] = selectDataSource();
    
    % Zaktualizuj konfigurację
    config.dataLoading.format = selectedFormat;
    
    if useMatFiles
        logInfo(sprintf('Loading from .mat file: %s', matFilePath), logFile);
    else
        logInfo(sprintf('Loading original images - format: %s', selectedFormat), logFile);
    end
    
    %% KROK 3: Wczytywanie danych
    fprintf('\n📥 Loading data...\n');
    
    if useMatFiles
        % WCZYTAJ Z PLIKU .MAT
        fprintf('Loading preprocessed data from .mat file...\n');
        [preprocessedImages, allMinutiae, allFeatures, labels, metadata] = loadProcessedData(matFilePath);
        
        if isempty(allFeatures)
            error('Failed to load data from .mat file or file contains no features.');
        end
        
        % Symuluj validImageIndices
        validImageIndices = 1:length(labels);
        
        % Normalizuj cechy jeśli potrzeba
        if max(allFeatures(:)) > 1 || min(allFeatures(:)) < 0
            fprintf('🔧 Normalizing loaded features...\n');
            normalizedFeatures = normalizeFeatures(allFeatures, 'minmax');
        else
            normalizedFeatures = allFeatures;
        end
        
        fprintf('✅ Loaded %d samples from .mat file\n', length(labels));
        
        % Pomiń preprocessing - dane już przetworzone
        skipToML = true;
        
    else
        % TRADYCYJNE WCZYTYWANIE OBRAZÓW
        dataPath = 'data';
        
        fprintf('Loading %s images from: %s\n', selectedFormat, dataPath);
        [imageData, labels, metadata] = loadImages(dataPath, config, logFile);
        
        if isempty(imageData)
            error('No images loaded. Please check data path and format.');
        end
        
        fprintf('✅ Loaded %d images from %d fingers\n', metadata.totalImages, metadata.actualFingers);
        skipToML = false;
    end
    
    %% KROK 4: Wyświetl podsumowanie danych
    displayDataSummary(metadata, useMatFiles);
    
    if ~skipToML
        %% KROK 5-9: TRADYCYJNY PREPROCESSING (tylko dla oryginalnych obrazów)
        
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
        
        %% KROK 8: Normalizacja cech
        fprintf('\n🔧 Normalizing features...\n');
        
        % Automatyczna normalizacja cech (Min-Max)
        fprintf('Normalizing features using Min-Max method...\n');
        normalizedFeatures = normalizeFeatures(allFeatures, 'minmax');
        
        logInfo('Features automatically normalized using Min-Max method', logFile);
        
        %% KROK 9: WIZUALIZACJE CECH MINUCJI
        fprintf('\n📊 Creating minutiae features visualizations...\n');
        
        try
            if numValidImages >= 10 % Minimum próbek dla sensownych wizualizacji
                % TYLKO znormalizowane cechy - lepsze do wizualizacji i porównan
                visualizeMinutiaeFeatures(normalizedFeatures, validLabels, metadata, config.visualization.outputDir);
                
                fprintf('✅ Minutiae features visualizations completed\n');
            else
                fprintf('⚠️  Skipping visualizations - need at least 10 samples (have %d)\n', numValidImages);
            end
        catch ME
            fprintf('⚠️  Visualization creation failed: %s\n', ME.message);
            logWarning(sprintf('Visualization creation failed: %s', ME.message), logFile);
        end
    end
    
    %% KROK 10: ML PIPELINE (dla obu ścieżek)
    fprintf('\n🤖 Starting ML Pipeline...\n');
    
    % Zapytaj użytkownika czy chce uruchomić ML Pipeline
    fprintf('Do you want to run ML Pipeline for model training and evaluation?\n');
    fprintf('  1. Yes - Run full ML Pipeline (training, optimization, evaluation)\n');
    fprintf('  2. No - Skip ML Pipeline\n');
    
    while true
        choice = input('Select option (1 or 2): ');
        
        if choice == 1
            runMLPipeline = true;
            break;
        elseif choice == 2
            runMLPipeline = false;
            break;
        else
            fprintf('Invalid choice. Please enter 1 or 2.\n');
        end
    end
    
    if runMLPipeline
        try
            % Uruchom ML Pipeline z obecnymi danymi
            fprintf('\n🔗 Delegating to MLPipeline...\n');
            
            if useMatFiles
                % Dla plików .mat - przekaż tylko dostępne dane
                MLPipeline(normalizedFeatures, labels, metadata, preprocessedImages, validImageIndices);
            else
                % Dla oryginalnych obrazów - pełne dane
                MLPipeline(normalizedFeatures, labels(validImageIndices), metadata, preprocessedImages, validImageIndices);
            end
            
            fprintf('✅ ML Pipeline completed successfully!\n');
        catch ME
            fprintf('⚠️  ML Pipeline failed: %s\n', ME.message);
            logWarning(sprintf('ML Pipeline failed: %s', ME.message), logFile);
        end
    else
        fprintf('⏭️  ML Pipeline skipped by user\n');
    end
    
    %% KROK 11: Zakończenie
    executionTime = toc(startTime);
    
    fprintf('\n🎉 Processing completed successfully!\n');
    fprintf('Total execution time: %.2f seconds\n', executionTime);
    fprintf('Feature vector size: %d features per image\n', size(normalizedFeatures, 2));
    fprintf('Normalized features range: [0, 1]\n');
    
    if useMatFiles
        fprintf('Loaded samples from .mat file: %d\n', length(labels));
    else
        fprintf('Images successfully processed: %d/%d\n', length(validImageIndices), length(imageData));
    end
    
    if runMLPipeline
        fprintf('ML models saved to: output/models/\n');
        fprintf('Model comparisons saved to: output/figures/\n');
    end
    
    % Zamknij log
    closeLog(logFile, executionTime);
    
    fprintf('\nLog file saved to: %s\n', logFile);
    fprintf('\n=================================================================\n');
    
    %% KROK 13: ZAPISZ ANONIMOWE DANE (tylko dla oryginalnych obrazów)
    if ~useMatFiles
        % SPRAWDŹ CZY JUŻ ISTNIEJĄ PLIKI .MAT
        matFilesDir = 'output/anonymized_data';
        existingMats = [];
        if exist(matFilesDir, 'dir')
            existingMats = dir(fullfile(matFilesDir, 'complete_anonymized_dataset_*.mat'));
        end
        
        if ~isempty(existingMats)
            fprintf('\n📋 Found existing .mat files:\n');
            for i = 1:length(existingMats)
                fileInfo = dir(fullfile(matFilesDir, existingMats(i).name));
                fprintf('  %s (%.1f MB, %s)\n', existingMats(i).name, ...
                    fileInfo.bytes/1024/1024, datestr(fileInfo.datenum));
            end
            
            fprintf('\n💾 Do you want to save NEW anonymized data? (existing files will remain) (y/n): ');
        else
            fprintf('\n💾 Do you want to save anonymized data for sharing? (y/n): ');
        end
        
        saveAnonymized = input('', 's');
        
        if strcmpi(saveAnonymized, 'y') || strcmpi(saveAnonymized, 'yes')
            fprintf('\n🔒 Saving anonymized data (no original biometric data)...\n');
            try
                saveProcessedData(preprocessedImages, allMinutiae, allFeatures, ...
                    validImageIndices, labels, metadata, 'output/anonymized_data');
                
                fprintf('✅ Anonymized data saved successfully!\n');
                fprintf('🎓 Safe to send to professor - contains no original biometric data!\n');
            catch ME
                fprintf('⚠️  Failed to save anonymized data: %s\n', ME.message);
                logWarning(sprintf('Anonymized data save failed: %s', ME.message), logFile);
            end
        else
            fprintf('⏭️  Anonymized data export skipped\n');
        end
    else
        fprintf('\n💾 Data already in .mat format - no need to save anonymized data\n');
    end
    
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

%% NOWA FUNKCJA - WYBÓR ŹRÓDŁA DANYCH

function [useMatFiles, matFilePath, selectedFormat] = selectDataSource()
% SELECTDATASOURCE Wybór między oryginalnymi obrazami a plikami .mat

% Sprawdź czy istnieją pliki .mat w output/anonymized_data
matFilesDir = 'output/anonymized_data';
matFiles = [];

if exist(matFilesDir, 'dir')
    matSearch = dir(fullfile(matFilesDir, 'complete_anonymized_dataset_*.mat'));
    if ~isempty(matSearch)
        matFiles = matSearch;
    end
end

fprintf('Data source options:\n');

if ~isempty(matFiles)
    fprintf('  🎯 RECOMMENDED: Use preprocessed .mat files (faster, anonymous)\n');
    fprintf('  1. Load from .mat file (preprocessed data)\n');
    fprintf('  2. Load original images (full preprocessing pipeline)\n');
    
    % Pokaż dostępne pliki .mat
    fprintf('\n📋 Available .mat files:\n');
    for i = 1:length(matFiles)
        fileInfo = dir(fullfile(matFilesDir, matFiles(i).name));
        fprintf('    %d. %s (%.1f MB, %s)\n', i, matFiles(i).name, ...
            fileInfo.bytes/1024/1024, datestr(fileInfo.datenum));
    end
    
    while true
        choice = input('\nSelect option (1 or 2): ');
        
        if choice == 1
            % WYBÓR PLIKU .MAT
            if length(matFiles) == 1
                selectedFile = 1;
            else
                fprintf('Select .mat file:\n');
                while true
                    selectedFile = input(sprintf('Enter number (1-%d): ', length(matFiles)));
                    if selectedFile >= 1 && selectedFile <= length(matFiles)
                        break;
                    else
                        fprintf('Invalid choice. Please enter number between 1 and %d.\n', length(matFiles));
                    end
                end
            end
            
            useMatFiles = true;
            matFilePath = fullfile(matFilesDir, matFiles(selectedFile).name);
            selectedFormat = 'MAT'; % Dla logów
            
            fprintf('✅ Selected .mat file: %s\n', matFiles(selectedFile).name);
            break;
            
        elseif choice == 2
            % ORYGINALNE OBRAZY
            useMatFiles = false;
            matFilePath = '';
            selectedFormat = selectDataFormat(); % Wywołaj oryginalną funkcję
            break;
            
        else
            fprintf('Invalid choice. Please enter 1 or 2.\n');
        end
    end
    
else
    % BRAK PLIKÓW .MAT - TYLKO ORYGINALNE OBRAZY
    fprintf('  ⚠️  No .mat files found in output/anonymized_data/\n');
    fprintf('  📁 Checking for original sample images...\n');
    
    % Sprawdź czy są oryginalne próbki
    if exist('data', 'dir')
        pngFiles = dir('data/**/*.png');
        tiffFiles = dir('data/**/*.tiff');
        
        if isempty(pngFiles) && isempty(tiffFiles)
            fprintf('  ❌ No original sample images found in data/ directory!\n\n');
            fprintf('📋 SOLUTION OPTIONS:\n');
            fprintf('  1. Add sample fingerprint images to data/ directory\n');
            fprintf('  2. Use existing .mat file with preprocessed data\n');
            fprintf('  3. Download sample dataset\n\n');
            
            error('No data source available. Please add images to data/ directory or use .mat file.');
        else
            fprintf('  ✅ Found original images: %d PNG, %d TIFF\n', length(pngFiles), length(tiffFiles));
        end
    else
        fprintf('  ❌ No data/ directory found!\n\n');
        fprintf('📋 SOLUTION:\n');
        fprintf('  Create data/ directory and add sample fingerprint images\n');
        fprintf('  OR use existing .mat file with preprocessed data\n\n');
        
        error('No data directory found. Please create data/ directory with sample images.');
    end
    
    fprintf('  1. Load original images (full preprocessing pipeline)\n');
    
    while true
        choice = input('Press 1 to continue with original images: ');
        if choice == 1
            useMatFiles = false;
            matFilePath = '';
            selectedFormat = selectDataFormat();
            break;
        else
            fprintf('Invalid choice. Please enter 1.\n');
        end
    end
end

end

function selectedFormat = selectDataFormat()
% SELECTDATAFORMAT Pozwala użytkownikowi wybrać format danych (bez zmian)
fprintf('\nAvailable image formats:\n');
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

function displayDataSummary(metadata, useMatFiles)
% DISPLAYDATASUMMARY Wyświetla podsumowanie wczytanych danych - POPRAWIONA
fprintf('\n📋 Data Summary:\n');
fprintf('================\n');

if useMatFiles
    fprintf('Source: .mat file (preprocessed data)\n');
    
    % BEZPIECZNE sprawdzanie pól metadata
    if isfield(metadata, 'description')
        fprintf('Description: %s\n', metadata.description);
    end
    
    if isfield(metadata, 'timestamp')
        fprintf('Generated: %s\n', metadata.timestamp);
    end
    
    % Dodatkowe informacje z metadata jeśli dostępne
    if isfield(metadata, 'totalImages')
        fprintf('Total samples: %d\n', metadata.totalImages);
    end
    
    if isfield(metadata, 'actualFingers') || isfield(metadata, 'fingerNames')
        if isfield(metadata, 'actualFingers')
            fprintf('Number of fingers: %d\n', metadata.actualFingers);
        elseif isfield(metadata, 'fingerNames')
            fprintf('Number of fingers: %d\n', length(metadata.fingerNames));
        end
    end
    
else
    fprintf('Source: Original images\n');
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
end

function createOutputDirectories(config)
% CREATEOUTPUTDIRECTORIES Tworzy niezbędne katalogi wyjściowe - ROZSZERZONA
dirs = {
    config.logging.outputDir,
    config.visualization.outputDir,
    'output/models',  % Dla ML Pipeline
    'output/anonymized_data'  % NOWE: dla plików .mat
    };

for i = 1:length(dirs)
    if ~exist(dirs{i}, 'dir')
        mkdir(dirs{i});
    end
end
end