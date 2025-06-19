function compareModels(finalModels, optimizationResults, models)
% COMPAREMODELS Kompleksowe porównanie wydajności modeli klasyfikacji odcisków palców
%
% Funkcja wykonuje wielowymiarową analizę porównawczą wyników różnych modeli
% (PatternNet, CNN), generując tabelę metryk, wykres 2×2 oraz szczegółowe
% rekomendacje. Automatycznie wykrywa overfitting, analizuje czas trenowania
% i ocenia jakość klasyfikacji z matrycami pomyłek.
%
% Parametry wejściowe:
%   finalModels - struktura z wytrenowanymi modelami i wynikami:
%                .modelType - wytrenowany model
%                .modelType_results - wyniki testowania (testAccuracy, trainTime, etc.)
%   optimizationResults - wyniki optymalizacji hiperparametrów:
%                        .modelType.bestScore - najlepsza accuracy walidacyjna
%   models - cell array nazw modeli do porównania {'patternnet', 'cnn'}
%
% Dane wyjściowe:
%   - Tabela porównawcza w konsoli (Validation/Test Accuracy, Overfitting, Czas)
%   - Wykres 2×2: Accuracy, Training Time, Confusion Matrices (PNG)
%   - Rekomendacje diagnostyczne i wybór najlepszego modelu
%
% Metryki analizy:
%   1. Validation Accuracy - najlepszy wynik z optymalizacji hiperparametrów
%   2. Test Accuracy - finalna accuracy na nieznanym zbiorze testowym
%   3. Overfitting - różnica val_acc - test_acc (idealne: < 5%)
%   4. Training Time - czas trenowania finalnego modelu (sekundy)
%   5. Status - kategoryzacja jakości: EXCELLENT/GOOD/MODERATE/POOR
%
% Klasyfikacja jakości:
%   - EXCELLENT: ≥90% test accuracy (gotowe do produkcji)
%   - GOOD: 75-89% test accuracy (dobra jakość, możliwe usprawnienia)
%   - MODERATE: 60-74% test accuracy (wymaga optymalizacji)
%   - POOR: <60% test accuracy (problemy fundamentalne)
%
% Przykład użycia:
%   compareModels(finalModels, optimizationResults, {'patternnet', 'cnn'});

fprintf('\n📊 MODEL COMPARISON ANALYSIS\n');
fprintf('============================\n');

% AGREGACJA DANYCH Z WSZYSTKICH MODELI
modelData = struct();
for i = 1:length(models)
    modelType = models{i};
    if isfield(finalModels, modelType)
        % Zbierz metryki dla aktualnego modelu
        modelData.(modelType) = struct();
        
        % Validation accuracy z optymalizacji hiperparametrów
        modelData.(modelType).valAcc = optimizationResults.(modelType).bestScore * 100;
        
        % Test accuracy z finalnego modelu
        resultsField = [modelType '_results'];
        modelData.(modelType).testAcc = finalModels.(resultsField).testAccuracy * 100;
        
        % Czas trenowania finalnego modelu
        modelData.(modelType).trainTime = finalModels.(resultsField).trainTime;
        
        % Pełne wyniki dla confusion matrix
        modelData.(modelType).results = finalModels.(resultsField);
    end
end

% TABELA PORÓWNAWCZA GŁÓWNYCH METRYK
fprintf('\nModel        | Val Acc | Test Acc | Overfitting | Train Time | Status\n');
fprintf('-------------|---------|----------|-------------|------------|----------\n');

modelTypes = fieldnames(modelData);
for i = 1:length(modelTypes)
    modelType = modelTypes{i};
    data = modelData.(modelType);
    
    % Oblicz overfitting jako różnicę validation - test accuracy
    overfitting = data.valAcc - data.testAcc;
    
    % Kategoryzacja jakości modelu na podstawie test accuracy
    if data.testAcc >= 90
        status = 'EXCELLENT'; % Gotowy do produkcji
    elseif data.testAcc >= 75
        status = 'GOOD';      % Dobra jakość
    elseif data.testAcc >= 60
        status = 'MODERATE';  % Wymaga popraw
    else
        status = 'POOR';      % Problemy fundamentalne
    end
    
    % Wydrukuj wiersz tabeli z formatowaniem
    fprintf('%-12s | %6.1f%% | %7.1f%% | %10.1f%% | %9.1fs | %s\n', ...
        upper(modelType), data.valAcc, data.testAcc, overfitting, data.trainTime, status);
end

% GENEROWANIE WIZUALIZACJI PORÓWNAWCZEJ
if length(modelTypes) >= 2
    fprintf('\n📈 Generating comparison visualization...\n');
    createAdvancedComparison(modelData);
end

% ANALIZA I REKOMENDACJE EKSPERTOWSKIE
fprintf('\n🎯 EXPERT RECOMMENDATIONS:\n');
fprintf('==========================\n');

% Znajdź najlepszy model na podstawie test accuracy
bestModel = '';
bestAcc = 0;
for i = 1:length(modelTypes)
    if modelData.(modelTypes{i}).testAcc > bestAcc
        bestAcc = modelData.(modelTypes{i}).testAcc;
        bestModel = modelTypes{i};
    end
end

fprintf('• 🏆 Best performing model: %s (%.1f%% test accuracy)\n', upper(bestModel), bestAcc);

% ANALIZA SPECJALNA: CNN vs PatternNet (jeśli oba dostępne)
if isfield(modelData, 'cnn') && isfield(modelData, 'patternnet')
    cnnAcc = modelData.cnn.testAcc;
    patternAcc = modelData.patternnet.testAcc;
    gapSize = abs(cnnAcc - patternAcc);
    
    fprintf('\n🔬 CNN vs PatternNet Analysis:\n');
    
    if cnnAcc < patternAcc - 15
        % CNN znacząco gorszy
        fprintf('• ⚠️  CNN significantly underperforms PatternNet (%.1f%% gap)\n', patternAcc - cnnAcc);
        fprintf('    → Try increasing CNN training epochs\n');
        fprintf('    → Verify image preprocessing pipeline\n');
        fprintf('    → Consider data augmentation strategies\n');
        fprintf('    → Check CNN architecture complexity\n');
        
    elseif cnnAcc > patternAcc + 5
        % CNN lepszy - surowe obrazy zawierają więcej informacji
        fprintf('• 🎉 CNN outperforms PatternNet! Raw images capture richer patterns.\n');
        fprintf('    → Consider CNN as primary production model\n');
        fprintf('    → Image-based approach shows superior feature learning\n');
        
    else
        % Podobna wydajność - oba podejścia równoważne
        fprintf('• 📊 Both models perform similarly (%.1f%% gap)\n', gapSize);
        fprintf('    → Feature extraction pipeline works effectively\n');
        fprintf('    → Choose based on deployment constraints:\n');
        fprintf('      • PatternNet: faster inference, smaller memory footprint\n');
        fprintf('      • CNN: more robust to image variations, scalable\n');
    end
    
    % Analiza overfitting dla obu modeli
    fprintf('\n📉 Overfitting Analysis:\n');
    cnnOverfit = modelData.cnn.valAcc - modelData.cnn.testAcc;
    patternOverfit = modelData.patternnet.valAcc - modelData.patternnet.testAcc;
    
    fprintf('• CNN overfitting: %.1f%%', cnnOverfit);
    if cnnOverfit > 10
        fprintf(' (HIGH - consider regularization)');
    elseif cnnOverfit > 5
        fprintf(' (MODERATE - monitor)');
    else
        fprintf(' (LOW - good generalization)');
    end
    fprintf('\n');
    
    fprintf('• PatternNet overfitting: %.1f%%', patternOverfit);
    if patternOverfit > 10
        fprintf(' (HIGH - reduce model complexity)');
    elseif patternOverfit > 5
        fprintf(' (MODERATE - acceptable)');
    else
        fprintf(' (LOW - excellent generalization)');
    end
    fprintf('\n');
end

% REKOMENDACJE OGÓLNE NA PODSTAWIE WYNIKÓW
fprintf('\n💡 General Recommendations:\n');

% Rekomendacje na podstawie najlepszego wyniku
if bestAcc >= 90
    fprintf('• ✅ Excellent results! System ready for deployment consideration.\n');
    fprintf('• 🔄 Focus on production optimization and robustness testing.\n');
elseif bestAcc >= 75
    fprintf('• 📈 Good performance. Consider fine-tuning for production.\n');
    fprintf('• 🛠️  Investigate hyperparameter optimization and data quality.\n');
elseif bestAcc >= 60
    fprintf('• ⚡ Moderate performance. Significant improvements needed.\n');
    fprintf('• 🧪 Experiment with different architectures and preprocessing.\n');
else
    fprintf('• 🚨 Poor performance. Fundamental issues require investigation.\n');
    fprintf('• 🔍 Review data quality, preprocessing pipeline, and model architecture.\n');
end

% Rekomendacje na podstawie czasu trenowania
fastestModel = '';
fastestTime = inf;
for i = 1:length(modelTypes)
    if modelData.(modelTypes{i}).trainTime < fastestTime
        fastestTime = modelData.(modelTypes{i}).trainTime;
        fastestModel = modelTypes{i};
    end
end

fprintf('• ⚡ Fastest training: %s (%.1fs) - consider for rapid prototyping.\n', ...
    upper(fastestModel), fastestTime);

fprintf('\n🏁 Analysis completed. Check output/figures/ for detailed visualizations.\n');
end

function createAdvancedComparison(modelData)
% CREATEADVANCEDCOMPARISON Generuje zaawansowany wykres porównawczy 2×2
%
% Funkcja tworzy profesjonalną wizualizację składającą się z:
% 1. Validation vs Test Accuracy (wykres słupkowy)
% 2. Training Time comparison (wykres słupkowy)
% 3-4. Confusion Matrices dla dostępnych modeli

modelTypes = fieldnames(modelData);
figure('Position', [100, 100, 1400, 900]); % Duży rozmiar dla czytelności

%% PRZYGOTOWANIE ETYKIET MODELI (raz dla wszystkich wykresów)
modelLabels = cell(1, length(modelTypes));
for i = 1:length(modelTypes)
    modelLabels{i} = upper(modelTypes{i});
end

%% 1. VALIDATION vs TEST ACCURACY COMPARISON
subplot(2, 2, 1);
valAccs = arrayfun(@(i) modelData.(modelTypes{i}).valAcc, 1:length(modelTypes));
testAccs = arrayfun(@(i) modelData.(modelTypes{i}).testAcc, 1:length(modelTypes));

x = 1:length(modelTypes);
bar_width = 0.35;

% Kontrastowe kolory dla czytelności
h1 = bar(x - bar_width/2, valAccs, bar_width, 'DisplayName', 'Validation Accuracy', ...
    'FaceColor', [0.2, 0.4, 0.8], 'EdgeColor', 'black', 'LineWidth', 1);
hold on;
h2 = bar(x + bar_width/2, testAccs, bar_width, 'DisplayName', 'Test Accuracy', ...
    'FaceColor', [0.8, 0.2, 0.2], 'EdgeColor', 'black', 'LineWidth', 1);

% Konfiguracja osi i etykiet
set(gca, 'XTick', 1:length(modelTypes));
set(gca, 'XTickLabel', modelLabels);
set(gca, 'FontSize', 12, 'FontWeight', 'bold');

ylabel('Accuracy (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Validation vs Test Accuracy', 'FontSize', 14, 'FontWeight', 'bold');

% Legenda w górnym lewym rogu
legend('Location', 'northwest', 'FontSize', 11, 'Box', 'on', 'EdgeColor', 'black');
grid on;
ylim([0, 105]); % Małe rozszerzenie dla wartości tekstowych

% Wartości na słupkach (białe dla kontrastu)
for i = 1:length(modelTypes)
    % Validation accuracy - środek słupka
    text(i - bar_width/2, valAccs(i)/2, sprintf('%.1f%%', valAccs(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'FontWeight', 'bold', 'Color', 'white');
    
    % Test accuracy - środek słupka
    text(i + bar_width/2, testAccs(i)/2, sprintf('%.1f%%', testAccs(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'FontWeight', 'bold', 'Color', 'white');
end

%% 2. TRAINING TIME COMPARISON
subplot(2, 2, 2);
trainTimes = arrayfun(@(i) modelData.(modelTypes{i}).trainTime, 1:length(modelTypes));

% Różne kolory dla każdego modelu
colors = [0.3, 0.7, 0.3; 0.7, 0.3, 0.7; 0.3, 0.3, 0.7]; % Zielony, fioletowy, niebieski
barColors = colors(1:length(modelTypes), :);

b = bar(trainTimes, 'EdgeColor', 'black', 'LineWidth', 1.5);
b.FaceColor = 'flat';
for i = 1:length(trainTimes)
    b.CData(i,:) = barColors(i,:);
end

% Konfiguracja osi
set(gca, 'XTick', 1:length(modelTypes));
set(gca, 'XTickLabel', modelLabels);
set(gca, 'FontSize', 12, 'FontWeight', 'bold');

ylabel('Training Time (seconds)', 'FontSize', 12, 'FontWeight', 'bold');
title('Training Time Comparison', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

% Dynamiczny zakres Y z marginesem
maxTime = max(trainTimes);
if maxTime < 5
    ylim([0, maxTime * 1.3]);
else
    ylim([0, maxTime * 1.15]);
end

% Wartości czasu na słupkach
for i = 1:length(trainTimes)
    if trainTimes(i) < 1
        timeText = sprintf('%.2fs', trainTimes(i));
    elseif trainTimes(i) < 10
        timeText = sprintf('%.1fs', trainTimes(i));
    else
        timeText = sprintf('%.0fs', trainTimes(i));
    end
    
    % Tekst w środku słupka
    text(i, trainTimes(i)/2, timeText, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'FontWeight', 'bold', 'Color', 'white');
end

%% 3. & 4. CONFUSION MATRICES dla dostępnych modeli
for i = 1:min(2, length(modelTypes))
    if i == 1
        subplot(2, 2, 3); % Lewy dolny
    else
        subplot(2, 2, 4); % Prawy dolny
    end
    
    modelType = modelTypes{i};
    results = modelData.(modelType).results;
    
    % Utworz confusion matrix
    C = confusionmat(results.trueLabels, results.predictions);
    
    % Narysuj profesjonalną confusion matrix
    plotEnhancedConfusionMatrix(C, upper(modelType));
end

% TYTUŁ GŁÓWNY FIGURY
sgtitle('Comprehensive Model Performance Analysis - Fingerprint Classification', ...
    'FontSize', 18, 'FontWeight', 'bold');

% METADANE W STOPCE
annotation('textbox', [0.02, 0.02, 0.3, 0.05], 'String', ...
    sprintf('Generated: %s | System: Fingerprint Identification', datestr(now, 'yyyy-mm-dd HH:MM')), ...
    'FontSize', 10, 'EdgeColor', 'none', 'FontWeight', 'bold');

% ZAPIS DO PLIKU
set(gcf, 'PaperPositionMode', 'auto');
saveas(gcf, 'output/figures/comprehensive_model_comparison.png');
fprintf('📊 Comparison visualization saved to: output/figures/comprehensive_model_comparison.png\n');
close(gcf);
end

function plotEnhancedConfusionMatrix(C, modelName)
% PLOTENHANCEDCONFUSIONMATRIX Profesjonalna confusion matrix z opisowymi etykietami
%
% Generuje confusion matrix z rzeczywistymi nazwami palców zamiast numerów klas,
% oblicza accuracy oraz stosuje odpowiednią kolorystykę i formatowanie.

% Oblicz accuracy z macierzy pomyłek
acc = trace(C) / sum(C(:)) * 100;

% Realistische nazwy palców dla lepszej czytelności
[m, n] = size(C);
fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};
classLabels = cell(1, m);

for i = 1:m
    if i <= length(fingerNames)
        classLabels{i} = fingerNames{i};
    else
        classLabels{i} = sprintf('Palec %d', i);
    end
end

try
    % PREFEROWANA METODA: confusionchart (MATLAB R2018b+)
    cm = confusionchart(C, classLabels);
    cm.Title = sprintf('%s - Accuracy: %.1f%%', modelName, acc);
    cm.ColumnSummary = 'column-normalized';
    cm.RowSummary = 'row-normalized';
    cm.FontSize = 10;
    cm.XLabel = 'Predicted Class';
    cm.YLabel = 'True Class';
    
    % Kolorystyka Parula dla lepszego kontrastu
    colormap(parula);
    
catch
    % FALLBACK: Klasyczny imagesc z pełną kontrolą
    imagesc(C);
    colormap(parula);
    colorbar;
    
    % Konfiguracja osi
    set(gca, 'XTick', 1:n, 'YTick', 1:m);
    set(gca, 'XTickLabel', classLabels, 'YTickLabel', classLabels);
    set(gca, 'FontSize', 9, 'FontWeight', 'normal');
    
    % Obrót etykiet X dla lepszej czytelności
    xtickangle(45);
    
    % Etykiety osi i tytuł
    xlabel('Predicted Class', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('True Class', 'FontSize', 10, 'FontWeight', 'bold');
    title(sprintf('%s - Accuracy: %.1f%%', modelName, acc), ...
        'FontSize', 11, 'FontWeight', 'bold');
    
    % Wartości numeryczne w komórkach macierzy
    for i = 1:m
        for j = 1:n
            if C(i,j) > 0
                % Automatyczny wybór koloru tekstu dla kontrastu
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
    
    % Dopasowanie osi
    axis tight;
    xlim([0.5, n+0.5]);
    ylim([0.5, m+0.5]);
end
end