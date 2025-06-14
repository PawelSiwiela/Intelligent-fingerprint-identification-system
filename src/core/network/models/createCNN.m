function cnnStruct = createCNN(hyperparams, numClasses, inputSize)
% CREATECNN 2D CNN dla obrazów szkieletyzowanych odcisków palców
%
% Args:
%   hyperparams - struktura z hiperparametrami CNN
%   numClasses - liczba klas (5 palców)
%   inputSize - rozmiar wejścia [height, width, channels] np. [128, 128, 1]
%
% Returns:
%   cnnStruct - struktura z layers i options

% Walidacja parametrów z bezpiecznymi wartościami domyślnymi
if ~isfield(hyperparams, 'filterSize'), hyperparams.filterSize = 5; end
if ~isfield(hyperparams, 'numFilters1'), hyperparams.numFilters1 = 16; end
if ~isfield(hyperparams, 'numFilters2'), hyperparams.numFilters2 = 32; end
if ~isfield(hyperparams, 'numFilters3'), hyperparams.numFilters3 = 64; end
if ~isfield(hyperparams, 'dropoutRate'), hyperparams.dropoutRate = 0.3; end
if ~isfield(hyperparams, 'lr'), hyperparams.lr = 0.001; end
if ~isfield(hyperparams, 'l2reg'), hyperparams.l2reg = 1e-4; end
if ~isfield(hyperparams, 'epochs'), hyperparams.epochs = 50; end
if ~isfield(hyperparams, 'miniBatchSize'), hyperparams.miniBatchSize = 8; end

% Walidacja miniBatchSize
miniBatchSize = max(2, min(16, round(hyperparams.miniBatchSize)));

% 2D CNN ARCHITECTURE dla obrazów fingerprint
layers = [
    % Input layer - obrazy szkieletyzowane
    imageInputLayer(inputSize, 'Name', 'input', 'Normalization', 'zscore')
    
    % BLOCK 1: Conv + ReLU + Pool
    convolution2dLayer([hyperparams.filterSize, hyperparams.filterSize], ...
    hyperparams.numFilters1, 'Padding', 'same', 'Name', 'conv1', ...
    'WeightsInitializer', 'he')
    batchNormalizationLayer('Name', 'bn1')
    reluLayer('Name', 'relu1')
    maxPooling2dLayer([2, 2], 'Stride', [2, 2], 'Name', 'pool1')  % Zmniejsz o połowę
    
    % BLOCK 2: Conv + ReLU + Pool
    convolution2dLayer([3, 3], hyperparams.numFilters2, ...
    'Padding', 'same', 'Name', 'conv2', 'WeightsInitializer', 'he')
    batchNormalizationLayer('Name', 'bn2')
    reluLayer('Name', 'relu2')
    maxPooling2dLayer([2, 2], 'Stride', [2, 2], 'Name', 'pool2')  % Zmniejsz o połowę
    
    % BLOCK 3: Conv + ReLU + Pool
    convolution2dLayer([3, 3], hyperparams.numFilters3, ...
    'Padding', 'same', 'Name', 'conv3', 'WeightsInitializer', 'he')
    batchNormalizationLayer('Name', 'bn3')
    reluLayer('Name', 'relu3')
    maxPooling2dLayer([2, 2], 'Stride', [2, 2], 'Name', 'pool3')  % Zmniejsz o połowę
    
    % FULLY CONNECTED LAYERS
    dropoutLayer(hyperparams.dropoutRate, 'Name', 'dropout1')
    fullyConnectedLayer(128, 'Name', 'fc1', 'WeightsInitializer', 'he')
    reluLayer('Name', 'fc_relu1')
    dropoutLayer(hyperparams.dropoutRate, 'Name', 'dropout2')
    
    fullyConnectedLayer(64, 'Name', 'fc2', 'WeightsInitializer', 'he')
    reluLayer('Name', 'fc_relu2')
    
    % OUTPUT LAYER
    fullyConnectedLayer(numClasses, 'Name', 'fc_final', 'WeightsInitializer', 'he')
    softmaxLayer('Name', 'softmax')
    classificationLayer('Name', 'output')
    ];

% Training options dla obrazów fingerprint - OPTIMIZED
options = trainingOptions('adam', ...
    'InitialLearnRate', hyperparams.lr, ...
    'MaxEpochs', hyperparams.epochs, ...
    'MiniBatchSize', miniBatchSize, ...
    'L2Regularization', hyperparams.l2reg, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.2, ...
    'LearnRateDropPeriod', max(3, round(hyperparams.epochs/4)), ...
    'Shuffle', 'every-epoch', ...
    'ValidationPatience', max(2, round(hyperparams.epochs/6)), ...
    'Verbose', false, ...
    'Plots', 'none', ...
    'ExecutionEnvironment', 'auto', ...
    'GradientThreshold', 1);

% Tworzenie struktury CNN
cnnStruct.layers = layers;
cnnStruct.options = options;
end