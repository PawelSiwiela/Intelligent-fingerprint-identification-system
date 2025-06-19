function createModelVisualization(model, results, modelType, testData)
% CREATEMODELVISUALIZATION Kompletna analiza modelu + struktura + konwergencja

outputDir = 'output/figures';
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

%% FIGURA 1: PODSTAWOWE METRYKI (pozostaje bez zmian)
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

%% FIGURA 2: STRUKTURA SIECI + KONWERGENCJA
createNetworkStructureVisualization(model, results, modelType, outputDir);

end

function createNetworkStructureVisualization(model, results, modelType, outputDir)
% CREATENETWORKSTRUCTUREVISUALIZATION Wizualizacja struktury i konwergencji

figure('Position', [100, 100, 1400, 600]);

%% SUBPLOT 1: STRUKTURA SIECI
subplot(1, 2, 1);

if strcmp(modelType, 'patternnet')
    % PATTERNNET - wizualizacja warstw
    plotPatternNetStructure(model, results);
    
elseif strcmp(modelType, 'cnn')
    % CNN - wizualizacja architektury
    plotCNNStructure(model, results);
end

%% SUBPLOT 2: KRZYWE KONWERGENCJI
subplot(1, 2, 2);
plotTrainingConvergence(model, results, modelType);

% Główny tytuł
sgtitle(sprintf('%s - Network Structure & Training Convergence', upper(modelType)), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Zapisz
saveas(gcf, fullfile(outputDir, sprintf('%s_network_structure.png', modelType)));
close(gcf);
end

function plotPatternNetStructure(model, results)
% PLOTPATTERNNETSTRUCTURE Wizualizacja struktury PatternNet - POPRAWIONE KOLORY

try
    % Pobierz informacje o warstwach
    inputSize = model.inputs{1}.size;
    hiddenSizes = [];
    
    % Znajdź ukryte warstwy
    for i = 1:model.numLayers
        if i < model.numLayers % Nie ostatnia warstwa
            hiddenSizes(end+1) = model.layers{i}.size;
        end
    end
    
    outputSize = model.outputs{end}.size;
    
    % Rysuj architekturę sieci
    layers = [inputSize, hiddenSizes, outputSize];
    layerNames = cell(1, length(layers));
    layerNames{1} = sprintf('Input\n(%d)', inputSize);
    
    for i = 2:length(layers)-1
        layerNames{i} = sprintf('Hidden %d\n(%d)', i-1, layers(i));
    end
    layerNames{end} = sprintf('Output\n(%d)', outputSize);
    
    % Pozycje warstw
    x_positions = 1:length(layers);
    y_center = 0;
    
    % POPRAWIONE KOLORY - używaj RGB arrays zamiast nazw
    colors = [0.8, 0.2, 0.2; repmat([0.2, 0.6, 0.8], length(hiddenSizes), 1); 0.2, 0.8, 0.2];
    
    maxNodes = max(layers);
    nodeRadius = 0.3;
    
    for i = 1:length(layers)
        numNodes = layers(i);
        
        % Pozycje węzłów w warstwie
        if numNodes == 1
            y_positions = y_center;
        else
            y_positions = linspace(-maxNodes/4, maxNodes/4, numNodes);
        end
        
        % Rysuj węzły
        for j = 1:numNodes
            if numNodes <= 10 || j <= 5 || j > numNodes-5 % Ograniczenie dla czytelności
                circle = viscircles([x_positions(i), y_positions(j)], nodeRadius, ...
                    'Color', colors(i,:), 'LineWidth', 2);
            elseif j == 6 && numNodes > 10
                % Kropki "..." dla dużych warstw
                text(x_positions(i), y_center, '...', 'FontSize', 20, ...
                    'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end
        end
        
        % Etykiety warstw - POPRAWIONE KOLORY
        text(x_positions(i), maxNodes/3 + 1, layerNames{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 11, ...
            'FontWeight', 'bold', 'BackgroundColor', 'white', ...
            'EdgeColor', 'black', 'Margin', 3);
    end
    
    % Połączenia między warstwami (reprezentacyjne)
    for i = 1:length(layers)-1
        line([x_positions(i)+nodeRadius, x_positions(i+1)-nodeRadius], ...
            [0, 0], 'Color', 'black', 'LineWidth', 1, 'LineStyle', '--');
    end
    
    % Dodaj informacje o parametrach treningu - POPRAWIONE KOLORY
    if isfield(results, 'hyperparams')
        hp = results.hyperparams;
        infoText = sprintf('Training Function: %s\nEpochs: %d\nLearning Rate: %.1e\nGoal: %.1e', ...
            hp.trainFcn, hp.epochs, hp.lr, hp.goal);
        
        text(1, -maxNodes/3 - 1, infoText, 'FontSize', 9, ...
            'BackgroundColor', [1, 1, 0.8], 'EdgeColor', 'black', 'Margin', 5); % ZMIENIONE: RGB zamiast 'lightyellow'
    end
    
    xlim([0.5, length(layers) + 0.5]);
    ylim([-maxNodes/2 - 2, maxNodes/2 + 2]);
    axis off;
    title('PatternNet Architecture', 'FontSize', 14, 'FontWeight', 'bold');
    
catch ME
    % POPRAWIONY FALLBACK - tylko podstawowe kolory
    if exist('hiddenSizes', 'var')
        hiddenInfo = mat2str(hiddenSizes);
    else
        hiddenInfo = 'N/A';
    end
    
    text(0.5, 0.5, sprintf('PatternNet Structure\n%s\nNodes: %s\nTest Accuracy: %.2f%%', ...
        results.modelType, hiddenInfo, results.testAccuracy*100), ...
        'HorizontalAlignment', 'center', 'FontSize', 12, ...
        'BackgroundColor', [0.7, 0.9, 1], 'EdgeColor', 'black'); % ZMIENIONE: RGB zamiast 'lightblue'
    axis off;
    title('PatternNet Structure', 'FontSize', 14, 'FontWeight', 'bold');
end
end

function plotCNNStructure(model, results)
% PLOTCNNSTRUCTURE Wizualizacja struktury CNN - POPRAWIONE KOLORY

try
    % Pobierz warstwy CNN
    layers = model.Layers;
    
    % Przygotuj informacje o warstwach
    layerInfo = {};
    yPos = length(layers);
    
    for i = 1:length(layers)
        layer = layers(i);
        
        % Różne typy warstw - POPRAWIONE KOLORY (RGB arrays)
        switch class(layer)
            case 'nnet.cnn.layer.ImageInputLayer'
                info = sprintf('Input: %dx%dx%d', layer.InputSize(1), layer.InputSize(2), layer.InputSize(3));
                color = [0.8, 0.8, 0.2];
                
            case 'nnet.cnn.layer.Convolution2DLayer'
                info = sprintf('Conv2D: %d filters %dx%d', layer.NumFilters, layer.FilterSize(1), layer.FilterSize(2));
                color = [0.2, 0.6, 0.8];
                
            case 'nnet.cnn.layer.ReLULayer'
                info = 'ReLU';
                color = [0.6, 0.8, 0.6];
                
            case 'nnet.cnn.layer.MaxPooling2DLayer'
                info = sprintf('MaxPool: %dx%d', layer.PoolSize(1), layer.PoolSize(2));
                color = [0.8, 0.6, 0.2];
                
            case 'nnet.cnn.layer.DropoutLayer'
                info = sprintf('Dropout: %.1f%%', layer.Probability*100);
                color = [0.8, 0.4, 0.6];
                
            case 'nnet.cnn.layer.FullyConnectedLayer'
                info = sprintf('FC: %d neurons', layer.OutputSize);
                color = [0.6, 0.2, 0.8];
                
            case 'nnet.cnn.layer.SoftmaxLayer'
                info = 'Softmax';
                color = [0.8, 0.2, 0.2];
                
            case 'nnet.cnn.layer.ClassificationOutputLayer'
                info = 'Output';
                color = [0.2, 0.8, 0.2];
                
            otherwise
                info = class(layer);
                color = [0.5, 0.5, 0.5];
        end
        
        % Rysuj prostokąt warstwy
        rect = rectangle('Position', [1, yPos-0.4, 8, 0.8], ...
            'FaceColor', color, 'EdgeColor', 'black', 'LineWidth', 1.5);
        
        % Tekst opisu warstwy
        text(5, yPos, sprintf('%d. %s', i, info), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontWeight', 'bold', 'Color', 'white');
        
        % Strzałka do następnej warstwy
        if i < length(layers)
            arrow([5, yPos-0.5], [5, yPos-1.5], 'Color', 'black', 'LineWidth', 2);
        end
        
        yPos = yPos - 1;
    end
    
    % Dodaj informacje o hiperparametrach - POPRAWIONE KOLORY
    if isfield(results, 'hyperparams')
        hp = results.hyperparams;
        infoText = sprintf('Learning Rate: %.1e\nEpochs: %d\nBatch Size: %d\nDropout: %.2f', ...
            hp.lr, hp.epochs, hp.miniBatchSize, hp.dropoutRate);
        
        text(10.5, length(layers)/2, infoText, 'FontSize', 9, ...
            'BackgroundColor', [1, 1, 0.8], 'EdgeColor', 'black', 'Margin', 5); % ZMIENIONE: RGB zamiast 'lightyellow'
    end
    
    xlim([0, 12]);
    ylim([0, length(layers) + 1]);
    axis off;
    title('CNN Architecture', 'FontSize', 14, 'FontWeight', 'bold');
    
catch ME
    % POPRAWIONY FALLBACK
    text(0.5, 0.5, sprintf('CNN Structure\n%d layers\nTest Accuracy: %.2f%%', ...
        length(model.Layers), results.testAccuracy*100), ...
        'HorizontalAlignment', 'center', 'FontSize', 12, ...
        'BackgroundColor', [0.7, 1, 0.7], 'EdgeColor', 'black'); % ZMIENIONE: RGB zamiast 'lightgreen'
    axis off;
    title('CNN Structure', 'FontSize', 14, 'FontWeight', 'bold');
end
end

function plotTrainingConvergence(model, results, modelType)
% PLOTTRAININGCONVERGENCE Krzywe konwergencji treningu

try
    if strcmp(modelType, 'patternnet')
        % PatternNet - użyj informacji z treningu jeśli dostępne
        if isfield(model, 'trainRecord') && ~isempty(model.trainRecord)
            tr = model.trainRecord;
            
            % Wykresy performance i gradient
            yyaxis left;
            semilogy(tr.epoch, tr.perf, 'b-', 'LineWidth', 2, 'DisplayName', 'Training Performance');
            ylabel('Performance (MSE)', 'Color', 'blue');
            
            yyaxis right;
            if isfield(tr, 'gradient')
                semilogy(tr.epoch, tr.gradient, 'r-', 'LineWidth', 2, 'DisplayName', 'Gradient');
                ylabel('Gradient', 'Color', 'red');
            end
            
            xlabel('Epoch');
            title('Training Convergence', 'FontSize', 14, 'FontWeight', 'bold');
            
            % POPRAWKA: Zmień na prawidłową wartość
            legend('Location', 'northeast'); % ZMIENIONE z 'best'
            grid on;
            
            % Dodaj informacje o zatrzymaniu
            if isfield(tr, 'stop')
                text(0.7, 0.95, sprintf('Stopped: %s\nEpochs: %d\nFinal Performance: %.2e', ...
                    tr.stop, length(tr.epoch), tr.perf(end)), ...
                    'Units', 'normalized', 'FontSize', 9, ...
                    'BackgroundColor', 'white', 'EdgeColor', 'black', 'Margin', 3);
            end
            
        else
            % Symuluj krzywą konwergencji
            plotSimulatedConvergence(results, 'PatternNet');
        end
        
    elseif strcmp(modelType, 'cnn')
        % CNN - symuluj lub użyj danych treningu jeśli dostępne
        plotSimulatedConvergence(results, 'CNN');
    end
    
catch ME
    % Fallback
    plotSimulatedConvergence(results, modelType);
end
end

function plotSimulatedConvergence(results, modelTypeStr)
% PLOTSIMULATEDCONVERGENCE Symulowana krzywa konwergencji na podstawie wyników

% Symuluj realistyczną krzywą treningu
if isfield(results, 'hyperparams') && isfield(results.hyperparams, 'epochs')
    maxEpochs = results.hyperparams.epochs;
else
    maxEpochs = 20;
end

epochs = 1:maxEpochs;

% Symuluj loss na podstawie finalnej accuracy
finalAcc = results.testAccuracy;
initialLoss = 1.6; % Wysoki początkowy loss dla klasyfikacji 5-klasowej

% Krzywa spadku loss (eksponencjalna z plateau)
targetLoss = -log(finalAcc); % Docelowy loss na podstawie accuracy
lossDecay = 0.15;
trainingLoss = targetLoss + (initialLoss - targetLoss) * exp(-lossDecay * epochs);

% Dodaj realny szum
noise = 0.05 * randn(size(epochs));
trainingLoss = trainingLoss + noise;

% Accuracy na podstawie loss
trainingAcc = exp(-trainingLoss) * 100;

% Validation loss (nieco wyższy, więcej szumu)
valLoss = trainingLoss * 1.1 + 0.02 * randn(size(epochs));
valAcc = exp(-valLoss) * 100;

% Plots
yyaxis left;
plot(epochs, trainingLoss, 'b-', 'LineWidth', 2, 'DisplayName', 'Training Loss');
hold on;
plot(epochs, valLoss, 'b--', 'LineWidth', 2, 'DisplayName', 'Validation Loss');
ylabel('Loss', 'Color', 'blue');

yyaxis right;
plot(epochs, trainingAcc, 'r-', 'LineWidth', 2, 'DisplayName', 'Training Accuracy');
plot(epochs, valAcc, 'r--', 'LineWidth', 2, 'DisplayName', 'Validation Accuracy');
ylabel('Accuracy (%)', 'Color', 'red');

xlabel('Epoch');
title(sprintf('%s Training Convergence (Simulated)', modelTypeStr), 'FontSize', 14, 'FontWeight', 'bold');

% POPRAWKA: Zmień 'center right' na 'eastoutside'
legend('Location', 'eastoutside');
grid on;

% Informacje o treningu
text(0.05, 0.95, sprintf('Final Test Accuracy: %.2f%%\nTraining Time: %.1fs\nConverged in ~%d epochs', ...
    finalAcc*100, results.trainTime, maxEpochs), ...
    'Units', 'normalized', 'FontSize', 9, ...
    'BackgroundColor', 'white', 'EdgeColor', 'black', 'Margin', 3);
end

% Helper function for arrows (jeśli nie istnieje)
function arrow(start, stop, varargin)
% ARROW Simple arrow drawing
try
    % Używaj quiver jeśli dostępne
    quiver(start(1), start(2), stop(1)-start(1), stop(2)-start(2), 0, varargin{:});
catch
    % Fallback - prosta linia
    line([start(1), stop(1)], [start(2), stop(2)], varargin{:});
end
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
% PLOTVALTESTCOMPARISON Porównanie validation vs test accuracy - POPRAWIONE KOLORY

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

% POPRAWIONE KOLORY - używaj tylko RGB arrays zamiast nazw kolorów
if overfitting > 15
    colorRGB = [1, 0, 0]; % czerwony
elseif overfitting > 8
    colorRGB = [1, 1, 0]; % żółty
elseif overfitting >= -5 && overfitting <= 8
    colorRGB = [0, 1, 0]; % zielony
else
    colorRGB = [0, 0, 1]; % niebieski
end

% TYLKO GAP - bez opisów, z RGB kolorami
text(1.5, 75, sprintf('Gap: %.1f%%', overfitting), ...
    'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', colorRGB, ...
    'FontWeight', 'bold', 'BackgroundColor', 'white', 'EdgeColor', colorRGB, ...
    'Margin', 3);

% USUNIĘTE - żadnych dodatkowych opisów o generalizacji
end

function plotPerClassMetrics(results, titleStr)
% PLOTPERCLASSMETRICS F1-Score dla każdej klasy - POPRAWIONE KOLORY

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

% POPRAWIONE KOLORY - używaj tylko RGB arrays
text(numClasses * 0.75, 0.9, sprintf('Mean F1: %.2f', mean_f1), ...
    'FontSize', 10, 'Color', [1, 0, 0], 'FontWeight', 'bold', ...
    'BackgroundColor', 'white', 'EdgeColor', [1, 0, 0], 'Margin', 2); % ZMIENIONE: RGB zamiast 'red'

% Color bars based on performance
cmap = colormap(hot(100));
for i = 1:numClasses
    color_idx = max(1, min(100, round(f1score(i) * 100)));
    b.CData(i,:) = cmap(color_idx, :);
end
end