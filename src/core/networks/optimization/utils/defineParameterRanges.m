function param_ranges = defineParameterRanges(config)
% DEFINEPARAMETERRANGES Definiuje zakresy parametrów dla optymalizacji sieci odcisków palców
%
% Składnia:
%   param_ranges = defineParameterRanges(config)
%
% Argumenty:
%   config - struktura konfiguracyjna
%
% Zwraca:
%   param_ranges - struktura z zakresami parametrów

param_ranges = struct();

% Obsługa ograniczenia do określonego typu sieci
if isfield(config, 'network_types') && length(config.network_types) == 1
    param_ranges.fixed_network_type = config.network_types{1};
    param_ranges.network_types = config.network_types;
else
    % TYLKO PatternNet vs CNN dla odcisków palców
    param_ranges.network_types = {'patternnet', 'cnn'};
end

% Zakresy parametrów dla odcisków palców
switch config.scenario
    case 'fingerprints'
        % Konfiguracja zoptymalizowana dla cech odcisków palców (122 wymiary)
        param_ranges.hidden_layers = {
            [15], [18], [20], [22], [24], [26], [28], [30],  % Jednowarstwowe
            [20, 10], [24, 12], [28, 14]                     % Dwuwarstwowe
            };
        param_ranges.training_algs = {'trainlm', 'trainbr', 'trainscg'};
        param_ranges.activation_functions = {'tansig', 'logsig', 'poslin'};
        param_ranges.learning_rates = [0.008, 0.01, 0.012, 0.015, 0.018, 0.02, 0.025];
        param_ranges.epochs_range = [200, 250, 300, 350, 400];
        
    otherwise
        % Domyślne wartości dla odcisków palców
        param_ranges.hidden_layers = {[20], [22], [24]};
        param_ranges.training_algs = {'trainlm'};
        param_ranges.activation_functions = {'tansig'};
        param_ranges.learning_rates = [0.01, 0.015, 0.02];
        param_ranges.epochs_range = [250, 300];
end

% CNN-specyficzne parametry
if any(strcmp(param_ranges.network_types, 'cnn'))
    param_ranges.cnn_learning_rates = [0.001, 0.003, 0.005, 0.008, 0.01];
    param_ranges.cnn_batch_sizes = [16, 32];
    param_ranges.cnn_dropout_rates = [0.3, 0.5, 0.7];
end

% Sprawdzenie kompletności konfiguracji
if ~isfield(param_ranges, 'hidden_layers') || isempty(param_ranges.hidden_layers)
    param_ranges.hidden_layers = {[20]};
end

if ~isfield(param_ranges, 'training_algs') || isempty(param_ranges.training_algs)
    param_ranges.training_algs = {'trainlm'};
end

if ~isfield(param_ranges, 'activation_functions') || isempty(param_ranges.activation_functions)
    param_ranges.activation_functions = {'tansig'};
end

if ~isfield(param_ranges, 'learning_rates') || isempty(param_ranges.learning_rates)
    param_ranges.learning_rates = [0.01, 0.015, 0.02];
end

if ~isfield(param_ranges, 'epochs_range') || isempty(param_ranges.epochs_range)
    param_ranges.epochs_range = [250, 300];
end

% Liczba parametrów do zakodowania w genotypie
param_ranges.num_genes = 6;  % typ sieci, warstwy ukryte, alg. uczenia, f. aktywacji, lr, epoki

end