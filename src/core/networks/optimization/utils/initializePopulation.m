function population = initializePopulation(population_size, param_ranges)
% INITIALIZEPOPULATION Inicjalizacja populacji początkowej
%
% Składnia:
%   population = initializePopulation(population_size, param_ranges)
%
% Argumenty:
%   population_size - rozmiar populacji
%   param_ranges - struktura z definicjami zakresów parametrów
%
% Zwraca:
%   population - macierz populacji początkowej [osobniki x geny]

% Sprawdzenie dostępności wymaganych parametrów
required_fields = {'network_types', 'hidden_layers', 'training_algs', 'activation_functions', 'learning_rates'};
for i = 1:length(required_fields)
    field = required_fields{i};
    if ~isfield(param_ranges, field) || isempty(param_ranges.(field))
        error('Brakujące pole w param_ranges: %s', field);
    end
end

% Sprawdzenie liczby genów
if ~isfield(param_ranges, 'num_genes')
    param_ranges.num_genes = 6; % Domyślna liczba genów
end

% Inicjalizacja populacji
population = zeros(population_size, param_ranges.num_genes);

% Wypełnienie populacji wartościami skoncentrowanymi na najlepszych architekturach
for i = 1:population_size
    % Gen 1: Typ sieci - zawsze patternnet
    population(i, 1) = 1;
    
    % Gen 2: Warstwy ukryte - skupienie na jednowarstwowych sieciach [19-24]
    if i <= length(param_ranges.hidden_layers)
        % Gwarantujemy, że każda architektura będzie miała co najmniej jednego przedstawiciela
        population(i, 2) = i;
    else
        % Dla pozostałych osobników, preferujemy najlepsze jednowarstwowe sieci
        best_layers_idx = find(cellfun(@(x) length(x) == 1 && x(1) >= 19 && x(1) <= 24, param_ranges.hidden_layers));
        if ~isempty(best_layers_idx)
            population(i, 2) = best_layers_idx(randi(length(best_layers_idx)));
        else
            population(i, 2) = randi(length(param_ranges.hidden_layers));
        end
    end
    
    % Gen 3: Algorytm uczenia - preferujemy trainlm
    trainlm_idx = find(strcmp(param_ranges.training_algs, 'trainlm'));
    if ~isempty(trainlm_idx)
        population(i, 3) = trainlm_idx;
    else
        population(i, 3) = randi(length(param_ranges.training_algs));
    end
    
    % Gen 4: Funkcja aktywacji
    population(i, 4) = randi(length(param_ranges.activation_functions));
    
    % Gen 5: Współczynnik uczenia - skupienie na optymalnym zakresie 0.01-0.02
    optimal_lr_indices = find(param_ranges.learning_rates >= 0.01 & param_ranges.learning_rates <= 0.02);
    if ~isempty(optimal_lr_indices)
        population(i, 5) = optimal_lr_indices(randi(length(optimal_lr_indices)));
    else
        population(i, 5) = randi(length(param_ranges.learning_rates));
    end
    
    % Gen 6: Liczba epok - preferujemy 300-350
    optimal_epoch_indices = find(param_ranges.epochs_range >= 300 & param_ranges.epochs_range <= 350);
    if ~isempty(optimal_epoch_indices)
        population(i, 6) = optimal_epoch_indices(randi(length(optimal_epoch_indices)));
    else
        population(i, 6) = randi(length(param_ranges.epochs_range));
    end
end
end