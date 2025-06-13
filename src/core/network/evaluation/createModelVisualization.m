function createModelVisualization(model, results, modelType, testData)
% CREATEMODELVISUALIZATION Tworzy szczegółowe wizualizacje dla modelu

outputDir = 'output/figures';
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

figure('Position', [100, 100, 1200, 800]);

% ROC Curve
subplot(2, 3, 1);
plotROCCurve(results, sprintf('%s ROC Curve', upper(modelType)));

% Precision-Recall
subplot(2, 3, 2);
plotPrecisionRecall(results, sprintf('%s Precision-Recall', upper(modelType)));

% Feature importance (dla PatternNet)
if strcmp(modelType, 'patternnet')
    subplot(2, 3, 3);
    plotFeatureImportance(model, testData, 'Feature Importance');
end

% Class accuracy
subplot(2, 3, 4);
plotClassAccuracy(results, sprintf('%s Per-Class Accuracy', upper(modelType)));

% Training metrics visualization
subplot(2, 3, 5);
plotTrainingMetrics(results, sprintf('%s Training Summary', upper(modelType)));

% Hyperparameters visualization
subplot(2, 3, 6);
plotHyperparameters(results.hyperparams, sprintf('%s Hyperparameters', upper(modelType)));

sgtitle(sprintf('%s Detailed Analysis', upper(modelType)), 'FontSize', 16);

saveas(gcf, fullfile(outputDir, sprintf('%s_detailed_analysis.png', modelType)));
close(gcf);
end

function plotROCCurve(results, titleStr)
% PLOTROCCURVE Rysuje krzywą ROC

% One-vs-rest ROC dla multi-class
numClasses = length(unique(results.trueLabels));
colors = lines(numClasses);

hold on;
for class = 1:numClasses
    % Binary classification: class vs rest
    trueBinary = (results.trueLabels == class);
    predBinary = (results.predictions == class);
    
    [X, Y, ~, AUC] = perfcurve(trueBinary, double(predBinary), true);
    plot(X, Y, 'Color', colors(class,:), 'LineWidth', 2, ...
        'DisplayName', sprintf('Class %d (AUC=%.3f)', class, AUC));
end

plot([0,1], [0,1], 'k--', 'LineWidth', 1);
xlabel('False Positive Rate');
ylabel('True Positive Rate');
title(titleStr);
legend('Location', 'southeast');
grid on;
end

function plotPrecisionRecall(results, titleStr)
% PLOTPRECISIONRECALL Rysuje krzywą Precision-Recall

% Oblicz precision i recall per class
numClasses = length(unique(results.trueLabels));
C = confusionmat(results.trueLabels, results.predictions);

precision = diag(C) ./ sum(C, 1)';
recall = diag(C) ./ sum(C, 2);

% Remove NaN values
precision(isnan(precision)) = 0;
recall(isnan(recall)) = 0;

x = categorical(arrayfun(@(x) sprintf('Class %d', x), 1:numClasses, 'UniformOutput', false));
bar(x, [precision, recall]);
title(titleStr);
ylabel('Score');
legend('Precision', 'Recall', 'Location', 'best');
grid on;
ylim([0, 1]);
end

function plotFeatureImportance(model, testData, titleStr)
% PLOTFEATUREIMPORTANCE Wizualizuje ważność cech dla PatternNet

% Dla PatternNet - analiza wag
if isa(model, 'network')
    weights = model.IW{1}; % Input weights [neurons x features]
    
    % Oblicz średnią absolutną wartość wag dla każdej cechy
    featureImportance = mean(abs(weights), 1);
    
    % Normalizuj do [0, 1]
    featureImportance = featureImportance / max(featureImportance);
    
    bar(featureImportance);
    xlabel('Feature Index');
    ylabel('Importance');
    title(titleStr);
    grid on;
else
    text(0.5, 0.5, 'Feature importance not available for this model type', ...
        'HorizontalAlignment', 'center');
    title(titleStr);
end
end

function plotClassAccuracy(results, titleStr)
% PLOTCLASSACCURACY Wizualizuje accuracy per klasa

C = confusionmat(results.trueLabels, results.predictions);
classAccuracy = diag(C) ./ sum(C, 2);

% Usuń NaN
classAccuracy(isnan(classAccuracy)) = 0;

x = categorical(arrayfun(@(x) sprintf('Class %d', x), 1:length(classAccuracy), 'UniformOutput', false));
bar(x, classAccuracy);
title(titleStr);
ylabel('Accuracy');
ylim([0, 1]);
grid on;

% Dodaj wartości na słupkach
for i = 1:length(classAccuracy)
    text(i, classAccuracy(i) + 0.02, sprintf('%.2f', classAccuracy(i)), ...
        'HorizontalAlignment', 'center');
end
end

function plotTrainingMetrics(results, titleStr)
% PLOTTRAININGMETRICS Podsumowanie treningu

metrics = {
    'Test Accuracy', results.testAccuracy;
    'Train Time (s)', results.trainTime;
    'Model Type', 1  % Placeholder
};

subplot(2,1,1);
bar([results.testAccuracy, results.trainTime/100]); % Przeskaluj czas
set(gca, 'XTickLabel', {'Accuracy', 'Time/100'});
title(sprintf('%s - Performance Metrics', titleStr));
ylabel('Value');
grid on;

subplot(2,1,2);
text(0.5, 0.5, sprintf('Model: %s\nAccuracy: %.2f%%\nTime: %.1fs', ...
    results.modelType, results.testAccuracy*100, results.trainTime), ...
    'HorizontalAlignment', 'center', 'FontSize', 12);
axis off;
end

function plotHyperparameters(hyperparams, titleStr)
% PLOTHYPERPARAMETERS Wizualizuje hiperparametry

fields = fieldnames(hyperparams);
values = [];
labels = {};

for i = 1:length(fields)
    field = fields{i};
    value = hyperparams.(field);
    
    if isnumeric(value) && isscalar(value)
        values(end+1) = value;
        labels{end+1} = field;
    end
end

if ~isempty(values)
    % Normalizuj wartości do lepszej wizualizacji
    normalizedValues = values ./ max(abs(values));
    
    bar(normalizedValues);
    set(gca, 'XTickLabel', labels);
    title(titleStr);
    ylabel('Normalized Value');
    xtickangle(45);
    grid on;
else
    text(0.5, 0.5, 'No numeric hyperparameters to display', ...
        'HorizontalAlignment', 'center');
    title(titleStr);
end
end