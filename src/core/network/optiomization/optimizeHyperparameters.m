function [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials)
% OPTIMIZEHYPERPARAMETERS Optymalizacja hiperparametrów (Random Search ONLY)

if nargin < 4
    numTrials = 50;
end

fprintf('\n🔍 Starting hyperparameter optimization for %s...\n', upper(modelType));
fprintf('Number of trials: %d (Random Search only)\n', numTrials);

% Zakresy hiperparametrów
ranges = getHyperparameterRanges(modelType);

% Inicjalizacja
bestScore = 0;
bestHyperparams = [];
allResults = [];

% TYLKO Random Search
fprintf('\n🎲 Random Search (%d trials)\n', numTrials);

for trial = 1:numTrials
    fprintf('  Trial %d/%d: ', trial, numTrials);
    
    % Losuj hiperparametry
    hyperparams = sampleRandomHyperparams(ranges, modelType);
    
    % Trenuj i ewaluuj
    [score, trainTime] = evaluateHyperparams(hyperparams, trainData, valData, modelType);
    
    % Zapisz wynik
    result = struct();
    result.hyperparams = hyperparams;
    result.score = score;
    result.trainTime = trainTime;
    result.method = 'random';
    allResults = [allResults; result];
    
    % Sprawdź czy to najlepszy wynik
    if score > bestScore
        bestScore = score;
        bestHyperparams = hyperparams;
        fprintf('🎯 NEW BEST! Score: %.3f (%.1fs)\n', score, trainTime);
    else
        fprintf('Score: %.3f (%.1fs)\n', score, trainTime);
    end
end

% Podsumowanie
fprintf('\n📊 Optimization completed!\n');
fprintf('Best validation accuracy: %.3f%%\n', bestScore * 100);
fprintf('Total trials: %d\n', length(allResults));

% Sortuj wszystkie wyniki
[~, sortIdx] = sort([allResults.score], 'descend');
allResults = allResults(sortIdx);

% Pokaż top 5
fprintf('\n🏆 Top 5 configurations:\n');
for i = 1:min(5, length(allResults))
    result = allResults(i);
    fprintf('  %d. Score: %.3f%% (%.1fs) - %s\n', ...
        i, result.score*100, result.trainTime, result.method);
end
end

function ranges = getHyperparameterRanges(modelType)
% GETHYPERPARAMETERRANGES Definiuje zakresy hiperparametrów

ranges = struct();

switch lower(modelType)
    case 'patternnet'
        % PatternNet ranges (bez zmian)
        ranges.hiddenSizes = {[8], [10], [12], [14], [16], [20]};
        ranges.trainFcn = {'trainlm', 'trainlm', 'traingdx', 'trainrp'};
        ranges.lr = [0.00005, 0.0005];
        ranges.epochs = [50, 300];
        ranges.mu = [0.001, 0.02];
        ranges.mu_dec = [0.3, 0.8];
        ranges.mu_inc = [20, 80];
        ranges.max_fail = [1, 5];
        ranges.goal = [0.0, 1e-6];
        
    case 'cnn'
        % 1D CNN ZAKRESY
        ranges.filterSize = [3, 7];                    % Rozmiar kernela 1D
        ranges.numFilters1 = [8, 32];                  % Pierwsza warstwa conv1d
        ranges.numFilters2 = [16, 64];                 % Druga warstwa conv1d
        ranges.dropoutRate = [0.2, 0.5];               % Dropout
        ranges.lr = [0.0001, 0.01];                    % Learning rate
        ranges.l2reg = [1e-6, 1e-2];                   % L2 regularization
        ranges.epochs = [20, 100];                     % Liczba epochs
        ranges.miniBatchSize = [2, 8];                 % Batch size
        
    otherwise
        error('Unknown model type: %s', modelType);
end
end

function hyperparams = sampleRandomHyperparams(ranges, modelType)
% SAMPLERANDOMHYPERPARAMS Inteligentne losowanie hiperparametrów

hyperparams = struct();
fields = fieldnames(ranges);

switch lower(modelType)
    case 'patternnet'
        % PatternNet sampling (bez zmian)
        for i = 1:length(fields)
            fieldName = fields{i};
            range = ranges.(fieldName);
            
            if iscell(range)
                idx = randi(length(range));
                hyperparams.(fieldName) = range{idx};
            elseif length(range) == 2
                if strcmp(fieldName, 'lr')
                    optimalLR = 0.000098;
                    sigma = 0.0001;
                    sample = normrnd(optimalLR, sigma);
                    hyperparams.(fieldName) = max(range(1), min(range(2), sample));
                elseif strcmp(fieldName, 'mu')
                    optimalMu = 0.008175;
                    sigma = 0.005;
                    sample = normrnd(optimalMu, sigma);
                    hyperparams.(fieldName) = max(range(1), min(range(2), sample));
                elseif strcmp(fieldName, 'mu_dec')
                    optimalMuDec = 0.572343;
                    sigma = 0.15;
                    sample = normrnd(optimalMuDec, sigma);
                    hyperparams.(fieldName) = max(range(1), min(range(2), sample));
                elseif strcmp(fieldName, 'mu_inc')
                    optimalMuInc = 43.891772;
                    sigma = 15;
                    sample = normrnd(optimalMuInc, sigma);
                    hyperparams.(fieldName) = max(range(1), min(range(2), sample));
                elseif strcmp(fieldName, 'max_fail')
                    optimalMaxFail = 2;
                    sigma = 1;
                    sample = round(normrnd(optimalMaxFail, sigma));
                    hyperparams.(fieldName) = max(range(1), min(range(2), sample));
                elseif strcmp(fieldName, 'epochs')
                    lambda = 1/100;
                    sample = exprnd(1/lambda);
                    hyperparams.(fieldName) = max(range(1), min(range(2), round(sample)));
                elseif strcmp(fieldName, 'goal')
                    if range(1) == 0
                        hyperparams.(fieldName) = 0;
                    else
                        logMin = log10(range(1));
                        logMax = log10(range(2));
                        logVal = logMin + (logMax - logMin) * rand();
                        hyperparams.(fieldName) = 10^logVal;
                    end
                else
                    hyperparams.(fieldName) = range(1) + (range(2) - range(1)) * rand();
                end
                
                if any(strcmp(fieldName, {'epochs', 'max_fail'}))
                    hyperparams.(fieldName) = round(hyperparams.(fieldName));
                end
            end
        end
        
        hyperparams.performFcn = 'crossentropy';
        hyperparams.showWindow = false;
        hyperparams.showCommandLine = false;
        
    case 'cnn'
        % 1D CNN SAMPLING
        hyperparams.filterSize = 3 + round(4 * rand());        % 3-7
        hyperparams.numFilters1 = 8 + round(24 * rand());      % 8-32
        hyperparams.numFilters2 = 16 + round(48 * rand());     % 16-64
        hyperparams.dropoutRate = 0.2 + 0.3 * rand();          % 0.2-0.5
        hyperparams.lr = 0.0001 + 0.0099 * rand();             % 0.0001-0.01
        hyperparams.l2reg = 1e-6 + (1e-2 - 1e-6) * rand();    % 1e-6 to 1e-2
        hyperparams.epochs = round(20 + 80 * rand());           % 20-100
        hyperparams.miniBatchSize = round(2 + 6 * rand());     % 2-8
        
        % Walidacja
        hyperparams.miniBatchSize = max(2, min(8, hyperparams.miniBatchSize));
end
end

function [score, trainTime] = evaluateHyperparams(hyperparams, trainData, valData, modelType)
% EVALUATEHYPERPARAMS Trenuje model z danymi hiperparametrami

try
    tic;
    
    switch lower(modelType)
        case 'patternnet'
            % PatternNet evaluation (bez zmian)
            net = createPatternNet(hyperparams);
            
            X_train = trainData.features';
            T_train = full(ind2vec(trainData.labels', 5));
            
            net = train(net, X_train, T_train);
            
            X_val = valData.features';
            Y_val = net(X_val);
            [~, predicted] = max(Y_val, [], 1);
            
            score = sum(predicted(:) == valData.labels(:)) / length(valData.labels);
            
        case 'cnn'
            % 1D CNN EVALUATION
            try
                fprintf('🔧 1D CNN Debug:\n');
                fprintf('   Train features: [%d, %d]\n', size(trainData.features));
                fprintf('   Val features: [%d, %d]\n', size(valData.features));
                
                % Sprawdź rozmiar danych
                if size(trainData.features, 1) < 4
                    error('Not enough training samples for CNN');
                end
                
                % Dostosuj miniBatchSize
                maxBatchSize = min(6, floor(size(trainData.features, 1) / 2));
                hyperparams.miniBatchSize = min(hyperparams.miniBatchSize, maxBatchSize);
                fprintf('   Batch size: %d\n', hyperparams.miniBatchSize);
                
                % Utwórz 1D CNN
                numFeatures = size(trainData.features, 2);  % 51 cech
                cnnStruct = createCNN(hyperparams, 5, numFeatures);
                
                % POPRAWNE FORMATOWANIE DANYCH DLA 1D CNN
                % Dla sequence-to-one: każda próbka to kolumna w cell array
                numTrainSamples = size(trainData.features, 1);
                numValSamples = size(valData.features, 1);
                
                % Konwertuj do cell arrays - każda próbka to kolumna w komórce
                X_train = cell(1, numTrainSamples);
                for i = 1:numTrainSamples
                    X_train{i} = trainData.features(i, :)';  % [51 × 1] kolumna
                end
                Y_train = categorical(trainData.labels);
                
                X_val = cell(1, numValSamples);
                for i = 1:numValSamples
                    X_val{i} = valData.features(i, :)';      % [51 × 1] kolumna
                end
                Y_val = categorical(valData.labels);
                
                fprintf('   1D CNN input: %d cell arrays with [%d × 1] sequences\n', ...
                    length(X_train), size(X_train{1}, 1));
                
                % Trenuj 1D CNN
                net = trainNetwork(X_train, Y_train, cnnStruct.layers, cnnStruct.options);
                
                % Ewaluuj
                predicted = classify(net, X_val);
                score = sum(predicted == Y_val) / length(Y_val);
                
                fprintf('   1D CNN score: %.3f\n', score);
                
            catch ME
                score = 0;
                fprintf('   1D CNN failed: %s\n', ME.message);
            end
            
        otherwise
            error('Unknown model type: %s', modelType);
    end
    
    trainTime = toc;
    
catch ME
    score = 0;
    trainTime = toc;
    fprintf('[FAILED: %s] ', ME.message);
end
end