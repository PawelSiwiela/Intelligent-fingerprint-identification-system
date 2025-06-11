function net_config = convertToNetworkConfig(individual, param_ranges)
% CONVERTTONETWORKCONFIG Konwertuje genotyp osobnika na konfigurację sieci
%
% Składnia:
%   net_config = convertToNetworkConfig(individual, param_ranges)
%
% Argumenty:
%   individual - wektor genów osobnika
%   param_ranges - struktura z definicjami zakresów parametrów
%
% Zwraca:
%   net_config - struktura z konfiguracją sieci neuronowej

% Inicjalizacja struktury konfiguracyjnej
net_config = struct();

% Uzupełnienie brakujących parametrów
if ~isfield(param_ranges, 'network_types') || isempty(param_ranges.network_types)
    param_ranges.network_types = {'patternnet'};
end

if ~isfield(param_ranges, 'hidden_layers') || isempty(param_ranges.hidden_layers)
    param_ranges.hidden_layers = {[10]};
end

if ~isfield(param_ranges, 'training_algs') || isempty(param_ranges.training_algs)
    param_ranges.training_algs = {'trainlm'};
end

if ~isfield(param_ranges, 'activation_functions') || isempty(param_ranges.activation_functions)
    param_ranges.activation_functions = {'logsig'};
end

if ~isfield(param_ranges, 'learning_rates') || isempty(param_ranges.learning_rates)
    param_ranges.learning_rates = [0.01];
end

% Zabezpieczenie - rozszerzenie wektora indywidualnego, jeśli jest zbyt krótki
expected_length = param_ranges.num_genes;
if length(individual) < expected_length
    extended_individual = ones(1, expected_length);
    extended_individual(1:length(individual)) = individual;
    individual = extended_individual;
end

% Gen 1: Typ sieci
if isfield(param_ranges, 'fixed_network_type') && ~isempty(param_ranges.fixed_network_type)
    % Jeśli mamy zdefiniowany stały typ sieci, użyj go
    net_config.type = param_ranges.fixed_network_type;
else
    network_type_idx = max(1, min(individual(1), length(param_ranges.network_types)));
    net_config.type = param_ranges.network_types{network_type_idx};
end

% Gen 2: Warstwy ukryte
if length(param_ranges.hidden_layers) >= 1
    hidden_layer_idx = max(1, min(individual(2), length(param_ranges.hidden_layers)));
    net_config.hidden_layers = param_ranges.hidden_layers{hidden_layer_idx};
else
    net_config.hidden_layers = [10]; % Awaryjne ustawienie
end

% Gen 3: Algorytm uczenia
training_alg_idx = max(1, min(individual(3), length(param_ranges.training_algs)));
net_config.training_algorithm = param_ranges.training_algs{training_alg_idx};

% Gen 4: Funkcja aktywacji
activation_idx = max(1, min(individual(4), length(param_ranges.activation_functions)));
net_config.activation_function = param_ranges.activation_functions{activation_idx};

% Gen 5: Współczynnik uczenia
learning_rate_idx = max(1, min(individual(5), length(param_ranges.learning_rates)));
net_config.learning_rate = param_ranges.learning_rates(learning_rate_idx);

% Gen 6: Liczba epok
if isfield(param_ranges, 'epochs_range') && ~isempty(param_ranges.epochs_range) && length(individual) >= 6
    epochs_idx = max(1, min(individual(6), length(param_ranges.epochs_range)));
    net_config.max_epochs = param_ranges.epochs_range(epochs_idx);
else
    net_config.max_epochs = 300; % Wartość domyślna
end

% Dodatkowe parametry konfiguracyjne
net_config.validation_checks = 15;  % Liczba sprawdzeń walidacyjnych
net_config.show_progress = false;   % Nie pokazuj okna postępu treningu
net_config.show_command_line = true; % Pokaż postęp w linii komend

% Dodatkowe parametry dla specyficznych algorytmów uczenia
if strcmp(net_config.training_algorithm, 'trainbr')
    % Parametry dla Bayesian Regularization
    net_config.mu = 0.005;
    net_config.mu_dec = 0.1;
    net_config.mu_inc = 10;
    net_config.max_fail = 30;
    net_config.min_grad = 1e-10;
elseif strcmp(net_config.training_algorithm, 'trainlm')
    % Parametry dla Levenberg-Marquardt
    net_config.mu = 0.001;
    net_config.mu_dec = 0.1;
    net_config.mu_inc = 10;
    net_config.max_fail = 15;
    net_config.min_grad = 1e-8;
end
end