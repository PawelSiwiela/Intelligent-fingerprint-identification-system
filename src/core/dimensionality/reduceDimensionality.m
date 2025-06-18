function [reducedFeatures, info] = reduceDimensionality(features, method, params, labels)
% REDUCEDIMENSIONALITY Reduces feature dimensionality using specified method - BEZ LDA

if nargin < 4
    labels = [];
end

fprintf('🔍 Applying %s...\n', upper(method));

switch lower(method)
    case 'pca'
        [reducedFeatures, info] = applyPCA(features, params);
        
    case 'mda'
        if isempty(labels)
            error('MDA requires labels for supervised learning');
        end
        [reducedFeatures, info] = applyMDA(features, labels, params);
        
    otherwise
        error('Unknown dimensionality reduction method: %s. Available: PCA, MDA', method);
end

% Podsumowanie (wspólne dla wszystkich metod)
fprintf('✅ %s completed: %d → %d features\n', upper(method), ...
    size(features, 2), size(reducedFeatures, 2));

if isfield(info, 'varianceExplained') && ~isempty(info.varianceExplained)
    fprintf('   (%.1f%% variance preserved)\n', info.varianceExplained * 100);
elseif isfield(info, 'totalVarianceExplained') && ~isempty(info.totalVarianceExplained)
    fprintf('   (%.1f%% variance preserved)\n', info.totalVarianceExplained);
end

fprintf('\n📊 Dimensionality Reduction Summary:\n');
fprintf('Method: %s\n', upper(method));
fprintf('Original dimensions: %d\n', size(features, 2));
fprintf('Reduced dimensions: %d\n', size(reducedFeatures, 2));
fprintf('Reduction ratio: %.1f%%\n', (1 - size(reducedFeatures, 2)/size(features, 2)) * 100);

% Wbudowana analiza
switch lower(method)
    case 'mda'
        if isfield(info, 'separabilityScore')
            fprintf('Class separability: %.3f\n', info.separabilityScore);
        end
        if isfield(info, 'eigenValues') && ~isempty(info.eigenValues)
            fprintf('Top eigenvalues: %s\n', mat2str(info.eigenValues(1:min(3, end))', 3));
        end
        
    case 'pca'
        if isfield(info, 'explained') && ~isempty(info.explained)
            topComponents = min(3, length(info.explained));
            fprintf('Top %d components explain: %.1f%% variance\n', ...
                topComponents, sum(info.explained(1:topComponents)));
            fprintf('Individual variance: %s%%\n', ...
                mat2str(info.explained(1:topComponents)', 1));
        end
end

end

%% SUBFUNCTIONS - USUŃ LDA FUNCTIONS

function [reducedFeatures, info] = applyPCA(features, params)
% APPLYPCA Applies Principal Component Analysis - BEZ ZMIAN

% Domyślne parametry
if ~isfield(params, 'varianceThreshold')
    params.varianceThreshold = 0.95; % 95% wariancji
end

if ~isfield(params, 'maxComponents')
    params.maxComponents = min(size(features, 1) - 1, 15); % Max 15 komponentów
end

fprintf('   Target variance preserved: %.1f%%\n', params.varianceThreshold * 100);

% PCA z MATLAB
[coeff, score, latent, ~, explained] = pca(features);

% Oblicz kumulatywną wariancję
cumulativeVariance = cumsum(explained) / 100;

% Znajdź liczbę komponentów dla żądanej wariancji
numComponents = find(cumulativeVariance >= params.varianceThreshold, 1, 'first');

% Ogranicz do maksymalnej liczby komponentów
numComponents = min(numComponents, params.maxComponents);

% Jeśli nie znaleziono, użyj maksymalnej liczby
if isempty(numComponents)
    numComponents = params.maxComponents;
end

% Ekstraktuj pierwsze numComponents komponentów
reducedFeatures = score(:, 1:numComponents);

% Informacje o redukcji
info = struct();
info.method = 'PCA';
info.numComponents = numComponents;
info.coefficients = coeff(:, 1:numComponents);
info.eigenvalues = latent(1:numComponents);
info.explained = explained(1:numComponents);
info.varianceExplained = cumulativeVariance(numComponents);
info.totalVarianceExplained = sum(explained(1:numComponents));
info.originalDims = size(features, 2);
info.reducedDims = numComponents;

end

function [reducedFeatures, info] = applyMDA(features, labels, params)
% APPLYMDA Applies Multiple Discriminant Analysis (enhanced LDA) - BEZ ZMIAN

% Domyślne parametry
if ~isfield(params, 'maxComponents')
    params.maxComponents = 4;
end

fprintf('   Target components: %d\n', params.maxComponents);

% MDA - Enhanced LDA with better class separation
numClasses = length(unique(labels));
actualComponents = min(numClasses - 1, params.maxComponents);

% Oblicz średnie per klasa
classLabels = unique(labels);
classFeatures = cell(length(classLabels), 1);
classMeans = zeros(length(classLabels), size(features, 2));

for i = 1:length(classLabels)
    classIdx = labels == classLabels(i);
    classFeatures{i} = features(classIdx, :);
    classMeans(i, :) = mean(classFeatures{i}, 1);
end

% Oblicz between-class scatter matrix
overallMean = mean(features, 1);
Sb = zeros(size(features, 2));

for i = 1:length(classLabels)
    classSize = sum(labels == classLabels(i));
    meanDiff = classMeans(i, :) - overallMean;
    Sb = Sb + classSize * (meanDiff' * meanDiff);
end

% Oblicz within-class scatter matrix
Sw = zeros(size(features, 2));

for i = 1:length(classLabels)
    classData = classFeatures{i};
    classMean = classMeans(i, :);
    
    for j = 1:size(classData, 1)
        diff = classData(j, :) - classMean;
        Sw = Sw + (diff' * diff);
    end
end

% Regularyzacja jeśli potrzeba
if rank(Sw) < size(Sw, 1)
    fprintf('   Adding regularization...\n');
    Sw = Sw + 1e-6 * eye(size(Sw));
end

% Rozwiąż problem eigenvalue
try
    [eigenvectors, eigenvalues] = eig(Sb, Sw);
    [~, sortIdx] = sort(diag(eigenvalues), 'descend');
    
    % Wybierz najlepsze komponenty
    selectedVectors = eigenvectors(:, sortIdx(1:actualComponents));
    eigenVals = diag(eigenvalues);
    eigenVals = eigenVals(sortIdx(1:actualComponents));
    
    % Transform features
    reducedFeatures = features * selectedVectors;
    
catch ME
    fprintf('   MDA eigenvalue solution failed: %s\n', ME.message);
    fprintf('   Fallback to PCA...\n');
    
    % FALLBACK: PCA zamiast LDA
    params_fallback = struct('varianceThreshold', 0.90, 'maxComponents', actualComponents);
    [reducedFeatures, info] = applyPCA(features, params_fallback);
    info.method = 'MDA (PCA fallback)';
    return;
end

% Informacje o redukcji
info = struct();
info.method = 'MDA';
info.numComponents = actualComponents;
info.transformMatrix = selectedVectors;
info.eigenValues = eigenVals;
info.originalDims = size(features, 2);
info.reducedDims = actualComponents;

% Oblicz separowalność
info.separabilityScore = calculateClassSeparability(reducedFeatures, labels);

end

function separabilityScore = calculateClassSeparability(projectedData, labels)
% CALCULATECLASSSEPARABILITY Oblicz jak dobrze klasy są rozdzielone - BEZ ZMIAN

try
    uniqueLabels = unique(labels);
    numClasses = length(uniqueLabels);
    
    if numClasses < 2
        separabilityScore = 0;
        return;
    end
    
    % Stosunek between-class do within-class variance
    betweenClassVar = 0;
    withinClassVar = 0;
    globalMean = mean(projectedData, 1);
    
    for i = 1:numClasses
        classMask = labels == uniqueLabels(i);
        classData = projectedData(classMask, :);
        
        if isempty(classData)
            continue;
        end
        
        classMean = mean(classData, 1);
        classSize = sum(classMask);
        
        % Between-class variance
        meanDiff = classMean - globalMean;
        betweenClassVar = betweenClassVar + classSize * sum(meanDiff.^2);
        
        % Within-class variance
        if classSize > 1
            classVar = sum(var(classData, 0, 1));
            withinClassVar = withinClassVar + classVar;
        end
    end
    
    % Oblicz separability score
    if withinClassVar > 1e-10
        separabilityScore = betweenClassVar / withinClassVar;
    else
        separabilityScore = betweenClassVar; % Perfect separation
    end
    
    % Sanitize output
    if ~isfinite(separabilityScore) || separabilityScore < 0
        separabilityScore = 0;
    end
    
catch ME
    separabilityScore = 0;
end
end