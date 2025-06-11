function [net, tr, training_results] = trainNetwork(net, X, Y, config)
% TRAINNETWORK Trenuje sieć neuronową do rozpoznawania odcisków palców
%
% Składnia:
%   [net, tr, training_results] = trainNetwork(net, X, Y, config)
%
% Argumenty:
%   net - sieć neuronowa do trenowania (PatternNet lub CNN)
%   X - macierz cech [próbki × cechy] (122-wymiarowe wektory)
%   Y - macierz etykiet [próbki × kategorie] (one-hot encoding dla 5 palców)
%   config - struktura konfiguracyjna
%
% Zwraca:
%   net - wytrenowana sieć neuronowa
%   tr - dane z procesu treningu
%   training_results - struktura z wynikami treningu

% Domyślne parametry
if nargin < 4
    config = struct();
end

% Ustaw domyślne wartości
if ~isfield(config, 'learning_rate'), config.learning_rate = 0.01; end
if ~isfield(config, 'max_epochs'), config.max_epochs = 300; end
if ~isfield(config, 'validation_checks'), config.validation_checks = 15; end
if ~isfield(config, 'show_progress'), config.show_progress = false; end
if ~isfield(config, 'show_command_line'), config.show_command_line = true; end

% Podział danych na treningowe i testowe, jeśli nie podano danych testowych
if ~isfield(config, 'X_test') || ~isfield(config, 'Y_test')
    if ~isfield(config, 'test_ratio'), config.test_ratio = 0.2; end
    [X_train, Y_train, X_test, Y_test] = splitDataForNetworks(X, Y, config.test_ratio);
else
    X_train = X;
    Y_train = Y;
    X_test = config.X_test;
    Y_test = config.Y_test;
end

logInfo('🔄 Rozpoczynam trenowanie sieci...');
tic;

% Sprawdź typ sieci i trenuj odpowiednio
if isa(net, 'LayerGraph') || isa(net, 'SeriesNetwork') || isa(net, 'DAGNetwork')
    % ======================================================================
    % TRENOWANIE CNN
    % ======================================================================
    
    % Przekształć dane do formatu wymaganego przez CNN
    X_train_cnn = reshape(X_train', [size(X_train, 2), 1, 1, size(X_train, 1)]);  % [122, 1, 1, N]
    X_test_cnn = reshape(X_test', [size(X_test, 2), 1, 1, size(X_test, 1)]);      % [122, 1, 1, N_test]
    
    % Konwertuj etykiety na categorical
    [~, Y_train_labels] = max(Y_train, [], 2);
    [~, Y_test_labels] = max(Y_test, [], 2);
    Y_train_cat = categorical(Y_train_labels);
    Y_test_cat = categorical(Y_test_labels);
    
    % Opcje trenowania CNN
    options = trainingOptions('adam', ...
        'MaxEpochs', config.max_epochs, ...
        'MiniBatchSize', min(32, size(X_train, 1)), ...
        'InitialLearnRate', config.learning_rate, ...
        'ValidationData', {X_test_cnn, Y_test_cat}, ...
        'ValidationFrequency', 10, ...
        'ValidationPatience', config.validation_checks, ...
        'Verbose', config.show_command_line, ...
        'Plots', 'none', ...
        'Shuffle', 'every-epoch');
    
    % Trenuj CNN
    [net, tr] = trainNetwork(X_train_cnn, Y_train_cat, net, options);
    
    % Ewaluacja CNN
    y_pred_cat = classify(net, X_test_cnn);
    y_pred_labels = double(y_pred_cat);
    y_true_labels = Y_test_labels;
    
    accuracy = sum(y_pred_labels == y_true_labels) / length(y_true_labels);
    
    % Dla CNN tr.best_epoch może nie istnieć
    if isfield(tr, 'TrainingLoss')
        best_epoch = length(tr.TrainingLoss);
    else
        best_epoch = config.max_epochs;
    end
    
else
    % ======================================================================
    % TRENOWANIE PATTERNNET
    % ======================================================================
    
    % Transpozycja danych do formatu wymaganego przez Neural Network Toolbox
    X_net = X_train';
    Y_net = Y_train';
    
    % Konfiguracja parametrów trenowania
    net.trainParam.lr = config.learning_rate;
    net.trainParam.epochs = config.max_epochs;
    net.trainParam.max_fail = config.validation_checks;
    net.trainParam.showWindow = config.show_progress;
    net.trainParam.showCommandLine = config.show_command_line;
    
    % Trenuj PatternNet
    [net, tr] = train(net, X_net, Y_net);
    
    % Ewaluacja PatternNet
    y_pred = net(X_test');
    [~, y_pred_labels] = max(y_pred, [], 1);
    [~, y_true_labels] = max(Y_test', [], 1);
    
    accuracy = sum(y_pred_labels == y_true_labels) / length(y_true_labels);
    best_epoch = tr.best_epoch;
end

training_time = toc;

% Obliczenie macierzy konfuzji
confusion_matrix = confusionmat(y_true_labels, y_pred_labels);

% Zwrócenie wyników
training_results = struct(...
    'accuracy', accuracy, ...
    'confusion_matrix', confusion_matrix, ...
    'best_epoch', best_epoch, ...
    'training_time', training_time, ...
    'network_type', class(net));

logInfo('✅ Trenowanie zakończone. Dokładność: %.2f%%, czas: %.2fs', accuracy*100, training_time);

end

function [X_train, Y_train, X_test, Y_test] = splitDataForNetworks(X, Y, test_ratio)
% Pomocnicza funkcja do podziału danych

n_samples = size(X, 1);
n_test = round(n_samples * test_ratio);
n_train = n_samples - n_test;

% Losowy podział
indices = randperm(n_samples);
train_indices = indices(1:n_train);
test_indices = indices(n_train+1:end);

X_train = X(train_indices, :);
Y_train = Y(train_indices, :);
X_test = X(test_indices, :);
Y_test = Y(test_indices, :);
end