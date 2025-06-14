function net = createPatternNet(hyperparams)
% CREATEPATTERNNET Tworzy i konfiguruje PatternNet

% Ustaw deterministyczne zachowanie
rng(42, 'twister'); % Fixed seed dla powtarzalności

% Walidacja hiddenSizes
if isfield(hyperparams, 'hiddenSizes')
    hyperparams.hiddenSizes = round(hyperparams.hiddenSizes);
    hyperparams.hiddenSizes = max(1, hyperparams.hiddenSizes);
    fprintf('🔧 Hidden sizes validated: %s\n', mat2str(hyperparams.hiddenSizes));
end

% Utwórz sieć z hidden layers
net = patternnet(hyperparams.hiddenSizes, hyperparams.trainFcn);

% Konfiguracja funkcji performance
net.performFcn = hyperparams.performFcn;

% Parametry trenowania
net.trainParam.epochs = hyperparams.epochs;
net.trainParam.goal = hyperparams.goal;
net.trainParam.lr = hyperparams.lr;
net.trainParam.show = 25;
net.trainParam.showWindow = false;
net.trainParam.showCommandLine = false;

% Parametry specyficzne dla trainlm
if strcmp(hyperparams.trainFcn, 'trainlm')
    net.trainParam.mu = hyperparams.mu;
    net.trainParam.mu_dec = hyperparams.mu_dec;
    net.trainParam.mu_inc = hyperparams.mu_inc;
    net.trainParam.mu_max = 1e10;
    
    % Użyj nowej składni dla nowszych wersji MATLAB
    try
        net.efficiency.memoryReduction = 1; % NOWA składnia
    catch
        net.trainParam.mem_reduc = 1; % STARA składnia (fallback)
    end
end

% Deterministyczne dzielenie danych
net.divideFcn = 'divideind';
net.divideMode = 'sample';

% Deterministyczne inicjalizowanie wag
net.initFcn = 'initlay';
for i = 1:length(net.layers)
    net.layers{i}.initFcn = 'initwb';
    net.inputWeights{i,1}.initFcn = 'rands';
    if i > 1
        net.layerWeights{i,i-1}.initFcn = 'rands';
    end
end

% Regularization dla lepszej generalizacji
try
    net.performParam.regularization = 0.01;
catch
    % Starsza wersja może nie obsługiwać tego parametru
end

% Wczesne zatrzymanie
net.trainParam.max_fail = hyperparams.max_fail;

% Plotowanie wyłączone
net.plotFcns = {};
end