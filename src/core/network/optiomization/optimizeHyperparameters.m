function [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials, imagesData)
% OPTIMIZEHYPERPARAMETERS Random Search optymalizacja hiperparametrów
%
% PROSTA WERSJA - TYLKO RANDOM SEARCH

if nargin < 4
    numTrials = 50;
end

if nargin < 5
    imagesData = [];
end

fprintf('\n🔍 Starting Random Search optimization for %s...\n', upper(modelType));
fprintf('Number of trials: %d\n', numTrials);

% EARLY STOPPING PARAMETERS
earlyStopThreshold = 0.95;

% Zakresy hiperparametrów
ranges = getHyperparameterRanges(modelType);

% RANDOM SEARCH
fprintf('\n🎲 Random Search (%d trials)\n', numTrials);

bestScore = 0;
bestHyperparams = [];
allResults = [];

for trial = 1:numTrials
    fprintf('  Trial %d/%d: ', trial, numTrials);
    
    % Losuj hiperparametry
    hyperparams = sampleRandomHyperparams(ranges, modelType);
    
    % DODAJ DEBUG INFO
    if strcmp(modelType, 'patternnet')
        fprintf('[%s, %s, lr=%.1e, epochs=%d] ', ...
            mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, ...
            hyperparams.lr, hyperparams.epochs);
    end
    
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
        
        % EARLY STOPPING
        if score >= earlyStopThreshold
            fprintf('🛑 EARLY STOPPING! Achieved %.1f%% accuracy\n', score * 100);
            
            % Sortuj wyniki
            [~, sortIdx] = sort([allResults.score], 'descend');
            allResults = allResults(sortIdx);
            return;
        end
    else
        fprintf('Score: %.3f (%.1fs)\n', score, trainTime);
    end
end

% Sortuj wszystkie wyniki
[~, sortIdx] = sort([allResults.score], 'descend');
allResults = allResults(sortIdx);

% Podsumowanie
fprintf('\n📊 Random Search completed!\n');
fprintf('Best validation accuracy: %.3f%%\n', bestScore * 100);
fprintf('Total evaluations: %d\n', length(allResults));

% Pokaż top 5
fprintf('\n🏆 Top 5 configurations:\n');
for i = 1:min(5, length(allResults))
    result = allResults(i);
    fprintf('  %d. Score: %.3f%% (%.1fs)\n', ...
        i, result.score*100, result.trainTime);
end
end

%% FUNKCJE POMOCNICZE

function ranges = getHyperparameterRanges(modelType)
% GETHYPERPARAMETERRANGES Zwraca zakresy hiperparametrów dla danego modelu

switch lower(modelType)
    case 'patternnet'
        ranges = struct();
        
        % ZNACZNIE MNIEJSZE SIECI - przeciw overfittingowi
        ranges.hiddenSizes = {
            [5], [8], [10], [12]  % USUŃ duże sieci [15], [20], [25], [30]
            };
        
        % Training functions
        ranges.trainFcn = {'trainlm', 'trainbr', 'traingd'};
        
        % Performance functions
        ranges.performFcn = {'mse'}; % Tylko MSE dla stabilności
        
        % KRÓTSZE TRENOWANIE
        ranges.epochs = [20, 200]; % Zmniejszone z [20, 200]
        
        % WYŻSZY GOAL - zatrzymaj wcześniej
        ranges.goal = [1e-4, 1e-2]; % Wyższy z [1e-8, 1e-2]
        
        % MNIEJSZY max_fail - wcześniejsze zatrzymanie
        ranges.max_fail = [1, 3]; % Zmniejszone z [1, 8]
        
        % WĘŻSZNY zakres LR
        ranges.lr = [1e-4, 1e-2]; % Zmniejszone z [1e-6, 1e-1]
        
        % Szersze zakresy LM parameters
        ranges.mu = [0.0001, 0.1];
        ranges.mu_dec = [0.1, 0.9];
        ranges.mu_inc = [5, 100];
        
    case 'cnn'
        ranges = struct();
        
        % Filter sizes
        ranges.filterSize = [3, 5, 7];  % Discrete values
        
        % Number of filters per layer
        ranges.numFilters1 = [8, 32];
        ranges.numFilters2 = [16, 64];
        ranges.numFilters3 = [32, 128];
        
        % Dropout rate
        ranges.dropoutRate = [0.1, 0.5];
        
        % Learning rate
        ranges.lr = [0.0005, 0.02];  % Log scale
        
        % L2 regularization
        ranges.l2reg = [1e-6, 1e-2];  % Log scale
        
        % Epochs
        ranges.epochs = [5, 40];
        
        % Mini batch size
        ranges.miniBatchSize = [4, 8, 16];  % Discrete values
        
    otherwise
        error('Unknown model type: %s', modelType);
end
end

function hyperparams = sampleRandomHyperparams(ranges, modelType)
% SAMPLERANDOMHYPERPARAMS Losuje hiperparametry z zadanych zakresów

hyperparams = struct();

switch lower(modelType)
    case 'patternnet'
        % DODAJ SEED randomization na początku każdego sampling
        rng('shuffle'); % Nowy seed za każdym razem
        
        % Hidden sizes - WIĘKSZA LOSOWOŚĆ
        hyperparams.hiddenSizes = ranges.hiddenSizes{randi(length(ranges.hiddenSizes))};
        
        % ZAWSZE inne training functions
        hyperparams.trainFcn = ranges.trainFcn{randi(length(ranges.trainFcn))};
        
        % ZAWSZE MSE
        hyperparams.performFcn = 'mse';
        
        % Learning rate (log scale) - WIĘKSZY ZAKRES
        logLr = log10(ranges.lr(1)) + (log10(ranges.lr(2)) - log10(ranges.lr(1))) * rand();
        hyperparams.lr = 10^logLr;
        
        % Epochs - DODAJ WIĘCEJ RANDOMIZACJI
        hyperparams.epochs = randi([ranges.epochs(1), ranges.epochs(2)]);
        
        % Goal (log scale) - SZERSZY ZAKRES
        logGoal = log10(ranges.goal(1)) + (log10(ranges.goal(2)) - log10(ranges.goal(1))) * rand();
        hyperparams.goal = 10^logGoal;
        
        % Max fail - WIĘCEJ OPCJI
        hyperparams.max_fail = randi([ranges.max_fail(1), ranges.max_fail(2)]);
        
        % LM parameters - DODAJ WIĘCEJ LOSOWOŚCI
        hyperparams.mu = ranges.mu(1) + (ranges.mu(2) - ranges.mu(1)) * rand();
        hyperparams.mu_dec = ranges.mu_dec(1) + (ranges.mu_dec(2) - ranges.mu_dec(1)) * rand();
        hyperparams.mu_inc = ranges.mu_inc(1) + (ranges.mu_inc(2) - ranges.mu_inc(1)) * rand();
        
    case 'cnn'
        % Filter size - wybierz losowo z dyskretnych wartości
        hyperparams.filterSize = ranges.filterSize(randi(length(ranges.filterSize)));
        
        % Number of filters (linear scale)
        hyperparams.numFilters1 = randi([ranges.numFilters1(1), ranges.numFilters1(2)]);
        hyperparams.numFilters2 = randi([ranges.numFilters2(1), ranges.numFilters2(2)]);
        hyperparams.numFilters3 = randi([ranges.numFilters3(1), ranges.numFilters3(2)]);
        
        % Dropout rate
        hyperparams.dropoutRate = ranges.dropoutRate(1) + (ranges.dropoutRate(2) - ranges.dropoutRate(1)) * rand();
        
        % Learning rate (log scale)
        logLr = log10(ranges.lr(1)) + (log10(ranges.lr(2)) - log10(ranges.lr(1))) * rand();
        hyperparams.lr = 10^logLr;
        
        % L2 regularization (log scale)
        logL2 = log10(ranges.l2reg(1)) + (log10(ranges.l2reg(2)) - log10(ranges.l2reg(1))) * rand();
        hyperparams.l2reg = 10^logL2;
        
        % Epochs
        hyperparams.epochs = randi([ranges.epochs(1), ranges.epochs(2)]);
        
        % Mini batch size - wybierz losowo z dyskretnych wartości
        hyperparams.miniBatchSize = ranges.miniBatchSize(randi(length(ranges.miniBatchSize)));
        
    otherwise
        error('Unknown model type: %s', modelType);
end
end

function [score, trainTime] = evaluateHyperparams(hyperparams, trainData, valData, modelType, imagesData)
% EVALUATEHYPERPARAMS Ewaluuje hiperparametry przez trenowanie i testowanie modelu

tic;

try
    switch lower(modelType)
        case 'patternnet'
            % Trenuj PatternNet
            net = createPatternNet(hyperparams);
            
            % Przygotuj dane
            X_train = trainData.features';
            T_train = full(ind2vec(trainData.labels', 5));  % 5 klas
            
            X_val = valData.features';
            
            % Ustaw podział danych dla sieci
            net.divideParam.trainInd = 1:size(X_train, 2);
            net.divideParam.valInd = [];
            net.divideParam.testInd = [];
            
            % Trenuj
            trainedNet = train(net, X_train, T_train);
            
            % Testuj na validation set
            Y_val = trainedNet(X_val);
            [~, predicted] = max(Y_val, [], 1);
            
            score = sum(predicted == valData.labels') / length(valData.labels);
            
        case 'cnn'
            if isempty(imagesData) || ~isfield(imagesData, 'X_train')
                error('Images data required for CNN');
            end
            
            % CNN training
            inputSize = size(imagesData.X_train);
            if length(inputSize) >= 4
                inputSize = inputSize(1:3);  % [height, width, channels]
            else
                error('Invalid image data format for CNN');
            end
            
            cnnStruct = createCNN(hyperparams, 5, inputSize);
            
            % Trenuj CNN
            trainedNet = trainNetwork(imagesData.X_train, imagesData.Y_train, ...
                cnnStruct.layers, cnnStruct.options);
            
            % Testuj na validation set
            predicted = classify(trainedNet, imagesData.X_val);
            score = sum(predicted == imagesData.Y_val) / length(imagesData.Y_val);
            
        otherwise
            error('Unknown model type: %s', modelType);
    end
    
    trainTime = toc;
    
    % Dodaj penalty za bardzo długie trenowanie
    if trainTime > 30  % Więcej niż 30 sekund
        score = score * 0.9;  % 10% penalty
    end
    
catch ME
    fprintf('   ⚠️  Evaluation failed: %s\n', ME.message);
    score = 0;
    trainTime = toc;
end
end