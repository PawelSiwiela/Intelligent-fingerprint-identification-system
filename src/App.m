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
    
    %% KROK 2: WYBÓR ŹRÓDŁA DANYCH
    fprintf('\n📂 Data source selection...\n');
    [useMatFiles, matFilePath, selectedFormat] = selectDataSource();
    
    % Zaktualizuj konfigurację
    config.dataLoading.format = selectedFormat;
    
    if useMatFiles
        logInfo(sprintf('Loading from .mat file: %s', matFilePath), logFile);
    else
        logInfo(sprintf('Loading original images - format: %s', selectedFormat), logFile);
    end
    
    %% KROK 3: GŁÓWNA LOGIKA - w zależności od źródła danych
    if useMatFiles
        %% ŚCIEŻKA A: Wczytaj z .mat i przejdź do ML
        fprintf('\n📥 Loading preprocessed data...\n');
        [preprocessedImages, allMinutiae, normalizedFeatures, labels, metadata] = loadProcessedData(matFilePath);
        
        if isempty(normalizedFeatures)
            error('Failed to load data from .mat file or file contains no features.');
        end
        
        % Symuluj validImageIndices
        validImageIndices = 1:length(labels);
        
        % Normalizuj cechy jeśli potrzeba
        if max(normalizedFeatures(:)) > 1 || min(normalizedFeatures(:)) < 0
            fprintf('🔧 Normalizing loaded features...\n');
            normalizedFeatures = normalizeFeatures(normalizedFeatures, 'minmax');
        end
        
        fprintf('✅ Loaded %d samples from .mat file\n', length(labels));
        displayDataSummary(metadata, true);
        
    else
        %% ŚCIEŻKA B: Pełny preprocessing
        fprintf('\n🔄 Starting preprocessing pipeline...\n');
        
        % DELEGUJ DO PreprocessingPipeline
        [normalizedFeatures, labels, metadata, preprocessedImages, validImageIndices] = ...
            PreprocessingPipeline(selectedFormat, config, logFile);
        
        if isempty(normalizedFeatures)
            error('Preprocessing failed - no features extracted.');
        end
        
        displayDataSummary(metadata, false);
        
        %% OPCJA ZAPISU DANYCH ANONIMOWYCH
        offerDataSaving(preprocessedImages, [], normalizedFeatures, validImageIndices, labels, metadata, logFile);
    end
    
    %% KROK 4: ML PIPELINE (dla obu ścieżek) - ZAWSZE URUCHAMIANY
    fprintf('\n🤖 Starting Machine Learning Pipeline...\n');
    
    try
        % ZAWSZE URUCHOM MLPipeline - pełna optymalizacja i trenowanie
        MLPipeline(normalizedFeatures, labels, metadata, preprocessedImages, validImageIndices);
        
        fprintf('✅ ML Pipeline completed successfully!\n');
    catch ME
        fprintf('⚠️  ML Pipeline failed: %s\n', ME.message);
        logWarning(sprintf('ML Pipeline failed: %s', ME.message), logFile);
        
        % Pokaż stack trace dla debugowania
        fprintf('Stack trace: %s\n', getReport(ME, 'extended'));
    end
    
    %% KROK 5: Zakończenie
    executionTime = toc(startTime);
    
    fprintf('\n🎉 Processing completed successfully!\n');
    fprintf('Total execution time: %.2f seconds\n', executionTime);
    fprintf('Feature vector size: %d features per image\n', size(normalizedFeatures, 2));
    
    if useMatFiles
        fprintf('Loaded samples from .mat file: %d\n', length(labels));
    else
        fprintf('Images successfully processed: %d/%d\n', length(validImageIndices), metadata.totalImages);
    end
    
    % Zamknij log
    closeLog(logFile, executionTime);
    
    fprintf('\nLog file saved to: %s\n', logFile);
    fprintf('Check output/models/ for saved optimal parameters.\n');
    fprintf('Check output/figures/ for visualizations.\n');
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

%% HELPER FUNCTIONS (pozostają w App.m)

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

function offerDataSaving(preprocessedImages, allMinutiae, allFeatures, validImageIndices, labels, metadata, logFile)
% OFFERDATASAVING Oferuje zapis danych anonimowych
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
end