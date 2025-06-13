function net = createPatternNet(hyperparams)
% CREATEPATTERNNET Tworzy i konfiguruje PatternNet
%
% Argumenty:
%   hyperparams - struktura z hiperparametrami
%
% Output:
%   net - skonfigurowana sieć PatternNet

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

% Parametry specyficzne dla trainlm
if strcmp(hyperparams.trainFcn, 'trainlm')
    net.trainParam.mu = hyperparams.mu;
    net.trainParam.mu_dec = hyperparams.mu_dec;
    net.trainParam.mu_inc = hyperparams.mu_inc;
    net.trainParam.mu_max = 1e10;
end

% Ustawienia walidacji
net.divideParam.trainRatio = 0.7;
net.divideParam.valRatio = 0.15;
net.divideParam.testRatio = 0.15;

% Dodaj weight decay
net.performParam.regularization = 0.01; % Zwiększ z 0.005

% Wczesne zatrzymanie
net.trainParam.max_fail = 5; % Zwiększ z 3

% Dropout simulation przez noise
net.trainParam.lr = hyperparams.lr * 0.5; % Mniejszy learning rate

% Plotowanie wyłączone
net.plotFcns = {};
end