function MLPipeline()
% MLPIPELINE Główny pipeline uczenia maszynowego dla klasyfikacji palców
%
% Pipeline:
% 1. Podział danych (stratified 70/15/15)
% 2. Optymalizacja hiperparametrów (Random Search + GA)
% 3. Trening finalnych modeli (PatternNet vs CNN)
% 4. Ewaluacja i porównanie modeli
% 5. Zapis najlepszych modeli (accuracy > 95%)

fprintf('\n');
fprintf('=================================================================\n');
fprintf('                    ML PIPELINE - FINGERPRINT CLASSIFICATION     \n');
fprintf('=================================================================\n');

try
    %% KROK 1: Wczytaj dane z poprzedniego pipeline'u
    fprintf('\n📂 Loading processed features...\n');
    
    % Pobierz dane z workspace (z App())
    if nargin < 3
        error('MLPipeline requires features, labels, and metadata as arguments!');
    end
    
    fprintf('✅ Loaded %d samples with %d features\n', size(allFeatures, 1), size(allFeatures, 2));
    
    %% KROK 2: Podział danych
    fprintf('\n📊 Splitting dataset...\n');
    [trainData, valData, testData] = splitDataset(allFeatures, validLabels, metadata, [0.7, 0.15, 0.15]);
    
    %% KROK 3: Optymalizacja hiperparametrów dla obu modeli
    models = {'patternnet', 'cnn'};
    optimizationResults = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        
        fprintf('\n' + string(repmat('=', 1, 60)) + '\n');
        fprintf('🚀 OPTIMIZING %s\n', upper(modelType));
        fprintf(string(repmat('=', 1, 60)) + '\n');
        
        % Optymalizacja (50 prób dla każdego modelu)
        [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, 50);
        
        optimizationResults.(modelType) = struct();
        optimizationResults.(modelType).bestHyperparams = bestHyperparams;
        optimizationResults.(modelType).bestScore = bestScore;
        optimizationResults.(modelType).allResults = allResults;
        
        fprintf('\n🎯 Best %s validation accuracy: %.2f%%\n', upper(modelType), bestScore * 100);
    end
    
    %% KROK 4: Trenuj finalne modele z najlepszymi hiperparametrami
    fprintf('\n' + string(repmat('=', 1, 60)) + '\n');
    fprintf('🏁 TRAINING FINAL MODELS\n');
    fprintf(string(repmat('=', 1, 60)) + '\n');
    
    finalModels = struct();
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        bestHyperparams = optimizationResults.(modelType).bestHyperparams;
        
        fprintf('\n🔥 Training final %s model...\n', upper(modelType));
        
        % Trenuj finalny model na train+val danych
        combinedTrainData = struct();
        combinedTrainData.features = [trainData.features; valData.features];
        combinedTrainData.labels = [trainData.labels; valData.labels];
        
        [finalModel, trainResults] = trainFinalModel(combinedTrainData, testData, modelType, bestHyperparams);
        
        finalModels.(modelType) = finalModel;
        finalModels.([modelType '_results']) = trainResults;
        
        fprintf('✅ Final %s test accuracy: %.2f%%\n', upper(modelType), trainResults.testAccuracy * 100);
        
        % Zapisz model jeśli accuracy > 95%
        if trainResults.testAccuracy > 0.95
            saveHighPerformanceModel(finalModel, trainResults, modelType, bestHyperparams);
        end
    end
    
    %% KROK 5: Porównanie modeli i wizualizacje
    fprintf('\n📊 Generating visualizations and comparisons...\n');
    
    % Porównaj modele
    compareModels(finalModels, optimizationResults, models);
    
    % Szczegółowe wizualizacje dla każdego modelu
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        model = finalModels.(modelType);
        results = finalModels.([modelType '_results']);
        
        createModelVisualization(model, results, modelType, testData);
    end
    
    %% KROK 6: Podsumowanie końcowe
    fprintf('\n' + string(repmat('=', 1, 60)) + '\n');
    fprintf('📈 FINAL RESULTS SUMMARY\n');
    fprintf(string(repmat('=', 1, 60)) + '\n');
    
    for modelIdx = 1:length(models)
        modelType = models{modelIdx};
        results = finalModels.([modelType '_results']);
        
        fprintf('\n%s:\n', upper(modelType));
        fprintf('  Best validation accuracy: %.2f%%\n', optimizationResults.(modelType).bestScore * 100);
        fprintf('  Final test accuracy:      %.2f%%\n', results.testAccuracy * 100);
        fprintf('  Training time:            %.1f seconds\n', results.trainTime);
        
        if results.testAccuracy > 0.95
            fprintf('  🏆 HIGH PERFORMANCE MODEL SAVED!\n');
        end
    end
    
    % Wybierz najlepszy model
    patternnetAcc = finalModels.patternnet_results.testAccuracy;
    cnnAcc = finalModels.cnn_results.testAccuracy;
    
    if patternnetAcc > cnnAcc
        winner = 'PatternNet';
        winnerAcc = patternnetAcc;
    else
        winner = 'CNN';
        winnerAcc = cnnAcc;
    end
    
    fprintf('\n🥇 WINNER: %s with %.2f%% test accuracy!\n', winner, winnerAcc * 100);
    
    fprintf('\n✅ ML Pipeline completed successfully!\n');
    fprintf('Check output/models/ for saved high-performance models.\n');
    fprintf('Check output/figures/ for visualizations.\n');
    
catch ME
    fprintf('\n❌ ML Pipeline error: %s\n', ME.message);
    fprintf('Stack trace: %s\n', getReport(ME, 'extended'));
    rethrow(ME);
end
end

function [finalModel, results] = trainFinalModel(trainData, testData, modelType, hyperparams)
% TRAINFINALMODEL Trenuje finalny model z najlepszymi hiperparametrami

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
        
    case 'cnn'
        % 1D CNN dla sekwencji cech - POPRAWIONA WERSJA
        numFeatures = size(trainData.features, 2);  % 51 cech
        cnnStruct = createCNN(hyperparams, 5, numFeatures);
        
        % KONWERTUJ DO CELL ARRAYS
        numTrainSamples = size(trainData.features, 1);
        numTestSamples = size(testData.features, 1);
        
        % Dane dla 1D CNN: cell arrays z [features × 1] kolumnami
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