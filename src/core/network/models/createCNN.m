function cnnStruct = createCNN(hyperparams, numClasses, inputSize)
% CREATECNN 1D CNN dla sekwencji cech minucji (UPROSZCZONA WERSJA)

% Walidacja parametrów z bezpiecznymi wartościami domyślnymi
if ~isfield(hyperparams, 'filterSize'), hyperparams.filterSize = 3; end
if ~isfield(hyperparams, 'numFilters1'), hyperparams.numFilters1 = 8; end
if ~isfield(hyperparams, 'numFilters2'), hyperparams.numFilters2 = 16; end
if ~isfield(hyperparams, 'dropoutRate'), hyperparams.dropoutRate = 0.2; end
if ~isfield(hyperparams, 'lr'), hyperparams.lr = 0.001; end
if ~isfield(hyperparams, 'l2reg'), hyperparams.l2reg = 1e-4; end
if ~isfield(hyperparams, 'epochs'), hyperparams.epochs = 30; end
if ~isfield(hyperparams, 'miniBatchSize'), hyperparams.miniBatchSize = 4; end

% Walidacja miniBatchSize
miniBatchSize = max(2, min(6, round(hyperparams.miniBatchSize)));

% BARDZO PROSTA 1D CNN ARCHITEKTURA - bez batch norm!
layers = [
    sequenceInputLayer(inputSize, 'Name', 'input')  % inputSize = 51 cech
    
    % Pierwsza warstwa 1D conv - mała
    convolution1dLayer(hyperparams.filterSize, hyperparams.numFilters1, ...
    'Padding', 'same', 'Name', 'conv1d_1')
    reluLayer('Name', 'relu1')
    % BEZ POOLING - za mała sekwencja
    
    % Druga warstwa 1D conv - jeszcze mniejsza
    convolution1dLayer(3, hyperparams.numFilters2, ...
    'Padding', 'same', 'Name', 'conv1d_2')
    reluLayer('Name', 'relu2')
    
    % Global pooling - agreguje całą sekwencję do jednego wektora
    globalMaxPooling1dLayer('Name', 'globalmaxpool')
    
    % Proste FC layers
    dropoutLayer(hyperparams.dropoutRate, 'Name', 'dropout1')
    fullyConnectedLayer(32, 'Name', 'fc1')  % Mały FC layer
    reluLayer('Name', 'fc_relu')
    
    % Output layer
    fullyConnectedLayer(numClasses, 'Name', 'fc_final')
    softmaxLayer('Name', 'softmax')
    classificationLayer('Name', 'output')
    ];

% Proste training options
options = trainingOptions('sgdm', ...           % SGD zamiast Adam
    'InitialLearnRate', hyperparams.lr, ...
    'MaxEpochs', hyperparams.epochs, ...
    'MiniBatchSize', miniBatchSize, ...
    'L2Regularization', hyperparams.l2reg, ...
    'Momentum', 0.9, ...                        % Standard momentum
    'Shuffle', 'every-epoch', ...
    'Verbose', false, ...
    'Plots', 'none', ...
    'ExecutionEnvironment', 'auto');

cnnStruct = struct();
cnnStruct.layers = layers;
cnnStruct.options = options;
end