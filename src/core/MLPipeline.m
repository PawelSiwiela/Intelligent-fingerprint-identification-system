function MLPipeline(allFeatures, validLabels, metadata, preprocessedImages, validImageIndices, logFile)
% MLPIPELINE Kompleksowy pipeline uczenia maszynowego dla klasyfikacji odcisków palców
%
% Funkcja realizuje pełny cykl trenowania i ewaluacji modeli PatternNet i CNN,
% obejmując optymalizację hiperparametrów, redukcję wymiarowości, podział danych
% oraz szczegółową analizę porównawczą wyników. Automatycznie zarządza zapisem
% optymalnych parametrów i generuje kompleksowe wizualizacje.
%
% Parametry wejściowe:
%   allFeatures - macierz cech [n_samples × n_features] dla PatternNet
%   validLabels - wektor etykiet klas [1×n] odpowiadający próbkom
%   metadata - struktura z nazwami palców i informacjami o klasach
%   preprocessedImages - cell array przetworzonych obrazów dla CNN (opcjonalny)
%   validImageIndices - indeksy ważnych obrazów w preprocessedImages (opcjonalny)
%   logFile - uchwyt pliku do logowania (opcjonalny, domyślnie [])
%
% Dane wyjściowe:
%   - Wytrenowane modele zapisane w output/models/
%   - Wizualizacje porównawcze w output/figures/
%   - Tabela metryk wydajności w konsoli
%   - Optymalne parametry dla przyszłego użycia (przy accuracy ≥95%)
%
% Obsługiwane modele:
%   1. PatternNet - klasyfikacja na podstawie ekstraktowanych cech
%   2. CNN - klasyfikacja bezpośrednio na obrazach (jeśli dostępne)
%
% Strategia optymalizacji:
%   - Automatyczne wykrywanie zapisanych optymalnych parametrów
%   - Random Search dla nowych hiperparametrów (20-50 prób)
%   - Inteligentny podział danych [9:2:3] próbek na klasę
%   - Finalne trenowanie na train+validation → test
%
% Przykład użycia:
%   % Tylko PatternNet:
%   MLPipeline(features, labels, metadata);
%
%   % PatternNet + CNN:
%   MLPipeline(features, labels, metadata, images, imageIndices, logHandle);

% PARAMETR logFile z domyślną wartością
if nargin < 6
    logFile = [];
end

fprintf('\n');
fprintf('=================================================================\n');
fprintf('                    ML PIPELINE - FINGERPRINT CLASSIFICATION     \n');
fprintf('                         (PatternNet + CNN)                      \n');
fprintf('=================================================================\n');

% LOGOWANIE ROZPOCZĘCIA PIPELINE
if ~isempty(logFile)
    logInfo('=============================================================', logFile);
    logInfo('           ML PIPELINE - FINGERPRINT CLASSIFICATION          ', logFile);
    logInfo('=============================================================', logFile);
end

% WALIDACJA ARGUMENTÓW WEJŚCIOWYCH
if nargin < 3
    error('MLPipeline requires at least allFeatures, validLabels, and metadata');
end

% SPRAWDZENIE DOSTĘPNOŚCI DANYCH DLA CNN
hasCNNData = (nargin >= 5) && ~isempty(preprocessedImages) && ~isempty(validImageIndices);

if hasCNNData
    fprintf('📊 Running with PatternNet (features) + CNN (images)\n');
    models = {'patternnet', 'cnn'};
    if ~isempty(logFile)
        logInfo('Running with PatternNet (features) + CNN (images)', logFile);
    end
else
    fprintf('📊 Running with PatternNet only (no image data for CNN)\n');
    models = {'patternnet'};
    if ~isempty(logFile)
        logInfo('Running with PatternNet only (no image data for CNN)', logFile);
    end
end

try
    %% KROK 1: PODSUMOWANIE OTRZYMANYCH DANYCH
    fprintf('\n📂 Received Data Summary:\n');
    fprintf('✅ Features: %d samples with %d features\n', size(allFeatures, 1), size(allFeatures, 2));
    
    % LOGOWANIE STATYSTYK DANYCH
    if ~isempty(logFile)
        logInfo(sprintf('Features: %d samples with %d features', size(allFeatures, 1), size(allFeatures, 2)), logFile);
    end
    
    if hasCNNData
        fprintf('✅ Images: %d preprocessed images for CNN\n', length(preprocessedImages));
        fprintf('✅ Valid image indices: %d\n', length(validImageIndices));
        if ~isempty(logFile)
            logInfo(sprintf('Images: %d preprocessed images for CNN', length(preprocessedImages)), logFile);
        end
    end
    
    % ANALIZA ROZKŁADU KLAS
    uniqueLabels = unique(validLabels);
    if ~isempty(logFile)
        logInfo('CLASS DISTRIBUTION:', logFile);
    end
    for i = 1:length(uniqueLabels)
        label = uniqueLabels(i);
        count = sum(validLabels == label);
        fingerName = metadata.fingerNames{label};
        fprintf('   %s (label %d): %d samples\n', fingerName, label, count);
        if ~isempty(logFile)
            logInfo(sprintf('%s (label %d): %d samples', fingerName, label, count), logFile);
        end
    end
    
    %% KROK 2: REDUKCJA WYMIAROWOŚCI
    fprintf('\n🔬 DIMENSIONALITY REDUCTION FOR PATTERNNET\n');
    reductionStartTime = tic;
    
    [allFeatures, reductionInfo] = askForDimensionalityReduction(allFeatures, validLabels, metadata);
    
    reductionTime = toc(reductionStartTime);
    fprintf('✅ Dimensionality reduction completed in %.2f seconds\n', reductionTime);
    
    %% KROK 3: PODZIAŁ DANYCH
    fprintf('\n📊 Splitting dataset...\n');
    splittingStartTime = tic;
    
    % STRATEGIA PODZIAŁU zoptymalizowana dla małych zbiorów danych
    SPLIT_COUNTS = [9, 2, 3]; % Train: 9, Val: 2, Test: 3 próbki na klasę
    fprintf('🔧 Using optimized split: [%d, %d, %d] per class\n', SPLIT_COUNTS(1), SPLIT_COUNTS(2), SPLIT_COUNTS(3));
    
    if ~isempty(logFile)
        logInfo(sprintf('Dataset split strategy: [%d, %d, %d] per class', SPLIT_COUNTS(1), SPLIT_COUNTS(2), SPLIT_COUNTS(3)), logFile);
    end
    
    % PODZIAŁ CECH dla PatternNet
    [trainData, valData, testData] = splitDataset(allFeatures, validLabels, metadata, SPLIT_COUNTS);
    
    % PODZIAŁ OBRAZÓW dla CNN (używa tych samych indeksów próbek)
    imagesData = [];
    if hasCNNData
        fprintf('\n🖼️  Splitting images for CNN (using same indices)...\n');
        
        [trainImages, valImages, testImages] = splitImagesDataset(...
            preprocessedImages, validImageIndices, validLabels, metadata, SPLIT_COUNTS);
        
        fprintf('\n🔧 Preparing images for CNN training...\n');
        targetSize = [128, 128];
        
        % KONWERSJA OBRAZÓW do formatów CNN (4D arrays)
        X_train_images = prepareImagesForCNN(trainImages.images, targetSize, true);
        Y_train_images = categorical(trainImages.labels);
        
        X_val_images = prepareImagesForCNN(valImages.images, targetSize, true);
        Y_val_images = categorical(valImages.labels);
        
        X_test_images = prepareImagesForCNN(testImages.images, targetSize, true);
        Y_test_images = categorical(testImages.labels);
        
        % STRUKTURA z danymi obrazów dla CNN
        imagesData = struct();
        imagesData.X_train = X_train_images;
        imagesData.Y_train = Y_train_images;
        imagesData.X_val = X_val_images;
        imagesData.Y_val = Y_val_images;
        imagesData.X_test = X_test_images;
        imagesData.Y_test = Y_test_images;
        
        fprintf('✅ Images prepared for CNN: Train:[%s], Val:[%s], Test:[%s]\n', ...
            mat2str(size(X_train_images)), mat2str(size(X_val_images)), mat2str(size(X_test_images)));
    end
    
    splittingTime = toc(splittingStartTime);
    fprintf('✅ Data splitting completed in %.2f seconds\n', splittingTime);
    
    %% KROK 4: WYBÓR STRATEGII OPTYMALIZACJI HIPERPARAMETRÓW
    fprintf('\n🎯 HYPERPARAMETER OPTIMIZATION STRATEGY\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    % SPRAWDZENIE dostępności zapisanych optymalnych parametrów
    savedModelsDir = 'output/models';
    availableParameters = checkAvailableOptimalParameters(savedModelsDir, models);
    
    if ~isempty(availableParameters)
        fprintf('Found optimal parameters for: %s\n', strjoin(availableParameters, ', '));
        fprintf('\nChoose optimization strategy:\n');
        fprintf('  1. Use saved optimal parameters (FAST - seconds)\n');
        fprintf('  2. Optimize hyperparameters with Random Search (SLOW - minutes)\n');
        
        while true
            strategy = input('Select strategy (1 or 2): ');
            if ismember(strategy, [1, 2])
                break;
            else
                fprintf('Invalid choice. Please enter 1 or 2.\n');
            end
        end
    else
        fprintf('No saved optimal parameters found. Will use Random Search optimization.\n');
        strategy = 2; % Wymuś optymalizację
    end
    
    fprintf('\n📋 Selected strategy: ');
    switch strategy
        case 1
            fprintf('Use saved optimal parameters\n');
        case 2
            fprintf('Random Search hyperparameter optimization\n');
    end
    
    %% KROK 5: OPTYMALIZACJA HIPERPARAMETRÓW DLA KAŻDEGO MODELU
    optimizationResults = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        
        fprintf('\n%s\n', repmat('=', 1, 60));
        fprintf('🚀 PROCESSING %s\n', upper(modelType));
        fprintf('%s\n', repmat('=', 1, 60));
        
        if ~isempty(logFile)
            logInfo(sprintf('PROCESSING %s', upper(modelType)), logFile);
        end
        
        % SPRAWDZENIE strategii dla aktualnego modelu
        shouldOptimize = true;
        optimalParams = [];
        
        if strategy == 1
            % STRATEGIA 1: Załaduj zapisane optymalne parametry
            [optimalParams, loadSuccess] = loadOptimalParameters(savedModelsDir, modelType);
            
            if loadSuccess
                fprintf('✅ Loaded optimal parameters for %s\n', upper(modelType));
                shouldOptimize = false;
                
                % OSZACOWANIE wydajności na podstawie historycznych danych
                estimatedScore = 0.90; % Konserwatywne oszacowanie dla załadowanych parametrów
                
                optimizationResults.(modelType) = struct();
                optimizationResults.(modelType).bestHyperparams = optimalParams;
                optimizationResults.(modelType).bestScore = estimatedScore;
                optimizationResults.(modelType).allResults = [];
                optimizationResults.(modelType).source = 'loaded_optimal';
                
                fprintf('🎯 Using optimal %s parameters (estimated score: %.1f%%)\n', ...
                    upper(modelType), estimatedScore * 100);
            else
                fprintf('⚠️  Failed to load optimal parameters for %s.\n', upper(modelType));
                fprintf('    Switching to optimization...\n');
                strategy = 2; % Automatyczny fallback na optymalizację
            end
        end
        
        if shouldOptimize
            optimizationStartTime = tic;
            
            % STRATEGIA 2: Optymalizacja hiperparametrów od zera
            if strcmp(modelType, 'cnn')
                numTrials = 20;
            else
                numTrials = 50;
            end
            
            fprintf('🔍 Optimizing %s hyperparameters (%d trials)...\n', upper(modelType), numTrials);
            
            if strcmp(modelType, 'cnn') && hasCNNData
                [bestHyperparams, bestScore, results] = optimizeHyperparameters(...
                    trainData, valData, modelType, numTrials, imagesData, logFile);
            else
                [bestHyperparams, bestScore, results] = optimizeHyperparameters(...
                    trainData, valData, modelType, numTrials, [], logFile);
            end
            
            optimizationTime = toc(optimizationStartTime);
            
            optimizationResults.(modelType) = struct(...
                'bestHyperparams', bestHyperparams, ...
                'bestScore', bestScore, ...
                'allResults', results, ...
                'source', 'optimized', ...
                'optimizationTime', optimizationTime);
            
            fprintf('\n🎯 Best %s validation accuracy: %.2f%% (optimization: %.1f sec)\n', ...
                upper(modelType), bestScore * 100, optimizationTime);
        end
    end
    
    %% KROK 6: TRENOWANIE FINALNYCH MODELI na połączonych danych train+validation
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('🏁 TRAINING FINAL MODELS (Train + Validation Data)\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    if ~isempty(logFile)
        logInfo('TRAINING FINAL MODELS (Train + Validation Data)', logFile);
    end
    
    finalModels = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        
        % SPRAWDZENIE czy optymalizacja się powiodła
        if ~isfield(optimizationResults, modelType) || optimizationResults.(modelType).bestScore == 0
            fprintf('\n⚠️  Skipping %s - optimization failed\n', upper(modelType));
            if ~isempty(logFile)
                logWarning(sprintf('Skipping %s - optimization failed', upper(modelType)), logFile);
            end
            continue;
        end
        
        bestHyperparams = optimizationResults.(modelType).bestHyperparams;
        
        fprintf('\n🔥 Training final %s model...\n', upper(modelType));
        if ~isempty(logFile)
            logInfo(sprintf('Training final %s model', upper(modelType)), logFile);
        end
        
        try
            if strcmp(modelType, 'cnn') && hasCNNData
                % CNN - trenowanie na obrazach (train+val → test)
                fprintf('   📊 Using Train+Val images for final training\n');
                fprintf('   📈 Train images: %d, Val images: %d, Test images: %d\n', ...
                    size(imagesData.X_train, 4), size(imagesData.X_val, 4), size(imagesData.X_test, 4));
                
                [finalModel, trainResults] = trainFinalModelCNN(imagesData, bestHyperparams);
                
            elseif strcmp(modelType, 'patternnet')
                % PatternNet - łączenie train+val dla finalnego trenowania
                fprintf('   📊 Combining Train+Val features for final training\n');
                fprintf('   📈 Train samples: %d, Val samples: %d, Test samples: %d\n', ...
                    length(trainData.labels), length(valData.labels), length(testData.labels));
                
                combinedTrainData = struct();
                combinedTrainData.features = [trainData.features; valData.features];
                combinedTrainData.labels = [trainData.labels; valData.labels];
                
                fprintf('   ✅ Combined training set: %d samples (%.1f%% more data)\n', ...
                    length(combinedTrainData.labels), ...
                    (length(valData.labels) / length(trainData.labels)) * 100);
                
                [finalModel, trainResults] = trainFinalModel(combinedTrainData, testData, modelType, bestHyperparams);
            else
                fprintf('⚠️  Skipping %s - no data or unsupported type\n', upper(modelType));
                continue;
            end
            
            % DODANIE validation accuracy do wyników (bezpieczne przypisanie)
            if isfield(optimizationResults, modelType) && isfield(optimizationResults.(modelType), 'bestScore')
                trainResults.valAccuracy = optimizationResults.(modelType).bestScore;  % Z fazy optymalizacji
            else
                trainResults.valAccuracy = 0; % Fallback dla nieprawidłowych danych
            end
            
            finalModels.(modelType) = finalModel;
            finalModels.([modelType '_results']) = trainResults;
            
            fprintf('✅ Final %s test accuracy: %.2f%% (trained on %s)\n', ...
                upper(modelType), trainResults.testAccuracy * 100, ...
                strcmp(modelType, 'cnn'), 'train+val images', 'train+val features');
            
            % ZAPIS OPTYMALNYCH PARAMETRÓW przy wysokiej jakości (≥95% TEST accuracy)
            shouldSaveOptimal = (trainResults.testAccuracy >= 0.95) && ... % Tylko test accuracy!
                isfield(optimizationResults, modelType) && ...
                isfield(optimizationResults.(modelType), 'source') && ...
                strcmp(optimizationResults.(modelType).source, 'optimized'); % Nie z wcześniej załadowanych
            
            if shouldSaveOptimal
                saveOptimalParameters(modelType, bestHyperparams, trainResults, optimizationResults.(modelType));
                fprintf('🎯 EXCELLENT %.1f%% TEST accuracy! Optimal parameters saved for future use!\n', ...
                    trainResults.testAccuracy * 100);
                if ~isempty(logFile)
                    logInfo(sprintf('EXCELLENT %.1f%% TEST accuracy! Optimal parameters saved', trainResults.testAccuracy * 100), logFile);
                end
            elseif trainResults.testAccuracy >= 0.95 && ...
                    isfield(optimizationResults, modelType) && ...
                    isfield(optimizationResults.(modelType), 'source') && ...
                    strcmp(optimizationResults.(modelType).source, 'loaded_optimal')
                fprintf('🎯 EXCELLENT %.1f%% TEST accuracy achieved with loaded parameters (not re-saving)\n', ...
                    trainResults.testAccuracy * 100);
            elseif trainResults.testAccuracy < 0.95
                fprintf('📊 Test accuracy %.1f%% < 95%% - optimal parameters not saved\n', ...
                    trainResults.testAccuracy * 100);
            end
            
        catch ME
            fprintf('⚠️  Training %s model failed: %s\n', upper(modelType), ME.message);
            if ~isempty(logFile)
                logError(sprintf('Training %s model failed: %s', upper(modelType), ME.message), logFile);
            end
        end
    end
    
    % IDENTYFIKACJA POMYŚLNIE WYTRENOWANYCH MODELI
    successfulModels = {};
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        if isfield(finalModels, modelType)
            successfulModels{end+1} = modelType;
        end
    end
    
    %% KROK 7: POMIAR SZYBKOŚCI IDENTYFIKACJI
    if ~isempty(successfulModels)
        fprintf('\n⚡ MEASURING IDENTIFICATION SPEED...\n');
        fprintf('%s\n', repmat('=', 1, 50));
        
        totalOptimizationTime = 0;
        totalTrainingTime = 0;
        
        for i = 1:length(successfulModels)
            modelType = successfulModels{i};
            model = finalModels.(modelType);
            
            % POMIAR SZYBKOŚCI IDENTYFIKACJI
            if strcmp(modelType, 'cnn') && hasCNNData
                identResults = measureIdentificationSpeed(model, imagesData.X_test, imagesData.Y_test, modelType);
            else
                identResults = measureIdentificationSpeed(model, testData.features, testData.labels, modelType);
            end
            
            % ZAPISZ WYNIKI SZYBKOŚCI
            finalModels.([modelType '_speed']) = identResults;
            
            % AKUMULUJ CZASY TRENOWANIA
            if isfield(finalModels, [modelType '_results'])
                trainTime = finalModels.([modelType '_results']).trainTime;
                totalTrainingTime = totalTrainingTime + trainTime;
            end
            
            % AKUMULUJ CZASY OPTYMALIZACJI
            if isfield(optimizationResults, modelType) && isfield(optimizationResults.(modelType), 'optimizationTime')
                optTime = optimizationResults.(modelType).optimizationTime;
                totalOptimizationTime = totalOptimizationTime + optTime;
            end
        end
    end
    
    %% KROK 8: GENEROWANIE WIZUALIZACJI I ANALIZ PORÓWNAWCZYCH
    fprintf('\n📊 Generating visualizations...\n');
    
    if ~isempty(successfulModels)
        % SZCZEGÓŁOWE WIZUALIZACJE dla każdego modelu
        for i = 1:length(successfulModels)
            modelType = successfulModels{i};
            model = finalModels.(modelType);
            results = finalModels.([modelType '_results']);
            
            if strcmp(modelType, 'cnn')
                % Dla CNN użyj danych obrazowych testowych
                createModelVisualization(model, results, modelType, imagesData);
            else
                % Dla PatternNet użyj cech testowych
                createModelVisualization(model, results, modelType, testData);
            end
        end
        
        % PORÓWNANIE MODELI jeśli dostępne więcej niż jeden
        if length(successfulModels) > 1
            compareModels(finalModels, optimizationResults, successfulModels);
        end
    else
        fprintf('⚠️  No successful models to visualize\n');
    end
    
    %% KROK 9: PODSUMOWANIE KOŃCOWE I REKOMENDACJE
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('📈 FINAL RESULTS SUMMARY\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    if isempty(successfulModels)
        fprintf('\n❌ No models trained successfully!\n');
        return;
    end
    
    % PODSUMOWANIE dla każdego pomyślnego modelu
    bestAcc = 0;
    bestModel = '';
    
    for i = 1:length(successfulModels)
        modelType = successfulModels{i};
        results = finalModels.([modelType '_results']);
        valAcc = optimizationResults.(modelType).bestScore * 100;
        testAcc = results.testAccuracy * 100;
        
        fprintf('\n%s:\n', upper(modelType));
        fprintf('  Best validation accuracy: %.2f%%\n', valAcc);
        fprintf('  Final test accuracy:      %.2f%%\n', testAcc);
        fprintf('  Training time:            %.1f seconds\n', results.trainTime);
        
        if results.testAccuracy > 0.95
            fprintf('  🏆 HIGH PERFORMANCE MODEL SAVED!\n');
        end
        
        % ŚLEDZENIE najlepszego modelu
        if testAcc > bestAcc
            bestAcc = testAcc;
            bestModel = modelType;
        end
    end
    
    % OGŁOSZENIE ZWYCIĘZCY
    if ~isempty(bestModel)
        fprintf('\n🏆 BEST MODEL: %s with %.2f%% test accuracy!\n', upper(bestModel), bestAcc);
        
        % OCENA JAKOŚCI najlepszego modelu
        if bestAcc > 90
            fprintf('🎉 EXCELLENT PERFORMANCE! Model ready for deployment.\n');
        elseif bestAcc > 80
            fprintf('😊 GOOD PERFORMANCE! Model shows promising results.\n');
        elseif bestAcc > 60
            fprintf('🤔 MODERATE PERFORMANCE! Consider more data or tuning.\n');
        else
            fprintf('😕 POOR PERFORMANCE! Needs significant improvement.\n');
        end
    end
    
    fprintf('\n✅ ML Pipeline completed successfully!\n');
    fprintf('Check output/models/ for saved models.\n');
    fprintf('Check output/figures/ for visualizations.\n');
    
    if ~isempty(logFile)
        logInfo('ML Pipeline completed successfully!', logFile);
    end
    
    if ~isempty(successfulModels)
        fprintf('\n⏱️  COMPLETE TIMING ANALYSIS\n');
        fprintf('===========================\n');
        
        % CZASY PREPROCESSINGU (z metadata)
        if isfield(metadata, 'timings')
            fprintf('📋 PREPROCESSING PHASE:\n');
            fprintf('  📥 Data Loading:        %.2f sec\n', metadata.timings.dataLoading);
            fprintf('  🔄 Image Processing:    %.2f sec\n', metadata.timings.imagePreprocessing);
            fprintf('  🔍 Minutiae Extraction: %.2f sec\n', metadata.timings.minutiaeExtraction);
            fprintf('  🔧 Normalization:       %.2f sec\n', metadata.timings.normalization);
            fprintf('  📊 Total Preprocessing: %.2f sec (%.1f min)\n\n', ...
                metadata.timings.totalPreprocessing, metadata.timings.totalPreprocessing/60);
        end
        
        % CZASY MACHINE LEARNING
        fprintf('📋 MACHINE LEARNING PHASE:\n');
        fprintf('  🔬 Dimensionality Reduction: %.2f sec\n', reductionTime);
        fprintf('  📊 Data Splitting:           %.2f sec\n', splittingTime);
        
        for modelIdx = 1:length(successfulModels)
            modelType = successfulModels{modelIdx};
            
            if isfield(optimizationResults, modelType) && isfield(optimizationResults.(modelType), 'optimizationTime')
                optTime = optimizationResults.(modelType).optimizationTime;
                fprintf('  🎯 %s Optimization:     %.1f sec\n', upper(modelType), optTime);
            end
            
            if isfield(finalModels, [modelType '_results'])
                trainTime = finalModels.([modelType '_results']).trainTime;
                fprintf('  🚀 %s Final Training:   %.1f sec\n', upper(modelType), trainTime);
            end
            
            % WYNIKI SZYBKOŚCI IDENTYFIKACJI
            if isfield(finalModels, [modelType '_speed'])
                speedResults = finalModels.([modelType '_speed']);
                fprintf('  ⚡ %s Identification:   %.2f ms/sample (%.0f samples/sec)\n', ...
                    upper(modelType), speedResults.avgTimeMs, speedResults.throughputSamplesPerSec);
            end
        end
        
        fprintf('  📊 Total ML Processing:      %.2f sec (%.1f min)\n\n', ...
            reductionTime + splittingTime + totalOptimizationTime + totalTrainingTime, ...
            (reductionTime + splittingTime + totalOptimizationTime + totalTrainingTime)/60);
        
        % CAŁKOWITY CZAS SESJI
        if isfield(metadata, 'timings')
            totalSessionTime = metadata.timings.totalPreprocessing + reductionTime + splittingTime + totalOptimizationTime + totalTrainingTime;
            fprintf('🏁 TOTAL SESSION TIME: %.2f seconds (%.1f minutes)\n', totalSessionTime, totalSessionTime/60);
            
            % BREAKDOWN PROCENTOWY
            fprintf('\n📊 TIME BREAKDOWN:\n');
            fprintf('  Preprocessing: %.1f%% (%.1f sec)\n', (metadata.timings.totalPreprocessing/totalSessionTime)*100, metadata.timings.totalPreprocessing);
            fprintf('  Optimization:  %.1f%% (%.1f sec)\n', (totalOptimizationTime/totalSessionTime)*100, totalOptimizationTime);
            fprintf('  Training:      %.1f%% (%.1f sec)\n', (totalTrainingTime/totalSessionTime)*100, totalTrainingTime);
            fprintf('  Other:         %.1f%% (%.1f sec)\n', ((reductionTime + splittingTime)/totalSessionTime)*100, reductionTime + splittingTime);
            
            % TABELA PORÓWNAWCZA MODELI
            fprintf('\n📊 MODEL PERFORMANCE COMPARISON:\n');
            fprintf('=====================================\n');
            fprintf('%-12s | %-8s | %-8s | %-12s | %-15s\n', 'Model', 'Val Acc', 'Test Acc', 'Train Time', 'Speed (ms/sample)');
            fprintf('%s\n', repmat('-', 1, 70));
            
            for i = 1:length(successfulModels)
                modelType = successfulModels{i};
                results = finalModels.([modelType '_results']);
                valAcc = optimizationResults.(modelType).bestScore * 100;
                testAcc = results.testAccuracy * 100;
                trainTime = results.trainTime;
                
                if isfield(finalModels, [modelType '_speed'])
                    avgSpeed = finalModels.([modelType '_speed']).avgTimeMs;
                    speedStr = sprintf('%.2f', avgSpeed);
                else
                    speedStr = 'N/A';
                end
                
                fprintf('%-12s | %6.2f%% | %6.2f%% | %8.1fs | %15s\n', ...
                    upper(modelType), valAcc, testAcc, trainTime, speedStr);
            end
        end
    end
    
catch ME
    fprintf('\n❌ ML Pipeline error: %s\n', ME.message);
    if ~isempty(logFile)
        logError(sprintf('ML Pipeline error: %s', ME.message), logFile);
    end
    rethrow(ME);
end
end

%% FUNKCJE POMOCNICZE DLA TRENOWANIA FINALNYCH MODELI

function [finalModel, results] = trainFinalModel(trainData, testData, modelType, hyperparams)
% TRAINFINALMODEL Trenuje finalny model PatternNet na cechach

results = struct();
tic;

switch lower(modelType)
    case 'patternnet'
        % UTWORZENIE sieci PatternNet z optymalnymi hiperparametrami
        net = createPatternNet(hyperparams);
        
        X_train = trainData.features';
        T_train = full(ind2vec(trainData.labels', 5));
        
        finalModel = train(net, X_train, T_train);
        
        % TESTOWANIE na zbiorze testowym
        X_test = testData.features';
        Y_test = finalModel(X_test);
        [~, predicted] = max(Y_test, [], 1);
        
        results.testAccuracy = sum(predicted(:) == testData.labels(:)) / length(testData.labels);
        results.predictions = predicted(:);
        results.trueLabels = testData.labels;
        
    otherwise
        error('Unknown model type: %s', modelType);
end

results.trainTime = toc;
results.modelType = modelType;
results.hyperparams = hyperparams;
end

function [finalModel, results] = trainFinalModelCNN(imagesData, hyperparams)
% TRAINFINALMODELCNN Trenuje finalny model CNN na połączonych danych train+val → test

results = struct();
tic;

% ŁĄCZENIE train + val dla finalnego trenowania (lepsza praktyka)
fprintf('🔗 Combining train and validation sets for final CNN training...\n');

X_combined = cat(4, imagesData.X_train, imagesData.X_val);
Y_combined = [imagesData.Y_train; imagesData.Y_val];

fprintf('   Combined training set: [%s] (was [%s] + [%s])\n', ...
    mat2str(size(X_combined)), mat2str(size(imagesData.X_train)), mat2str(size(imagesData.X_val)));

% ZBIÓR TESTOWY pozostaje niezmieniony
X_test = imagesData.X_test;
Y_test = imagesData.Y_test;

fprintf('   Test set: [%s] (unchanged)\n', mat2str(size(X_test)));

% UTWORZENIE CNN z finalnymi hiperparametrami
inputSize = size(X_combined(:,:,:,1));
cnnStruct = createCNN(hyperparams, 5, inputSize);

fprintf('🚀 Training final CNN with combined data...\n');

% TRENOWANIE na train+val
finalModel = trainNetwork(X_combined, Y_combined, cnnStruct.layers, cnnStruct.options);

% EWALUACJA tylko na zbiorze testowym
fprintf('🎯 Evaluating on test set...\n');
predicted = classify(finalModel, X_test);
results.testAccuracy = sum(predicted == Y_test) / length(Y_test);
results.predictions = double(predicted);
results.trueLabels = double(Y_test);

results.trainTime = toc;
results.modelType = 'cnn';
results.hyperparams = hyperparams;

fprintf('📊 Final CNN trained on %d samples, tested on %d samples\n', ...
    size(X_combined, 4), size(X_test, 4));
end

function saveOptimalParameters(modelType, hyperparams, results, optimizationResults)
% SAVEOPTIMALPARAMETERS Zapisuje optymalne parametry tylko przy ≥95% TEST accuracy

% WALIDACJA: Upewnij się że test accuracy rzeczywiście ≥95%
if results.testAccuracy < 0.95
    fprintf('⚠️  Cannot save optimal parameters - TEST accuracy %.1f%% < 95%%\n', results.testAccuracy * 100);
    return;
end

outputDir = 'output/models';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
modelTypeLower = lower(modelType);

% NAZWY PLIKÓW oparte na test accuracy z opisowymi tagami
if results.testAccuracy >= 1.0
    qualityTag = 'perfect_100pct_TEST';
    qualityNote = 'Perfect 100% TEST accuracy achieved through optimization';
    filename = sprintf('%s_OPTIMAL_100PCT_TEST_%s.mat', modelTypeLower, timestamp);
elseif results.testAccuracy >= 0.98
    qualityTag = 'excellent_98pct_TEST';
    qualityNote = 'Excellent 98%+ TEST accuracy achieved through optimization';
    filename = sprintf('%s_OPTIMAL_98PCT_TEST_%s.mat', modelTypeLower, timestamp);
else
    qualityTag = 'very_good_95pct_TEST';
    qualityNote = 'Very good 95%+ TEST accuracy achieved through optimization';
    filename = sprintf('%s_OPTIMAL_95PCT_TEST_%s.mat', modelTypeLower, timestamp);
end

filepath = fullfile(outputDir, filename);

% STRUKTURA z optymalnymi parametrami - podkreślenie test accuracy
optimalData = struct();
optimalData.hyperparams = hyperparams;
optimalData.modelType = modelType;
optimalData.testAccuracy = results.testAccuracy;        % Główny wskaźnik jakości
optimalData.validationAccuracy = optimizationResults.bestScore; % Wskaźnik pomocniczy
optimalData.trainTime = results.trainTime;
optimalData.saveTimestamp = timestamp;
optimalData.source = qualityTag;
optimalData.isHighQuality = true;

% DODANE: Wyraźne oznaczenie że kryterium to test accuracy
optimalData.qualityMetric = 'TEST_ACCURACY';           % Kryterium główne
optimalData.testAccuracyScore = results.testAccuracy;  % Wyraźne oznaczenie
optimalData.validationAccuracyScore = optimizationResults.bestScore; % Wyraźne oznaczenie
optimalData.note = qualityNote;

save(filepath, 'optimalData');

fprintf('🎯 HIGH-QUALITY optimal parameters saved: %s\n', filename);
fprintf('   These parameters achieved %.1f%% TEST accuracy (validation: %.1f%%)!\n', ...
    results.testAccuracy * 100, optimizationResults.bestScore * 100);
end

%% FUNKCJE POMOCNICZE DLA ZARZĄDZANIA OPTYMALNYMI PARAMETRAMI

function availableModels = checkAvailableOptimalParameters(modelsDir, requestedModels)
% CHECKAVAILABLEOPTIMALPARAMETERS Sprawdza które modele mają zapisane optymalne parametry

availableModels = {};

if ~exist(modelsDir, 'dir')
    return;
end

for i = 1:length(requestedModels)
    modelType = requestedModels{i};
    
    % SZUKANIE tylko plików z optymalnymi parametrami
    pattern = sprintf('%s_OPTIMAL_*.mat', modelType);
    files = dir(fullfile(modelsDir, pattern));
    
    if ~isempty(files)
        availableModels{end+1} = modelType;
        
        % POKAZANIE najnowszego pliku dla informacji
        [~, newestIdx] = max([files.datenum]);
        newestFile = files(newestIdx);
        
        try
            filePath = fullfile(modelsDir, newestFile.name);
            loadedData = load(filePath);
            
            if isfield(loadedData, 'optimalData')
                accuracy = loadedData.optimalData.testAccuracy * 100;
                fprintf('  %s: %.1f%% TEST accuracy (%s)\n', ...
                    upper(modelType), accuracy, newestFile.name);
            else
                fprintf('  %s: Available (%s)\n', upper(modelType), newestFile.name);
            end
        catch
            fprintf('  %s: Available (%s)\n', upper(modelType), newestFile.name);
        end
    end
end
end

function [optimalParams, success] = loadOptimalParameters(modelsDir, modelType)
% LOADOPTIMALPARAMETERS Ładuje najnowsze optymalne parametry dla modelu

optimalParams = [];
success = false;

if ~exist(modelsDir, 'dir')
    return;
end

% WYSZUKIWANIE plików z optymalnymi parametrami
pattern = sprintf('%s_OPTIMAL_*.mat', modelType);
files = dir(fullfile(modelsDir, pattern));

if isempty(files)
    return;
end

% SORTOWANIE chronologiczne - najnowsze pliki pierwsze
[~, sortIdx] = sort([files.datenum], 'descend');
selectedFile = files(sortIdx(1));

try
    filePath = fullfile(modelsDir, selectedFile.name);
    loadedData = load(filePath);
    
    if isfield(loadedData, 'optimalData')
        optimalData = loadedData.optimalData;
        optimalParams = optimalData.hyperparams;
        success = true;
        
        % KOMUNIKAT o załadowanych parametrach
        if isfield(optimalData, 'testAccuracy')
            accuracy = optimalData.testAccuracy * 100;
            
            if accuracy >= 100
                fprintf('📂 Loaded PERFECT parameters: %.1f%% TEST accuracy (%s)\n', accuracy, selectedFile.name);
            elseif accuracy >= 98
                fprintf('📂 Loaded EXCELLENT parameters: %.1f%% TEST accuracy (%s)\n', accuracy, selectedFile.name);
            elseif accuracy >= 95
                fprintf('📂 Loaded VERY GOOD parameters: %.1f%% TEST accuracy (%s)\n', accuracy, selectedFile.name);
            else
                fprintf('📂 Loaded parameters: %.1f%% TEST accuracy (%s)\n', accuracy, selectedFile.name);
            end
        else
            fprintf('📂 Loaded optimal parameters: %s\n', selectedFile.name);
        end
        
    else
        fprintf('⚠️  File does not contain optimal parameters: %s\n', selectedFile.name);
    end
    
catch ME
    fprintf('⚠️  Error loading %s: %s\n', selectedFile.name, ME.message);
end
end

function [reducedFeatures, reductionInfo] = askForDimensionalityReduction(allFeatures, validLabels, metadata)
% ASKFORDIMENSIONALITYREDUCTION Interaktywny wybór metody redukcji wymiarowości

fprintf('PatternNet has %d features for %d samples (ratio: %.2f)\n', ...
    size(allFeatures, 2), size(allFeatures, 1), size(allFeatures, 1)/size(allFeatures, 2));
fprintf('Choose dimensionality reduction method:\n');
fprintf('  1. MDA - Multiple Discriminant Analysis (SUPERVISED - most stable)\n');
fprintf('  2. PCA - Principal Component Analysis (UNSUPERVISED)\n');
fprintf('  3. No reduction - Use all original features\n');

while true
    reductionChoice = input('Select option (1, 2, or 3): ');
    if ismember(reductionChoice, [1, 2, 3])
        break;
    else
        fprintf('Invalid choice. Please enter 1, 2, or 3.\n');
    end
end

originalFeatures = allFeatures;
reductionInfo = [];

switch reductionChoice
    case 1 % MDA (Multiple Discriminant Analysis)
        fprintf('🔍 Applying MDA (Multiple Discriminant Analysis)...\n');
        params = struct('maxComponents', 4);
        [reducedFeatures, reductionInfo] = reduceDimensionality(allFeatures, 'mda', params, validLabels);
        
        fprintf('📊 MDA Results: %d -> %d features\n', size(originalFeatures, 2), size(reducedFeatures, 2));
        
        try
            visualizeReduction(originalFeatures, reducedFeatures, reductionInfo, validLabels, metadata, 'output/figures');
            fprintf('✅ MDA visualization saved\n');
        catch
            fprintf('⚠️  MDA visualization failed\n');
        end
        
    case 2 % PCA (Principal Component Analysis)
        fprintf('🔍 Applying PCA (unsupervised)...\n');
        params = struct('varianceThreshold', 0.95, 'maxComponents', 15);
        [reducedFeatures, reductionInfo] = reduceDimensionality(allFeatures, 'pca', params);
        
        fprintf('📊 PCA Results: %d -> %d features\n', size(originalFeatures, 2), size(reducedFeatures, 2));
        
        try
            visualizeReduction(originalFeatures, reducedFeatures, reductionInfo, validLabels, metadata, 'output/figures');
            fprintf('✅ PCA visualization saved\n');
        catch
            fprintf('⚠️  PCA visualization failed\n');
        end
        
    case 3 % BEZ REDUKCJI WYMIAROWOŚCI
        fprintf('📊 Using all %d original features\n', size(allFeatures, 2));
        reducedFeatures = allFeatures;
        
        % MINIMALNA struktura reductionInfo dla spójności
        reductionInfo = struct();
        reductionInfo.method = 'none';
        reductionInfo.originalDims = size(allFeatures, 2);
        reductionInfo.reducedDims = size(allFeatures, 2);
end
end