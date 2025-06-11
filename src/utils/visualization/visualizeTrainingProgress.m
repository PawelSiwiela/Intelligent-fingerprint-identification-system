function visualizeROC(y_pred, y_true, network_name, save_path, labels)
% VISUALIZEROC Wizualizacja krzywej ROC dla porównania PatternNet vs CNN
%
% Składnia:
%   visualizeROC(y_pred, y_true, network_name, save_path, labels)
%
% Argumenty:
%   y_pred - macierz przewidywań sieci [klasy × próbki]
%   y_true - macierz prawdziwych etykiet [klasy × próbki]
%   network_name - nazwa sieci ('PatternNet' lub 'CNN')
%   save_path - ścieżka do zapisu wykresu
%   labels - nazwy klas odcisków palców ['Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały']

% Domyślna nazwa sieci
if nargin < 3
    network_name = 'Sieć neuronowa';
end

% Domyślnie brak zapisu
if nargin < 4
    save_path = '';
end

% Domyślne etykiety dla odcisków palców
if nargin < 5
    labels = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};
end

try
    % Utworzenie figury z odpowiednim tytułem
    h = figure('Name', sprintf('Krzywa ROC - %s (Odciski Palców)', network_name), 'Position', [200, 200, 800, 600]);
    
    try
        % Próba użycia plotroc z Neural Network Toolbox
        plotroc(y_true, y_pred);
        title(sprintf('Krzywa ROC - %s\n(Klasyfikacja Odcisków Palców)', network_name));
        
        % Zmień etykiety legendy na nazwy palców
        hLegend = findobj(h, 'Type', 'Legend');
        if ~isempty(hLegend) && length(hLegend.String) >= length(labels)
            for i = 1:length(labels)
                % Znajdź i zastąp standardowe etykiety
                old_label = sprintf('Class %d', i);
                if i <= length(hLegend.String)
                    hLegend.String{i} = strrep(hLegend.String{i}, old_label, labels{i});
                end
            end
        end
    catch
        % Alternatywna metoda - ręczne rysowanie krzywych ROC
        [num_classes, num_samples] = size(y_true);
        
        % Ograniczenie do 5 klas (palców)
        max_classes = min(5, num_classes);
        
        hold on;
        colors = {'#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd'};  % Kolory dla 5 palców
        legend_entries = cell(1, max_classes);
        
        for i = 1:max_classes
            % Obliczenie TPR i FPR dla różnych progów
            [tpr, fpr, ~] = roc_curve(y_true(i,:), y_pred(i,:));
            
            % Obliczenie AUC (Area Under Curve)
            auc_value = trapz(fpr, tpr);
            
            % Rysowanie krzywej ROC dla każdego palca
            plot(fpr, tpr, 'Color', colors{i}, 'LineWidth', 2.5);
            
            % Etykieta z nazwą palca i AUC
            legend_entries{i} = sprintf('%s (AUC = %.3f)', labels{i}, auc_value);
        end
        
        % Linia odniesienia (random classifier)
        plot([0, 1], [0, 1], 'k--', 'LineWidth', 1);
        
        xlabel('False Positive Rate (1 - Specyficzność)', 'FontSize', 12);
        ylabel('True Positive Rate (Czułość)', 'FontSize', 12);
        title(sprintf('Krzywe ROC - %s\n(Klasyfikacja Odcisków Palców)', network_name), 'FontSize', 14);
        
        % Legenda z nazwami palców
        legend([legend_entries, {'Random Classifier'}], 'Location', 'southeast', 'FontSize', 10);
        grid on;
        axis([0 1 0 1]);
        hold off;
    end
    
    % Zapisanie wizualizacji
    if ~isempty(save_path)
        viz_dir = fileparts(save_path);
        if ~exist(viz_dir, 'dir')
            mkdir(viz_dir);
            logInfo('📁 Utworzono katalog dla wizualizacji: %s', viz_dir);
        end
        
        saveas(h, save_path);
        logInfo('💾 Zapisano krzywą ROC dla %s: %s', network_name, save_path);
    end
    
catch e
    logWarning('❌ Błąd podczas generowania krzywej ROC dla %s: %s', network_name, e.message);
end
end

% Funkcja pomocnicza pozostaje bez zmian
function [tpr, fpr, thresholds] = roc_curve(y_true, y_pred)
thresholds = sort(y_pred, 'descend');
thresholds = [1.1*max(y_pred), thresholds, 0];

n_thresholds = length(thresholds);
tpr = zeros(1, n_thresholds);
fpr = zeros(1, n_thresholds);

n_pos = sum(y_true);
n_neg = length(y_true) - n_pos;

for i = 1:n_thresholds
    y_pred_binary = (y_pred >= thresholds(i));
    
    tp = sum(y_pred_binary & (y_true == 1));
    fp = sum(y_pred_binary & (y_true == 0));
    
    if n_pos > 0
        tpr(i) = tp / n_pos;
    else
        tpr(i) = 0;
    end
    
    if n_neg > 0
        fpr(i) = fp / n_neg;
    else
        fpr(i) = 0;
    end
end
end