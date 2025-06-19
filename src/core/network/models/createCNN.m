function cnnStruct = createCNN(hyperparams, numClasses, inputSize)
% CREATECNN Tworzy 2D CNN do klasyfikacji szkieletyzowanych odcisków palców
%
% Funkcja konstruuje architekturę konwolucyjnej sieci neuronowej (CNN)
% zoptymalizowanej do rozpoznawania obrazów odcisków palców po szkieletyzacji.
% Implementuje 3-blokową architekturę Conv-BatchNorm-ReLU-Pool z warstwami
% fully-connected i zaawansowanymi technikami regularyzacji.
%
% Parametry wejściowe:
%   hyperparams - struktura z hiperparametrami sieci:
%                .filterSize - rozmiar filtrów konwolucyjnych (domyślnie 5)
%                .numFilters1/2/3 - liczba filtrów w blokach 1/2/3 (16/32/64)
%                .dropoutRate - współczynnik dropout (domyślnie 0.3)
%                .lr - learning rate (domyślnie 0.001)
%                .l2reg - regularyzacja L2 (domyślnie 1e-4)
%                .epochs - liczba epok (domyślnie 50)
%                .miniBatchSize - rozmiar mini-batcha (domyślnie 8)
%   numClasses - liczba klas do klasyfikacji (typowo 5 palców)
%   inputSize - rozmiar obrazu wejściowego [height, width, channels], np. [128, 128, 1]
%
% Parametry wyjściowe:
%   cnnStruct - struktura zawierająca:
%              .layers - warstwy sieci neuronowej
%              .options - opcje trenowania
%
% Architektura sieci:
%   Input → [Conv-BN-ReLU-Pool] × 3 → Dropout → FC(128) → ReLU →
%   → Dropout → FC(64) → ReLU → FC(numClasses) → Softmax → Output
%
% Przykład użycia:
%   cnn = createCNN(hyperparams, 5, [128, 128, 1]);

% Walidacja i uzupełnienie hiperparametrów wartościami domyślnymi
if ~isfield(hyperparams, 'filterSize'), hyperparams.filterSize = 5; end
if ~isfield(hyperparams, 'numFilters1'), hyperparams.numFilters1 = 16; end
if ~isfield(hyperparams, 'numFilters2'), hyperparams.numFilters2 = 32; end
if ~isfield(hyperparams, 'numFilters3'), hyperparams.numFilters3 = 64; end
if ~isfield(hyperparams, 'dropoutRate'), hyperparams.dropoutRate = 0.3; end
if ~isfield(hyperparams, 'lr'), hyperparams.lr = 0.001; end
if ~isfield(hyperparams, 'l2reg'), hyperparams.l2reg = 1e-4; end
if ~isfield(hyperparams, 'epochs'), hyperparams.epochs = 50; end
if ~isfield(hyperparams, 'miniBatchSize'), hyperparams.miniBatchSize = 8; end

% Walidacja rozmiaru mini-batcha (ograniczenie do rozsądnych wartości)
miniBatchSize = max(2, min(16, round(hyperparams.miniBatchSize)));

% DEFINICJA ARCHITEKTURY CNN DLA OBRAZÓW ODCISKÓW PALCÓW
layers = [
    % WARSTWA WEJŚCIOWA
    % Normalizacja z-score automatyczna dla stabilności treningu
    imageInputLayer(inputSize, 'Name', 'input', 'Normalization', 'zscore')
    
    % BLOK KONWOLUCYJNY 1: Detekcja podstawowych cech lokalnych
    % Filtry o rozmiarze filterSize×filterSize, inicjalizacja He dla ReLU
    convolution2dLayer([hyperparams.filterSize, hyperparams.filterSize], ...
    hyperparams.numFilters1, 'Padding', 'same', 'Name', 'conv1', ...
    'WeightsInitializer', 'he')
    % Batch normalization - przyspiesza zbieżność i stabilizuje trening
    batchNormalizationLayer('Name', 'bn1')
    % ReLU - funkcja aktywacji, eliminuje gradient vanishing
    reluLayer('Name', 'relu1')
    % Max pooling 2×2 - redukcja wymiarowości o połowę, translational invariance
    maxPooling2dLayer([2, 2], 'Stride', [2, 2], 'Name', 'pool1')
    
    % BLOK KONWOLUCYJNY 2: Detekcja cech średniego poziomu
    % Mniejsze filtry 3×3 dla bardziej precyzyjnej analizy
    convolution2dLayer([3, 3], hyperparams.numFilters2, ...
    'Padding', 'same', 'Name', 'conv2', 'WeightsInitializer', 'he')
    batchNormalizationLayer('Name', 'bn2')
    reluLayer('Name', 'relu2')
    maxPooling2dLayer([2, 2], 'Stride', [2, 2], 'Name', 'pool2')
    
    % BLOK KONWOLUCYJNY 3: Detekcja cech wysokiego poziomu
    % Największa liczba filtrów dla złożonych reprezentacji
    convolution2dLayer([3, 3], hyperparams.numFilters3, ...
    'Padding', 'same', 'Name', 'conv3', 'WeightsInitializer', 'he')
    batchNormalizationLayer('Name', 'bn3')
    reluLayer('Name', 'relu3')
    maxPooling2dLayer([2, 2], 'Stride', [2, 2], 'Name', 'pool3')
    
    % WARSTWY FULLY CONNECTED - KLASYFIKATOR
    % Dropout przed pierwszą FC - regularyzacja przeciw overfitting
    dropoutLayer(hyperparams.dropoutRate, 'Name', 'dropout1')
    % Pierwsza warstwa FC - 128 neuronów, redukcja wymiarowości
    fullyConnectedLayer(128, 'Name', 'fc1', 'WeightsInitializer', 'he')
    reluLayer('Name', 'fc_relu1')
    % Drugi dropout dla dodatkowej regularyzacji
    dropoutLayer(hyperparams.dropoutRate, 'Name', 'dropout2')
    
    % Druga warstwa FC - 64 neurony, dalsze skupienie na cechach
    fullyConnectedLayer(64, 'Name', 'fc2', 'WeightsInitializer', 'he')
    reluLayer('Name', 'fc_relu2')
    
    % WARSTWA WYJŚCIOWA
    % Końcowa FC - numClasses neuronów (jeden na klasę)
    fullyConnectedLayer(numClasses, 'Name', 'fc_final', 'WeightsInitializer', 'he')
    % Softmax - konwersja na rozkład prawdopodobieństwa
    softmaxLayer('Name', 'softmax')
    % Classification layer - oblicza cross-entropy loss
    classificationLayer('Name', 'output')
    ];

% OPCJE TRENOWANIA ZOPTYMALIZOWANE DLA ODCISKÓW PALCÓW
options = trainingOptions('adam', ...
    'InitialLearnRate', hyperparams.lr, ...           % Learning rate początkowy
    'MaxEpochs', hyperparams.epochs, ...               % Maksymalna liczba epok
    'MiniBatchSize', miniBatchSize, ...                % Rozmiar mini-batcha
    'L2Regularization', hyperparams.l2reg, ...        % Regularyzacja L2 wag
    'LearnRateSchedule', 'piecewise', ...             % Harmonogram zmniejszania LR
    'LearnRateDropFactor', 0.2, ...                   % Współczynnik redukcji LR (80% spadek)
    'LearnRateDropPeriod', max(3, round(hyperparams.epochs/4)), ... % Co 1/4 epok
    'Shuffle', 'every-epoch', ...                     % Mieszanie danych co epokę
    'ValidationPatience', max(2, round(hyperparams.epochs/6)), ... % Early stopping
    'Verbose', false, ...                             % Brak verbose output
    'Plots', 'none', ...                              % Brak automatycznych wykresów
    'ExecutionEnvironment', 'auto', ...               % Automatyczny wybór GPU/CPU
    'GradientThreshold', 1);                          % Gradient clipping przeciw exploding

% Utworzenie struktury wyjściowej
cnnStruct.layers = layers;
cnnStruct.options = options;
end