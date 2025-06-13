function compareModels(finalModels, optimizationResults, models)
% COMPAREMODELS Porównuje wyniki różnych modeli

fprintf('\n📊 MODEL COMPARISON\n');
fprintf('===================\n');

% Tabela porównawcza
fprintf('%-12s | %-15s | %-15s | %-12s\n', 'Model', 'Val Accuracy', 'Test Accuracy', 'Train Time');
fprintf('%s\n', repmat('-', 1, 65));

for i = 1:length(models)
    modelType = models{i};
    valAcc = optimizationResults.(modelType).bestScore * 100;
    testAcc = finalModels.([modelType '_results']).testAccuracy * 100;
    trainTime = finalModels.([modelType '_results']).trainTime;
    
    fprintf('%-12s | %13.2f%% | %13.2f%% | %10.1fs\n', ...
        upper(modelType), valAcc, testAcc, trainTime);
end

% Wykres porównawczy
figure('Position', [100, 100, 800, 600]);

subplot(2, 2, 1);
valAccs = [optimizationResults.patternnet.bestScore, optimizationResults.cnn.bestScore] * 100;
testAccs = [finalModels.patternnet_results.testAccuracy, finalModels.cnn_results.testAccuracy] * 100;

x = categorical({'PatternNet', 'CNN'});
y = [valAccs; testAccs]';

bar(x, y);
title('Model Accuracy Comparison');
ylabel('Accuracy (%)');
legend('Validation', 'Test', 'Location', 'best');
grid on;

subplot(2, 2, 2);
trainTimes = [finalModels.patternnet_results.trainTime, finalModels.cnn_results.trainTime];
bar(x, trainTimes);
title('Training Time Comparison');
ylabel('Time (seconds)');
grid on;

% Confusion matrices
subplot(2, 2, 3);
plotConfusionMatrix(finalModels.patternnet_results, 'PatternNet');

subplot(2, 2, 4);
plotConfusionMatrix(finalModels.cnn_results, 'CNN');

saveas(gcf, 'output/figures/model_comparison.png');
close(gcf);
end

function plotConfusionMatrix(results, modelName)
% PLOTCONFUSIONMATRIX Rysuje confusion matrix

C = confusionmat(results.trueLabels, results.predictions);
confusionchart(C);
title(sprintf('%s Confusion Matrix', modelName));
end