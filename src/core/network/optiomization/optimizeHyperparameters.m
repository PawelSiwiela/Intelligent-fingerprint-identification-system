function [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials, imagesData)
% OPTIMIZEHYPERPARAMETERS Random Search - PRZEPISANY TYLKO DLA PATTERNNET

if nargin < 4, numTrials = 30; end
if nargin < 5, imagesData = []; end

fprintf('\n🔍 Random Search for %s (%d trials)...\n', upper(modelType), numTrials);

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
        
        % Early stopping przy 90%
        if score >= 0.90
            fprintf('🛑 EARLY STOPPING! Achieved %.1f%% accuracy\n', score * 100);
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
end

%% NOWY PROSTY GENERATOR DLA PATTERNNET

function hyperparams = generatePatternNetHyperparams(trial)
% GENERATEPATTERNETHYPERPARAMS Proste i różnorodne parametry

% RÓŻNE ARCHITEKTURY - każdy trial ma inną
architectures = {
    [5], [8], [10], [12], [15], [20]};

% RÓŻNE FUNKCJE TRENOWANIA
trainFunctions = {'trainlm','traingd', 'trainscg'};

% RÓŻNE PERFORMANCE FUNCTIONS
performFunctions = {'mse'};

% Użyj trial number dla systematycznej różnorodności
archIdx = mod(trial-1, length(architectures)) + 1;
trainIdx = mod(trial-1, length(trainFunctions)) + 1;
perfIdx = mod(trial-1, length(performFunctions)) + 1;

hyperparams = struct();
hyperparams.hiddenSizes = architectures{archIdx};
hyperparams.trainFcn = trainFunctions{trainIdx};
hyperparams.performFcn = performFunctions{perfIdx};

% Randomizuj pozostałe parametry z seed bazującym na trial
rng(trial * 123); % Deterministyczny seed per trial

hyperparams.epochs = 10 + randi(40);           % 10-50 epochs
hyperparams.lr = 10^(-4 + rand() * 2);        % 10^(-4) do 10^(-2)
hyperparams.goal = 10^(-5 + rand() * 2);      % 10^(-5) do 10^(-3)
hyperparams.max_fail = 1 + randi(4);          % 1-5

% LM parametry
hyperparams.mu = 0.001 + rand() * 0.02;       % 0.001-0.021
hyperparams.mu_dec = 0.3 + rand() * 0.5;      % 0.3-0.8
hyperparams.mu_inc = 5 + rand() * 15;         % 5-20

fprintf('[Arch=%s, Train=%s, Perf=%s, E=%d, LR=%.1e] ', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn(1:4), ...
    hyperparams.performFcn(1:3), hyperparams.epochs, hyperparams.lr);
end

%% UPROSZCZONA EWALUACJA PATTERNNET

function [score, trainTime] = evaluatePatternNet(hyperparams, trainData, valData)
% EVALUATEPATTERNNET Prosta ewaluacja bez skomplikowanych podziałów

tic;

try
    % 1. Utwórz sieć
    net = createPatternNet(hyperparams);
    
    % 2. Przygotuj dane treningowe
    X_train = trainData.features';
    T_train = full(ind2vec(trainData.labels', 5));
    
    % 3. PROSTY PODZIAŁ - trenuj na train, waliduj wewnętrznie
    net.divideParam.trainRatio = 0.8;   % 80% danych train do treningu
    net.divideParam.valRatio = 0.2;     % 20% danych train do walidacji
    net.divideParam.testRatio = 0;      % 0% - nie używamy wewnętrznego testu
    
    % 4. Trenuj sieć
    trainedNet = train(net, X_train, T_train);
    
    % 5. Testuj na ZEWNĘTRZNYCH danych walidacyjnych
    X_val = valData.features';
    Y_val = trainedNet(X_val);
    [~, predicted] = max(Y_val, [], 1);
    
    % 6. Oblicz accuracy
    score = sum(predicted == valData.labels') / length(valData.labels);
    
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