function compareModels(finalModels, optimizationResults, models)
% COMPAREMODELS Proste porównanie modeli - klasyczne metryki

fprintf('\n📊 MODEL COMPARISON\n');
fprintf('===================\n');

% Zbierz dane
modelData = struct();
for i = 1:length(models)
    modelType = models{i};
    if isfield(finalModels, modelType)
        modelData.(modelType) = struct();
        modelData.(modelType).valAcc = optimizationResults.(modelType).bestScore * 100;
        modelData.(modelType).testAcc = finalModels.([modelType '_results']).testAccuracy * 100;
        modelData.(modelType).trainTime = finalModels.([modelType '_results']).trainTime;
        modelData.(modelType).results = finalModels.([modelType '_results']);
    end
end

% Tabelka porównawcza
fprintf('\nModel        | Val Acc | Test Acc | Overfitting | Train Time | Status\n');
fprintf('-------------|---------|----------|-------------|------------|----------\n');

modelTypes = fieldnames(modelData);
for i = 1:length(modelTypes)
    modelType = modelTypes{i};
    data = modelData.(modelType);
    
    overfitting = data.valAcc - data.testAcc;
    
    if data.testAcc >= 90
        status = 'EXCELLENT';
    elseif data.testAcc >= 75
        status = 'GOOD';
    elseif data.testAcc >= 60
        status = 'MODERATE';
    else
        status = 'POOR';
    end
    
    fprintf('%-12s | %6.1f%% | %7.1f%% | %10.1f%% | %9.1fs | %s\n', ...
        upper(modelType), data.valAcc, data.testAcc, overfitting, data.trainTime, status);
end

% Wizualizacja porównawcza
if length(modelTypes) >= 2
    createSimpleComparison(modelData);
end

% Rekomendacje
fprintf('\nRECOMMENDATIONS:\n');
bestModel = '';
bestAcc = 0;

for i = 1:length(modelTypes)
    if modelData.(modelTypes{i}).testAcc > bestAcc
        bestAcc = modelData.(modelTypes{i}).testAcc;
        bestModel = modelTypes{i};
    end
end

fprintf('• Best model: %s (%.1f%% test accuracy)\n', upper(bestModel), bestAcc);

% Analiza CNN vs PatternNet
if isfield(modelData, 'cnn') && isfield(modelData, 'patternnet')
    cnnAcc = modelData.cnn.testAcc;
    patternAcc = modelData.patternnet.testAcc;
    
    if cnnAcc < patternAcc - 15
        fprintf('• ⚠️  CNN significantly underperforms PatternNet (%.1f%% gap)\n', patternAcc - cnnAcc);
        fprintf('    - Try more training epochs\n');
        fprintf('    - Check image preprocessing\n');
        fprintf('    - Consider data augmentation\n');
    elseif cnnAcc > patternAcc + 5
        fprintf('• 🎉 CNN outperforms PatternNet! Images capture more information.\n');
    else
        fprintf('• 📊 Both models perform similarly - feature extraction works well.\n');
    end
end
end

function createSimpleComparison(modelData)
% CREATESIMPLECOMPARISON Ulepszona wizualizacja 2x2 z lepszą czytelnością

modelTypes = fieldnames(modelData);
figure('Position', [100, 100, 1400, 900]); % WIĘKSZA FIGURA

%% PRZYGOTUJ ETYKIETY RAZ - używaj w obu wykresach
modelLabels = cell(1, length(modelTypes));
for i = 1:length(modelTypes)
    modelLabels{i} = upper(modelTypes{i});
end

%% 1. Validation vs Test Accuracy - POPRAWIONA LEGENDA I TEKST
subplot(2, 2, 1);
valAccs = arrayfun(@(i) modelData.(modelTypes{i}).valAcc, 1:length(modelTypes));
testAccs = arrayfun(@(i) modelData.(modelTypes{i}).testAcc, 1:length(modelTypes));

x = 1:length(modelTypes);
bar_width = 0.35;

% Użyj kontrastowych kolorów
h1 = bar(x - bar_width/2, valAccs, bar_width, 'DisplayName', 'Validation', ...
    'FaceColor', [0.2, 0.4, 0.8], 'EdgeColor', 'black');
hold on;
h2 = bar(x + bar_width/2, testAccs, bar_width, 'DisplayName', 'Test', ...
    'FaceColor', [0.8, 0.2, 0.2], 'EdgeColor', 'black');

% EXPLICITE USTAW XTick i XTickLabel
set(gca, 'XTick', 1:length(modelTypes));
set(gca, 'XTickLabel', modelLabels);
set(gca, 'FontSize', 12, 'FontWeight', 'bold');

ylabel('Accuracy (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Validation vs Test Accuracy', 'FontSize', 14, 'FontWeight', 'bold');

% POPRAWIONA LEGENDA - umieść w lewym górnym rogu z ramką
legend('Location', 'northwest', 'FontSize', 11, 'Box', 'on', 'EdgeColor', 'black');
grid on;
ylim([0, 100]);

% POPRAWIONE WARTOŚCI - W ŚRODKU słupków zamiast nad nimi
for i = 1:length(modelTypes)
    % Validation - w środku słupka
    text(i - bar_width/2, valAccs(i)/2, sprintf('%.1f%%', valAccs(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'FontWeight', 'bold', 'Color', 'white');
    
    % Test - w środku słupka
    text(i + bar_width/2, testAccs(i)/2, sprintf('%.1f%%', testAccs(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'FontWeight', 'bold', 'Color', 'white');
end

%% 2. Training Time - POPRAWIONE WARTOŚCI
subplot(2, 2, 2);
trainTimes = arrayfun(@(i) modelData.(modelTypes{i}).trainTime, 1:length(modelTypes));

% Kolory dla każdego modelu
colors = [0.3, 0.7, 0.3; 0.7, 0.3, 0.7]; % Zielony dla pierwszego, fioletowy dla drugiego
barColors = colors(1:length(modelTypes), :);

b = bar(trainTimes, 'EdgeColor', 'black', 'LineWidth', 1.5);
b.FaceColor = 'flat';
for i = 1:length(trainTimes)
    b.CData(i,:) = barColors(i,:);
end

% EXPLICITE USTAW XTick i XTickLabel RÓWNIEŻ TUTAJ
set(gca, 'XTick', 1:length(modelTypes));
set(gca, 'XTickLabel', modelLabels);
set(gca, 'FontSize', 12, 'FontWeight', 'bold');

ylabel('Time (seconds)', 'FontSize', 12, 'FontWeight', 'bold');
title('Training Time', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

% POPRAWIONY ZAKRES - dynamiczny z małym marginesem
maxTime = max(trainTimes);
if maxTime < 5
    ylim([0, maxTime * 1.3]); % Zwiększone z 1.2 do 1.3 dla miejsca na tekst
else
    ylim([0, maxTime * 1.15]); % Zwiększone z 1.1 do 1.15
end

% POPRAWIONE WARTOŚCI - W ŚRODKU słupków
for i = 1:length(trainTimes)
    if trainTimes(i) < 1
        timeText = sprintf('%.2fs', trainTimes(i));
    else
        timeText = sprintf('%.1fs', trainTimes(i));
    end
    
    % Umieść tekst W ŚRODKU słupka
    text(i, trainTimes(i)/2, timeText, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'FontWeight', 'bold', 'Color', 'white');
end

%% 3. & 4. Confusion Matrices - BEZ ZMIAN (już używają confusionchart)
for i = 1:min(2, length(modelTypes))
    % WIĘKSZE SUBPLOT dla confusion matrices
    if i == 1
        subplot(2, 2, 3); % Lewy dolny
    else
        subplot(2, 2, 4); % Prawy dolny
    end
    
    modelType = modelTypes{i};
    results = modelData.(modelType).results;
    
    C = confusionmat(results.trueLabels, results.predictions);
    
    % UŻYJ POPRAWIONEJ FUNKCJI
    plotConfusionMatrix(C, upper(modelType));
end

% Lepszy tytuł główny
sgtitle('Model Comparison - Fingerprint Classification', ...
    'FontSize', 18, 'FontWeight', 'bold');

% Dodaj informacje o dacie
annotation('textbox', [0.02, 0.02, 0.3, 0.05], 'String', ...
    sprintf('Generated: %s', datestr(now, 'yyyy-mm-dd HH:MM')), ...
    'FontSize', 10, 'EdgeColor', 'none');

% WIĘCEJ PRZESTRZENI między subplot
set(gcf, 'PaperPositionMode', 'auto');

% Zapisz z wyższą rozdzielczością
saveas(gcf, 'output/figures/model_comparison.png');
print(gcf, 'output/figures/model_comparison_hires.png', '-dpng', '-r300');
close(gcf);
end

function plotConfusionMatrix(C, modelName)
% PLOTCONFUSIONMATRIX Profesjonalna confusion matrix z confusionchart - POPRAWIONA

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
    % UŻYJ CONFUSIONCHART - ale z poprawkami dla subplot
    cm = confusionchart(C, classLabels);
    cm.Title = sprintf('%s Confusion Matrix - Accuracy: %.1f%%', modelName, acc);
    cm.ColumnSummary = 'column-normalized';
    cm.RowSummary = 'row-normalized';
    
    % POPRAWKI dla lepszej czytelności w subplot
    cm.FontSize = 10;  % Mniejsza czcionka
    cm.XLabel = 'Predicted Class';
    cm.YLabel = 'True Class';
    
    % Dostosowanie kolorystyki - czytelna mapa kolorów
    colormap(parula);
    
    % POPRAWKA: Ustaw pozycję i rozmiar dla lepszej czytelności
    ax = gca;
    pos = get(ax, 'Position');
    % Zwiększ wysokość i szerokość subplot dla confusion matrix
    set(ax, 'Position', [pos(1), pos(2)-0.02, pos(3)+0.03, pos(4)+0.05]);
    
catch
    % FALLBACK - imagesc z lepszą kontrolą etykiet
    imagesc(C);
    colormap(parula);
    colorbar;
    
    % Ustawienia osi z kontrolą czcionki
    set(gca, 'XTick', 1:n, 'YTick', 1:m);
    set(gca, 'XTickLabel', classLabels, 'YTickLabel', classLabels);
    set(gca, 'FontSize', 9, 'FontWeight', 'normal'); % Mniejsza czcionka
    
    % POPRAWKA: Obróć etykiety osi X dla lepszej czytelności
    xtickangle(45);
    
    % Etykiety i tytuł
    xlabel('Predicted Class', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('True Class', 'FontSize', 10, 'FontWeight', 'bold');
    title(sprintf('%s Confusion Matrix - Accuracy: %.1f%%', modelName, acc), ...
        'FontSize', 11, 'FontWeight', 'bold');
    
    % Dodaj liczby w środku każdej komórki
    for i = 1:m
        for j = 1:n
            if C(i,j) > 0
                % Automatyczny wybór koloru tekstu
                if C(i,j) > max(C(:))/2
                    textColor = 'white';
                else
                    textColor = 'black';
                end
                
                text(j, i, sprintf('%d', C(i,j)), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                    'FontSize', 12, 'FontWeight', 'bold', 'Color', textColor);
            end
        end
    end
    
    % DODATKOWA POPRAWKA: Zwiększ margines wokół wykresu
    axis tight;
    xlim([0.5, n+0.5]);
    ylim([0.5, m+0.5]);
end
end