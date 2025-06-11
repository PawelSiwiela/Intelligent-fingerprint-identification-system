function visualizeROC(y_pred, y_true, network_name, save_path, labels)
% VISUALIZEROC Wizualizacja krzywej ROC dla sieci neuronowej
%
% Składnia:
%   visualizeROC(y_pred, y_true, network_name, save_path, labels)
%
% Argumenty:
%   y_pred - macierz przewidywań sieci [klasy × próbki]
%   y_true - macierz prawdziwych etykiet [klasy × próbki]
%   network_name - opcjonalna nazwa sieci (domyślnie 'Sieć neuronowa')
%   save_path - opcjonalna ścieżka do zapisu wykresu
%   labels - opcjonalna tablica z nazwami klas (np. {'a/normalnie', 'a/szybko'})

% Domyślna nazwa sieci
if nargin < 3
    network_name = 'Sieć neuronowa';
end

% Domyślnie brak zapisu
if nargin < 4
    save_path = '';
end

% Domyślnie brak nazw klas
if nargin < 5
    % Domyślne etykiety klas
    [num_classes, ~] = size(y_true);
    labels = cell(1, num_classes);
    for i = 1:num_classes
        labels{i} = sprintf('Klasa %d', i);
    end
end

try
    % Utworzenie figury z unikalnym uchwytem
    h = figure('Name', sprintf('Krzywa ROC - %s', network_name), 'Position', [200, 200, 800, 600]);
    
    try
        % Próba użycia plotroc z Neural Network Toolbox z niestandardowymi etykietami
        plotroc(y_true, y_pred);
        title(sprintf('Krzywa ROC - %s', network_name));
        
        % Próba zmiany etykiet legendy jeśli jest dostępna
        hLegend = findobj(h, 'Type', 'Legend');
        if ~isempty(hLegend) && length(hLegend.String) == length(labels)
            for i = 1:length(labels)
                hLegend.String{i} = strrep(hLegend.String{i}, sprintf('Class %d', i), labels{i});
            end
        end
    catch
        % Alternatywna metoda dla braku plotroc
        [num_classes, num_samples] = size(y_true);
        
        % Obsługa maksymalnie 8 klas na jednym wykresie
        max_classes = min(8, num_classes);
        
        hold on;
        colors = {'b', 'r', 'g', 'm', 'c', 'y', [0.8 0.4 0], [0.5 0 0.5]};  % Rozszerzona paleta kolorów
        legend_entries = cell(1, max_classes);
        
        for i = 1:max_classes
            % Obliczenie TPR i FPR dla różnych progów
            [tpr, fpr, ~] = roc_curve(y_true(i,:), y_pred(i,:));
            
            % Obliczenie AUC (Area Under Curve)
            auc_value = trapz(fpr, tpr);
            
            % Rysowanie krzywej ROC
            plot(fpr, tpr, [colors{mod(i-1, length(colors))+1}, '-'], 'LineWidth', 2);
            
            % Używaj nazw klas z parametru labels
            legend_entries{i} = sprintf('%s (AUC = %.3f)', labels{i}, auc_value);
        end
        
        % Linia odniesienia (random classifier)
        plot([0, 1], [0, 1], 'k--');
        
        xlabel('False Positive Rate (1 - Specyficzność)', 'FontSize', 11);
        ylabel('True Positive Rate (Czułość)', 'FontSize', 11);
        title(sprintf('Krzywe ROC - %s', network_name), 'FontSize', 14);
        
        % Tworzenie legendy z niestandardowymi nazwami
        legend(legend_entries, 'Location', 'southeast', 'FontSize', 9);
        grid on;
        axis([0 1 0 1]);
        hold off;
    end
    
    % Zapisanie wizualizacji jeśli podano ścieżkę
    if ~isempty(save_path)
        % Sprawdzenie czy folder istnieje, jeśli nie - utworzenie
        viz_dir = fileparts(save_path);
        if ~exist(viz_dir, 'dir')
            mkdir(viz_dir);
            logInfo('📁 Utworzono katalog dla wizualizacji: %s', viz_dir);
        end
        
        % Zapisanie figury
        saveas(h, save_path);
        logInfo('💾 Zapisano wizualizację ROC do: %s', save_path);
    end
    
catch e
    logWarning('❌ Błąd podczas generowania krzywej ROC: %s', e.message);
end
end

function [tpr, fpr, thresholds] = roc_curve(y_true, y_pred)
% Implementacja funkcji obliczającej krzywą ROC
thresholds = sort(y_pred, 'descend');
thresholds = [1.1*max(y_pred), thresholds, 0]; % Dodanie skrajnych progów

n_thresholds = length(thresholds);
tpr = zeros(1, n_thresholds);
fpr = zeros(1, n_thresholds);

n_pos = sum(y_true);
n_neg = length(y_true) - n_pos;

for i = 1:n_thresholds
    y_pred_binary = (y_pred >= thresholds(i));
    
    % True Positive
    tp = sum(y_pred_binary & (y_true == 1));
    % False Positive
    fp = sum(y_pred_binary & (y_true == 0));
    
    % True Positive Rate (Sensitivity, Recall)
    if n_pos > 0
        tpr(i) = tp / n_pos;
    else
        tpr(i) = 0;
    end
    
    % False Positive Rate (Fall-out)
    if n_neg > 0
        fpr(i) = fp / n_neg;
    else
        fpr(i) = 0;
    end
end
end