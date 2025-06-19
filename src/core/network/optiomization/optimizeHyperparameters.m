function [bestHyperparams, bestScore, allResults] = optimizeHyperparameters(trainData, valData, modelType, numTrials, imagesData, logFile)
% OPTIMIZEHYPERPARAMETERS Optymalizacja hiperparametrów metodą Random Search
%
% Funkcja implementuje Random Search dla znajdowania optymalnych hiperparametrów
% modeli klasyfikacji odcisków palców. Wykorzystuje strategię prób losowych
% z deterministycznym seedem, early stopping oraz zaawansowane logowanie.
% Zoptymalizowana specjalnie dla PatternNet z konserwatywnym podejściem.
%
% Parametry wejściowe:
%   trainData - dane treningowe do optymalizacji:
%              .features - macierz cech [samples × features]
%              .labels - wektor etykiet [samples × 1]
%   valData - dane walidacyjne do ewaluacji:
%            .features/.labels - analogiczne do trainData
%   modelType - typ modelu: 'patternnet' lub 'cnn'
%   numTrials - liczba prób Random Search (domyślnie 30)
%   imagesData - dane obrazowe dla CNN (opcjonalne dla PatternNet)
%   logFile - uchwyt pliku logów (opcjonalny)
%
% Parametry wyjściowe:
%   bestHyperparams - struktura z najlepszymi hiperparametrami
%   bestScore - najlepsza accuracy walidacyjna [0-1]
%   allResults - array struktur z wszystkimi wynikami (posortowane malejąco)
%
% Strategia Random Search:
%   1. Konserwatywne zakresy hiperparametrów (sprawdzone empirycznie)
%   2. Deterministyczny seed per trial dla reprodukowalności
%   3. Early stopping przy 90% accuracy (oszczędność czasu)
%   4. Ranking wszystkich prób według accuracy walidacyjnej
%   5. Szczegółowe logowanie każdej próby
%
% Zoptymalizowana konfiguracja PatternNet:
%   - Architektury: [5], [10], [15], [20] neuronów (tylko sprawdzone)
%   - Algorytm: trainscg (Scaled Conjugate Gradient)
%   - Funkcja kosztu: MSE (Mean Squared Error)
%   - Epoki: 15-25 (krótkie dla szybkości)
%   - Learning rate: 5e-4, 1e-3 (konserwatywne)
%   - Early stopping: 1-2 failures (agresywne zatrzymanie)
%
% Przykład użycia:
%   [bestParams, bestAcc, results] = optimizeHyperparameters(train, val, 'patternnet', 30);

% OBSŁUGA PARAMETRÓW OPCJONALNYCH
if nargin < 4, numTrials = 30; end
if nargin < 5, imagesData = []; end
if nargin < 6, logFile = []; end

fprintf('\n🔍 RANDOM SEARCH OPTIMIZATION for %s (%d trials)\n', upper(modelType), numTrials);
fprintf('========================================================\n');

% INICJALIZACJA LOGOWANIA
if ~isempty(logFile)
    logInfo(sprintf('Starting Random Search optimization for %s (%d trials)', upper(modelType), numTrials), logFile);
end

% INICJALIZACJA ZMIENNYCH WYNIKOWYCH
bestScore = 0;              % Najlepsza accuracy walidacyjna
bestHyperparams = [];       % Najlepsze hiperparametry
allResults = [];            % Historia wszystkich prób

% GŁÓWNA PĘTLA RANDOM SEARCH
for trial = 1:numTrials
    fprintf('  Trial %2d/%d: ', trial, numTrials);
    
    switch lower(modelType)
        case 'patternnet'
            % GENERATOR HIPERPARAMETRÓW PATTERNNET (zoptymalizowany)
            hyperparams = generatePatternNetHyperparams(trial);
            [score, trainTime] = evaluatePatternNet(hyperparams, trainData, valData);
            
        case 'cnn'
            % GENERATOR HIPERPARAMETRÓW CNN (oryginalny, bez zmian)
            hyperparams = generateCNNParams();
            [score, trainTime] = evaluateCNN(hyperparams, imagesData);
            
        otherwise
            error('Unsupported model type: %s. Supported: patternnet, cnn', modelType);
    end
    
    % ZAPISZ WYNIK AKTUALNEJ PRÓBY
    result = struct();
    result.hyperparams = hyperparams;
    result.score = score;
    result.trainTime = trainTime;
    result.trial = trial;
    allResults = [allResults; result];
    
    % SPRAWDŹ CZY TO NOWY NAJLEPSZY WYNIK
    if score > bestScore
        bestScore = score;
        bestHyperparams = hyperparams;
        fprintf('🎯 NEW BEST! Score: %.3f (%.1fs)\n', score, trainTime);
        
        % LOGOWANIE NOWEGO REKORDU
        if ~isempty(logFile)
            logInfo(sprintf('NEW BEST %s score: %.3f (trial %d/%d)', upper(modelType), score, trial, numTrials), logFile);
        end
        
        % EARLY STOPPING - przerwij optymalizację przy 90% accuracy
        if score >= 0.90
            fprintf('🛑 EARLY STOPPING! Achieved %.1f%% accuracy (target: 90%%)\n', score * 100);
            
            if ~isempty(logFile)
                logInfo(sprintf('EARLY STOPPING %s optimization at %.1f%% accuracy (trial %d/%d)', upper(modelType), score * 100, trial, numTrials), logFile);
            end
            
            break; % Wyjdź z pętli optymalizacji
        end
    else
        fprintf('Score: %.3f (%.1fs)\n', score, trainTime);
    end
end

% POST-PROCESSING WYNIKÓW
% Sortuj wszystkie wyniki według accuracy (malejąco)
[~, sortIdx] = sort([allResults.score], 'descend');
allResults = allResults(sortIdx);

% PODSUMOWANIE KOŃCOWE
fprintf('\n📊 OPTIMIZATION SUMMARY:\n');
fprintf('========================\n');
fprintf('Best validation accuracy: %.3f%% (%.1f%%)\n', bestScore, bestScore * 100);
fprintf('Total trials completed: %d/%d\n', length(allResults), numTrials);
fprintf('Improvement achieved: %.1f%% → %.1f%% (Δ=%.1f%%)\n', ...
    allResults(end).score * 100, bestScore * 100, (bestScore - allResults(end).score) * 100);

% KOŃCOWE LOGOWANIE
if ~isempty(logFile)
    logInfo(sprintf('%s optimization completed: Best score %.3f%% after %d trials', ...
        upper(modelType), bestScore * 100, length(allResults)), logFile);
end
end

%% GENERATOR HIPERPARAMETRÓW DLA PATTERNNET (ZOPTYMALIZOWANY)

function hyperparams = generatePatternNetHyperparams(trial)
% GENERATEPATTERNETHYPERPARAMS Ultra-konserwatywny generator dla PatternNet
%
% Generator zoptymalizowany na podstawie empirycznych wyników, zawężający
% przestrzeń poszukiwań do najlepiej działających konfiguracji.
% Priorytet: szybkość + stabilność + wysoka accuracy (95%+).

% ARCHITEKTURA: Tylko sprawdzone, małe sieci (unikanie overfitting)
validArchitectures = {[5], [10], [15], [20]};

% ALGORYTM TRENOWANIA: Tylko trainscg (najstabilniejszy dla małych sieci)
trainFunctions = {'trainscg'};

% FUNKCJA KOSZTU: Tylko MSE (najlepsza dla klasyfikacji wzorców)
performFunctions = {'mse'};

% LICZBA EPOK: Krótka (15-25) dla szybkości i unikania overfitting
epochsOptions = [15, 20, 25];

% LEARNING RATE: Konserwatywne wartości (stabilna zbieżność)
lrOptions = [5e-4, 1e-3];

% PRÓG ZATRZYMANIA: Wyższe wartości (wcześniejsze zatrzymanie)
goalOptions = [2e-3, 3e-3];

% MAX FAIL: Bardzo agresywne early stopping (1-2 niepowodzenia)
maxFailOptions = [1, 2];

% DETERMINISTYCZNY WYBÓR NA PODSTAWIE NUMERU PRÓBY
hyperparams = struct();

% Cykliczny wybór architektury
hyperparams.hiddenSizes = validArchitectures{mod(trial-1, length(validArchitectures)) + 1};

% Zawsze te same sprawdzone opcje
hyperparams.trainFcn = trainFunctions{1};    % Zawsze 'trainscg'
hyperparams.performFcn = performFunctions{1}; % Zawsze 'mse'

% LOSOWY WYBÓR POZOSTAŁYCH PARAMETRÓW (z deterministycznym seedem)
rng(trial * 123); % Unikalny seed per trial

hyperparams.epochs = epochsOptions(randi(length(epochsOptions)));
hyperparams.lr = lrOptions(randi(length(lrOptions)));
hyperparams.goal = goalOptions(randi(length(goalOptions)));
hyperparams.max_fail = maxFailOptions(randi(length(maxFailOptions)));

% PARAMETRY LEVENBERG-MARQUARDT (dla kompatybilności)
hyperparams.mu = 0.01;      % Wyższa wartość początkowa
hyperparams.mu_dec = 0.2;   % Bardziej agresywne zmniejszanie
hyperparams.mu_inc = 15;    % Szybsze zwiększanie przy niepowodzeniu

% DEBUG: Wyświetl konfigurację aktualnej próby
fprintf('[Arch=%s, Train=%s, E=%d, LR=%.1e, Goal=%.1e, MaxFail=%d] ', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, ...
    hyperparams.epochs, hyperparams.lr, hyperparams.goal, hyperparams.max_fail);
end

%% EWALUATOR PATTERNNET (ULEPSZONA WERSJA)

function [score, trainTime] = evaluatePatternNet(hyperparams, trainData, valData)
% EVALUATEPATTERNNET Deterministyczna ewaluacja PatternNet z diagnostyką
%
% Funkcja trenuje i testuje PatternNet z podanymi hiperparametrami,
% implementując szczegółową diagnostykę dla wykrywania problemów
% z klasyfikacją (np. single-class prediction).

tic;

try
    % DETERMINISTYCZNY SEED dla reprodukowalności wyników
    rng(42, 'twister');
    
    % ETAP 1: Tworzenie sieci PatternNet
    net = createPatternNet(hyperparams);
    
    % ETAP 2: Przygotowanie danych treningowych
    X_train = trainData.features';           % Transpozycja dla PatternNet [features × samples]
    T_train = full(ind2vec(trainData.labels', 5)); % One-hot encoding [classes × samples]
    
    % DIAGNOSTYKA: Sprawdź różnorodność klas treningowych
    uniqueTrainLabels = unique(trainData.labels);
    fprintf('Train classes: %s ', mat2str(uniqueTrainLabels));
    
    % ETAP 3: Trening sieci (z wyłączonymi ostrzeżeniami)
    warning('off', 'all');
    trainedNet = train(net, X_train, T_train);
    warning('on', 'all');
    
    % ETAP 4: Predykcja na danych walidacyjnych
    X_val = valData.features';
    Y_val = trainedNet(X_val);                % Wyjście sieci [classes × samples]
    [~, predicted] = max(Y_val, [], 1);       % Wybór klasy z max prawdopodobieństwem
    
    % DIAGNOSTYKA: Sprawdź różnorodność predykcji
    uniquePredicted = unique(predicted);
    fprintf('Predicted: %s ', mat2str(uniquePredicted));
    
    % ETAP 5: Obliczenie accuracy
    score = sum(predicted == valData.labels') / length(valData.labels);
    
    % DIAGNOSTYKA: Ostrzeżenie o single-class prediction
    if length(uniquePredicted) == 1
        fprintf('⚠️ SINGLE CLASS! ');
        % Single-class prediction często wskazuje na problemy z overfitting lub
        % zbyt wysokie learning rate / zbyt małą regularyzację
    end
    
    trainTime = toc;
    
catch ME
    % OBSŁUGA BŁĘDÓW TRENOWANIA
    fprintf('FAILED: %s ', ME.message);
    score = 0;      % Najgorszy możliwy wynik
    trainTime = toc;
end
end

%% GENERATOR I EWALUATOR CNN (BEZ ZMIAN - ORYGINALNY KOD)

function hyperparams = generateCNNParams()
% GENERATECNNPARAMS Generator hiperparametrów CNN (oryginalny kod)
%
% Pozostaje bez zmian - Random Search dla CNN z szerokim zakresem parametrów.

filterSizes = [3, 5, 7];

hyperparams = struct();
hyperparams.filterSize = filterSizes(randi(length(filterSizes)));
hyperparams.numFilters1 = randi([8, 32]);
hyperparams.numFilters2 = randi([16, 64]);
hyperparams.numFilters3 = randi([32, 128]);
hyperparams.dropoutRate = 0.2 + rand() * 0.3;  % 0.2-0.5
hyperparams.lr = 10^(-3.5 + rand() * 1);       % 10^-3.5 do 10^-2.5
hyperparams.l2reg = 10^(-6 + rand() * 3);      % 10^-6 do 10^-3
hyperparams.epochs = randi([5, 20]);

batchSizes = [4, 8, 16];
hyperparams.miniBatchSize = batchSizes(randi(length(batchSizes)));
end

function [score, trainTime] = evaluateCNN(hyperparams, imagesData)
% EVALUATECNN Ewaluator CNN (oryginalny kod)
%
% Pozostaje bez zmian - trening i ewaluacja CNN na danych obrazowych.

tic;

try
    if isempty(imagesData) || ~isfield(imagesData, 'X_train')
        error('Images data required for CNN evaluation');
    end
    
    inputSize = size(imagesData.X_train);
    if length(inputSize) >= 4
        inputSize = inputSize(1:3);  % [height, width, channels]
    else
        error('Invalid image data format for CNN');
    end
    
    % Utwórz i trenuj CNN
    cnnStruct = createCNN(hyperparams, 5, inputSize);
    trainedNet = trainNetwork(imagesData.X_train, imagesData.Y_train, ...
        cnnStruct.layers, cnnStruct.options);
    
    % Ewaluacja na zbiorze walidacyjnym
    predicted = classify(trainedNet, imagesData.X_val);
    score = sum(predicted == imagesData.Y_val) / length(imagesData.Y_val);
    
    trainTime = toc;
    
catch ME
    fprintf('FAILED: %s ', ME.message);
    score = 0;
    trainTime = toc;
end
end