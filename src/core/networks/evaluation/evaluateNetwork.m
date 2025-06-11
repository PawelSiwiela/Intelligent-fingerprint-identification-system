function [evaluation_results] = evaluateNetwork(net, X, Y, labels, config)
% EVALUATENETWORK Ewaluuje wytrenowaną sieć neuronową
%
% Składnia:
%   [evaluation_results] = evaluateNetwork(net, X, Y, labels, config)
%
% Argumenty:
%   net - wytrenowana sieć neuronowa
%   X - macierz cech [próbki × cechy]
%   Y - macierz etykiet [próbki × kategorie] (one-hot encoding)
%   labels - nazwy kategorii (cell array)
%   config - struktura konfiguracyjna z polami:
%     .show_confusion_matrix - czy pokazać wizualizację macierzy pomyłek
%     .show_roc_curve - czy pokazać krzywą ROC
%
% Zwraca:
%   evaluation_results - struktura z wynikami ewaluacji

% Domyślne parametry
if nargin < 5
    config = struct();
end

if ~isfield(config, 'show_confusion_matrix')
    config.show_confusion_matrix = true;
end

if ~isfield(config, 'show_roc_curve')
    config.show_roc_curve = false;  % ROC tylko gdy jawnie wskazane
end

if ~isfield(config, 'figure_title')
    config.figure_title = 'Ewaluacja sieci';
end

% Transpozycja danych do formatu wymaganego przez Neural Network Toolbox
X_net = X';
Y_net = Y';

% Predykcje sieci
tic;
y_pred = net(X_net);
prediction_time = toc;

[~, pred_idx] = max(y_pred, [], 1);
[~, true_idx] = max(Y_net, [], 1);

% Podstawowe metryki
accuracy = sum(pred_idx == true_idx) / length(true_idx);

% Bezpieczne utworzenie macierzy konfuzji
num_classes = size(Y, 2);
try
    % Upewnij się, że wszystkie indeksy są w prawidłowym zakresie
    if max(pred_idx) > num_classes || max(true_idx) > num_classes
        logWarning('⚠️ Wykryto indeksy klas poza zakresem - przycinanie do dozwolonego zakresu');
        pred_idx = min(pred_idx, num_classes);
        true_idx = min(true_idx, num_classes);
    end
    
    % Utworzenie macierzy konfuzji
    confusion_matrix = confusionmat(true_idx, pred_idx);
    
    % Sprawdź czy macierz konfuzji ma oczekiwany rozmiar
    if size(confusion_matrix, 1) < num_classes
        logInfo('Rozszerzanie macierzy konfuzji do pełnego rozmiaru %dx%d', num_classes, num_classes);
        temp = zeros(num_classes, num_classes);
        temp(1:size(confusion_matrix,1), 1:size(confusion_matrix,2)) = confusion_matrix;
        confusion_matrix = temp;
    end
catch e
    logWarning('⚠️ Problem z utworzeniem macierzy konfuzji: %s', e.message);
    % Utworzenie pustej macierzy konfuzji
    confusion_matrix = zeros(num_classes, num_classes);
    
    % Ręczne wypełnienie macierzy konfuzji
    for i = 1:length(true_idx)
        if true_idx(i) <= num_classes && pred_idx(i) <= num_classes
            confusion_matrix(true_idx(i), pred_idx(i)) = confusion_matrix(true_idx(i), pred_idx(i)) + 1;
        end
    end
end

% Obliczenie metryk dla każdej klasy
precision = zeros(num_classes, 1);
recall = zeros(num_classes, 1);
f1_score = zeros(num_classes, 1);

for i = 1:num_classes
    true_positives = confusion_matrix(i, i);
    false_positives = sum(confusion_matrix(:, i)) - true_positives;
    false_negatives = sum(confusion_matrix(i, :)) - true_positives;
    
    % Precision = TP / (TP + FP)
    if (true_positives + false_positives) > 0
        precision(i) = true_positives / (true_positives + false_positives);
    else
        precision(i) = 0;
    end
    
    % Recall = TP / (TP + FN)
    if (true_positives + false_negatives) > 0
        recall(i) = true_positives / (true_positives + false_negatives);
    else
        recall(i) = 0;
    end
    
    % F1 Score = 2 * (Precision * Recall) / (Precision + Recall)
    if (precision(i) + recall(i)) > 0
        f1_score(i) = 2 * (precision(i) * recall(i)) / (precision(i) + recall(i));
    else
        f1_score(i) = 0;
    end
end

% Średnie metryki
macro_precision = mean(precision);
macro_recall = mean(recall);
macro_f1 = mean(f1_score);

% Przygotowanie wyników ewaluacji
evaluation_results = struct(...
    'accuracy', accuracy, ...
    'confusion_matrix', confusion_matrix, ...
    'precision', precision, ...
    'recall', recall, ...
    'f1_score', f1_score, ...
    'macro_precision', macro_precision, ...
    'macro_recall', macro_recall, ...
    'macro_f1', macro_f1, ...
    'prediction_time', prediction_time);

% Wizualizacje (opcjonalne)
if config.show_confusion_matrix
    try
        figure('Name', config.figure_title, 'Position', [200, 200, 800, 600]);
        confusionchart(confusion_matrix, labels);
        title(sprintf('Dokładność: %.2f%%', accuracy * 100));
    catch e
        logWarning('⚠️ Problem z wyświetleniem macierzy konfuzji: %s', e.message);
    end
end

if config.show_roc_curve && size(Y, 2) <= 10  % ROC tylko dla niezbyt wielu klas
    try
        figure('Name', [config.figure_title ' - Krzywe ROC'], 'Position', [200, 200, 800, 600]);
        plotroc(Y_net, y_pred);
        title('Krzywe ROC dla wszystkich klas');
    catch e
        logWarning('⚠️ Problem z wyświetleniem krzywych ROC: %s', e.message);
    end
end

end