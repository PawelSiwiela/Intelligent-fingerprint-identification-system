function [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials, imagesData)
% OPTIMIZEHYPERPARAMETERS Random Search optymalizacja hiperparametrów
% UPROSZCZONA WERSJA

if nargin < 4
    numTrials = 30; % Zmniejszone z 50
end

if nargin < 5
    imagesData = [];
end

fprintf('\n🔍 Random Search for %s (%d trials)...\n', upper(modelType), numTrials);

bestScore = 0;
bestHyperparams = [];
allResults = [];

for trial = 1:numTrials
    fprintf('  Trial %d/%d: ', trial, numTrials);
    
    % Losuj hiperparametry
    hyperparams = generateRandomHyperparams(modelType);
    
    % Ewaluuj
    [score, trainTime] = evaluateHyperparams(hyperparams, trainData, valData, modelType, imagesData);
    
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
        
        % Early stopping przy 95%
        if score >= 0.95
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

%% UPROSZCZONE GENEROWANIE HIPERPARAMETRÓW

function hyperparams = generateRandomHyperparams(modelType)
% GENERATERANDOMHYPERPARAMS Proste losowanie hiperparametrów

switch lower(modelType)
    case 'patternnet'
        hyperparams = generatePatternNetParams();
    case 'cnn'
        hyperparams = generateCNNParams();
    otherwise
        error('Unknown model type: %s', modelType);
end
end

function hyperparams = generatePatternNetParams()
% GENERATEPATTERNNETPARAMS - POPRAWIONA RANDOMIZACJA I SZERSZE ZAKRESY

% USUŃ rng('shuffle') - to powoduje problemy z powtarzalnością
% Zamiast tego użyj większej różnorodości parametrów

% ZNACZNIE WIĘCEJ OPCJI hidden layers
hiddenOptions = {[3], [4], [5], [6], [7], [8], [10], [12]}; % 8 opcji zamiast 2

hyperparams = struct();
hyperparams.hiddenSizes = hiddenOptions{randi(length(hiddenOptions))};
hyperparams.trainFcn = 'trainlm'; % Tylko Levenberg-Marquardt
hyperparams.performFcn = 'mse';   % Tylko MSE

% SZERSZY ZAKRES EPOCHS
hyperparams.epochs = randi([5, 25]); % ZWIĘKSZONE z [5, 15] na [5, 25]

% SZERSZY ZAKRES learning rate
hyperparams.lr = 10^(-4 + rand() * 2); % ZWIĘKSZONE z (-2.5 + rand() * 0.5) na (-4 + rand() * 2)
% Teraz: 10^(-4) do 10^(-2) zamiast 10^(-2.5) do 10^(-2)

% SZERSZY ZAKRES GOAL
hyperparams.goal = 10^(-5 + rand() * 2); % ZWIĘKSZONE z (-3 + rand() * 0.5) na (-5 + rand() * 2)
% Teraz: 10^(-5) do 10^(-3) zamiast 10^(-3) do 10^(-2.5)

% WIĘCEJ OPCJI max_fail
hyperparams.max_fail = randi([1, 4]); % ZWIĘKSZONE z [1, 2] na [1, 4]

% LM parametry - SZERSZE ZAKRESY
hyperparams.mu = 0.001 + rand() * 0.019;     % SZERSZE: 0.001-0.02 zamiast 0.01-0.02
hyperparams.mu_dec = 0.5 + rand() * 0.3;     % SZERSZE: 0.5-0.8 zamiast 0.7-0.8
hyperparams.mu_inc = 2 + rand() * 18;        % SZERSZE: 2-20 zamiast 2-5

% DODAJ WIĘCEJ RANDOMIZACJI - różne kombinacje train functions
trainFunctions = {'trainlm', 'trainbr', 'traingd', 'trainscg'};
hyperparams.trainFcn = trainFunctions{randi(length(trainFunctions))};

% DODAJ WIĘCEJ RANDOMIZACJI - różne performance functions
performFunctions = {'mse', 'crossentropy'};
hyperparams.performFcn = performFunctions{randi(length(performFunctions))};

% DEBUG: Pokaż wygenerowane parametry
fprintf('[Gen: Hidden=%s, Fn=%s, Perf=%s, Epochs=%d, LR=%.2e, Goal=%.2e, MaxFail=%d] ', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, hyperparams.performFcn, ...
    hyperparams.epochs, hyperparams.lr, hyperparams.goal, hyperparams.max_fail);
end

function hyperparams = generateCNNParams()
% GENERATECNNPARAMS Losowe parametry dla CNN

filterSizes = [3, 5, 7];

hyperparams = struct();
hyperparams.filterSize = filterSizes(randi(length(filterSizes)));
hyperparams.numFilters1 = randi([8, 32]);
hyperparams.numFilters2 = randi([16, 64]);
hyperparams.numFilters3 = randi([32, 128]);
hyperparams.dropoutRate = 0.2 + rand() * 0.3;    % 0.2 do 0.5
hyperparams.lr = 10^(-3.5 + rand() * 1);         % 10^(-3.5) do 10^(-2.5)
hyperparams.l2reg = 10^(-6 + rand() * 3);        % 10^(-6) do 10^(-3)
hyperparams.epochs = randi([5, 20]);

batchSizes = [4, 8, 16];
hyperparams.miniBatchSize = batchSizes(randi(length(batchSizes)));
end

%% UPROSZCZONA EWALUACJA

function [score, trainTime] = evaluateHyperparams(hyperparams, trainData, valData, modelType, imagesData)
% EVALUATEHYPERPARAMS Prosta ewaluacja modelu

tic;

try
    switch lower(modelType)
        case 'patternnet'
            score = evaluatePatternNet(hyperparams, trainData, valData);
        case 'cnn'
            score = evaluateCNN(hyperparams, imagesData);
        otherwise
            error('Unknown model type: %s', modelType);
    end
    
    trainTime = toc;
    
    % Penalty za długie trenowanie
    if trainTime > 30
        score = score * 0.9;
    end
    
catch ME
    fprintf('   ⚠️  Failed: %s\n', ME.message);
    score = 0;
    trainTime = toc;
end
end

function score = evaluatePatternNet(hyperparams, trainData, valData)
% EVALUATEPATTERNNET - Z PRAWDZIWĄ WALIDACJĄ

% Utwórz sieć
net = createPatternNet(hyperparams);

% POPRAWKA: Użyj ratio zamiast indices (zgodnie z wcześniejszą poprawką)
X_train_full = trainData.features';
T_train_full = full(ind2vec(trainData.labels', 5));

% POPRAWKA: Użyj RATIO zamiast INDICES
net.divideParam.trainRatio = 0.7;   % 70% dla treningu
net.divideParam.valRatio = 0.3;     % 30% dla walidacji wewnętrznej
net.divideParam.testRatio = 0;      % 0% dla testu

% DODAJ: Wczesne zatrzymywanie na walidacji
net.trainParam.max_fail = 1; % Zatrzymaj po 1 epoce bez poprawy

% Trenuj z wewnętrzną walidacją
trainedNet = train(net, X_train_full, T_train_full);

% Testuj na ZEWNĘTRZNYM validation set
X_val = valData.features';
Y_val = trainedNet(X_val);
[~, predicted] = max(Y_val, [], 1);

score = sum(predicted == valData.labels') / length(valData.labels);

% DEBUG INFO
fprintf(' [Hidden=%s, Epochs=%d, LR=%.1e, Goal=%.1e] ', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.epochs, hyperparams.lr, hyperparams.goal);
end

function score = evaluateCNN(hyperparams, imagesData)
% EVALUATECNN Trenuj i testuj CNN

if isempty(imagesData) || ~isfield(imagesData, 'X_train')
    error('Images data required for CNN');
end

% Sprawdź format danych
inputSize = size(imagesData.X_train);
if length(inputSize) >= 4
    inputSize = inputSize(1:3);
else
    error('Invalid image data format for CNN');
end

% Utwórz CNN
cnnStruct = createCNN(hyperparams, 5, inputSize);

% Trenuj
trainedNet = trainNetwork(imagesData.X_train, imagesData.Y_train, ...
    cnnStruct.layers, cnnStruct.options);

% Testuj
predicted = classify(trainedNet, imagesData.X_val);
score = sum(predicted == imagesData.Y_val) / length(imagesData.Y_val);
end