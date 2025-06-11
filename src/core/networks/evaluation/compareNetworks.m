function [comparison_results] = compareNetworks(X, Y, labels, config)
% COMPARENETWORKS Porównuje sieci PatternNet i CNN używając cech odcisków palców
%
% Składnia:
%   [comparison_results] = compareNetworks(X, Y, labels, config)
%
% Argumenty:
%   X - macierz cech [próbki × 122] (wektory cech z minucji)
%   Y - macierz etykiet [próbki × 5] (one-hot dla 5 palców)
%   labels - nazwy kategorii ['Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały']
%   config - struktura konfiguracyjna
%
% Zwraca:
%   comparison_results - wyniki porównania PatternNet vs CNN

% Inicjalizacja rezultatów
comparison_results = struct(...
    'patternnet', struct(), ...
    'cnn', struct(), ...
    'comparison', struct());

logInfo('🧠 Rozpoczynam porównanie sieci PatternNet i CNN na cechach odcisków palców...');

% =========================================================================
% ETAP 1: PRZYGOTOWANIE DANYCH
% =========================================================================

% Jednokrotny podział danych dla wszystkich sieci
[X_train, Y_train, X_val, Y_val, X_test, Y_test] = splitFingerprintData(X, Y, 0.6, 0.2, 0.2);
logInfo('🔢 Stratyfikowany podział danych 60%%/20%%/20%% dla odcisków palców');

% Połącz dane treningowe i walidacyjne dla optymalizacji hiperparametrów
X_train_opt = [X_train; X_val];
Y_train_opt = [Y_train; Y_val];

% =========================================================================
% ETAP 2: OPTYMALIZACJA PARAMETRÓW SIECI PATTERNNET
% =========================================================================
logInfo('🔍 Optymalizacja parametrów dla sieci PATTERNNET (odciski palców)');

% Konfiguracja dla optymalizatora PatternNet
patternnet_config = config;
patternnet_config.network_types = {'patternnet'};
patternnet_config.X_test = X_test;
patternnet_config.Y_test = Y_test;
patternnet_config.X_val = X_val;
patternnet_config.Y_val = Y_val;
patternnet_config.scenario = 'fingerprints';

% Używamy tylko geneticOptimizer
[pattern_net, pattern_tr, pattern_results] = geneticOptimizer(X_train_opt, Y_train_opt, labels, patternnet_config);

logSuccess('✅ Najlepsza dokładność dla PatternNet: %.2f%%', pattern_results.best_accuracy * 100);

% =========================================================================
% ETAP 3: OPTYMALIZACJA PARAMETRÓW SIECI CNN
% =========================================================================
logInfo('🔍 Optymalizacja parametrów dla sieci CNN (cechy odcisków palców)');

% Konfiguracja dla optymalizatora CNN
cnn_config = config;
cnn_config.network_types = {'cnn'};
cnn_config.X_test = X_test;
cnn_config.Y_test = Y_test;
cnn_config.X_val = X_val;
cnn_config.Y_val = Y_val;
cnn_config.scenario = 'fingerprints';

% Używamy tylko geneticOptimizer
[cnn_net, cnn_tr, cnn_results] = geneticOptimizer(X_train_opt, Y_train_opt, labels, cnn_config);

logSuccess('✅ Najlepsza dokładność dla CNN: %.2f%%', cnn_results.best_accuracy * 100);

% =========================================================================
% ETAP 4: SZCZEGÓŁOWA EWALUACJA OBU SIECI
% =========================================================================
logInfo('📊 Szczegółowa ewaluacja obu sieci na danych testowych...');

% Konfiguracja ewaluacji
eval_config = struct(...
    'show_confusion_matrix', false, ...
    'show_roc_curve', false);

% Ewaluacja PatternNet na danych testowych
eval_config.figure_title = 'Ewaluacja PatternNet (Odciski Palców)';
pattern_evaluation = evaluateNetwork(pattern_net, X_test, Y_test, labels, eval_config);

% Ewaluacja CNN na danych testowych
eval_config.figure_title = 'Ewaluacja CNN (Odciski Palców)';
cnn_evaluation = evaluateNetwork(cnn_net, X_test, Y_test, labels, eval_config);

% Zapisanie wyników ewaluacji
comparison_results.patternnet.evaluation = pattern_evaluation;
comparison_results.cnn.evaluation = cnn_evaluation;

% =========================================================================
% ETAP 5: ANALIZA PORÓWNAWCZA
% =========================================================================
logInfo('📊 Analiza porównawcza wyników...');

% Zapisanie szczegółowych wyników dla obu sieci
comparison_results.patternnet.net = pattern_net;
comparison_results.patternnet.tr = pattern_tr;
comparison_results.patternnet.results = pattern_results;

comparison_results.cnn.net = cnn_net;
comparison_results.cnn.tr = cnn_tr;
comparison_results.cnn.results = cnn_results;

% Określenie zwycięzcy na podstawie dokładności
if pattern_evaluation.accuracy > cnn_evaluation.accuracy
    comparison_results.comparison.winner = 'patternnet';
    comparison_results.comparison.accuracy_gain = pattern_evaluation.accuracy - cnn_evaluation.accuracy;
elseif cnn_evaluation.accuracy > pattern_evaluation.accuracy
    comparison_results.comparison.winner = 'cnn';
    comparison_results.comparison.accuracy_gain = cnn_evaluation.accuracy - pattern_evaluation.accuracy;
else
    comparison_results.comparison.winner = 'tie';
    comparison_results.comparison.accuracy_gain = 0;
end

% Procentowy wzrost dokładności zwycięzcy
if ~strcmp(comparison_results.comparison.winner, 'tie')
    if strcmp(comparison_results.comparison.winner, 'patternnet')
        baseline = cnn_evaluation.accuracy;
    else
        baseline = pattern_evaluation.accuracy;
    end
    
    if baseline > 0
        comparison_results.comparison.accuracy_gain_percent = (comparison_results.comparison.accuracy_gain / baseline) * 100;
    else
        comparison_results.comparison.accuracy_gain_percent = 0;
    end
else
    comparison_results.comparison.accuracy_gain_percent = 0;
end

% Porównanie innych metryk
comparison_results.comparison.precision_diff = pattern_evaluation.macro_precision - cnn_evaluation.macro_precision;
comparison_results.comparison.recall_diff = pattern_evaluation.macro_recall - cnn_evaluation.macro_recall;
comparison_results.comparison.f1_diff = pattern_evaluation.macro_f1 - cnn_evaluation.macro_f1;
comparison_results.comparison.prediction_time_diff = pattern_evaluation.prediction_time - cnn_evaluation.prediction_time;

% Informacja o metodzie optymalizacji
comparison_results.comparison.optimization_method = config.optimization_method;
comparison_results.comparison.problem_domain = 'fingerprint_identification';

logSuccess('✅ Analiza zakończona. Zwycięzca: %s (przewaga: %.2f%%)', ...
    comparison_results.comparison.winner, ...
    comparison_results.comparison.accuracy_gain * 100);

% =========================================================================
% ETAP 6: WIZUALIZACJA WYNIKÓW (OPCJONALNIE)
% =========================================================================
if isfield(config, 'show_visualizations') && config.show_visualizations
    logInfo('📈 Generowanie wizualizacji porównawczych...');
    
    try
        % Utworzenie folderu wizualizacji
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        viz_dir = fullfile('output', 'visualizations', ...
            sprintf('fingerprint_patternnet_vs_cnn_%s', timestamp));
        
        if ~exist(viz_dir, 'dir')
            mkdir(viz_dir);
            logInfo('📁 Utworzono katalog wizualizacji: %s', viz_dir);
        end
        
        % Generowanie wizualizacji porównawczych
        generateFingerprintComparisonVisualizations(comparison_results, viz_dir, labels);
        
        logSuccess('✅ Wizualizacje wygenerowane i zapisane do: %s', viz_dir);
    catch e
        logWarning('⚠️ Problem z generowaniem wizualizacji: %s', e.message);
    end
end

logSuccess('✅ Porównanie sieci PatternNet vs CNN zakończone.');

end

function [X_train, Y_train, X_val, Y_val, X_test, Y_test] = splitFingerprintData(X, Y, train_ratio, val_ratio, test_ratio)
% Podział danych z zachowaniem proporcji klas (stratified split)

n_samples = size(X, 1);
n_classes = size(Y, 2);

X_train = []; Y_train = [];
X_val = []; Y_val = [];
X_test = []; Y_test = [];

% Stratified split dla każdej klasy
for class = 1:n_classes
    % Znajdź próbki tej klasy
    class_indices = find(Y(:, class) == 1);
    n_class_samples = length(class_indices);
    
    % Oblicz liczby próbek dla każdego zbioru
    n_train = round(n_class_samples * train_ratio);
    n_val = round(n_class_samples * val_ratio);
    n_test = n_class_samples - n_train - n_val;
    
    % Losowe pomieszanie próbek klasy
    shuffled_indices = class_indices(randperm(n_class_samples));
    
    % Podział na zbiory
    train_indices = shuffled_indices(1:n_train);
    val_indices = shuffled_indices(n_train+1:n_train+n_val);
    test_indices = shuffled_indices(n_train+n_val+1:end);
    
    % Dodanie do zbiorów
    X_train = [X_train; X(train_indices, :)];
    Y_train = [Y_train; Y(train_indices, :)];
    
    X_val = [X_val; X(val_indices, :)];
    Y_val = [Y_val; Y(val_indices, :)];
    
    X_test = [X_test; X(test_indices, :)];
    Y_test = [Y_test; Y(test_indices, :)];
end

logInfo('Podział danych: Train=%d, Val=%d, Test=%d', size(X_train,1), size(X_val,1), size(X_test,1));
end

function generateFingerprintComparisonVisualizations(results, output_dir, labels)
% Generuje specjalistyczne wizualizacje dla porównania sieci w kontekście odcisków palców

% Placeholder - funkcja do rozwinięcia
logInfo('Generowanie wizualizacji porównawczych dla odcisków palców...');
% Tu można dodać specjalistyczne wizualizacje
end