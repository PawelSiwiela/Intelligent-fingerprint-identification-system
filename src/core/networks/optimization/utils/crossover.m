function child = crossover(parent1, parent2, crossover_rate)
% CROSSOVER Operator krzyżowania dwóch osobników
%
% Składnia:
%   child = crossover(parent1, parent2, crossover_rate)
%
% Argumenty:
%   parent1 - genotyp pierwszego rodzica
%   parent2 - genotyp drugiego rodzica
%   crossover_rate - prawdopodobieństwo krzyżowania (opcjonalne)
%
% Zwraca:
%   child - genotyp potomka

% Sprawdzenie długości wektorów rodziców
if length(parent1) ~= length(parent2)
    error('Rodzice mają różne długości wektorów: %d vs %d', length(parent1), length(parent2));
end

% Domyślna wartość współczynnika krzyżowania
if nargin < 3 || isempty(crossover_rate)
    crossover_rate = 0.8;
end

% Liczba genów
num_genes = length(parent1);

% Inicjalizacja potomka - na początku kopia pierwszego rodzica
child = parent1;

% Sprawdzenie czy dojdzie do krzyżowania
if rand() < crossover_rate
    % Wybieramy losowo typ krzyżowania
    crossover_type = randi(2);
    
    switch crossover_type
        case 1
            % Krzyżowanie jednopunktowe
            crossover_point = randi(num_genes - 1);
            
            child(1:crossover_point) = parent1(1:crossover_point);
            child(crossover_point+1:end) = parent2(crossover_point+1:end);
            
        case 2
            % Krzyżowanie dwupunktowe
            points = sort(randperm(num_genes, 2));
            crossover_point1 = points(1);
            crossover_point2 = points(2);
            
            child(1:crossover_point1) = parent1(1:crossover_point1);
            child(crossover_point1+1:crossover_point2) = parent2(crossover_point1+1:crossover_point2);
            child(crossover_point2+1:end) = parent1(crossover_point2+1:end);
    end
end

% Weryfikacja integralności potomka
if length(child) ~= num_genes
    disp(['BŁĄD: Potomek ma nieprawidłową długość: ', num2str(length(child)), ...
        ' zamiast ', num2str(num_genes)]);
    % Napraw potomka
    if length(child) < num_genes
        full_child = ones(1, num_genes);
        full_child(1:length(child)) = child;
        child = full_child;
    else
        child = child(1:num_genes);
    end
end

end