function net = createPatternNet(hyperparams)
% CREATEPATTERNNET - NAPRAWIONA WERSJA BEZ BŁĘDNYCH PARAMETRÓW

% DETERMINISTYCZNY seed
rng(42, 'twister');

% Walidacja hiperparametrów
if ~isfield(hyperparams, 'hiddenSizes') || isempty(hyperparams.hiddenSizes)
    hyperparams.hiddenSizes = [10];
end

if ~isfield(hyperparams, 'trainFcn')
    hyperparams.trainFcn = 'trainscg';
end

if ~isfield(hyperparams, 'performFcn')
    hyperparams.performFcn = 'mse';
end

%% UTWÓRZ SIEĆ
net = patternnet(hyperparams.hiddenSizes, hyperparams.trainFcn);
net.performFcn = hyperparams.performFcn;

%% POPRAWNE WYŁĄCZENIE AUTOMATYCZNEGO PODZIAŁU
net.divideFcn = 'dividetrain';  % 100% treningu, 0% walidacji, 0% testu

%% PARAMETRY TRENOWANIA

% Epochs
if isfield(hyperparams, 'epochs')
    net.trainParam.epochs = hyperparams.epochs;
else
    net.trainParam.epochs = 20;
end

% Goal
if isfield(hyperparams, 'goal')
    net.trainParam.goal = hyperparams.goal;
else
    net.trainParam.goal = 1e-3;
end

% Learning rate
if isfield(hyperparams, 'lr')
    net.trainParam.lr = hyperparams.lr;
else
    net.trainParam.lr = 1e-3;
end

% Max fail
if isfield(hyperparams, 'max_fail')
    net.trainParam.max_fail = hyperparams.max_fail;
else
    net.trainParam.max_fail = 2;
end

%% PARAMETRY ALGORYTMU
if strcmp(hyperparams.trainFcn, 'trainscg')
    net.trainParam.sigma = 5.0e-5;
    net.trainParam.lambda = 5.0e-7;
elseif strcmp(hyperparams.trainFcn, 'trainlm')
    if isfield(hyperparams, 'mu')
        net.trainParam.mu = hyperparams.mu;
    else
        net.trainParam.mu = 0.01;
    end
    net.trainParam.mu_dec = 0.1;
    net.trainParam.mu_inc = 10;
    net.trainParam.mu_max = 1e10;
end

%% WYŁĄCZ PLOTTING
net.plotFcns = {};
net.trainParam.showWindow = false;
net.trainParam.showCommandLine = false;
net.trainParam.show = NaN;

fprintf('🔧 PatternNet: [%s] %s, epochs=%d, goal=%.1e, lr=%.1e, maxfail=%d\n', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, ...
    net.trainParam.epochs, net.trainParam.goal, net.trainParam.lr, net.trainParam.max_fail);
end