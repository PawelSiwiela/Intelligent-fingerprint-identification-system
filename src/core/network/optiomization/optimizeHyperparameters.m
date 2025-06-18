function [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials, imagesData, logFile)
% OPTIMIZEHYPERPARAMETERS Random Search - PRZEPISANY TYLKO DLA PATTERNNET

if nargin < 4, numTrials = 30; end
if nargin < 5, imagesData = []; end
if nargin < 6, logFile = []; end

fprintf('\n🔍 Random Search for %s (%d trials)...\n', upper(modelType), numTrials);

% LOGOWANIE
if ~isempty(logFile)
    logInfo(sprintf('Starting Random Search for %s (%d trials)', upper(modelType), numTrials), logFile);
end

bestScore = 0;
bestHyperparams = [];
allResults = [];

for trial = 1:numTrials
    fprintf('  Trial %d/%d: ', trial, numTrials);
    
    switch lower(modelType)
        case 'patternnet'
            % NOWY PROSTY GENERATOR dla PatternNet
            hyperparams = generatePatternNetHyperparams(trial);
            [score, trainTime] = evaluatePatternNet(hyperparams, trainData, valData);
            
        case 'cnn'
            % CNN NIE ZMIENIAMY - zostaje jak było
            hyperparams = generateCNNParams();
            [score, trainTime] = evaluateCNN(hyperparams, imagesData);
            
        otherwise
            error('Unknown model type: %s', modelType);
    end
    
    % Zapisz wynik
    result = struct();
    result.hyperparams = hyperparams;
    result.score = score;
    result.trainTime = trainTime;
    allResults = [allResults; result];
    
    % Sprawdź czy najlepszy
    if score > bestScore
        bestScore = score;
        bestHyperparams = hyperparams;
        fprintf('🎯 NEW BEST! Score: %.3f (%.1fs)\n', score, trainTime);
        
        % LOGOWANIE NAJLEPSZEGO WYNIKU
        if ~isempty(logFile)
            logInfo(sprintf('NEW BEST %s score: %.3f (trial %d)', upper(modelType), score, trial), logFile);
        end
        
        % Early stopping przy 95% - ZMIANA Z 90% na 95%
        if score >= 0.90
            fprintf('🛑 EARLY STOPPING! Achieved %.1f%% accuracy\n', score * 100);
            
            % LOGOWANIE EARLY STOPPING
            if ~isempty(logFile)
                logInfo(sprintf('EARLY STOPPING %s optimization at %.1f%% accuracy (trial %d)', upper(modelType), score * 100, trial), logFile);
            end
            
            break;
        end
    else
        fprintf('Score: %.3f (%.1fs)\n', score, trainTime);
    end
end

% Sortuj wyniki
[~, sortIdx] = sort([allResults.score], 'descend');
allResults = allResults(sortIdx);

fprintf('\n📊 Best validation accuracy: %.3f%%\n', bestScore * 100);

% LOGOWANIE KOŃCOWEGO WYNIKU
if ~isempty(logFile)
    logInfo(sprintf('%s optimization completed: Best score %.3f%% after %d trials', upper(modelType), bestScore * 100, length(allResults)), logFile);
end
end

%% NOWY PROSTY GENERATOR DLA PATTERNNET

function hyperparams = generatePatternNetHyperparams(trial)
% ULTRA KONSERWATYWNE PARAMETRY dla 95%+

% TYLKO NAJLEPSZE ARCHITEKTURY
architectures = {[5], [10], [15], [20]}; % TYLKO te które działają dobrze

% TYLKO trainscg
trainFunctions = {'trainscg'};

% MSE tylko
performFunctions = {'mse'};

% KRÓTSZA LICZBA EPOK
epochsOptions = [15, 20, 25]; % ZMNIEJSZ maksimum

% BARDZO KONSERWATYWNE LR
lrOptions = [5e-4, 1e-3]; % TYLKO sprawdzone wartości

% WYSOKIE GOALS
goalOptions = [2e-3, 3e-3]; % WYŻSZE progi zatrzymania

% BARDZO WCZESNY STOP
maxFailOptions = [1, 2]; % TYLKO 1-2 fails

% Użyj trial number do cyklicznego wyboru z list
hyperparams = struct();
hyperparams.hiddenSizes = architectures{mod(trial-1, length(architectures)) + 1};
hyperparams.trainFcn = trainFunctions{1}; % Zawsze trainscg
hyperparams.performFcn = performFunctions{1}; % Zawsze mse

% Deterministyczny seed per trial
rng(trial * 123);

hyperparams.epochs = epochsOptions(randi(length(epochsOptions)));
hyperparams.lr = lrOptions(randi(length(lrOptions)));
hyperparams.goal = goalOptions(randi(length(goalOptions)));
hyperparams.max_fail = maxFailOptions(randi(length(maxFailOptions)));

% LM parametry
hyperparams.mu = 0.01; % Wyższe niż poprzednio
hyperparams.mu_dec = 0.2; % Bardziej agresywne
hyperparams.mu_inc = 15;

fprintf('[Arch=%s, Train=%s, E=%d, LR=%.1e, Goal=%.1e, MaxFail=%d] ', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, ...
    hyperparams.epochs, hyperparams.lr, hyperparams.goal, hyperparams.max_fail);
end

%% UPROSZCZONA EWALUACJA PATTERNNET

function [score, trainTime] = evaluatePatternNet(hyperparams, trainData, valData)
% EVALUATEPATTERNNET - NAPRAWIONA WERSJA BEZ BŁĘDNYCH PARAMETRÓW

tic;

try
    % DETERMINISTYCZNY seed
    rng(42, 'twister');
    
    % 1. Utwórz sieć (już z poprawnym podziałem)
    net = createPatternNet(hyperparams);
    
    % 2. Przygotuj dane treningowe
    X_train = trainData.features';
    T_train = full(ind2vec(trainData.labels', 5));
    
    % DEBUG: Sprawdź dane
    uniqueTrainLabels = unique(trainData.labels);
    fprintf('Train classes: %s ', mat2str(uniqueTrainLabels));
    
    % 4. Trenuj
    warning('off', 'all');
    trainedNet = train(net, X_train, T_train);
    warning('on', 'all');
    
    % 5. Testuj na valData
    X_val = valData.features';
    Y_val = trainedNet(X_val);
    [~, predicted] = max(Y_val, [], 1);
    
    % DEBUG
    uniquePredicted = unique(predicted);
    fprintf('Predicted: %s ', mat2str(uniquePredicted));
    
    % 6. Accuracy
    score = sum(predicted == valData.labels') / length(valData.labels);
    
    % DEBUG ostrzeżenie
    if length(uniquePredicted) == 1
        fprintf('⚠️ SINGLE CLASS! ');
    end
    
    trainTime = toc;
    
catch ME
    fprintf('FAILED: %s ', ME.message);
    score = 0;
    trainTime = toc;
end
end

%% CNN FUNCTIONS - NIE ZMIENIAMY!

function hyperparams = generateCNNParams()
% GENERATECNNPARAMS - NIE ZMIENIAMY (CNN bez zmian)

filterSizes = [3, 5, 7];

hyperparams = struct();
hyperparams.filterSize = filterSizes(randi(length(filterSizes)));
hyperparams.numFilters1 = randi([8, 32]);
hyperparams.numFilters2 = randi([16, 64]);
hyperparams.numFilters3 = randi([32, 128]);
hyperparams.dropoutRate = 0.2 + rand() * 0.3;
hyperparams.lr = 10^(-3.5 + rand() * 1);
hyperparams.l2reg = 10^(-6 + rand() * 3);
hyperparams.epochs = randi([5, 20]);

batchSizes = [4, 8, 16];
hyperparams.miniBatchSize = batchSizes(randi(length(batchSizes)));
end

function [score, trainTime] = evaluateCNN(hyperparams, imagesData)
% EVALUATECNN - NIE ZMIENIAMY (CNN bez zmian)

tic;

try
    if isempty(imagesData) || ~isfield(imagesData, 'X_train')
        error('Images data required for CNN');
    end
    
    inputSize = size(imagesData.X_train);
    if length(inputSize) >= 4
        inputSize = inputSize(1:3);
    else
        error('Invalid image data format for CNN');
    end
    
    cnnStruct = createCNN(hyperparams, 5, inputSize);
    
    trainedNet = trainNetwork(imagesData.X_train, imagesData.Y_train, ...
        cnnStruct.layers, cnnStruct.options);
    
    predicted = classify(trainedNet, imagesData.X_val);
    score = sum(predicted == imagesData.Y_val) / length(imagesData.Y_val);
    
    trainTime = toc;
    
catch ME
    fprintf('FAILED: %s ', ME.message);
    score = 0;
    trainTime = toc;
end
end