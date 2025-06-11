function visualizeMetricsComparison(metrics1, metrics2, network1_name, network2_name, save_path)
% VISUALIZEMETRICSCOMPARISON Porównuje wizualnie metryki PatternNet vs CNN
%
% Składnia:
%   visualizeMetricsComparison(metrics1, metrics2, network1_name, network2_name, save_path)
%
% Argumenty:
%   metrics1 - struktura metryk pierwszej sieci (PatternNet)
%   metrics2 - struktura metryk drugiej sieci (CNN)
%   network1_name - nazwa pierwszej sieci ('PatternNet')
%   network2_name - nazwa drugiej sieci ('CNN')
%   save_path - ścieżka do zapisu wykresu

% Domyślne nazwy dla porównania odcisków palców
if nargin < 3
    network1_name = 'PatternNet';
    network2_name = 'CNN';
elseif nargin < 4
    network2_name = 'CNN';
end

if nargin < 5
    save_path = '';
end

try
    % Metryki dla klasyfikacji odcisków palców
    metric_names = {'Dokładność', 'Precyzja', 'Czułość', 'F1-Score'};
    
    % Przygotowanie danych
    values1 = [
        metrics1.accuracy,
        metrics1.macro_precision,
        metrics1.macro_recall,
        metrics1.macro_f1
        ];
    
    values2 = [
        metrics2.accuracy,
        metrics2.macro_precision,
        metrics2.macro_recall,
        metrics2.macro_f1
        ];
    
    % Utworzenie figury z lepszym layoutem
    h = figure('Name', 'Porównanie PatternNet vs CNN', 'Position', [100, 100, 1200, 700]);
    
    % Kolory charakterystyczne dla każdego typu sieci
    color1 = [0.2, 0.6, 0.8];  % Niebieski dla PatternNet
    color2 = [0.8, 0.2, 0.4];  % Czerwony dla CNN
    
    % SUBPLOT 1: Porównanie bezpośrednie
    subplot(2, 2, [1, 2]);
    x = 1:length(metric_names);
    width = 0.35;
    
    b1 = bar(x - width/2, values1 * 100, width, 'FaceColor', color1, 'DisplayName', network1_name);
    hold on;
    b2 = bar(x + width/2, values2 * 100, width, 'FaceColor', color2, 'DisplayName', network2_name);
    
    title('Porównanie Metryk: PatternNet vs CNN (Odciski Palców)', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel('Wartość (%)', 'FontSize', 12);
    xlabel('Metryki', 'FontSize', 12);
    set(gca, 'XTick', x, 'XTickLabel', metric_names, 'FontSize', 11);
    legend('Location', 'northwest', 'FontSize', 11);
    grid on;
    ylim([0, 100]);
    
    % Dodanie wartości nad słupkami
    for i = 1:length(values1)
        text(x(i) - width/2, values1(i) * 100 + 2, sprintf('%.1f%%', values1(i) * 100), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 10);
        text(x(i) + width/2, values2(i) * 100 + 2, sprintf('%.1f%%', values2(i) * 100), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 10);
    end
    
    % SUBPLOT 2: Różnice między sieciami
    subplot(2, 2, 3);
    differences = (values2 - values1) * 100;  % Różnica CNN - PatternNet
    bar_colors = differences;
    bar_colors(bar_colors >= 0) = 1;  % Zielony dla pozytywnych różnic
    bar_colors(bar_colors < 0) = -1;  % Czerwony dla negatywnych różnic
    
    b3 = bar(differences);
    for i = 1:length(differences)
        if differences(i) >= 0
            b3.CData(i,:) = [0.2, 0.8, 0.2];  % Zielony
        else
            b3.CData(i,:) = [0.8, 0.2, 0.2];  % Czerwony
        end
    end
    
    title('Różnica: CNN - PatternNet', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Różnica (%)', 'FontSize', 11);
    set(gca, 'XTick', 1:length(metric_names), 'XTickLabel', metric_names, 'FontSize', 10);
    grid on;
    
    % Linia na poziomie 0
    hold on;
    plot([0.5, length(metric_names)+0.5], [0, 0], 'k--', 'LineWidth', 1);
    
    % Wartości nad słupkami
    for i = 1:length(differences)
        if differences(i) >= 0
            text(i, differences(i) + 0.5, sprintf('+%.1f%%', differences(i)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9);
        else
            text(i, differences(i) - 0.5, sprintf('%.1f%%', differences(i)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9);
        end
    end
    
    % SUBPLOT 3: Czas predykcji
    subplot(2, 2, 4);
    prediction_times = [metrics1.prediction_time * 1000, metrics2.prediction_time * 1000];  % ms
    network_names = {network1_name, network2_name};
    
    b4 = bar(prediction_times, 'FaceColor', [0.7, 0.7, 0.7]);
    b4.CData(1,:) = color1;
    b4.CData(2,:) = color2;
    
    title('Czas Predykcji', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Czas (ms)', 'FontSize', 11);
    set(gca, 'XTick', 1:2, 'XTickLabel', network_names, 'FontSize', 11);
    grid on;
    
    % Wartości nad słupkami
    for i = 1:2
        text(i, prediction_times(i) + max(prediction_times)*0.05, ...
            sprintf('%.2f ms', prediction_times(i)), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 10);
    end
    
    % Ogólny tytuł dla całej figury
    sgtitle('Analiza Porównawcza Sieci Neuronowych dla Klasyfikacji Odcisków Palców', ...
        'FontSize', 16, 'FontWeight', 'bold');
    
    % Zapisanie wizualizacji
    if ~isempty(save_path)
        viz_dir = fileparts(save_path);
        if ~exist(viz_dir, 'dir')
            mkdir(viz_dir);
            logInfo('📁 Utworzono katalog dla wizualizacji: %s', viz_dir);
        end
        
        saveas(h, save_path);
        logInfo('💾 Zapisano porównanie metryk PatternNet vs CNN: %s', save_path);
    end
    
catch e
    logWarning('❌ Błąd podczas generowania porównania metryk: %s', e.message);
    
    % Awaryjne wyświetlanie danych tekstowo
    fprintf('\n=== PORÓWNANIE PATTERNNET VS CNN ===\n');
    fprintf('                    PatternNet    CNN         Różnica\n');
    fprintf('Dokładność:         %.2f%%       %.2f%%      %+.2f%%\n', ...
        metrics1.accuracy*100, metrics2.accuracy*100, (metrics2.accuracy-metrics1.accuracy)*100);
    fprintf('Precyzja:           %.2f%%       %.2f%%      %+.2f%%\n', ...
        metrics1.macro_precision*100, metrics2.macro_precision*100, (metrics2.macro_precision-metrics1.macro_precision)*100);
    fprintf('Czułość:            %.2f%%       %.2f%%      %+.2f%%\n', ...
        metrics1.macro_recall*100, metrics2.macro_recall*100, (metrics2.macro_recall-metrics1.macro_recall)*100);
    fprintf('F1-Score:           %.2f%%       %.2f%%      %+.2f%%\n', ...
        metrics1.macro_f1*100, metrics2.macro_f1*100, (metrics2.macro_f1-metrics1.macro_f1)*100);
    fprintf('Czas predykcji:     %.2fms       %.2fms      %+.2fms\n', ...
        metrics1.prediction_time*1000, metrics2.prediction_time*1000, (metrics2.prediction_time-metrics1.prediction_time)*1000);
end
end