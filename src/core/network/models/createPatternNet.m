function net = createPatternNet(hyperparams)
% CREATEPATTERNNET Przepisana prosta wersja dla PatternNet

% Deterministyczne zachowanie
rng(42, 'twister');

% Walidacja hiperparametrów
if ~isfield(hyperparams, 'hiddenSizes') || isempty(hyperparams.hiddenSizes)
    hyperparams.hiddenSizes = [10]; % Domyślna architektura
end

if ~isfield(hyperparams, 'trainFcn')
    hyperparams.trainFcn = 'trainlm';
end

if ~isfield(hyperparams, 'performFcn')
    hyperparams.performFcn = 'mse';
end

% Sprawdź hiddenSizes
hyperparams.hiddenSizes = round(max(1, hyperparams.hiddenSizes));
fprintf('🔧 Creating PatternNet: %s, %s, %s\n', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, hyperparams.performFcn);

%% UTWÓRZ SIEĆ

net = patternnet(hyperparams.hiddenSizes, hyperparams.trainFcn);

% Performance function
net.performFcn = hyperparams.performFcn;

%% PARAMETRY TRENOWANIA

% Epochs
if isfield(hyperparams, 'epochs')
    net.trainParam.epochs = max(5, min(100, hyperparams.epochs));
else
    net.trainParam.epochs = 50;
end

% Goal
if isfield(hyperparams, 'goal')
    net.trainParam.goal = max(1e-6, hyperparams.goal);
else
    net.trainParam.goal = 1e-4;
end

% Learning rate
if isfield(hyperparams, 'lr')
    net.trainParam.lr = max(1e-5, min(0.1, hyperparams.lr));
else
    net.trainParam.lr = 0.01;
end

% Max fail
if isfield(hyperparams, 'max_fail')
    net.trainParam.max_fail = max(1, hyperparams.max_fail);
else
    net.trainParam.max_fail = 3;
end

% UI settings
net.trainParam.show = 25;
net.trainParam.showWindow = false;
net.trainParam.showCommandLine = false;

%% LEVENBERG-MARQUARDT PARAMETRY

if strcmp(hyperparams.trainFcn, 'trainlm')
    if isfield(hyperparams, 'mu')
        net.trainParam.mu = max(0.001, hyperparams.mu);
    else
        net.trainParam.mu = 0.001;
    end
    
    if isfield(hyperparams, 'mu_dec')
        net.trainParam.mu_dec = max(0.1, min(0.9, hyperparams.mu_dec));
    else
        net.trainParam.mu_dec = 0.1;
    end
    
    if isfield(hyperparams, 'mu_inc')
        net.trainParam.mu_inc = max(2, hyperparams.mu_inc);
    else
        net.trainParam.mu_inc = 10;
    end
    
    net.trainParam.mu_max = 1e10;
    
    % Memory reduction
    try
        net.efficiency.memoryReduction = 1;
    catch
        net.trainParam.mem_reduc = 1;
    end
end

%% REGULARYZACJA

try
    net.performParam.regularization = 0.01; % Lekka regularyzacja
catch
    % Ignore if not supported
end

%% INICJALIZACJA

net.initFcn = 'initlay';

% Inicjalizuj warstwy
for i = 1:length(net.layers)
    net.layers{i}.initFcn = 'initwb';
    
    % Input weights
    if i == 1
        net.inputWeights{i,1}.initFcn = 'rands';
    end
    
    % Layer weights
    if i > 1
        net.layerWeights{i,i-1}.initFcn = 'rands';
    end
end

%% PREPROCESSING

% Input preprocessing
net.inputs{1}.processFcns = {'removeconstantrows', 'mapminmax'};

% Output preprocessing
net.outputs{2}.processFcns = {'removeconstantrows', 'mapminmax'};

%% WYŁĄCZ PLOTOWANIE

net.plotFcns = {};

fprintf('🔧 PatternNet configured: %d epochs, goal=%.1e, lr=%.1e\n', ...
    net.trainParam.epochs, net.trainParam.goal, net.trainParam.lr);
end