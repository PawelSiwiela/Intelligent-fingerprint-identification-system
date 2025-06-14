function visualizeReduction(originalFeatures, reducedFeatures, reductionInfo, labels, metadata, outputDir)
% VISUALIZEREDUCTION Wizualizuj efekt redukcji wymiarowości

if nargin < 6
    outputDir = 'output/figures';
end

figure('Position', [100, 100, 1400, 1000]);

%% SUBPLOT 1: Porównanie wymiarowości
subplot(2, 3, 1);
dims = [reductionInfo.originalDims, reductionInfo.reducedDims];
labels_dims = {'Original', 'Reduced'};
colors = [0.8, 0.2, 0.2; 0.2, 0.8, 0.2];

b = bar(dims);
b.FaceColor = 'flat';
b.CData = colors;

set(gca, 'XTickLabel', labels_dims);
ylabel('Number of Features');
title('Dimensionality Reduction', 'FontWeight', 'bold');

% Dodaj wartości na słupkach
for i = 1:length(dims)
    text(i, dims(i)/2, sprintf('%d', dims(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'Color', 'white', 'FontSize', 12);
end

% Dodaj procent redukcji
reduction_pct = (1 - dims(2)/dims(1)) * 100;
text(1.5, max(dims)*0.8, sprintf('%.1f%% reduction', reduction_pct), ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
    'BackgroundColor', 'yellow', 'EdgeColor', 'black');

grid on;

%% SUBPLOT 2: Explained Variance/Separability Analysis
subplot(2, 3, 2);
if strcmp(reductionInfo.method, 'mda')
    % NOWE: MDA DISCRIMINANT ANALYSIS
    plotMDADiscriminantAnalysis(reductionInfo);
    
elseif strcmp(reductionInfo.method, 'lda')
    % LDA SEPARABILITY ANALYSIS
    plotLDASeparabilityAnalysis(reductionInfo);
    
elseif strcmp(reductionInfo.method, 'pca') || (strcmp(reductionInfo.method, 'combined') && isfield(reductionInfo, 'step2'))
    % PCA VARIANCE ANALYSIS
    if strcmp(reductionInfo.method, 'pca')
        explained = reductionInfo.explained;
    else
        explained = reductionInfo.step2.explained;
    end
    
    cumExplained = cumsum(explained);
    
    yyaxis left
    bar(1:length(explained), explained, 'FaceColor', [0.3, 0.6, 0.9]);
    ylabel('Individual Variance %', 'Color', [0.3, 0.6, 0.9]);
    ylim([0, max(explained)*1.1]);
    
    yyaxis right
    plot(1:length(explained), cumExplained, 'ro-', 'LineWidth', 2, 'MarkerSize', 6);
    ylabel('Cumulative Variance %', 'Color', 'red');
    ylim([0, 100]);
    
    xlabel('Principal Component');
    title('PCA Variance Explained', 'FontWeight', 'bold');
    grid on;
else
    text(0.5, 0.5, 'Analysis not available', ...
        'HorizontalAlignment', 'center', 'FontSize', 12);
    title('Component Analysis', 'FontWeight', 'bold');
end

%% SUBPLOT 3: Feature Correlation/Component Analysis - ROZSZERZONE DLA LDA
subplot(2, 3, 3);
if strcmp(reductionInfo.method, 'lda')
    % NOWE: LDA COMPONENT WEIGHTS ANALYSIS
    plotLDAComponentWeights(reductionInfo);
    
elseif size(reducedFeatures, 2) <= 15 % PCA correlation matrix
    corrMatrix = corr(reducedFeatures);
    imagesc(corrMatrix);
    colormap(redblue(64));
    colorbar;
    caxis([-1, 1]);
    
    % Użyj sensownych nazw cech
    numComponents = size(reducedFeatures, 2);
    componentNames = cell(1, numComponents);
    for i = 1:numComponents
        if strcmp(reductionInfo.method, 'pca') && isfield(reductionInfo, 'explained')
            componentNames{i} = sprintf('PC%d\n(%.1f%%)', i, reductionInfo.explained(i));
        else
            componentNames{i} = sprintf('PC%d', i);
        end
    end
    
    set(gca, 'XTick', 1:numComponents, 'YTick', 1:numComponents);
    set(gca, 'XTickLabel', componentNames, 'YTickLabel', componentNames);
    xtickangle(45);
    
    title('Reduced Features Correlation', 'FontWeight', 'bold');
    xlabel('Principal Components');
    ylabel('Principal Components');
    
    % Dodaj wartości korelacji
    [m, n] = size(corrMatrix);
    for i = 1:m
        for j = 1:n
            if abs(corrMatrix(i,j)) > 0.5
                if abs(corrMatrix(i,j)) > 0.7
                    textColor = 'white';
                else
                    textColor = 'black';
                end
                text(j, i, sprintf('%.2f', corrMatrix(i,j)), ...
                    'HorizontalAlignment', 'center', 'Color', textColor, 'FontSize', 8);
            end
        end
    end
else
    text(0.5, 0.5, sprintf('Too many features (%d) for display', size(reducedFeatures, 2)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
    title('Feature Analysis', 'FontWeight', 'bold');
end

%% SUBPLOT 4-6: Scatter plots - ULEPSZONE DLA LDA
uniqueLabels = unique(labels);
fingerNames = cell(1, length(uniqueLabels));
for i = 1:length(uniqueLabels)
    fingerNames{i} = metadata.fingerNames{uniqueLabels(i)};
end

colors = lines(length(uniqueLabels));

% SUBPLOT 4: First Two Components Z ELIPSAMI i LDA DECISION BOUNDARIES
subplot(2, 3, 4);
if size(reducedFeatures, 2) >= 2
    for i = 1:length(uniqueLabels)
        mask = labels == uniqueLabels(i);
        scatter(reducedFeatures(mask, 1), reducedFeatures(mask, 2), 50, colors(i,:), ...
            'filled', 'DisplayName', fingerNames{i});
        hold on;
        
        % Elipsy ufności
        if sum(mask) >= 3
            try
                plotConfidenceEllipse(reducedFeatures(mask, 1), reducedFeatures(mask, 2), colors(i,:), 0.95);
            catch
            end
        end
    end
    
    % NOWE: Decision boundaries dla LDA
    if strcmp(reductionInfo.method, 'lda') && size(reducedFeatures, 2) >= 2
        plotLDADecisionBoundaries(reducedFeatures, labels, colors);
    end
    
    % Nazwy osi - różne dla LDA i PCA
    if strcmp(reductionInfo.method, 'lda')
        xlabel(sprintf('LD1 (λ=%.3f)', reductionInfo.eigenValues(1)));
        ylabel(sprintf('LD2 (λ=%.3f)', reductionInfo.eigenValues(min(2, end))));
    elseif strcmp(reductionInfo.method, 'pca') && isfield(reductionInfo, 'explained')
        xlabel(sprintf('PC1 (%.1f%% variance)', reductionInfo.explained(1)));
        ylabel(sprintf('PC2 (%.1f%% variance)', reductionInfo.explained(2)));
    else
        xlabel('Component 1');
        ylabel('Component 2');
    end
    
    title('First Two Components', 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 8);
    grid on;
else
    text(0.5, 0.5, 'Need at least 2 components', 'HorizontalAlignment', 'center');
    title('2D Projection', 'FontWeight', 'bold');
end

% SUBPLOT 5: Components 1 vs 3
subplot(2, 3, 5);
if size(reducedFeatures, 2) >= 3
    for i = 1:length(uniqueLabels)
        mask = labels == uniqueLabels(i);
        scatter(reducedFeatures(mask, 1), reducedFeatures(mask, 3), 50, colors(i,:), ...
            'filled', 'DisplayName', fingerNames{i});
        hold on;
        
        if sum(mask) >= 3
            try
                plotConfidenceEllipse(reducedFeatures(mask, 1), reducedFeatures(mask, 3), colors(i,:), 0.95);
            catch
            end
        end
    end
    
    % Nazwy osi
    if strcmp(reductionInfo.method, 'lda')
        xlabel(sprintf('LD1 (λ=%.3f)', reductionInfo.eigenValues(1)));
        ylabel(sprintf('LD3 (λ=%.3f)', reductionInfo.eigenValues(min(3, end))));
    elseif strcmp(reductionInfo.method, 'pca') && isfield(reductionInfo, 'explained')
        xlabel(sprintf('PC1 (%.1f%% variance)', reductionInfo.explained(1)));
        ylabel(sprintf('PC3 (%.1f%% variance)', reductionInfo.explained(3)));
    else
        xlabel('Component 1');
        ylabel('Component 3');
    end
    
    title('Components 1 vs 3', 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 8);
    grid on;
else
    text(0.5, 0.5, 'Need at least 3 components', 'HorizontalAlignment', 'center');
    title('Alternative 2D Projection', 'FontWeight', 'bold');
end

% SUBPLOT 6: Components 2 vs 3 LUB CLASS SEPARABILITY METRICS
subplot(2, 3, 6);
if strcmp(reductionInfo.method, 'lda')
    % NOWE: Class separability metrics dla LDA
    plotLDAClassSeparabilityMetrics(reducedFeatures, labels, fingerNames, reductionInfo);
    
elseif size(reducedFeatures, 2) >= 3
    % ISTNIEJĄCE: PC2 vs PC3 dla PCA
    for i = 1:length(uniqueLabels)
        mask = labels == uniqueLabels(i);
        scatter(reducedFeatures(mask, 2), reducedFeatures(mask, 3), 50, colors(i,:), ...
            'filled', 'DisplayName', fingerNames{i});
        hold on;
        
        if sum(mask) >= 3
            try
                plotConfidenceEllipse(reducedFeatures(mask, 2), reducedFeatures(mask, 3), colors(i,:), 0.95);
            catch
            end
        end
    end
    
    if strcmp(reductionInfo.method, 'pca') && isfield(reductionInfo, 'explained')
        xlabel(sprintf('PC2 (%.1f%% variance)', reductionInfo.explained(2)));
        ylabel(sprintf('PC3 (%.1f%% variance)', reductionInfo.explained(3)));
    else
        xlabel('Component 2');
        ylabel('Component 3');
    end
    
    title('Components 2 vs 3', 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 8);
    grid on;
else
    text(0.5, 0.5, 'Need at least 3 components', 'HorizontalAlignment', 'center');
    title('Components Analysis', 'FontWeight', 'bold');
end

sgtitle(sprintf('Dimensionality Reduction Analysis (%s)', upper(reductionInfo.method)), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Zapisz
saveas(gcf, fullfile(outputDir, 'dimensionality_reduction_analysis.png'));
close(gcf);

fprintf('📊 Dimensionality reduction visualization saved\n');
end

function plotConfidenceEllipse(x, y, color, confidence)
% PLOTCONFIDENCEELLIPSE Rysuje elipsę poziomu ufności dla danych 2D
%
% Args:
%   x, y - współrzędne punktów
%   color - kolor elipsy
%   confidence - poziom ufności (np. 0.95 dla 95%)

% Sprawdź czy mamy wystarczająco punktów
if length(x) < 3 || length(y) < 3
    return;
end

% Usuń NaN i Inf
validIdx = isfinite(x) & isfinite(y);
x = x(validIdx);
y = y(validIdx);

if length(x) < 3
    return;
end

try
    % Oblicz średnie
    mu_x = mean(x);
    mu_y = mean(y);
    
    % Oblicz macierz kowariancji
    data = [x(:) - mu_x, y(:) - mu_y];
    covMatrix = cov(data);
    
    % Sprawdź czy macierz jest dodatnio określona
    if any(eig(covMatrix) <= 0)
        return;
    end
    
    % Współczynnik dla poziomu ufności (chi-square distribution dla 2 DOF)
    if confidence == 0.95
        chi2_val = 5.991; % 95% confidence dla 2 DOF
    elseif confidence == 0.99
        chi2_val = 9.210; % 99% confidence dla 2 DOF
    elseif confidence == 0.90
        chi2_val = 4.605; % 90% confidence dla 2 DOF
    else
        % Ogólne obliczenie dla dowolnego poziomu ufności
        chi2_val = chi2inv(confidence, 2);
    end
    
    % Dekompozycja własna macierzy kowariancji
    [eigVec, eigVal] = eig(covMatrix);
    eigVal = diag(eigVal);
    
    % Półosie elipsy
    a = sqrt(chi2_val * eigVal(1)); % Półoś główna
    b = sqrt(chi2_val * eigVal(2)); % Półoś poboczna
    
    % Kąt obrotu
    angle = atan2(eigVec(2, 1), eigVec(1, 1));
    
    % Wygeneruj punkty elipsy
    theta = linspace(0, 2*pi, 100);
    ellipse_x = a * cos(theta);
    ellipse_y = b * sin(theta);
    
    % Obróć elipsę
    cos_angle = cos(angle);
    sin_angle = sin(angle);
    ellipse_x_rot = ellipse_x * cos_angle - ellipse_y * sin_angle;
    ellipse_y_rot = ellipse_x * sin_angle + ellipse_y * cos_angle;
    
    % Przesuń do środka
    ellipse_x_rot = ellipse_x_rot + mu_x;
    ellipse_y_rot = ellipse_y_rot + mu_y;
    
    % Narysuj elipsę
    plot(ellipse_x_rot, ellipse_y_rot, '--', 'Color', color, 'LineWidth', 1.5, ...
        'HandleVisibility', 'off'); % Nie pokazuj w legendzie
    
    % Dodaj środek
    plot(mu_x, mu_y, '+', 'Color', color, 'MarkerSize', 8, 'LineWidth', 2, ...
        'HandleVisibility', 'off');
    
catch ME
    % Jeśli nie można narysować elipsy, pomiń ją
    fprintf('Warning: Could not plot confidence ellipse: %s\n', ME.message);
end
end

function cmap = redblue(n)
% REDBLUE Niebiesko-biało-czerwona mapa kolorów
if nargin < 1, n = 256; end
if n == 1, cmap = [1 1 1]; return; end

half = floor(n/2);
blue_to_white = [linspace(0, 1, half)', linspace(0, 1, half)', ones(half, 1)];
white_to_red = [ones(n-half, 1), linspace(1, 0, n-half)', linspace(1, 0, n-half)'];
cmap = [blue_to_white; white_to_red];
end

%% NOWE FUNKCJE DLA LDA VISUALIZATIONS

function plotLDASeparabilityAnalysis(reductionInfo)
% PLOTLDASEPARABILITYANALYSIS Analiza separowalności klas dla LDA

eigenValues = reductionInfo.eigenValues;
explainedRatio = reductionInfo.explainedVarianceRatio;

% Bar chart eigenvalues z annotations
yyaxis left
bars = bar(1:length(eigenValues), eigenValues, 'FaceColor', [0.8, 0.3, 0.3]);
ylabel('Eigenvalue (Separability)', 'Color', [0.8, 0.3, 0.3]);
ylim([0, max(eigenValues)*1.1]);

% Line plot explained ratio
yyaxis right
line = plot(1:length(explainedRatio), explainedRatio * 100, 'bo-', 'LineWidth', 2, 'MarkerSize', 6);
ylabel('Discrimination Power (%)', 'Color', 'blue');
ylim([0, 100]);

% Annotations
for i = 1:length(eigenValues)
    text(i, eigenValues(i)/2, sprintf('λ=%.2f', eigenValues(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'white', 'FontSize', 8);
    
    text(i, explainedRatio(i)*100 + 5, sprintf('%.1f%%', explainedRatio(i)*100), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'blue', 'FontSize', 8);
end

xlabel('Linear Discriminant');
title('LDA Separability Analysis', 'FontWeight', 'bold');
grid on;

% Separability score annotation
if isfield(reductionInfo, 'separabilityScore')
    text(length(eigenValues)/2, max(eigenValues)*0.8, ...
        sprintf('Overall Separability: %.3f', reductionInfo.separabilityScore), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'BackgroundColor', 'yellow', 'EdgeColor', 'black', 'Margin', 3);
end
end

function plotLDAComponentWeights(reductionInfo)
% PLOTLDACOMPONENTWEIGHTS Wizualizuje wagi cech w komponentach LDA

if ~isfield(reductionInfo, 'coeff') || isempty(reductionInfo.coeff)
    text(0.5, 0.5, 'LDA coefficients not available', 'HorizontalAlignment', 'center');
    title('LDA Component Weights', 'FontWeight', 'bold');
    return;
end

coeff = reductionInfo.coeff;
numComponents = min(3, size(coeff, 2)); % Max 3 komponenty dla czytelności
numFeatures = size(coeff, 1);

% Heatmap wag
imagesc(coeff(:, 1:numComponents)');
colormap(redblue(64));
colorbar;

% Labels
componentNames = cell(1, numComponents);
for i = 1:numComponents
    if isfield(reductionInfo, 'eigenValues')
        componentNames{i} = sprintf('LD%d\n(λ=%.2f)', i, reductionInfo.eigenValues(i));
    else
        componentNames{i} = sprintf('LD%d', i);
    end
end

featureNames = cell(1, numFeatures);
for i = 1:numFeatures
    featureNames{i} = sprintf('F%d', i);
end

set(gca, 'XTick', 1:numFeatures, 'YTick', 1:numComponents);
set(gca, 'XTickLabel', featureNames, 'YTickLabel', componentNames);
xtickangle(45);

% Dodaj wartości wag
for i = 1:numComponents
    for j = 1:numFeatures
        weight = coeff(j, i);
        if abs(weight) > 0.3
            if abs(weight) > 0.6
                textColor = 'white';
            else
                textColor = 'black';
            end
            text(j, i, sprintf('%.2f', weight), ...
                'HorizontalAlignment', 'center', 'Color', textColor, 'FontSize', 7);
        end
    end
end

title('LDA Component Weights', 'FontWeight', 'bold');
xlabel('Original Features');
ylabel('LDA Components');
end

function plotLDADecisionBoundaries(reducedFeatures, labels, colors)
% PLOTLDADECISIONBOUNDARIES Rysuje granice decyzyjne dla LDA w 2D

if size(reducedFeatures, 2) < 2
    return;
end

% Grid dla decision boundary
x1_range = linspace(min(reducedFeatures(:,1)), max(reducedFeatures(:,1)), 50);
x2_range = linspace(min(reducedFeatures(:,2)), max(reducedFeatures(:,2)), 50);
[X1, X2] = meshgrid(x1_range, x2_range);

% Dla każdej pary klas, narysuj boundary
uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);

if numClasses == 2
    % Binary classification - jedna granica
    label1_data = reducedFeatures(labels == uniqueLabels(1), 1:2);
    label2_data = reducedFeatures(labels == uniqueLabels(2), 1:2);
    
    mean1 = mean(label1_data, 1);
    mean2 = mean(label2_data, 1);
    
    % Linia między środkami klas
    plot([mean1(1), mean2(1)], [mean1(2), mean2(2)], 'k--', 'LineWidth', 2, ...
        'DisplayName', 'Class Centers');
    
    % Perpendicular bisector jako decision boundary
    mid_point = (mean1 + mean2) / 2;
    direction = mean2 - mean1;
    perp_direction = [-direction(2), direction(1)];
    perp_direction = perp_direction / norm(perp_direction);
    
    boundary_length = norm(mean2 - mean1) * 1.5;
    boundary_start = mid_point - perp_direction * boundary_length;
    boundary_end = mid_point + perp_direction * boundary_length;
    
    plot([boundary_start(1), boundary_end(1)], [boundary_start(2), boundary_end(2)], ...
        'k-', 'LineWidth', 3, 'DisplayName', 'Decision Boundary');
    
elseif numClasses > 2
    % Multi-class - pokaż Voronoi-style boundaries
    class_centers = zeros(numClasses, 2);
    for i = 1:numClasses
        class_data = reducedFeatures(labels == uniqueLabels(i), 1:2);
        if ~isempty(class_data)
            class_centers(i, :) = mean(class_data, 1);
            
            % Pokaż center każdej klasy
            plot(class_centers(i, 1), class_centers(i, 2), 'k+', ...
                'MarkerSize', 12, 'LineWidth', 3, 'HandleVisibility', 'off');
        end
    end
    
    % Narysuj linie między sąsiednimi centrami
    for i = 1:numClasses-1
        for j = i+1:numClasses
            if all(class_centers(i, :) ~= 0) && all(class_centers(j, :) ~= 0)
                plot([class_centers(i, 1), class_centers(j, 1)], ...
                    [class_centers(i, 2), class_centers(j, 2)], ...
                    'k:', 'LineWidth', 1, 'HandleVisibility', 'off');
            end
        end
    end
end
end

function plotLDAClassSeparabilityMetrics(reducedFeatures, labels, fingerNames, reductionInfo)
% PLOTLDACLASSSEPARABILITYMETRICS Metryki separowalności klas

uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);

% Oblicz między-klasowe i wewnątrz-klasowe odległości
between_class_distances = [];
within_class_distances = [];
class_labels = {};

for i = 1:numClasses
    class_data = reducedFeatures(labels == uniqueLabels(i), :);
    
    if size(class_data, 1) > 1
        % Within-class distance (średnia odległość od centroidu)
        class_center = mean(class_data, 1);
        distances_to_center = sqrt(sum((class_data - class_center).^2, 2));
        within_class_distances(i) = mean(distances_to_center);
        
        % Between-class distance (do najbliższej innej klasy)
        min_between_dist = inf;
        for j = 1:numClasses
            if i ~= j
                other_class_data = reducedFeatures(labels == uniqueLabels(j), :);
                if ~isempty(other_class_data)
                    other_center = mean(other_class_data, 1);
                    dist = norm(class_center - other_center);
                    min_between_dist = min(min_between_dist, dist);
                end
            end
        end
        between_class_distances(i) = min_between_dist;
        
    else
        within_class_distances(i) = 0;
        between_class_distances(i) = 0;
    end
    
    class_labels{i} = fingerNames{i};
end

% Separability ratio (between/within)
separability_ratios = between_class_distances ./ max(within_class_distances, 0.01);

% Bar chart
x = 1:numClasses;
width = 0.25;

bars1 = bar(x - width, within_class_distances, width, 'FaceColor', [0.8, 0.3, 0.3], ...
    'DisplayName', 'Within-class');
hold on;
bars2 = bar(x, between_class_distances, width, 'FaceColor', [0.3, 0.6, 0.9], ...
    'DisplayName', 'Between-class');
bars3 = bar(x + width, separability_ratios, width, 'FaceColor', [0.3, 0.8, 0.3], ...
    'DisplayName', 'Separability');

set(gca, 'XTick', x, 'XTickLabel', class_labels);
xtickangle(45);
ylabel('Distance / Ratio');
title('LDA Class Separability Metrics', 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8);
grid on;

% Dodaj wartości nad słupami
for i = 1:numClasses
    text(i - width, within_class_distances(i) + max(within_class_distances)*0.02, ...
        sprintf('%.2f', within_class_distances(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 7);
    text(i, between_class_distances(i) + max(between_class_distances)*0.02, ...
        sprintf('%.2f', between_class_distances(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 7);
    text(i + width, separability_ratios(i) + max(separability_ratios)*0.02, ...
        sprintf('%.1f', separability_ratios(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 7);
end

% Overall separability score
if isfield(reductionInfo, 'separabilityScore')
    text(numClasses/2, max([within_class_distances, between_class_distances, separability_ratios])*0.9, ...
        sprintf('Overall Score: %.3f', reductionInfo.separabilityScore), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'BackgroundColor', 'yellow', 'EdgeColor', 'black');
end
end

function plotMDADiscriminantAnalysis(reductionInfo)
% PLOTMDADISCRIMINANTANALYSIS Analiza dyskryminacyjna dla MDA

eigenValues = reductionInfo.eigenValues;
explainedRatio = reductionInfo.explainedVarianceRatio;

% Bar chart eigenvalues z annotations
yyaxis left
bars = bar(1:length(eigenValues), eigenValues, 'FaceColor', [0.2, 0.8, 0.4]);
ylabel('Eigenvalue (Discriminant Power)', 'Color', [0.2, 0.8, 0.4]);
ylim([0, max(eigenValues)*1.1]);

% Line plot explained ratio
yyaxis right
line = plot(1:length(explainedRatio), explainedRatio * 100, 'ro-', 'LineWidth', 2, 'MarkerSize', 6);
ylabel('Relative Power (%)', 'Color', 'red');
ylim([0, 100]);

% Annotations
for i = 1:length(eigenValues)
    text(i, eigenValues(i)/2, sprintf('λ=%.2f', eigenValues(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'white', 'FontSize', 8);
    
    text(i, explainedRatio(i)*100 + 5, sprintf('%.1f%%', explainedRatio(i)*100), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'red', 'FontSize', 8);
end

xlabel('MDA Component');
title('MDA Discriminant Analysis', 'FontWeight', 'bold');
grid on;

% Method info
if isfield(reductionInfo, 'methodUsed')
    text(length(eigenValues)/2, max(eigenValues)*0.8, ...
        sprintf('Method: %s\nSeparability: %.3f', upper(reductionInfo.methodUsed), reductionInfo.separabilityScore), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'BackgroundColor', 'yellow', 'EdgeColor', 'black', 'Margin', 3);
end
end