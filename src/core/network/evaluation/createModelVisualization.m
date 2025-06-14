function createModelVisualization(model, results, modelType, testData)
% CREATEMODELVISUALIZATION Proste, klasyczne metryki ML

outputDir = 'output/figures';
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% Prosta figura 2x2
figure('Position', [50, 50, 1000, 800]);

%% 1. CONFUSION MATRIX (górny lewy)
subplot(2, 2, 1);
plotSimpleConfusionMatrix(results, sprintf('%s Confusion Matrix', upper(modelType)));

%% 2. KLASYCZNE METRYKI (górny prawy)
subplot(2, 2, 2);
plotClassicMetrics(results, sprintf('%s Classification Metrics', upper(modelType)));

%% 3. VAL vs TEST PORÓWNANIE (dolny lewy)
subplot(2, 2, 3);
plotValTestComparison(results, sprintf('%s Val vs Test Performance', upper(modelType)));

%% 4. PER-CLASS METRICS (dolny prawy)
subplot(2, 2, 4);
plotPerClassMetrics(results, sprintf('%s Per-Class F1-Score', upper(modelType)));

sgtitle(sprintf('%s Analysis - Test Accuracy: %.1f%%', upper(modelType), results.testAccuracy*100), ...
    'FontSize', 16, 'FontWeight', 'bold');

saveas(gcf, fullfile(outputDir, sprintf('%s_analysis.png', modelType)));
close(gcf);
end

function plotSimpleConfusionMatrix(results, titleStr)
% PLOTSIMPLECONFUSIONMATRIX Confusion matrix wzorowana na screenshocie

C = confusionmat(results.trueLabels, results.predictions);

% Użyj tej samej funkcji co w compareModels
plotConfusionMatrix(C, titleStr);
end

function plotConfusionMatrix(C, titleStr)
% PLOTCONFUSIONMATRIX Profesjonalna confusion matrix z confusionchart

% Oblicz accuracy
acc = trace(C) / sum(C(:)) * 100;

% PRAWDZIWE NAZWY PALCÓW zamiast "Class 1", "Class 2"
[m, n] = size(C);
classLabels = cell(1, m);
fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};

for i = 1:m
    if i <= length(fingerNames)
        classLabels{i} = fingerNames{i};
    else
        classLabels{i} = sprintf('Palec %d', i);
    end
end

try
    % UŻYJ CONFUSIONCHART - profesjonalny wygląd jak w poprzednim projekcie
    cm = confusionchart(C, classLabels);
    cm.Title = sprintf('%s - Accuracy: %.1f%%', titleStr, acc);
    cm.ColumnSummary = 'column-normalized';
    cm.RowSummary = 'row-normalized';
    
    % Dostosowanie kolorystyki
    colormap(parula);
    
catch
    % FALLBACK - zwykła heatmapa z imagesc
    imagesc(C);
    
    % CZYTELNA COLORMAP
    colormap(gca, flipud(gray)); % Ciemny = wysokie wartości, jasny = niskie
    colorbar;
    
    % Ustawienia osi
    set(gca, 'XTick', 1:n, 'YTick', 1:m);
    set(gca, 'XTickLabel', classLabels, 'YTickLabel', classLabels);
    set(gca, 'FontSize', 11, 'FontWeight', 'bold');
    
    % Etykiety i tytuł
    xlabel('Predicted Class', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('True Class', 'FontSize', 12, 'FontWeight', 'bold');
    
    % ACCURACY W TYTULE
    title(sprintf('%s - Accuracy: %.1f%%', titleStr, acc), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    % Dodaj TYLKO LICZBY w środku każdej komórki
    for i = 1:m
        for j = 1:n
            % Automatyczny wybór koloru tekstu
            if C(i,j) > max(C(:))/2
                textColor = 'white';
            else
                textColor = 'black';
            end
            
            % TYLKO LICZBA - bez procentów
            text(j, i, sprintf('%d', C(i,j)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 14, 'FontWeight', 'bold', 'Color', textColor);
        end
    end
    
    % Ustaw limity osi
    xlim([0.5, n+0.5]);
    ylim([0.5, m+0.5]);
    
    % Standardowe ustawienia osi
    axis tight;
end
end

function plotClassicMetrics(results, titleStr)
% PLOTCLASSICMETRICS Klasyczne metryki: Precision, Recall, F1, Accuracy

C = confusionmat(results.trueLabels, results.predictions);

% Oblicz metryki
precision = diag(C) ./ sum(C, 1)';
recall = diag(C) ./ sum(C, 2);
f1score = 2 * (precision .* recall) ./ (precision + recall);
accuracy = trace(C) / sum(C(:));

% Usuń NaN
precision(isnan(precision)) = 0;
recall(isnan(recall)) = 0;
f1score(isnan(f1score)) = 0;

% Macro-averaged metrics
macro_precision = mean(precision);
macro_recall = mean(recall);
macro_f1 = mean(f1score);

% Wykres słupkowy
metrics = [accuracy, macro_precision, macro_recall, macro_f1];
labels = {'Accuracy', 'Precision', 'Recall', 'F1-Score'};
colors = [0.2, 0.6, 0.8; 0.8, 0.4, 0.2; 0.4, 0.8, 0.4; 0.8, 0.6, 0.4];

b = bar(metrics);
b.FaceColor = 'flat';
for i = 1:length(metrics)
    b.CData(i,:) = colors(i,:);
end

set(gca, 'XTickLabel', labels);
title(titleStr, 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Score', 'FontSize', 11, 'FontWeight', 'bold');
ylim([0, 1]);
grid on;

% POPRAWIONE - wartości nad słupkami z większym odstępem
for i = 1:length(metrics)
    text(i, metrics(i)/2, sprintf('%.3f', metrics(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 11, 'Color', 'white');
end

% POPRAWIONE - info box w dolnym obszarze
text(2.5, 0.12, sprintf('Model: %s\nSamples: %d\nClasses: %d', ...
    upper(results.modelType), length(results.trueLabels), length(unique(results.trueLabels))), ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'BackgroundColor', 'white', ...
    'EdgeColor', 'black', 'Margin', 3);
end

function plotValTestComparison(results, titleStr)
% PLOTVALTESTCOMPARISON Porównanie validation vs test accuracy

% POPRAWKA: Użyj rzeczywistego validation accuracy z wyników optymalizacji
if isfield(results, 'valAccuracy')
    valAcc = results.valAccuracy * 100;
elseif isfield(results, 'validationAccuracy')
    valAcc = results.validationAccuracy * 100;
else
    % BŁĄD - nie ma validation accuracy w results!
    % To znaczy że trzeba go przekazać z MLPipeline
    fprintf('⚠️  No validation accuracy found in results - using test accuracy\n');
    valAcc = results.testAccuracy * 100;
end

testAcc = results.testAccuracy * 100;

% Bar chart
bar_data = [valAcc, testAcc];
bar_labels = {'Validation', 'Test'};
colors = [0.3, 0.6, 0.9; 0.9, 0.4, 0.2];

b = bar(bar_data);
b.FaceColor = 'flat';
b.CData(1,:) = colors(1,:);
b.CData(2,:) = colors(2,:);

set(gca, 'XTickLabel', bar_labels);
title(titleStr, 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Accuracy (%)', 'FontSize', 11, 'FontWeight', 'bold');
ylim([0, 100]);
grid on;

% POPRAWIONE - wartości W ŚRODKU słupków
for i = 1:length(bar_data)
    text(i, bar_data(i)/2, sprintf('%.1f%%', bar_data(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 12, 'Color', 'white');
end

% POPRAWIONE - obliczanie gap ale BEZ opisów o przeuczeniu
overfitting = valAcc - testAcc;

% USUNIĘTE statusy o przeuczeniu - tylko gap i kolor
if overfitting > 15
    color = 'red';
elseif overfitting > 8
    color = 'orange';
elseif overfitting >= -5 && overfitting <= 8
    color = 'green';
else
    color = 'blue';
end

% TYLKO GAP - bez opisów
text(1.5, 75, sprintf('Gap: %.1f%%', overfitting), ...
    'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', color, ...
    'FontWeight', 'bold', 'BackgroundColor', 'white', 'EdgeColor', color, ...
    'Margin', 3);

% USUNIĘTE - żadnych dodatkowych opisów o generalizacji
end

function plotPerClassMetrics(results, titleStr)
% PLOTPERCLASSMETRICS F1-Score dla każdej klasy

C = confusionmat(results.trueLabels, results.predictions);
numClasses = size(C, 1);

% Oblicz F1 dla każdej klasy
precision = diag(C) ./ sum(C, 1)';
recall = diag(C) ./ sum(C, 2);
f1score = 2 * (precision .* recall) ./ (precision + recall);

% Usuń NaN
precision(isnan(precision)) = 0;
recall(isnan(recall)) = 0;
f1score(isnan(f1score)) = 0;

% Bar chart
b = bar(f1score, 'FaceColor', [0.4, 0.7, 0.9]);

% POPRAWIONE - nazwy palców zamiast numerów klas
fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};
classLabels = cell(1, numClasses);
for i = 1:numClasses
    if i <= length(fingerNames)
        classLabels{i} = fingerNames{i};
    else
        classLabels{i} = sprintf('Klasa %d', i);
    end
end

% Ustaw etykiety osi X
set(gca, 'XTick', 1:numClasses);
set(gca, 'XTickLabel', classLabels);
xtickangle(45); % Obróć etykiety dla lepszej czytelności

xlabel('Palec', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('F1-Score', 'FontSize', 11, 'FontWeight', 'bold');
title(titleStr, 'FontSize', 12, 'FontWeight', 'bold');
ylim([0, 1]);
grid on;

% POPRAWIONE - wartości W ŚRODKU słupków zamiast nad nimi
for i = 1:numClasses
    text(i, f1score(i)/2, sprintf('%.2f', f1score(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 10, 'Color', 'white');
end

% POPRAWIONE - linia średniej z lepszą pozycją tekstu
mean_f1 = mean(f1score);
yline(mean_f1, 'r--', 'LineWidth', 2);

% Dodaj tekst z mean F1 w prawym górnym rogu
text(numClasses * 0.75, 0.9, sprintf('Mean F1: %.2f', mean_f1), ...
    'FontSize', 10, 'Color', 'red', 'FontWeight', 'bold', ...
    'BackgroundColor', 'white', 'EdgeColor', 'red', 'Margin', 2);

% Color bars based on performance
cmap = colormap(hot(100));
for i = 1:numClasses
    color_idx = max(1, min(100, round(f1score(i) * 100)));
    b.CData(i,:) = cmap(color_idx, :);
end
end