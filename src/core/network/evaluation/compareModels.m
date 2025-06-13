function compareModels(finalModels, optimizationResults, models)
% COMPAREMODELS Porównuje wyniki różnych modeli - TYLKO PATTERNNET

fprintf('\n📊 MODEL ANALYSIS\n');
fprintf('==================\n');

% Analiza PatternNet
if isfield(finalModels, 'patternnet')
    valAcc = optimizationResults.patternnet.bestScore * 100;
    testAcc = finalModels.patternnet_results.testAccuracy * 100;
    trainTime = finalModels.patternnet_results.trainTime;
    
    fprintf('PATTERNNET RESULTS:\n');
    fprintf('  Validation Accuracy: %.2f%%\n', valAcc);
    fprintf('  Test Accuracy:       %.2f%%\n', testAcc);
    fprintf('  Training Time:       %.1f seconds\n', trainTime);
    
    % Wykres wyników
    figure('Position', [100, 100, 600, 400]);
    
    subplot(1, 2, 1);
    bar([valAcc, testAcc]);
    set(gca, 'XTickLabel', {'Validation', 'Test'});
    title('PatternNet Accuracy');
    ylabel('Accuracy (%)');
    ylim([0, 100]);
    grid on;
    
    subplot(1, 2, 2);
    plotConfusionMatrix(finalModels.patternnet_results, 'PatternNet');
    
    saveas(gcf, 'output/figures/patternnet_analysis.png');
    close(gcf);
else
    fprintf('⚠️  No PatternNet results to analyze\n');
end
end

function plotConfusionMatrix(results, modelName)
% PLOTCONFUSIONMATRIX Rysuje confusion matrix

C = confusionmat(results.trueLabels, results.predictions);
confusionchart(C);
title(sprintf('%s Confusion Matrix', modelName));
end