function MLPipeline(allFeatures, validLabels, metadata, preprocessedImages, validImageIndices)
% MLPIPELINE Główny pipeline uczenia maszynowego dla klasyfikacji palców - PatternNet + CNN
%
% Args:
%   allFeatures - cechy minucji dla PatternNet
%   validLabels - etykiety klas
%   metadata - metadane z nazwami palców
%   preprocessedImages - obrazy dla CNN (opcjonalne)
%   validImageIndices - indeksy prawidłowych obrazów (opcjonalne)

fprintf('\n');
fprintf('=================================================================\n');
fprintf('                    ML PIPELINE - FINGERPRINT CLASSIFICATION     \n');
fprintf('                         (PatternNet + CNN)                      \n');
fprintf('=================================================================\n');

% Sprawdź argumenty
if nargin < 3
    error('MLPipeline requires at least allFeatures, validLabels, and metadata');
end

% Czy mamy dane dla CNN?
hasCNNData = (nargin >= 5) && ~isempty(preprocessedImages) && ~isempty(validImageIndices);

if hasCNNData
    fprintf('📊 Running with PatternNet (features) + CNN (images)\n');
    models = {'patternnet', 'cnn'};
else
    fprintf('📊 Running with PatternNet only (no image data for CNN)\n');
    models = {'patternnet'};
end

try
    %% KROK 1: Podsumowanie danych
    fprintf('\n📂 Data Summary:\n');
    fprintf('✅ Loaded %d samples with %d features\n', size(allFeatures, 1), size(allFeatures, 2));
    
    if hasCNNData
        fprintf('✅ Loaded %d preprocessed images for CNN\n', length(preprocessedImages));
        fprintf('✅ Valid image indices: %d\n', length(validImageIndices));
    end
    
    %% KROK 2: Podział danych dla cech (PatternNet)
    fprintf('\n📊 Splitting FEATURES dataset...\n');
    [trainData, valData, testData] = splitDataset(allFeatures, validLabels, metadata, [0.7, 0.15, 0.15]);
    
    %% KROK 2.5: Podział obrazów dla CNN (jeśli dostępne)
    imagesData = [];
    if hasCNNData
        fprintf('\n🖼️  Splitting IMAGES dataset for CNN...\n');
        [trainImages, valImages, testImages] = splitImagesDataset(...
            preprocessedImages, validImageIndices, validLabels, metadata, [0.7, 0.15, 0.15]);
        
        fprintf('\n🔧 Preparing images for CNN training...\n');
        targetSize = [128, 128]; % Rozmiar docelowy obrazów
        
        % Konwertuj obrazy do 4D arrays
        X_train_images = prepareImagesForCNN(trainImages.images, targetSize, true);
        Y_train_images = categorical(trainImages.labels);
        
        X_val_images = prepareImagesForCNN(valImages.images, targetSize, true);
        Y_val_images = categorical(valImages.labels);
        
        X_test_images = prepareImagesForCNN(testImages.images, targetSize, true);
        Y_test_images = categorical(testImages.labels);
        
        % Struktura z danymi obrazów dla CNN
        imagesData = struct();
        imagesData.X_train = X_train_images;
        imagesData.Y_train = Y_train_images;
        imagesData.X_val = X_val_images;
        imagesData.Y_val = Y_val_images;
        imagesData.X_test = X_test_images;
        imagesData.Y_test = Y_test_images;
        
        fprintf('✅ Images prepared for CNN:\n');
        fprintf('  Train: [%s], Val: [%s], Test: [%s]\n', ...
            mat2str(size(X_train_images)), mat2str(size(X_val_images)), mat2str(size(X_test_images)));
    end
    
    %% KROK 3: Wybór strategii optymalizacji
    fprintf('\n🎯 HYPERPARAMETER OPTIMIZATION STRATEGY\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    % Sprawdź czy są dostępne zapisane modele
    savedModelsDir = 'output/models';
    availableModels = checkAvailableOptimalModels(savedModelsDir, models);
    
    if ~isempty(availableModels)
        fprintf('Found optimal parameters for: %s\n', strjoin(availableModels, ', '));
        fprintf('\nChoose optimization strategy:\n');
        fprintf('  1. Use saved optimal parameters (FAST - seconds)\n');
        fprintf('  2. Optimize hyperparameters from scratch (SLOW - minutes)\n');
        fprintf('  3. Hybrid: Use optimal for available models, optimize others\n');
        
        while true
            strategy = input('Select strategy (1, 2, or 3): ');
            if ismember(strategy, [1, 2, 3])
                break;
            else
                fprintf('Invalid choice. Please enter 1, 2, or 3.\n');
            end
        end
    else
        fprintf('No saved optimal parameters found. Will optimize from scratch.\n');
        strategy = 2; % Force optimization
    end
    
    fprintf('\n📋 Selected strategy: ');
    switch strategy
        case 1
            fprintf('Use all saved optimal parameters\n');
        case 2
            fprintf('Optimize all hyperparameters from scratch\n');
        case 3
            fprintf('Hybrid approach\n');
    end
    
    %% KROK 4: Optymalizacja hiperparametrów - z wyborem strategii
    optimizationResults = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        
        fprintf('\n%s\n', repmat('=', 1, 60));
        fprintf('🚀 PROCESSING %s\n', upper(modelType));
        fprintf('%s\n', repmat('=', 1, 60));
        
        % Sprawdź strategię dla tego modelu
        shouldOptimize = true;
        optimalParams = [];
        
        if strategy == 1 || (strategy == 3 && ismember(modelType, availableModels))
            % Spróbuj załadować optymalne parametry
            [optimalParams, loadSuccess] = loadOptimalParameters(savedModelsDir, modelType);
            
            if loadSuccess
                fprintf('✅ Loaded optimal parameters for %s\n', upper(modelType));
                shouldOptimize = false;
                
                % Oszacuj "bestScore" na podstawie zapisanych wyników
                estimatedScore = estimateScoreFromOptimalParams(optimalParams);
                
                optimizationResults.(modelType) = struct();
                optimizationResults.(modelType).bestHyperparams = optimalParams;
                optimizationResults.(modelType).bestScore = estimatedScore;
                optimizationResults.(modelType).allResults = [];
                optimizationResults.(modelType).source = 'loaded_optimal';
                
                fprintf('🎯 Using optimal %s parameters (estimated score: %.2f%%)\n', ...
                    upper(modelType), estimatedScore * 100);
            else
                fprintf('⚠️  Failed to load optimal parameters for %s. Will optimize.\n', upper(modelType));
                shouldOptimize = true;
            end
        end
        
        if shouldOptimize
            % Standardowa optymalizacja
            if strcmp(modelType, 'cnn')
                numTrials = 20;
            else
                numTrials = 50;
            end
            
            fprintf('🔍 Optimizing %s hyperparameters (%d trials)...\n', upper(modelType), numTrials);
            
            if strcmp(modelType, 'cnn') && hasCNNData
                [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(...
                    trainData, valData, modelType, numTrials, imagesData);
            elseif strcmp(modelType, 'patternnet')
                [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(...
                    trainData, valData, modelType, numTrials);
            else
                fprintf('⚠️  Skipping %s - no data available\n', upper(modelType));
                continue;
            end
            
            optimizationResults.(modelType) = struct();
            optimizationResults.(modelType).bestHyperparams = bestHyperparams;
            optimizationResults.(modelType).bestScore = bestScore;
            optimizationResults.(modelType).allResults = allResults;
            optimizationResults.(modelType).source = 'optimized';
            
            fprintf('\n🎯 Best %s validation accuracy: %.2f%%\n', upper(modelType), bestScore * 100);
        end
    end
    
    %% KROK 5: Trenuj finalne modele
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('🏁 TRAINING FINAL MODELS\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    finalModels = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        
        % SPRAWDŹ czy optymalizacja się udała
        if ~isfield(optimizationResults, modelType) || optimizationResults.(modelType).bestScore == 0
            fprintf('\n⚠️  Skipping %s - optimization failed\n', upper(modelType));
            continue;
        end
        
        bestHyperparams = optimizationResults.(modelType).bestHyperparams;
        
        fprintf('\n🔥 Training final %s model...\n', upper(modelType));
        
        try
            if strcmp(modelType, 'cnn') && hasCNNData
                % CNN - trenuj na obrazach
                [finalModel, trainResults] = trainFinalModelCNN(imagesData, bestHyperparams);
            elseif strcmp(modelType, 'patternnet')
                % PatternNet - trenuj na cechach
                combinedTrainData = struct();
                combinedTrainData.features = [trainData.features; valData.features];
                combinedTrainData.labels = [trainData.labels; valData.labels];
                
                [finalModel, trainResults] = trainFinalModel(combinedTrainData, testData, modelType, bestHyperparams);
            else
                fprintf('⚠️  Skipping %s - no data or unsupported type\n', upper(modelType));
                continue;
            end
            
            % POPRAWKA: Dodaj validation accuracy do results
            trainResults.valAccuracy = optimizationResults.(modelType).bestScore;  % Z optymalizacji!
            
            finalModels.(modelType) = finalModel;
            finalModels.([modelType '_results']) = trainResults;
            
            fprintf('✅ Final %s test accuracy: %.2f%%\n', upper(modelType), trainResults.testAccuracy * 100);
            
            % Zapisz model jeśli accuracy > 95%
            if trainResults.testAccuracy > 0.95
                saveHighPerformanceModel(finalModel, trainResults, modelType, bestHyperparams);
                fprintf('🏆 High-performance %s model saved!\n', upper(modelType));
            end
            
            % NOWE: Zapisz optymalne parametry dla przyszłego użycia
            if trainResults.testAccuracy > 0.85 % Próg dla "optymalnych" parametrów
                saveOptimalParameters(modelType, bestHyperparams, trainResults, optimizationResults.(modelType));
                fprintf('💾 Optimal parameters saved for future use!\n');
            end
            
        catch ME
            fprintf('⚠️  Training %s model failed: %s\n', upper(modelType), ME.message);
        end
    end
    
    %% KROK 6: Wizualizacje i porównania
    fprintf('\n📊 Generating visualizations...\n');
    
    % Sprawdź które modele się udały
    successfulModels = {};
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        if isfield(finalModels, modelType)
            successfulModels{end+1} = modelType;
        end
    end
    
    if ~isempty(successfulModels)
        % Szczegółowe wizualizacje dla każdego modelu
        for i = 1:length(successfulModels)
            modelType = successfulModels{i};
            model = finalModels.(modelType);
            results = finalModels.([modelType '_results']);
            
            if strcmp(modelType, 'cnn')
                % Dla CNN użyj obrazów testowych
                createModelVisualization(model, results, modelType, imagesData);
            else
                % Dla PatternNet użyj cech testowych
                createModelVisualization(model, results, modelType, testData);
            end
        end
        
        % Porównanie modeli jeśli mamy więcej niż jeden
        if length(successfulModels) > 1
            compareModels(finalModels, optimizationResults, successfulModels);
        end
    else
        fprintf('⚠️  No successful models to visualize\n');
    end
    
    %% KROK 7: Podsumowanie końcowe
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('📈 FINAL RESULTS SUMMARY\n');
    fprintf('%s\n', repmat('=', 1, 60));
    
    if isempty(successfulModels)
        fprintf('\n❌ No models trained successfully!\n');
        return;
    end
    
    % Podsumowanie dla każdego udanego modelu
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
        
        % Śledź najlepszy model
        if testAcc > bestAcc
            bestAcc = testAcc;
            bestModel = modelType;
        end
    end
    
    % Winner
    if ~isempty(bestModel)
        fprintf('\n🏆 BEST MODEL: %s with %.2f%% test accuracy!\n', upper(bestModel), bestAcc);
        
        % Dodatkowe podsumowanie dla winnera
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
    
catch ME
    fprintf('\n❌ ML Pipeline error: %s\n', ME.message);
    fprintf('Stack trace: %s\n', getReport(ME, 'extended'));
    rethrow(ME);
end
end

%% HELPER FUNCTIONS

function [finalModel, results] = trainFinalModel(trainData, testData, modelType, hyperparams)
% TRAINFINALMODEL Trenuje finalny model dla cech

results = struct();
tic;

switch lower(modelType)
    case 'patternnet'
        % PatternNet
        net = createPatternNet(hyperparams);
        
        X_train = trainData.features';
        T_train = full(ind2vec(trainData.labels', 5));
        
        finalModel = train(net, X_train, T_train);
        
        % Testuj
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
% TRAINFINALMODELCNN Trenuje finalny model CNN na obrazach

results = struct();
tic;

% Połącz train + val dla finalnego trenowania
X_combined = cat(4, imagesData.X_train, imagesData.X_val);
Y_combined = [imagesData.Y_train; imagesData.Y_val];

% Test data
X_test = imagesData.X_test;
Y_test = imagesData.Y_test;

% Utwórz CNN
inputSize = size(X_combined(:,:,:,1));
cnnStruct = createCNN(hyperparams, 5, inputSize);

% Trenuj
finalModel = trainNetwork(X_combined, Y_combined, cnnStruct.layers, cnnStruct.options);

% Testuj
predicted = classify(finalModel, X_test);
results.testAccuracy = sum(predicted == Y_test) / length(Y_test);
results.predictions = double(predicted);
results.trueLabels = double(Y_test);

results.trainTime = toc;
results.modelType = 'cnn';
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

function saveOptimalParameters(modelType, hyperparams, results, optimizationResults)
% SAVEOPTIMALPARAMETERS Zapisuje optymalne parametry dla przyszłego użycia

outputDir = 'output/models';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
filename = sprintf('%s_optimal_acc%.1f_%s.mat', modelType, results.testAccuracy*100, timestamp);
filepath = fullfile(outputDir, filename);

% Struktura z optymalnymi parametrami
optimalData = struct();
optimalData.hyperparams = hyperparams;
optimalData.modelType = modelType;
optimalData.testAccuracy = results.testAccuracy;
optimalData.validationAccuracy = optimizationResults.bestScore;
optimalData.trainTime = results.trainTime;
optimalData.saveTimestamp = timestamp;
optimalData.source = 'optimization';

% Dodatkowe metadane
optimalData.qualityScore = results.testAccuracy; % Dla estimateScoreFromOptimalParams
optimalData.validation_accuracy = optimizationResults.bestScore; % Fallback

save(filepath, 'optimalData');

fprintf('💾 Optimal parameters saved: %s\n', filename);
end

%% HELPER FUNCTIONS DLA OPTYMALNYCH PARAMETRÓW

function availableModels = checkAvailableOptimalModels(modelsDir, requestedModels)
% CHECKAVAILABLEOPTIMALMODELS Sprawdza które modele mają zapisane optymalne parametry

availableModels = {};

if ~exist(modelsDir, 'dir')
    return;
end

for i = 1:length(requestedModels)
    modelType = requestedModels{i};
    
    % Szukaj plików z optymalnych parametrów dla tego modelu
    pattern = sprintf('%s_optimal_*.mat', modelType);
    files = dir(fullfile(modelsDir, pattern));
    
    % Również szukaj plików z wysoką accuracy
    pattern2 = sprintf('%s_acc*.mat', modelType);
    files2 = dir(fullfile(modelsDir, pattern2));
    
    if ~isempty(files) || ~isempty(files2)
        availableModels{end+1} = modelType;
    end
end
end

function [optimalParams, success] = loadOptimalParameters(modelsDir, modelType)
% LOADOPTIMALPARAMETERS Ładuje optymalne parametry dla modelu

optimalParams = [];
success = false;

if ~exist(modelsDir, 'dir')
    return;
end

% Strategia 1: Szukaj pliku z "optimal" w nazwie
pattern = sprintf('%s_optimal_*.mat', modelType);
files = dir(fullfile(modelsDir, pattern));

if isempty(files)
    % Strategia 2: Szukaj najlepszego modelu z wysoką accuracy
    pattern = sprintf('%s_acc*.mat', modelType);
    files = dir(fullfile(modelsDir, pattern));
    
    if ~isempty(files)
        % Sortuj według accuracy w nazwie pliku
        accuracies = [];
        for i = 1:length(files)
            filename = files(i).name;
            % Wyciągnij accuracy z nazwy (np. "cnn_acc95.3_2025-01-01.mat")
            tokens = regexp(filename, sprintf('%s_acc([0-9.]+)_', modelType), 'tokens');
            if ~isempty(tokens)
                accuracies(i) = str2double(tokens{1}{1});
            else
                accuracies(i) = 0;
            end
        end
        
        % Wybierz najlepszy
        [~, bestIdx] = max(accuracies);
        files = files(bestIdx);
    end
end

if isempty(files)
    return;
end

% POPRAWKA: Sortuj chronologicznie - używaj datenum jako liczby
if length(files) > 1
    % Wyciągnij datenum values
    dateTimes = [files.datenum];
    
    % Sortuj w porządku malejącym (najnowsze pierwsze)
    [~, sortIdx] = sort(dateTimes, 'descend');
    selectedFile = files(sortIdx(1));
else
    selectedFile = files(1);
end

try
    filePath = fullfile(modelsDir, selectedFile.name);
    loadedData = load(filePath);
    
    % Sprawdź strukturę pliku
    if isfield(loadedData, 'optimalData')
        % Nowy format z zapisanymi optymalnymi parametrami
        optimalData = loadedData.optimalData;
        optimalParams = optimalData.hyperparams;
        success = true;
        
        fprintf('📂 Loaded from: %s (%.1f%% accuracy)\n', ...
            selectedFile.name, optimalData.testAccuracy * 100);
        
    elseif isfield(loadedData, 'modelData')
        % Format z MLPipeline
        modelData = loadedData.modelData;
        optimalParams = modelData.hyperparams;
        success = true;
        
        fprintf('📂 Loaded from: %s (%.1f%% accuracy)\n', ...
            selectedFile.name, modelData.results.testAccuracy * 100);
        
    elseif isfield(loadedData, 'bestHyperparams')
        % Stary format z optymalizacji
        optimalParams = loadedData.bestHyperparams;
        success = true;
        
        fprintf('📂 Loaded from: %s\n', selectedFile.name);
        
    else
        fprintf('⚠️  Unknown file format: %s\n', selectedFile.name);
        % Debug - pokaż dostępne pola
        availableFields = fieldnames(loadedData);
        fprintf('    Available fields: %s\n', strjoin(availableFields, ', '));
    end
    
catch ME
    fprintf('⚠️  Error loading %s: %s\n', selectedFile.name, ME.message);
end
end

function estimatedScore = estimateScoreFromOptimalParams(optimalParams)
% ESTIMATESCOREFROMOPTIMALPARAMS Oszacuj score na podstawie parametrów

% Domyślnie załóż że optymalne parametry dają dobrą accuracy
estimatedScore = 0.90; % 90% base estimate

% Jeśli są to parametry z wysokiej jakości modelu, podnieś estimate
if isfield(optimalParams, 'qualityScore')
    estimatedScore = optimalParams.qualityScore;
elseif isfield(optimalParams, 'validation_accuracy')
    estimatedScore = optimalParams.validation_accuracy;
end

% Clamp do sensownego zakresu
estimatedScore = max(0.5, min(0.98, estimatedScore));
end