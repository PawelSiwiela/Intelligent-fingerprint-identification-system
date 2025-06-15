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
% GENERATEPATTERNETHYPERPARAMS - ZOPTYMALIZOWANY DLA 86.7% SUCCESS

% NAJLEPSZE ARCHITEKTURY (w kolejności skuteczności)
architectures = {[3], [4], [5], [6], [7]};

% TYLKO TRAINSCG!
trainFunctions = {'trainscg'}; % 100% najlepszych wyników

% MSE tylko
performFunctions = {'mse'};

% OPTYMALNE EPOCHS - 20-25 sweet spot
epochsOptions = [20, 25]; % TYLKO sprawdzone wartości

% ZOPTYMALIZOWANE LR - wszystkie skuteczne wartości
lrOptions = [5e-4, 1e-3, 2e-3, 5e-3, 1e-2];

% MAGICZNY GOAL!
goalOptions = [1e-3, 2e-3]; % TYLKO wartość która daje 86.7

% MAX_FAIL - różny w najlepszych wynikach
maxFailOptions = [1, 2, 3];

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

% LM parametry (nie używane przez trainscg, ale dla kompletności)
hyperparams.mu = 0.005;
hyperparams.mu_dec = 0.3;
hyperparams.mu_inc = 10;

fprintf('[Arch=%s, Train=%s, E=%d, LR=%.1e, Goal=%.1e, MaxFail=%d] ', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, ...
    hyperparams.epochs, hyperparams.lr, hyperparams.goal, hyperparams.max_fail);
end

%% UPROSZCZONA EWALUACJA PATTERNNET

function [score, trainTime] = evaluatePatternNet(hyperparams, trainData, valData)
% EVALUATEPATTERNNET - UŻYWA GOTOWYCH PODZIAŁÓW

tic;

try
    % 1. Utwórz sieć
    net = createPatternNet(hyperparams);
    
    % 2. Przygotuj dane treningowe - UŻYJ TYLKO trainData
    X_train = trainData.features';
    T_train = full(ind2vec(trainData.labels', 5));
    
    % 3. WYŁĄCZ AUTOMATYCZNY PODZIAŁ - używamy zewnętrznych zbiorów
    net.divideParam.trainRatio = 1.0;   % Wszystkie dane X_train do treningu
    net.divideParam.valRatio = 0.0;     % Brak wewnętrznej walidacji
    net.divideParam.testRatio = 0.0;    % Brak wewnętrznego testu
    
    % 4. Trenuj TYLKO na trainData
    trainedNet = train(net, X_train, T_train);
    
    % 5. Testuj na ZEWNĘTRZNYM valData
    X_val = valData.features';
    Y_val = trainedNet(X_val);
    [~, predicted] = max(Y_val, [], 1);
    
    % 6. Oblicz accuracy na validation set
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