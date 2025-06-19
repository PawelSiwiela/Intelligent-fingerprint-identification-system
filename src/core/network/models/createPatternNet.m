function net = createPatternNet(hyperparams)
% CREATEPATTERNNET Tworzy sieć PatternNet do klasyfikacji cech minucji odcisków palców
%
% Funkcja konstruuje wielowarstwową sieć neuronową typu feedforward (PatternNet)
% zoptymalizowaną do klasyfikacji wektorów cech minucji. Implementuje deterministyczne
% ustawienia oraz konfigurowalną architekturę z różnymi algorytmami trenowania.
%
% Parametry wejściowe:
%   hyperparams - struktura z hiperparametrami sieci:
%                .hiddenSizes - wektor rozmiarów warstw ukrytych (domyślnie [10])
%                .trainFcn - algorytm trenowania ('trainscg', 'trainlm', etc.)
%                .performFcn - funkcja kosztu ('mse', 'crossentropy')
%                .epochs - maksymalna liczba epok (domyślnie 20)
%                .goal - cel funkcji kosztu (domyślnie 1e-3)
%                .lr - learning rate (domyślnie 1e-3)
%                .max_fail - maksymalne niepowodzenia walidacji (domyślnie 2)
%                .mu - parametr μ dla algorytmu Levenberg-Marquardt
%
% Parametry wyjściowe:
%   net - skonfigurowana sieć PatternNet gotowa do trenowania
%
% Obsługiwane algorytmy trenowania:
%   - 'trainscg' - Scaled Conjugate Gradient (domyślny, szybki, stabilny)
%   - 'trainlm' - Levenberg-Marquardt (precyzyjny dla małych sieci)
%   - 'traingd' - Gradient Descent (podstawowy)
%   - 'trainbr' - Bayesian Regularization (dobry dla małych zbiorów)
%
% Przykład użycia:
%   hyperparams.hiddenSizes = [20, 10];
%   hyperparams.trainFcn = 'trainscg';
%   net = createPatternNet(hyperparams);

% DETERMINISTYCZNY GENERATOR LICZB PSEUDOLOSOWYCH
% Zapewnia powtarzalność eksperymentów
rng(42, 'twister');

% WALIDACJA I UZUPEŁNIENIE HIPERPARAMETRÓW
if ~isfield(hyperparams, 'hiddenSizes') || isempty(hyperparams.hiddenSizes)
    % Domyślna architektura: jedna warstwa ukryta z 10 neuronami
    hyperparams.hiddenSizes = [10];
end

if ~isfield(hyperparams, 'trainFcn')
    % Scaled Conjugate Gradient - dobry kompromis szybkość/stabilność
    hyperparams.trainFcn = 'trainscg';
end

if ~isfield(hyperparams, 'performFcn')
    % Mean Squared Error - standardowa funkcja kosztu dla klasyfikacji
    hyperparams.performFcn = 'mse';
end

% UTWORZENIE SIECI PATTERNNET
% PatternNet to specjalizowana sieć feedforward dla klasyfikacji wzorców
net = patternnet(hyperparams.hiddenSizes, hyperparams.trainFcn);
net.performFcn = hyperparams.performFcn;

% KONFIGURACJA PODZIAŁU DANYCH
% Wyłączenie automatycznego podziału - pełna kontrola nad danymi treningowymi
net.divideFcn = 'dividetrain';  % 100% danych dla treningu, 0% walidacji, 0% testu

% PARAMETRY PODSTAWOWE TRENOWANIA

% Maksymalna liczba epok trenowania
if isfield(hyperparams, 'epochs')
    net.trainParam.epochs = hyperparams.epochs;
else
    net.trainParam.epochs = 20;  % Domyślnie 20 epok
end

% Cel funkcji kosztu (zatrzymanie gdy osiągnięty)
if isfield(hyperparams, 'goal')
    net.trainParam.goal = hyperparams.goal;
else
    net.trainParam.goal = 1e-3;  % MSE < 0.001
end

% Learning rate (krok uczenia)
if isfield(hyperparams, 'lr')
    net.trainParam.lr = hyperparams.lr;
else
    net.trainParam.lr = 1e-3;    % Konserwatywny learning rate
end

% Maksymalna liczba kolejnych niepowodzeń walidacji (early stopping)
if isfield(hyperparams, 'max_fail')
    net.trainParam.max_fail = hyperparams.max_fail;
else
    net.trainParam.max_fail = 2;  % Zatrzymaj po 2 niepowodzeniach
end

% PARAMETRY SPECYFICZNE DLA ALGORYTMÓW TRENOWANIA

if strcmp(hyperparams.trainFcn, 'trainscg')
    % SCALED CONJUGATE GRADIENT - parametry regularyzacji
    net.trainParam.sigma = 5.0e-5;   % Parametr σ - stabilność numeryczna
    net.trainParam.lambda = 5.0e-7;  % Parametr λ - regularyzacja Levenberg-Marquardt
    
elseif strcmp(hyperparams.trainFcn, 'trainlm')
    % LEVENBERG-MARQUARDT - adaptacyjne parametry μ
    if isfield(hyperparams, 'mu')
        net.trainParam.mu = hyperparams.mu;
    else
        net.trainParam.mu = 0.01;    % Początkowa wartość μ
    end
    net.trainParam.mu_dec = 0.1;     % Współczynnik zmniejszenia μ (sukces)
    net.trainParam.mu_inc = 10;      % Współczynnik zwiększenia μ (niepowodzenie)
    net.trainParam.mu_max = 1e10;    % Maksymalna wartość μ
end

% WYŁĄCZENIE INTERFEJSU GRAFICZNEGO I LOGOWANIA
% Zapewnia ciche działanie podczas automatyzacji
net.plotFcns = {};                        % Brak funkcji plotowania
net.trainParam.showWindow = false;        % Brak okna trenowania
net.trainParam.showCommandLine = false;   % Brak output w command line
net.trainParam.show = NaN;                % Brak okresowych komunikatów

% PODSUMOWANIE KONFIGURACJI SIECI
fprintf('🔧 PatternNet: [%s] %s, epochs=%d, goal=%.1e, lr=%.1e, maxfail=%d\n', ...
    mat2str(hyperparams.hiddenSizes), hyperparams.trainFcn, ...
    net.trainParam.epochs, net.trainParam.goal, net.trainParam.lr, net.trainParam.max_fail);
end