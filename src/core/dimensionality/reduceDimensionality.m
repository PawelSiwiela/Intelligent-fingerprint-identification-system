function [reducedFeatures, info] = reduceDimensionality(features, method, params, labels)
% REDUCEDIMENSIONALITY Redukuje wymiarowość cech używając wybranej metody
%
% Funkcja implementuje algorytmy redukcji wymiarowości dla cech odcisków palców,
% zmniejszając liczbę wymiarów przy zachowaniu najważniejszych informacji.
% Obsługuje metody nadzorowane (MDA) i nienadzorowane (PCA) z automatycznym
% doborem parametrów i raportowaniem jakości redukcji.
%
% Parametry wejściowe:
%   features - macierz cech [samples × features] do redukcji
%   method - nazwa metody ('PCA', 'MDA')
%   params - struktura parametrów specyficznych dla metody
%   labels - etykiety klas [samples × 1] (wymagane dla MDA, opcjonalne dla PCA)
%
% Parametry wyjściowe:
%   reducedFeatures - macierz zredukowanych cech [samples × reduced_dims]
%   info - struktura z informacjami o redukcji (method, explained variance, etc.)
%
% Dostępne metody:
%   PCA: Principal Component Analysis - analiza składowych głównych
%   MDA: Multiple Discriminant Analysis - analiza dyskryminacyjna
%
% Przykład użycia:
%   [redFeats, info] = reduceDimensionality(features, 'PCA', params);

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

% Raportowanie wyników (wspólne dla wszystkich metod)
fprintf('✅ %s completed: %d → %d features\n', upper(method), ...
    size(features, 2), size(reducedFeatures, 2));

% Wyświetlenie informacji o zachowanej wariancji jeśli dostępne
if isfield(info, 'varianceExplained') && ~isempty(info.varianceExplained)
    fprintf('   (%.1f%% variance preserved)\n', info.varianceExplained * 100);
elseif isfield(info, 'totalVarianceExplained') && ~isempty(info.totalVarianceExplained)
    fprintf('   (%.1f%% variance preserved)\n', info.totalVarianceExplained);
end

% Szczegółowe podsumowanie procesu redukcji
fprintf('\n📊 Dimensionality Reduction Summary:\n');
fprintf('Method: %s\n', upper(method));
fprintf('Original dimensions: %d\n', size(features, 2));
fprintf('Reduced dimensions: %d\n', size(reducedFeatures, 2));
fprintf('Reduction ratio: %.1f%%\n', (1 - size(reducedFeatures, 2)/size(features, 2)) * 100);

% Analiza specyficzna dla metody
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

%% FUNKCJE IMPLEMENTUJĄCE POSZCZEGÓLNE METODY

function [reducedFeatures, info] = applyPCA(features, params)
% APPLYPCA Implementuje Principal Component Analysis
%
% Metoda nienadzorowana znajdująca kierunki maksymalnej wariancji w danych.
% Redukuje wymiarowość poprzez projekcję na składowe główne zachowujące
% zadany procent całkowitej wariancji.

% Ustawienia domyślne dla PCA
if ~isfield(params, 'varianceThreshold')
    params.varianceThreshold = 0.95; % Zachowaj 95% wariancji
end

if ~isfield(params, 'maxComponents')
    params.maxComponents = min(size(features, 1) - 1, 15); % Maksymalnie 15 komponentów
end

fprintf('   Target variance preserved: %.1f%%\n', params.varianceThreshold * 100);

% Wykonanie PCA używając wbudowanej funkcji MATLAB
[coeff, score, latent, ~, explained] = pca(features);

% Obliczenie kumulatywnej wariancji wyjaśnionej
cumulativeVariance = cumsum(explained) / 100;

% Znajdź liczbę komponentów dla żądanej wariancji
numComponents = find(cumulativeVariance >= params.varianceThreshold, 1, 'first');

% Ograniczenie do maksymalnej liczby komponentów
numComponents = min(numComponents, params.maxComponents);

% Fallback jeśli nie znaleziono odpowiedniej liczby komponentów
if isempty(numComponents)
    numComponents = params.maxComponents;
end

% Projekcja na wybrane składowe główne
reducedFeatures = score(:, 1:numComponents);

% Tworzenie struktury informacyjnej
info = struct();
info.method = 'PCA';
info.numComponents = numComponents;
info.coefficients = coeff(:, 1:numComponents);    % Wektory własne
info.eigenvalues = latent(1:numComponents);       % Wartości własne
info.explained = explained(1:numComponents);      % Wyjaśniona wariancja per komponent
info.varianceExplained = cumulativeVariance(numComponents);
info.totalVarianceExplained = sum(explained(1:numComponents));
info.originalDims = size(features, 2);
info.reducedDims = numComponents;
end

function [reducedFeatures, info] = applyMDA(features, labels, params)
% APPLYMDA Implementuje Multiple Discriminant Analysis (Enhanced LDA)
%
% Metoda nadzorowana maksymalizująca separowalność między klasami przy
% minimalizacji wariancji wewnątrz klas. Znajduje kierunki optymalnej
% dyskryminacji między klasami odcisków palców.

% Ustawienia domyślne dla MDA
if ~isfield(params, 'maxComponents')
    params.maxComponents = 4; % Maksymalnie 4 komponenty dyskryminujące
end

fprintf('   Target components: %d\n', params.maxComponents);

% Obliczenie rzeczywistej liczby możliwych komponentów
numClasses = length(unique(labels));
actualComponents = min(numClasses - 1, params.maxComponents);

% Przygotowanie danych per klasa
classLabels = unique(labels);
classFeatures = cell(length(classLabels), 1);
classMeans = zeros(length(classLabels), size(features, 2));

for i = 1:length(classLabels)
    classIdx = labels == classLabels(i);
    classFeatures{i} = features(classIdx, :);
    classMeans(i, :) = mean(classFeatures{i}, 1);
end

% Obliczenie macierzy rozrzutu między klasami (between-class scatter)
overallMean = mean(features, 1);
Sb = zeros(size(features, 2));

for i = 1:length(classLabels)
    classSize = sum(labels == classLabels(i));
    meanDiff = classMeans(i, :) - overallMean;
    Sb = Sb + classSize * (meanDiff' * meanDiff);
end

% Obliczenie macierzy rozrzutu wewnątrz klas (within-class scatter)
Sw = zeros(size(features, 2));

for i = 1:length(classLabels)
    classData = classFeatures{i};
    classMean = classMeans(i, :);
    
    for j = 1:size(classData, 1)
        diff = classData(j, :) - classMean;
        Sw = Sw + (diff' * diff);
    end
end

% Regularyzacja macierzy Sw jeśli singular
if rank(Sw) < size(Sw, 1)
    fprintf('   Adding regularization...\n');
    Sw = Sw + 1e-6 * eye(size(Sw)); % Regularyzacja Ridge
end

% Rozwiązanie uogólnionego problemu wartości własnych
try
    [eigenvectors, eigenvalues] = eig(Sb, Sw);
    [~, sortIdx] = sort(diag(eigenvalues), 'descend');
    
    % Wybór najlepszych komponentów dyskryminujących
    selectedVectors = eigenvectors(:, sortIdx(1:actualComponents));
    eigenVals = diag(eigenvalues);
    eigenVals = eigenVals(sortIdx(1:actualComponents));
    
    % Transformacja cech do przestrzeni dyskryminującej
    reducedFeatures = features * selectedVectors;
    
catch ME
    fprintf('   MDA eigenvalue solution failed: %s\n', ME.message);
    fprintf('   Fallback to PCA...\n');
    
    % Fallback: użyj PCA jeśli MDA nie działa
    params_fallback = struct('varianceThreshold', 0.90, 'maxComponents', actualComponents);
    [reducedFeatures, info] = applyPCA(features, params_fallback);
    info.method = 'MDA (PCA fallback)';
    return;
end

% Tworzenie struktury informacyjnej
info = struct();
info.method = 'MDA';
info.numComponents = actualComponents;
info.transformMatrix = selectedVectors;           % Macierz transformacji
info.eigenValues = eigenVals;                    % Wartości własne
info.originalDims = size(features, 2);
info.reducedDims = actualComponents;

% Obliczenie miary separowalności klas
info.separabilityScore = calculateClassSeparability(reducedFeatures, labels);
end

function separabilityScore = calculateClassSeparability(projectedData, labels)
% CALCULATECLASSSEPARABILITY Oblicza miarę separowalności klas w przestrzeni zredukowanej
%
% Funkcja oblicza stosunek wariancji między klasami do wariancji wewnątrz klas
% jako miarę jakości separacji. Wyższe wartości oznaczają lepszą separowalność.

try
    uniqueLabels = unique(labels);
    numClasses = length(uniqueLabels);
    
    if numClasses < 2
        separabilityScore = 0;
        return;
    end
    
    % Obliczenie składników separowalności
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
        
        % Wariancja między klasami (between-class variance)
        meanDiff = classMean - globalMean;
        betweenClassVar = betweenClassVar + classSize * sum(meanDiff.^2);
        
        % Wariancja wewnątrz klasy (within-class variance)
        if classSize > 1
            classVar = sum(var(classData, 0, 1));
            withinClassVar = withinClassVar + classVar;
        end
    end
    
    % Obliczenie separability score jako stosunku wariancji
    if withinClassVar > 1e-10
        separabilityScore = betweenClassVar / withinClassVar;
    else
        separabilityScore = betweenClassVar; % Idealna separacja
    end
    
    % Sanityzacja wyniku
    if ~isfinite(separabilityScore) || separabilityScore < 0
        separabilityScore = 0;
    end
    
catch ME
    separabilityScore = 0; % Fallback dla błędów
end
end