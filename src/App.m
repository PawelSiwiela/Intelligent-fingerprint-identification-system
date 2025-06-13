function App()
% APP Główna aplikacja terminowa dla systemu identyfikacji odcisków palców
%
% Przeprowadza użytkownika przez cały pipeline:
% 1. Wybór formatu (PNG/TIFF)
% 2. Wczytywanie danych
% 3. Preprocessing
% 4. Detekcja minucji
% 5. Ekstrakcja cech
% 6. ML PIPELINE (NOWE!)

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
    
    %% KROK 10: ML PIPELINE (NOWE!)
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
            runIntegratedMLPipeline(allFeatures, validLabels, metadata, logFile);
            
            fprintf('✅ ML Pipeline completed successfully!\n');
        catch ME
            fprintf('⚠️  ML Pipeline failed: %s\n', ME.message);
            logWarning(sprintf('ML Pipeline failed: %s', ME.message), logFile);
        end
    else
        fprintf('⏭️  ML Pipeline skipped by user\n');
    end
    
    %% KROK 11: Zakończenie (poprzedni KROK 10)
    executionTime = toc(startTime);
    
    fprintf('\n🎉 Processing completed successfully!\n');
    fprintf('Total execution time: %.2f seconds\n', executionTime);
    fprintf('Feature vector size: %d features per image\n', size(allFeatures, 2));
    fprintf('Normalized features range: [0, 1]\n');
    fprintf('Images successfully processed: %d/%d\n', numValidImages, numImages);
    
    if runMLPipeline
        fprintf('ML models saved to: output/models/\n');
        fprintf('Model comparisons saved to: output/figures/\n');
    end
    
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
    config.visualization.outputDir
    };

for i = 1:length(dirs)
    if ~exist(dirs{i}, 'dir')
        mkdir(dirs{i});
    end
end
end

%% NOWA FUNKCJA: Zintegrowany ML Pipeline
function runIntegratedMLPipeline(features, labels, metadata, logFile)
% RUNINTEGRATEDMLPIPELINE Uruchamia ML Pipeline z danymi z App()

logInfo('Starting integrated ML Pipeline...', logFile);

try
    %% KROK 1: Podział danych
    fprintf('\n📊 Splitting dataset...\n');
    [trainData, valData, testData] = splitDataset(features, labels, metadata, [0.7, 0.25, 0.25]);
    
    %% KROK 2: Optymalizacja hiperparametrów
    models = {'patternnet', 'cnn'};
    optimizationResults = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        
        fprintf('\n%s\n', repmat('=', 1, 60));
        fprintf('🚀 OPTIMIZING %s\n', upper(modelType));
        fprintf('%s\n', repmat('=', 1, 60));
        
        % Mniejsza liczba prób dla szybszego działania w zintegrowanej wersji
        numTrials = 30;
        [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials);
        
        optimizationResults.(modelType) = struct();
        optimizationResults.(modelType).bestHyperparams = bestHyperparams;
        optimizationResults.(modelType).bestScore = bestScore;
        optimizationResults.(modelType).allResults = allResults;
        
        fprintf('\n🎯 Best %s validation accuracy: %.2f%%\n', upper(modelType), bestScore * 100);
        logInfo(sprintf('Best %s validation accuracy: %.2f%%', upper(modelType), bestScore * 100), logFile);
    end
    
    %% KROK 3: Trenuj finalne modele
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('🏁 TRAINING FINAL MODELS\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    finalModels = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        
        % SPRAWDŹ czy optymalizacja się udała
        if ~isfield(optimizationResults, modelType) || optimizationResults.(modelType).bestScore == 0
            fprintf('\n⚠️  Skipping %s - optimization failed\n', upper(modelType));
            logWarning(sprintf('Skipping %s - optimization failed', upper(modelType)), logFile);
            continue;
        end
        
        bestHyperparams = optimizationResults.(modelType).bestHyperparams;
        
        fprintf('\n🔥 Training final %s model...\n', upper(modelType));
        
        try
            % Połącz train+val dla finalnego trenowania
            combinedTrainData = struct();
            combinedTrainData.features = [trainData.features; valData.features];
            combinedTrainData.labels = [trainData.labels; valData.labels];
            
            [finalModel, trainResults] = trainFinalModel(combinedTrainData, testData, modelType, bestHyperparams);
            
            finalModels.(modelType) = finalModel;
            finalModels.([modelType '_results']) = trainResults;
            
            fprintf('✅ Final %s test accuracy: %.2f%%\n', upper(modelType), trainResults.testAccuracy * 100);
            logSuccess(sprintf('Final %s test accuracy: %.2f%%', upper(modelType), trainResults.testAccuracy * 100), logFile);
            
            % Zapisz model jeśli accuracy > 95%
            if trainResults.testAccuracy > 0.95
                saveHighPerformanceModel(finalModel, trainResults, modelType, bestHyperparams);
                logSuccess(sprintf('High-performance %s model saved!', upper(modelType)), logFile);
            end
            
        catch ME
            fprintf('⚠️  Training %s model failed: %s\n', upper(modelType), ME.message);
            logError(sprintf('Training %s model failed: %s', upper(modelType), ME.message), logFile);
        end
    end
    
    %% KROK 4: Wizualizacje i porównania (tylko dla udanych modeli)
    fprintf('\n📊 Generating model comparisons...\n');
    
    % Sprawdź które modele się udały
    successfulModels = {};
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        if isfield(finalModels, modelType)
            successfulModels{end+1} = modelType;
        end
    end
    
    if length(successfulModels) >= 1
        % Porównaj modele (tylko udane)
        compareModels(finalModels, optimizationResults, successfulModels);
        
        % Szczegółowe wizualizacje
        for i = 1:length(successfulModels)
            modelType = successfulModels{i};
            model = finalModels.(modelType);
            results = finalModels.([modelType '_results']);
            
            createModelVisualization(model, results, modelType, testData);
        end
    else
        fprintf('⚠️  No successful models to visualize\n');
    end
    
    %% KROK 5: Podsumowanie ML Pipeline (tylko udane modele)
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('📈 ML PIPELINE RESULTS\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    if isempty(successfulModels)
        fprintf('\n❌ No models trained successfully!\n');
        logError('No models trained successfully!', logFile);
        return;
    end
    
    % Podsumowanie tylko udanych modeli
    for i = 1:length(successfulModels)
        modelType = successfulModels{i};
        results = finalModels.([modelType '_results']);
        
        fprintf('\n%s:\n', upper(modelType));
        fprintf('  Validation accuracy: %.2f%%\n', optimizationResults.(modelType).bestScore * 100);
        fprintf('  Test accuracy:       %.2f%%\n', results.testAccuracy * 100);
        fprintf('  Training time:       %.1f seconds\n', results.trainTime);
        
        if results.testAccuracy > 0.95
            fprintf('  🏆 HIGH PERFORMANCE MODEL SAVED!\n');
        end
    end
    
    % Wybierz zwycięzcę (tylko z udanych modeli)
    if length(successfulModels) >= 2
        % Porównaj wszystkie udane modele
        bestAcc = 0;
        winner = '';
        for i = 1:length(successfulModels)
            modelType = successfulModels{i};
            acc = finalModels.([modelType '_results']).testAccuracy;
            if acc > bestAcc
                bestAcc = acc;
                winner = modelType;
            end
        end
        fprintf('\n🥇 BEST MODEL: %s with %.2f%% test accuracy!\n', upper(winner), bestAcc * 100);
        logSuccess(sprintf('Best model: %s with %.2f%% test accuracy', upper(winner), bestAcc * 100), logFile);
    else
        % Tylko jeden udany model
        winner = successfulModels{1};
        winnerAcc = finalModels.([winner '_results']).testAccuracy;
        fprintf('\n🏆 ONLY SUCCESSFUL MODEL: %s with %.2f%% test accuracy!\n', upper(winner), winnerAcc * 100);
        logSuccess(sprintf('Only successful model: %s with %.2f%% test accuracy', upper(winner), winnerAcc * 100), logFile);
    end
end
end

function [finalModel, results] = trainFinalModel(trainData, testData, modelType, hyperparams)
% TRAINFINALMODEL Trenuje finalny model z najlepszymi hiperparametrami

results = struct();
tic;

switch lower(modelType)
    case 'patternnet'
        % PatternNet (bez zmian)
        net = createPatternNet(hyperparams);
        
        X_train = trainData.features';
        T_train = full(ind2vec(trainData.labels', 5));
        
        finalModel = train(net, X_train, T_train);
        
        X_test = testData.features';
        Y_test = finalModel(X_test);
        [~, predicted] = max(Y_test, [], 1);
        
        results.testAccuracy = sum(predicted(:) == testData.labels(:)) / length(testData.labels);
        results.predictions = predicted(:);
        results.trueLabels = testData.labels;
        
    case 'cnn'
        % 1D CNN TRAINING
        numFeatures = size(trainData.features, 2);  % 51 cech
        cnnStruct = createCNN(hyperparams, 5, numFeatures);
        
        % KONWERTUJ DO CELL ARRAYS
        numTrainSamples = size(trainData.features, 1);
        numTestSamples = size(testData.features, 1);
        
        % Przygotuj dane dla 1D CNN: cell arrays z kolumnami [features × 1]
        X_train = cell(1, numTrainSamples);
        for i = 1:numTrainSamples
            X_train{i} = trainData.features(i, :)';  % [51 × 1]
        end
        Y_train = categorical(trainData.labels);
        
        X_test = cell(1, numTestSamples);
        for i = 1:numTestSamples
            X_test{i} = testData.features(i, :)';    % [51 × 1]
        end
        Y_test = categorical(testData.labels);
        
        finalModel = trainNetwork(X_train, Y_train, cnnStruct.layers, cnnStruct.options);
        
        % Testuj
        predicted = classify(finalModel, X_test);
        results.testAccuracy = sum(predicted == Y_test) / length(Y_test);
        results.predictions = double(predicted);
        results.trueLabels = double(Y_test);
        
    otherwise
        error('Unknown model type: %s', modelType);
end

results.trainTime = toc;
results.modelType = modelType;
results.hyperparams = hyperparams;
end

function saveHighPerformanceModel(model, results, modelType, hyperparams)
% SAVEHIGHPERFORMANCEMODEL Zapisuje modele z accuracy > 95%

outputDir = 'output/models';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
filename = sprintf('%s_acc%.1f_%s.mat', modelType, results.testAccuracy*100, timestamp);
filepath = fullfile(outputDir, filename);

% Struktura do zapisu
modelData = struct();
modelData.model = model;
modelData.results = results;
modelData.hyperparams = hyperparams;
modelData.modelType = modelType;
modelData.saveTimestamp = timestamp;

save(filepath, 'modelData');

fprintf('🔥 High-performance model saved: %s\n', filename);
end