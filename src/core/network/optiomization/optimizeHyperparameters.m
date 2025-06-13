function [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials, imagesData)
% OPTIMIZEHYPERPARAMETERS Optymalizacja hiperparametrów (Random Search + Early Stopping TYLKO przy 95%)

if nargin < 4
    numTrials = 50;
end

if nargin < 5
    imagesData = [];
end

fprintf('\n🔍 Starting hyperparameter optimization for %s...\n', upper(modelType));
fprintf('Number of trials: %d (Random Search with Early Stopping)\n', numTrials);

% EARLY STOPPING PARAMETERS - TYLKO PRZY WYSOKIEJ ACCURACY
earlyStopThreshold = 0.95;  % Zatrzymaj TYLKO jeśli osiągnie 95% accuracy

% Zakresy hiperparametrów
ranges = getHyperparameterRanges(modelType);

% Inicjalizacja
bestScore = 0;
bestHyperparams = [];
allResults = [];

% Random Search z Early Stopping TYLKO przy 95%
fprintf('\n🎲 Random Search (%d trials) with Early Stopping\n', numTrials);
fprintf('   Early stop threshold: %.1f%% accuracy (ONLY condition for stopping)\n', earlyStopThreshold * 100);

for trial = 1:numTrials
    fprintf('  Trial %d/%d: ', trial, numTrials);
    
    % Losuj hiperparametry
    hyperparams = sampleRandomHyperparams(ranges, modelType);
    
    % Trenuj i ewaluuj
    [score, trainTime] = evaluateHyperparams(hyperparams, trainData, valData, modelType, imagesData);
    
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
        
        % EARLY STOPPING - TYLKO jeśli osiągnięto doskonały wynik (>=95%)
        if score >= earlyStopThreshold
            fprintf('🛑 EARLY STOPPING! Achieved %.1f%% accuracy (>= %.1f%% threshold)\n', ...
                score * 100, earlyStopThreshold * 100);
            fprintf('   🎉 EXCELLENT RESULT! Stopping optimization after %d/%d trials\n', trial, numTrials);
            break;
        end
    else
        fprintf('Score: %.3f (%.1fs)\n', score, trainTime);
        % BRAK early stopping przy braku poprawy - kontynuuj wszystkie trials
    end
end

% Podsumowanie
fprintf('\n📊 Optimization completed!\n');
fprintf('Best validation accuracy: %.3f%%\n', bestScore * 100);
fprintf('Total trials completed: %d/%d\n', length(allResults), numTrials);

if bestScore >= earlyStopThreshold
    fprintf('🎉 EXCELLENT RESULT! Early stopped due to achieving %.1f%% accuracy\n', earlyStopThreshold * 100);
else
    fprintf('📈 Completed all %d trials. Best result: %.1f%%\n', numTrials, bestScore * 100);
end

% Sortuj wszystkie wyniki
[~, sortIdx] = sort([allResults.score], 'descend');
allResults = allResults(sortIdx);

% Pokaż top 5
fprintf('\n🏆 Top %d configurations:\n', min(5, length(allResults)));
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
        % 2D CNN RANGES - MAKSYMALNE PRZYSPIESZENIE!
        ranges.filterSize = [3, 5];                    % ZMNIEJSZONE z [3, 7] do [3, 5]
        ranges.numFilters1 = [8, 24];                  % ZMNIEJSZONE z [8, 32] do [8, 24]
        ranges.numFilters2 = [16, 48];                 % ZMNIEJSZONE z [16, 64] do [16, 48]
        ranges.numFilters3 = [32, 96];                 % ZMNIEJSZONE z [32, 128] do [32, 96]
        ranges.dropoutRate = [0.2, 0.4];               % ZMNIEJSZONE z [0.2, 0.5] do [0.2, 0.4]
        ranges.lr = [0.001, 0.01];                     % ZWIĘKSZONE z [0.0001, 0.01] do [0.001, 0.01]
        ranges.l2reg = [1e-5, 1e-3];                   % ZMNIEJSZONE z [1e-6, 1e-2] do [1e-5, 1e-3]
        ranges.epochs = [5, 15];                       % DRASTYCZNIE ZMNIEJSZONE z [10, 30] do [5, 15]
        ranges.miniBatchSize = [4, 12];                % ZMNIEJSZONE z [4, 16] do [4, 12]
        
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
        % 2D CNN SAMPLING
        hyperparams.filterSize = 3 + round(2 * rand());           % 3-5
        hyperparams.numFilters1 = 8 + round(16 * rand());         % 8-24
        hyperparams.numFilters2 = 16 + round(32 * rand());        % 16-48
        hyperparams.numFilters3 = 32 + round(64 * rand());        % 32-96
        hyperparams.dropoutRate = 0.2 + 0.2 * rand();             % 0.2-0.4
        hyperparams.lr = 0.001 + 0.009 * rand();                  % 0.001-0.01
        hyperparams.l2reg = 1e-5 + (1e-3 - 1e-5) * rand();       % 1e-5 to 1e-3
        hyperparams.epochs = round(5 + 10 * rand());             % 5-15
        hyperparams.miniBatchSize = round(4 + 8 * rand());       % 4-12
        
        % Walidacja
        hyperparams.miniBatchSize = max(4, min(12, hyperparams.miniBatchSize));
        
    otherwise
        error('Unknown model type: %s', modelType);
end
end

function [score, trainTime] = evaluateHyperparams(hyperparams, trainData, valData, modelType, imagesData)
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
            % 2D CNN EVALUATION
            if isempty(imagesData)
                error('CNN requires images data');
            end
            
            % Sprawdź czy mamy wystarczająco danych
            numTrainImages = size(imagesData.X_train, 4);
            numValImages = size(imagesData.X_val, 4);
            
            if numTrainImages < 4 || numValImages < 2
                error('Not enough images for CNN training');
            end
            
            % Dostosuj miniBatchSize do dostępnych danych
            maxBatchSize = min(hyperparams.miniBatchSize, floor(numTrainImages / 2));
            hyperparams.miniBatchSize = max(2, maxBatchSize);
            
            % Utwórz 2D CNN
            inputSize = size(imagesData.X_train(:,:,:,1));  % [H, W, C]
            cnnStruct = createCNN(hyperparams, 5, inputSize);
            
            % Trenuj 2D CNN
            net = trainNetwork(imagesData.X_train, imagesData.Y_train, ...
                cnnStruct.layers, cnnStruct.options);
            
            % Ewaluuj
            predicted = classify(net, imagesData.X_val);
            score = sum(predicted == imagesData.Y_val) / length(imagesData.Y_val);
            
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