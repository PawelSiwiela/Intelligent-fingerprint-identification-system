function mutated = mutate(individual, param_ranges, mutation_rate)
% MUTATE Operator mutacji osobnika - zoptymalizowany dla eksploatacji
%
% Składnia:
%   mutated = mutate(individual, param_ranges, mutation_rate)
%
% Argumenty:
%   individual - genotyp osobnika do mutacji
%   param_ranges - struktura z definicjami zakresów parametrów
%   mutation_rate - bazowe prawdopodobieństwo mutacji każdego genu

% Inicjalizacja wyniku
mutated = individual;

% Określenie niskiego współczynnika mutacji dla eksploatacji
actual_mutation_rate = mutation_rate; % Już powinien być niski (~0.15)

% Liczba genów
num_genes = length(individual);

% Sprawdzenie czy wszystkie wymagane pola są dostępne
required_fields = {'network_types', 'hidden_layers', 'training_algs', 'activation_functions', 'learning_rates'};
for i = 1:length(required_fields)
    field = required_fields{i};
    if ~isfield(param_ranges, field) || isempty(param_ranges.(field))
        error('Brakujące lub puste pole w param_ranges w funkcji mutate: %s', field);
    end
end

% Maksymalne wartości dla każdego genu - z dodatkowym zabezpieczeniem
max_values = zeros(1, 5); % Inicjalizacja tablicy
max_values(1) = length(param_ranges.network_types);
max_values(2) = length(param_ranges.hidden_layers);
max_values(3) = length(param_ranges.training_algs);
max_values(4) = length(param_ranges.activation_functions);
max_values(5) = length(param_ranges.learning_rates);

% Dodaj maksymalną wartość dla liczby epok (jeśli używana)
if num_genes >= 6 && isfield(param_ranges, 'epochs_range') && ~isempty(param_ranges.epochs_range)
    max_values(6) = length(param_ranges.epochs_range);
end

% Sprawdź czy max_values nie zawiera zer
for i = 1:length(max_values)
    if max_values(i) == 0
        max_values(i) = 1; % Minimalna wartość to 1
        disp(['Ostrzeżenie: Zerowa maksymalna wartość dla genu ', num2str(i), ' - ustawiono na 1']);
    end
end

% Mutacja każdego genu z określonym prawdopodobieństwem
for i = 1:min(num_genes, length(max_values))
    % Zmniejszamy prawdopodobieństwo mutacji dla ważnych genów (2, 3, 5)
    % aby zachować dobre wartości dla warstw, algorytmu uczenia i learning rate
    gene_mutation_rate = actual_mutation_rate;
    if i == 2 || i == 3 || i == 5
        gene_mutation_rate = gene_mutation_rate * 0.8; % Zmniejszamy o 20%
    end
    
    if rand() < gene_mutation_rate
        % Dla 2-go genu (warstwy sieci) preferujemy jednowarstwowe sieci [19-24]
        if i == 2
            single_layer_indices = find(cellfun(@(x) length(x) == 1 && x(1) >= 19 && x(1) <= 24, param_ranges.hidden_layers));
            if ~isempty(single_layer_indices) && rand() < 0.7 % 70% szans na wybór optymalnej architektury
                mutated(i) = single_layer_indices(randi(length(single_layer_indices)));
            else
                mutated(i) = randi(max_values(i));
            end
            % Dla 3-go genu (algorytm uczenia) preferujemy trainlm
        elseif i == 3
            trainlm_idx = find(strcmp(param_ranges.training_algs, 'trainlm'));
            if ~isempty(trainlm_idx) && rand() < 0.8 % 80% szans na wybór trainlm
                mutated(i) = trainlm_idx;
            else
                mutated(i) = randi(max_values(i));
            end
            % Dla 5-go genu (learning rate) preferujemy zakres 0.01-0.02
        elseif i == 5
            optimal_lr_indices = find(param_ranges.learning_rates >= 0.01 & param_ranges.learning_rates <= 0.02);
            if ~isempty(optimal_lr_indices) && rand() < 0.7 % 70% szans na wybór optymalnego LR
                mutated(i) = optimal_lr_indices(randi(length(optimal_lr_indices)));
            else
                mutated(i) = randi(max_values(i));
            end
        else
            % Standardowa mutacja dla pozostałych genów
            mutated(i) = randi(max_values(i));
        end
    end
end

end