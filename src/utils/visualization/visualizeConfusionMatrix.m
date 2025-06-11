function visualizeConfusionMatrix(confusion_matrix, labels, title_text, save_path)
% VISUALIZECONFUSIONMATRIX Macierz konfuzji dla klasyfikacji odcisków palców
%
% Składnia:
%   visualizeConfusionMatrix(confusion_matrix, labels, title_text, save_path)
%
% Argumenty:
%   confusion_matrix - macierz konfuzji [5×5] dla 5 palców
%   labels - etykiety palców ['Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały']
%   title_text - tytuł ('PatternNet' lub 'CNN')
%   save_path - ścieżka zapisu

% Domyślne etykiety dla odcisków palców
if nargin < 2 || isempty(labels)
    labels = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};
end

% Domyślny tytuł
if nargin < 3
    title_text = 'Macierz Konfuzji - Klasyfikacja Odcisków Palców';
end

if nargin < 4
    save_path = '';
end

% Obliczenie dokładności
accuracy = sum(diag(confusion_matrix)) / sum(confusion_matrix(:));

try
    % Utworzenie figury
    h = figure('Name', title_text, 'Position', [200, 200, 900, 700]);
    
    try
        % Próba użycia confusionchart (Machine Learning Toolbox)
        cm = confusionchart(confusion_matrix, labels);
        cm.Title = sprintf('%s\nDokładność: %.2f%% (Odciski Palców)', title_text, accuracy * 100);
        cm.ColumnSummary = 'column-normalized';
        cm.RowSummary = 'row-normalized';
        
        % Dostosowanie rozmiaru czcionki dla lepszej czytelności
        cm.FontSize = 12;
        
        % Kolorystyka - ciepła paleta dla odcisków palców
        colormap(hot);
        
    catch
        % Alternatywna metoda - heatmapa
        imagesc(confusion_matrix);
        
        % Kolorystyka
        colormap(hot);
        colorbar;
        
        % Etykiety osi z nazwami palców
        xticks(1:length(labels));
        yticks(1:length(labels));
        xticklabels(labels);
        yticklabels(labels);
        xlabel('Przewidziany Palec', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Rzeczywisty Palec', 'FontSize', 12, 'FontWeight', 'bold');
        
        % Tytuł z dokładnością
        title(sprintf('%s\nDokładność: %.2f%% (Klasyfikacja Odcisków Palców)', ...
            title_text, accuracy * 100), 'FontSize', 14, 'FontWeight', 'bold');
        
        % Dodanie wartości w komórkach
        for i = 1:size(confusion_matrix, 1)
            for j = 1:size(confusion_matrix, 2)
                value = confusion_matrix(i, j);
                if value > 0
                    % Wybór koloru tekstu w zależności od jasności tła
                    if value > max(confusion_matrix(:)) * 0.5
                        text_color = 'white';
                    else
                        text_color = 'black';
                    end
                    
                    text(j, i, num2str(value), ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', ...
                        'Color', text_color, ...
                        'FontWeight', 'bold', ...
                        'FontSize', 12);
                end
            end
        end
        
        % Dostosowanie osi
        set(gca, 'FontSize', 11);
        
        % Dodanie siatki dla lepszej czytelności
        grid on;
        set(gca, 'GridColor', 'white', 'GridLineStyle', '-', 'GridAlpha', 0.3);
    end
    
    % Dodanie dodatkowych informacji o klasyfikacji
    if accuracy >= 0.90
        accuracy_comment = 'Doskonała klasyfikacja';
        comment_color = [0, 0.8, 0];
    elseif accuracy >= 0.80
        accuracy_comment = 'Bardzo dobra klasyfikacja';
        comment_color = [0.5, 0.8, 0];
    elseif accuracy >= 0.70
        accuracy_comment = 'Dobra klasyfikacja';
        comment_color = [0.8, 0.8, 0];
    elseif accuracy >= 0.60
        accuracy_comment = 'Średnia klasyfikacja';
        comment_color = [0.8, 0.5, 0];
    else
        accuracy_comment = 'Słaba klasyfikacja';
        comment_color = [0.8, 0, 0];
    end
    
    % Dodanie komentarza jako adnotacji
    annotation('textbox', [0.02, 0.02, 0.3, 0.08], ...
        'String', accuracy_comment, ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'Color', comment_color, ...
        'BackgroundColor', [0.95, 0.95, 0.95], ...
        'EdgeColor', comment_color, ...
        'FitBoxToText', 'on');
    
    % Zapisanie wizualizacji
    if ~isempty(save_path)
        viz_dir = fileparts(save_path);
        if ~exist(viz_dir, 'dir')
            mkdir(viz_dir);
            logInfo('📁 Utworzono katalog dla wizualizacji: %s', viz_dir);
        end
        
        saveas(h, save_path);
        logInfo('💾 Zapisano macierz konfuzji %s: %s', title_text, save_path);
    end
    
catch e
    logWarning('⚠️ Problem z macierzą konfuzji dla %s: %s', title_text, e.message);
    
    % Tekstowe wyświetlenie macierzy
    fprintf('\n=== MACIERZ KONFUZJI - %s ===\n', upper(title_text));
    fprintf('Dokładność: %.2f%%\n\n', accuracy * 100);
    fprintf('%-12s', '');
    for j = 1:length(labels)
        fprintf('%-8s', labels{j}(1:min(8,end)));
    end
    fprintf('\n');
    
    for i = 1:size(confusion_matrix, 1)
        fprintf('%-12s', labels{i}(1:min(12,end)));
        for j = 1:size(confusion_matrix, 2)
            fprintf('%-8d', confusion_matrix(i, j));
        end
        fprintf('\n');
    end
end
end