function [net] = createNetwork(input_size, output_size, config)
% CREATENETWORK Tworzy sieć neuronową dla problemu rozpoznawania odcisków palców
%
% Składnia:
%   [net] = createNetwork(input_size, output_size, config)
%
% Argumenty:
%   input_size - liczba wejść (cech) - 122
%   output_size - liczba wyjść (kategorii) - 5 (palce)
%   config - struktura konfiguracyjna z polami:
%     .type - typ sieci ('patternnet', 'cnn')
%     .hidden_layers - liczba neuronów w warstwach ukrytych [n1, n2, ...]
%     .training_algorithm - algorytm uczenia
%     .activation_function - funkcja aktywacji
%
% Zwraca:
%   net - utworzona sieć neuronowa

% Inicjalizacja konfiguracji, jeśli nie podano
if nargin < 3
    config = struct();
end

% Określenie wartości domyślnych dla brakujących parametrów
if ~isfield(config, 'type') || isempty(config.type)
    config.type = 'patternnet';
end

if ~isfield(config, 'hidden_layers') || isempty(config.hidden_layers)
    config.hidden_layers = [20];  % Optymalne dla cech odcisków palców
end

if ~isfield(config, 'training_algorithm') || isempty(config.training_algorithm)
    config.training_algorithm = 'trainlm';
end

% Upewnij się, że hidden_layers jest wektorem
if isscalar(config.hidden_layers)
    config.hidden_layers = [config.hidden_layers];
end

% Utworzenie sieci danego typu
switch config.type
    case 'patternnet'
        net = patternnet(config.hidden_layers, config.training_algorithm);
        logInfo('🧠 Utworzono sieć patternnet z warstwami ukrytymi %s i algorytmem %s', ...
            mat2str(config.hidden_layers), config.training_algorithm);
        
    case 'cnn'
        % CNN dla wektorów cech 122D (przekształconych jako "obraz" 122x1x1)
        layers = [
            imageInputLayer([input_size, 1, 1], 'Name', 'input', 'Normalization', 'none')
            
            % Pierwsza warstwa konwolucyjna 1D
            convolution2dLayer([5, 1], 32, 'Padding', 'same', 'Name', 'conv1')
            batchNormalizationLayer('Name', 'bn1')
            reluLayer('Name', 'relu1')
            maxPooling2dLayer([2, 1], 'Stride', [2, 1], 'Name', 'pool1')
            
            % Druga warstwa konwolucyjna 1D
            convolution2dLayer([3, 1], 64, 'Padding', 'same', 'Name', 'conv2')
            batchNormalizationLayer('Name', 'bn2')
            reluLayer('Name', 'relu2')
            maxPooling2dLayer([2, 1], 'Stride', [2, 1], 'Name', 'pool2')
            
            % Trzecia warstwa konwolucyjna 1D
            convolution2dLayer([3, 1], 128, 'Padding', 'same', 'Name', 'conv3')
            batchNormalizationLayer('Name', 'bn3')
            reluLayer('Name', 'relu3')
            globalAveragePooling2dLayer('Name', 'gap')
            
            % Warstwy w pełni połączone
            fullyConnectedLayer(config.hidden_layers(1), 'Name', 'fc1')
            dropoutLayer(0.5, 'Name', 'dropout1')
            ];
        
        % Dodaj dodatkowe warstwy ukryte jeśli są w konfiguracji
        for i = 2:length(config.hidden_layers)
            layers = [layers;
                fullyConnectedLayer(config.hidden_layers(i), 'Name', sprintf('fc%d', i))
                dropoutLayer(0.5, 'Name', sprintf('dropout%d', i))];
        end
        
        % Warstwa wyjściowa
        layers = [layers;
            fullyConnectedLayer(output_size, 'Name', 'output')
            softmaxLayer('Name', 'softmax')
            classificationLayer('Name', 'classification')];
        
        net = layerGraph(layers);
        
        logInfo('🔬 Utworzono sieć CNN dla cech %dx1x1 z warstwami FC %s', ...
            input_size, mat2str(config.hidden_layers));
        
    otherwise
        logWarning('⚠️ Nieznany typ sieci: %s. Używam patternnet.', config.type);
        net = patternnet(config.hidden_layers, config.training_algorithm);
end

% Dla patternnet - zastosuj dodatkowe ustawienia
if strcmp(config.type, 'patternnet')
    % Funkcje aktywacji dla warstw ukrytych
    if isfield(config, 'activation_function') && ~isempty(config.activation_function)
        for i = 1:length(config.hidden_layers)
            net.layers{i}.transferFcn = config.activation_function;
        end
    end
    
    % Podział danych według specyfikacji
    if isfield(config, 'trainRatio'), net.divideParam.trainRatio = config.trainRatio; end
    if isfield(config, 'valRatio'), net.divideParam.valRatio = config.valRatio; end
    if isfield(config, 'testRatio'), net.divideParam.testRatio = config.testRatio; end
    
    % Ustawienia wyświetlania
    net.trainParam.showWindow = false;
    net.trainParam.showCommandLine = true;
    
    % Learning rate
    if isfield(config, 'learning_rate') && ~isempty(config.learning_rate)
        net.trainParam.lr = config.learning_rate;
    end
    
    % Maksymalna liczba epok
    if isfield(config, 'max_epochs') && ~isempty(config.max_epochs)
        net.trainParam.epochs = config.max_epochs;
    end
    
    % Dodatkowe parametry dla specyficznych algorytmów
    if isfield(config, 'min_grad'), net.trainParam.min_grad = config.min_grad; end
    if isfield(config, 'max_fail'), net.trainParam.max_fail = config.max_fail; end
    if isfield(config, 'mu'), net.trainParam.mu = config.mu; end
    if isfield(config, 'mu_dec'), net.trainParam.mu_dec = config.mu_dec; end
    if isfield(config, 'mu_inc'), net.trainParam.mu_inc = config.mu_inc; end
end
end