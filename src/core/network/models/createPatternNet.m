function net = createPatternNet(hyperparams)
% CREATEPATTERNNET - ZMNIEJSZONE OGRANICZENIA

% Ustaw deterministyczne zachowanie
rng(42, 'twister');

% Walidacja hiddenSizes - USUŃ OGRANICZENIE do 8
if isfield(hyperparams, 'hiddenSizes')
    hyperparams.hiddenSizes = round(hyperparams.hiddenSizes);
    hyperparams.hiddenSizes = max(1, hyperparams.hiddenSizes);
    
    % USUŃ: hyperparams.hiddenSizes = min(8, hyperparams.hiddenSizes);
    % Pozwól na większe sieci
    hyperparams.hiddenSizes = min(15, hyperparams.hiddenSizes); % Zwiększ limit
    
    fprintf('🔧 Hidden sizes validated: %s\n', mat2str(hyperparams.hiddenSizes));
end

% Utwórz sieć
net = patternnet(hyperparams.hiddenSizes, hyperparams.trainFcn);

% Konfiguracja funkcji performance
net.performFcn = hyperparams.performFcn;

% MNIEJ RESTRYKCYJNE parametry trenowania
net.trainParam.epochs = min(50, hyperparams.epochs); % ZWIĘKSZONE z 20 na 50
net.trainParam.goal = max(1e-5, hyperparams.goal);   % ZMNIEJSZONE z 1e-3 na 1e-5
net.trainParam.lr = hyperparams.lr;
net.trainParam.show = 25;
net.trainParam.showWindow = false;
net.trainParam.showCommandLine = false;

% ZREDUKOWANA REGULARYZACJA
try
    net.performParam.regularization = 0.01; % ZMNIEJSZONE z 0.1 na 0.01
catch
end

% MNIEJ AGRESYWNE ZATRZYMANIE
net.trainParam.max_fail = max(1, hyperparams.max_fail); % Użyj wartości z hyperparams

% LM parametry - mniej restrykcyjne
if strcmp(hyperparams.trainFcn, 'trainlm')
    net.trainParam.mu = max(0.001, hyperparams.mu);      % ZMNIEJSZONE z 0.01 na 0.001
    net.trainParam.mu_dec = max(0.5, hyperparams.mu_dec); % ZMNIEJSZONE z 0.7 na 0.5
    net.trainParam.mu_inc = min(20, hyperparams.mu_inc);  % ZWIĘKSZONE z 5 na 20
    net.trainParam.mu_max = 1e10; % Przywrócone z 1e8
    
    try
        net.efficiency.memoryReduction = 1;
    catch
        net.trainParam.mem_reduc = 1;
    end
end

% DETERMINISTYCZNE inicjalizowanie
net.initFcn = 'initlay';
for i = 1:length(net.layers)
    net.layers{i}.initFcn = 'initwb';
    net.inputWeights{i,1}.initFcn = 'rands';
    if i > 1
        net.layerWeights{i,i-1}.initFcn = 'rands';
    end
end

% Plotowanie wyłączone
net.plotFcns = {};

% Normalizacja danych wejściowych
net.inputs{1}.processFcns = {'removeconstantrows','mapminmax'};
net.outputs{2}.processFcns = {'removeconstantrows','mapminmax'};

fprintf('🔧 PatternNet configured with balanced parameters\n');
end