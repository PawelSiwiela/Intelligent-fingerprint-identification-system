function visualizeFeatures(trainFeatures, valFeatures, testFeatures, outputDir)
% VISUALIZEFEATURES Wizualizuje rozkłady cech

if nargin < 4, outputDir = fullfile(pwd, 'output', 'figures'); end

fprintf('   📊 Generowanie wizualizacji cech...\n');

% Połącz wszystkie cechy
allFeatures = [trainFeatures; valFeatures; testFeatures];
datasetLabels = [ones(size(trainFeatures,1),1); 2*ones(size(valFeatures,1),1); 3*ones(size(testFeatures,1),1)];

% 1. Podstawowe statystyki
createBasicStatsPlot(allFeatures, datasetLabels, outputDir);

% 2. Mapa gęstości
createDensityHeatmap(allFeatures, outputDir);

% 3. Histogram orientacji
createOrientationPlot(allFeatures, outputDir);

fprintf('   ✅ Wizualizacje cech zapisane w: %s\n', outputDir);
end

function createBasicStatsPlot(features, labels, outputDir)
% Wykres podstawowych statystyk

figure('Visible', 'off', 'Position', [0, 0, 1200, 800]);

statNames = {'Endpoints', 'Bifurcations', 'Total', 'Endpoint Ratio', 'Bifurcation Ratio', 'Density'};
datasetNames = {'Training', 'Validation', 'Test'};
colors = [0.8, 0.2, 0.2; 0.2, 0.8, 0.2; 0.2, 0.2, 0.8];

for i = 1:6
    subplot(2, 3, i);
    
    % Boxplot dla każdego zbioru
    data = [];
    groups = [];
    
    for d = 1:3
        subset = features(labels == d, i);
        data = [data; subset];
        groups = [groups; d * ones(length(subset), 1)];
    end
    
    boxplot(data, groups, 'Labels', datasetNames, 'Colors', colors);
    title(statNames{i}, 'FontWeight', 'bold');
    ylabel('Wartość');
    grid on;
end

sgtitle('Podstawowe statystyki cech', 'FontSize', 16, 'FontWeight', 'bold');

savePath = fullfile(outputDir, 'features_basic_statistics.png');
print(gcf, savePath, '-dpng', '-r200');
close(gcf);
end

function createDensityHeatmap(features, outputDir)
% Średnia mapa gęstości

figure('Visible', 'off', 'Position', [0, 0, 800, 600]);

% Pobierz cechy gęstości (7-70) i przekształć na mapę 8x8
densityFeatures = features(:, 7:70);
avgDensity = mean(densityFeatures, 1);
avgDensityMap = reshape(avgDensity, [8, 8]);

imagesc(avgDensityMap);
colormap(hot);
colorbar;
title('Średnia mapa gęstości minucji (8x8)', 'FontWeight', 'bold');
xlabel('Kolumny siatki');
ylabel('Wiersze siatki');

savePath = fullfile(outputDir, 'features_density_heatmap.png');
print(gcf, savePath, '-dpng', '-r200');
close(gcf);
end

function createOrientationPlot(features, outputDir)
% Histogram orientacji

figure('Visible', 'off', 'Position', [0, 0, 1000, 600]);

% Pobierz cechy orientacji (71-106)
orientationFeatures = features(:, 71:106);
avgOrientation = mean(orientationFeatures, 1);

% Kąty (0-350 stopni, co 10°)
angles = 0:10:350;

bar(angles, avgOrientation, 'FaceColor', [0.2, 0.6, 0.8], 'FaceAlpha', 0.7);
title('Średni rozkład orientacji minucji', 'FontWeight', 'bold');
xlabel('Kąt (stopnie)');
ylabel('Średnia częstość');
xlim([0, 360]);
grid on;

savePath = fullfile(outputDir, 'features_orientation_histogram.png');
print(gcf, savePath, '-dpng', '-r200');
close(gcf);
end