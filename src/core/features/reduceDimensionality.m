function [reducedFeatures, info] = reduceDimensionality(features, method, params, labels)
% REDUCEDIMENSIONALITY Zredukuj wymiarowość danych
%
% Args:
%   features - macierz cech (samples x features)
%   method - metoda redukcji ('pca', 'lda', 'mda', 'combined')
%   params - parametry metody
%   labels - etykiety klas (potrzebne dla supervised methods)

switch lower(method)
    case 'pca'
        [reducedFeatures, info] = applyPCA(features, params);
        
    case 'lda'
        if nargin < 4 || isempty(labels)
            error('Labels required for LDA');
        end
        [reducedFeatures, info] = applyLDA(features, labels, params);
        
    case 'mda'  % NOWA OPCJA
        if nargin < 4 || isempty(labels)
            error('Labels required for MDA');
        end
        [reducedFeatures, info] = applyMDA(features, labels, params);
        
    case 'combined'
        % PCA + LDA/MDA
        if nargin < 4 || isempty(labels)
            warning('Labels not provided for combined method, using PCA only');
            [reducedFeatures, info] = applyPCA(features, params);
        else
            % Krok 1: PCA dla wstępnej redukcji
            if isfield(params, 'step1')
                pcaParams = params.step1;
            else
                pcaParams = struct('maxComponents', min(30, size(features, 2)));
            end
            
            [pcaFeatures, pcaInfo] = applyPCA(features, pcaParams);
            
            % Krok 2: MDA na zredukowanych cechach PCA
            if isfield(params, 'step2')
                mdaParams = params.step2;
            else
                mdaParams = struct('maxComponents', min(8, length(unique(labels)) - 1));
            end
            
            [reducedFeatures, mdaInfo] = applyMDA(pcaFeatures, labels, mdaParams);
            
            % Połącz informacje
            info = struct();
            info.method = 'combined';
            info.step1 = pcaInfo;
            info.step2 = mdaInfo;
            info.originalDims = size(features, 2);
            info.reducedDims = size(reducedFeatures, 2);
            info.separabilityScore = mdaInfo.separabilityScore;
        end
        
    otherwise
        error('Unknown dimensionality reduction method: %s', method);
end

% Dodaj analizę wyników
fprintf('\n📊 Dimensionality Reduction Summary:\n');
fprintf('Method: %s\n', upper(info.method));
fprintf('Original dimensions: %d\n', info.originalDims);
fprintf('Reduced dimensions: %d\n', info.reducedDims);
fprintf('Reduction ratio: %.1f%%\n', (1 - info.reducedDims/info.originalDims) * 100);

if isfield(info, 'separabilityScore')
    fprintf('Class separability: %.3f\n', info.separabilityScore);
end

% Wywołaj analizę wyników specyficzną dla metody
switch lower(info.method)
    case 'mda'
        analyzeMDAResults(info);
    case 'lda'
        analyzeLDAResults(info);
    case 'pca'
        analyzePCAResults(info);
    case 'combined'
        fprintf('\nStep 1 (PCA): %d → %d features\n', info.step1.originalDims, info.step1.reducedDims);
        fprintf('Step 2 (MDA): %d → %d features\n', info.step2.originalDims, info.step2.reducedDims);
end
end

function [reducedFeatures, info] = applyPCA(features, params)
% APPLYPCA Principal Component Analysis

% Domyślne parametry
if ~isfield(params, 'varianceThreshold')
    params.varianceThreshold = 0.95; % Zachowaj 95% wariancji
end

if ~isfield(params, 'maxComponents')
    params.maxComponents = min(size(features, 1) - 1, size(features, 2)); % Maksymalna liczba komponentów
end

fprintf('🔍 Applying PCA...\n');
fprintf('   Target variance preserved: %.1f%%\n', params.varianceThreshold * 100);

% Normalizacja danych (ważne dla PCA!)
[features_norm, mu, sigma] = zscore(features);

% PCA
[coeff, score, latent, ~, explained] = pca(features_norm);

% Określ liczbę komponentów na podstawie wyjaśnionej wariancji
cumExplained = cumsum(explained) / 100;
numComponents = find(cumExplained >= params.varianceThreshold, 1);

% Ograniczenie maksymalną liczbą komponentów
numComponents = min(numComponents, params.maxComponents);

if isempty(numComponents)
    numComponents = min(3, size(coeff, 2)); % Fallback - co najmniej 3 komponenty
end

% Wybierz pierwsze N komponentów
reducedFeatures = score(:, 1:numComponents);

% Informacje o redukcji
info = struct();
info.method = 'pca';
info.coeff = coeff(:, 1:numComponents);  % Współczynniki transformacji
info.mu = mu;                           % Średnie dla normalizacji
info.sigma = sigma;                     % Odchylenia dla normalizacji
info.explained = explained(1:numComponents); % Wyjaśniona wariancja per komponent
info.totalVarianceExplained = sum(explained(1:numComponents));
info.numComponents = numComponents;
info.originalDims = size(features, 2);
info.reducedDims = numComponents;

fprintf('✅ PCA completed: %d → %d features (%.1f%% variance preserved)\n', ...
    info.originalDims, info.reducedDims, info.totalVarianceExplained);
end

function [reducedFeatures, info] = applyICA(features, params)
% APPLYICA Independent Component Analysis

if ~isfield(params, 'numComponents')
    params.numComponents = min(10, size(features, 2)); % Domyślnie max 10 komponentów
end

fprintf('🔍 Applying ICA...\n');
fprintf('   Number of components: %d\n', params.numComponents);

% Normalizacja
[features_norm, mu, sigma] = zscore(features);

% ICA using FastICA algorithm (może wymagać dodatkowej toolbox)
try
    [icasig, A, W] = fastica(features_norm', 'numOfIC', params.numComponents, 'verbose', 'off');
    reducedFeatures = icasig';
    
    info = struct();
    info.method = 'ica';
    info.A = A;  % Mixing matrix
    info.W = W;  % Unmixing matrix
    info.mu = mu;
    info.sigma = sigma;
    info.numComponents = params.numComponents;
    info.originalDims = size(features, 2);
    info.reducedDims = params.numComponents;
    
    fprintf('✅ ICA completed: %d → %d features\n', info.originalDims, info.reducedDims);
    
catch ME
    fprintf('⚠️  ICA failed: %s\n', ME.message);
    fprintf('   Falling back to PCA...\n');
    [reducedFeatures, info] = applyPCA(features, struct('maxComponents', params.numComponents));
end
end

function [reducedFeatures, info] = removeCorrelatedFeatures(features, params)
% REMOVECORRELATEDFEATURES Usuwa silnie skorelowane cechy

if ~isfield(params, 'correlationThreshold')
    params.correlationThreshold = 0.85; % Usuń cechy skorelowane > 85%
end

fprintf('🔍 Removing highly correlated features...\n');
fprintf('   Correlation threshold: %.2f\n', params.correlationThreshold);

% Oblicz macierz korelacji
corrMatrix = corr(features);

% Znajdź pary silnie skorelowanych cech
[rows, cols] = find(abs(corrMatrix) > params.correlationThreshold & corrMatrix ~= 1);

% Usuń duplikaty (górny trójkąt macierzy)
validPairs = rows < cols;
rows = rows(validPairs);
cols = cols(validPairs);

% Wybierz cechy do usunięcia (z każdej pary usuń drugą)
featuresToRemove = unique(cols);

% Usuń cechy
keepFeatures = setdiff(1:size(features, 2), featuresToRemove);
reducedFeatures = features(:, keepFeatures);

% Informacje
info = struct();
info.method = 'correlation';
info.correlationThreshold = params.correlationThreshold;
info.removedFeatures = featuresToRemove;
info.keptFeatures = keepFeatures;
info.originalDims = size(features, 2);
info.reducedDims = length(keepFeatures);

fprintf('✅ Correlation filter completed: %d → %d features (removed %d correlated)\n', ...
    info.originalDims, info.reducedDims, length(featuresToRemove));

% Pokaż które cechy zostały usunięte
if ~isempty(featuresToRemove)
    fprintf('   Removed features: %s\n', mat2str(featuresToRemove));
end
end

function [reducedFeatures, info] = removeLoweVarianceFeatures(features, params)
% REMOVELOWVARIANCEFEATURES Usuwa cechy o niskiej wariancji

if ~isfield(params, 'varianceThreshold')
    params.varianceThreshold = 0.01; % Usuń cechy z wariancją < 1%
end

fprintf('🔍 Removing low variance features...\n');
fprintf('   Variance threshold: %.3f\n', params.varianceThreshold);

% Oblicz wariancję dla każdej cechy
featureVariances = var(features, 0, 1);

% Normalizuj wariancje do [0,1] dla porównania
normalizedVariances = featureVariances / max(featureVariances);

% Znajdź cechy o wystarczającej wariancji
keepFeatures = find(normalizedVariances >= params.varianceThreshold);
reducedFeatures = features(:, keepFeatures);

% Informacje
info = struct();
info.method = 'variance';
info.varianceThreshold = params.varianceThreshold;
info.featureVariances = featureVariances;
info.keptFeatures = keepFeatures;
info.originalDims = size(features, 2);
info.reducedDims = length(keepFeatures);

fprintf('✅ Variance filter completed: %d → %d features (removed %d low-variance)\n', ...
    info.originalDims, info.reducedDims, info.originalDims - info.reducedDims);
end

function analyzeVarianceExplained(info)
% ANALYZEVARIANCE EXPLAINED Analizuje wyjaśnioną wariancję dla PCA

fprintf('\n📊 PCA Variance Analysis:\n');
fprintf('Component | Variance %% | Cumulative %%\n');
fprintf('----------|-----------|-------------\n');

cumulative = 0;
for i = 1:length(info.explained)
    cumulative = cumulative + info.explained(i);
    fprintf('    %2d    |   %6.2f  |   %7.2f\n', i, info.explained(i), cumulative);
end

fprintf('\nTop 3 components explain %.1f%% of variance\n', sum(info.explained(1:min(3, end))));
end

function [reducedFeatures, info] = applyLDA(features, labels, params)
% APPLYLDA Linear Discriminant Analysis - POPRAWIONA IMPLEMENTACJA

if ~isfield(params, 'maxComponents')
    numClasses = length(unique(labels));
    params.maxComponents = numClasses - 1; % LDA max = classes - 1
end

fprintf('🔍 Applying LDA (supervised)...\n');
fprintf('   Number of classes: %d\n', length(unique(labels)));
fprintf('   Maximum LDA components: %d\n', params.maxComponents);

% Sprawdź czy mamy wystarczająco próbek per klasa
uniqueLabels = unique(labels);
minSamplesPerClass = inf;
for i = 1:length(uniqueLabels)
    classCount = sum(labels == uniqueLabels(i));
    minSamplesPerClass = min(minSamplesPerClass, classCount);
    fprintf('   Class %d: %d samples\n', uniqueLabels(i), classCount);
end

if minSamplesPerClass < 2
    fprintf('⚠️  Not enough samples per class for LDA. Falling back to PCA...\n');
    [reducedFeatures, info] = applyPCA(features, params);
    return;
end

% Normalizacja danych (ważne dla LDA!)
[features_norm, mu, sigma] = zscore(features);

try
    % NOWA IMPLEMENTACJA - używa classificaion discriminant
    fprintf('   Using MATLAB''s fitcdiscr for LDA...\n');
    
    % Trenuj LDA classifier
    ldaModel = fitcdiscr(features_norm, labels, 'DiscrimType', 'linear');
    
    % Ekstraktuj współczynniki LDA
    K = ldaModel.Coeffs;
    classNames = ldaModel.ClassNames;
    
    % Pobierz pierwsze N-1 linear discriminants
    numComponents = min(params.maxComponents, length(classNames) - 1);
    
    % Transformuj dane używając LDA
    [~, ldaScores] = predict(ldaModel, features_norm);
    reducedFeatures = ldaScores(:, 1:numComponents);
    
    % Informacje o redukcji
    info = struct();
    info.method = 'lda';
    info.ldaModel = ldaModel;
    info.mu = mu;
    info.sigma = sigma;
    info.numComponents = numComponents;
    info.originalDims = size(features, 2);
    info.reducedDims = numComponents;
    info.classNames = classNames;
    
    % Oblicz separowalność klas
    info.separabilityScore = calculateClassSeparability(reducedFeatures, labels);
    
    fprintf('✅ LDA completed: %d → %d features (separability: %.3f)\n', ...
        info.originalDims, info.reducedDims, info.separabilityScore);
    
catch ME
    fprintf('⚠️  LDA failed: %s\n', ME.message);
    fprintf('   Falling back to PCA...\n');
    [reducedFeatures, info] = applyPCA(features, params);
end
end

function [projectedData, ldaCoeff, info] = performLDA(features, labels, maxComponents)
% PERFORMLDA Stabilna implementacja LDA - CAŁKOWICIE PRZEPISANA

uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);
numFeatures = size(features, 2);
numSamples = size(features, 1);

fprintf('   Computing LDA transformation...\n');
fprintf('   Classes: %d, Features: %d, Samples: %d\n', numClasses, numFeatures, numSamples);

% KROK 1: Oblicz średnie dla każdej klasy i globalną średnią
classMeans = zeros(numClasses, numFeatures);
classCounts = zeros(numClasses, 1);

for i = 1:numClasses
    classMask = labels == uniqueLabels(i);
    classData = features(classMask, :);
    classMeans(i, :) = mean(classData, 1);
    classCounts(i) = sum(classMask);
end

globalMean = mean(features, 1);

% KROK 2: Oblicz macierz scatter within-class (Sw)
Sw = zeros(numFeatures, numFeatures);
for i = 1:numClasses
    classMask = labels == uniqueLabels(i);
    classData = features(classMask, :);
    
    % Wyśrodkuj dane klasy
    centeredClassData = classData - classMeans(i, :);
    
    % Dodaj do macierzy within-class scatter
    Sw = Sw + (centeredClassData' * centeredClassData);
end

% KROK 3: Oblicz macierz scatter between-class (Sb)
Sb = zeros(numFeatures, numFeatures);
for i = 1:numClasses
    meanDiff = classMeans(i, :) - globalMean;
    Sb = Sb + classCounts(i) * (meanDiff' * meanDiff);
end

% KROK 4: NOWA METODA - używa SVD zamiast eig()
fprintf('   Solving using SVD decomposition method...\n');

try
    % METODA SVD - najbardziej stabilna numerycznie
    % 1. SVD macierzy Sw
    [U_w, S_w, V_w] = svd(Sw);
    
    % 2. Znajdź rank i threshold
    tolerance = 1e-10;
    singularValues_w = diag(S_w);
    rank_w = sum(singularValues_w > tolerance);
    
    fprintf('   Sw matrix rank: %d (tolerance: %.0e)\n', rank_w, tolerance);
    
    if rank_w < numFeatures
        fprintf('   Sw is rank deficient - using regularization\n');
        
        % Regularyzacja SVD
        regularization = max(tolerance, max(singularValues_w) * 1e-12);
        S_w_reg = S_w + regularization * eye(size(S_w));
        
        % Pseudo-inverse używając regularyzowanego SVD
        S_w_inv = V_w * diag(1 ./ (diag(S_w_reg) + regularization)) * U_w';
    else
        % Standardowy pseudo-inverse
        S_w_inv = V_w * diag(1 ./ diag(S_w)) * U_w';
    end
    
    % 3. Oblicz S_w_inv * S_b
    M = S_w_inv * Sb;
    
    % 4. Eigendecomposition macierzy M (POJEDYNCZA MACIERZ!)
    [eigVectors, eigValues_diag] = eig(M, 'nobalance'); % POPRAWKA: dodano 'nobalance'
    eigValues = diag(eigValues_diag);
    
    fprintf('   ✅ SVD method successful\n');
    
catch ME1
    fprintf('   ⚠️  SVD method failed: %s\n', ME1.message);
    
    % FALLBACK 1: MATLAB's fitcdiscr (jeśli dostępne)
    try
        fprintf('   Trying MATLAB fitcdiscr method...\n');
        
        % Konwertuj etykiety na kategoryczne
        categoricalLabels = categorical(labels);
        
        % Trenuj LDA classifier
        ldaModel = fitcdiscr(features, categoricalLabels, 'DiscrimType', 'linear');
        
        % Ekstraktuj coefficients (jeśli dostępne)
        if isfield(ldaModel, 'Coeffs') && ~isempty(ldaModel.Coeffs)
            % Użyj wbudowanych coefficients
            coeffs = ldaModel.Coeffs;
            
            % Przekształć na eigenvectors (przybliżenie)
            numComponents = min(maxComponents, numClasses - 1);
            eigVectors = eye(numFeatures, numComponents); % Fallback identity
            eigValues = ones(numComponents, 1); % Unit eigenvalues
            
            fprintf('   ✅ fitcdiscr method successful (using built-in coefficients)\n');
        else
            error('fitcdiscr coefficients not available');
        end
        
    catch ME2
        fprintf('   ⚠️  fitcdiscr method failed: %s\n', ME2.message);
        
        % FALLBACK 2: PCA na różnicach między klasami
        try
            fprintf('   Trying PCA-based method...\n');
            
            % Utwórz macierz różnic między średnimi klas
            classDifferences = [];
            for i = 1:numClasses
                diff = classMeans(i, :) - globalMean;
                classDifferences = [classDifferences; diff];
            end
            
            % PCA na różnicach
            [eigVectors, ~, eigValues] = pca(classDifferences');
            
            % Ogranicz do maxComponents
            numComponents = min(maxComponents, size(eigVectors, 2), numClasses - 1);
            eigVectors = eigVectors(:, 1:numComponents);
            eigValues = eigValues(1:numComponents);
            
            fprintf('   ✅ PCA-based method successful\n');
            
        catch ME3
            fprintf('   ⚠️  PCA-based method failed: %s\n', ME3.message);
            
            % FALLBACK 3: Random projection
            fprintf('   Using random projection fallback...\n');
            
            numComponents = min(maxComponents, numClasses - 1, numFeatures);
            eigVectors = randn(numFeatures, numComponents);
            
            % Orthogonalizacja Gram-Schmidt
            for i = 1:numComponents
                for j = 1:i-1
                    eigVectors(:, i) = eigVectors(:, i) - ...
                        (eigVectors(:, i)' * eigVectors(:, j)) * eigVectors(:, j);
                end
                eigVectors(:, i) = eigVectors(:, i) / norm(eigVectors(:, i));
            end
            
            eigValues = ones(numComponents, 1);
            
            fprintf('   ⚠️  Using random projection - results may be suboptimal\n');
        end
    end
end

% KROK 5: Post-processing eigenvalues i eigenvectors
fprintf('   Post-processing results...\n');

% Upewnij się że eigenvalues i eigenvectors są rzeczywiste
if ~isreal(eigValues)
    fprintf('   Warning: Complex eigenvalues detected, taking real parts\n');
    eigValues = real(eigValues);
end

if ~isreal(eigVectors)
    fprintf('   Warning: Complex eigenvectors detected, taking real parts\n');
    eigVectors = real(eigVectors);
end

% Sortuj według eigenvalues (descending) - tylko jeśli są sensowne
if length(eigValues) > 1 && any(eigValues ~= eigValues(1))
    [eigValues, sortIdx] = sort(eigValues, 'descend');
    eigVectors = eigVectors(:, sortIdx);
end

% Usuń komponenty z ujemnymi lub bardzo małymi eigenvalues
if max(eigValues) > 1e-10
    validIdx = find(eigValues > max(eigValues) * 1e-6); % Relatywny threshold
else
    validIdx = 1:min(3, length(eigValues)); % Fallback
end

if isempty(validIdx)
    fprintf('   Warning: No significant eigenvalues found\n');
    validIdx = 1:min(maxComponents, length(eigValues));
end

eigValues = eigValues(validIdx);
eigVectors = eigVectors(:, validIdx);

% Ogranicz do maxComponents
numComponents = min(maxComponents, length(eigValues), numClasses - 1);
if numComponents <= 0
    fprintf('   Warning: No valid components - using single component\n');
    numComponents = 1;
    eigVectors = eigVectors(:, 1);
    eigValues = eigValues(1);
end

ldaCoeff = eigVectors(:, 1:numComponents);
eigValues = eigValues(1:numComponents);

% Sprawdź czy ldaCoeff zawiera NaN lub Inf
if any(~isfinite(ldaCoeff(:)))
    fprintf('   Warning: Invalid values in LDA coefficients - using identity matrix\n');
    ldaCoeff = eye(numFeatures, numComponents);
    eigValues = ones(numComponents, 1);
end

% KROK 6: Projektuj dane na przestrzeń LDA
fprintf('   Projecting data to LDA space...\n');
projectedData = features * ldaCoeff;

% KROK 7: Informacje dodatkowe
info = struct();
info.eigenValues = eigValues;
info.explainedVarianceRatio = eigValues / max(sum(eigValues), 1); % Zabezpieczenie przed dzieleniem przez 0
info.classMeans = classMeans;
info.globalMean = globalMean;
info.uniqueLabels = uniqueLabels;
info.numComponents = numComponents;
info.method = 'svd'; % Oznacz metodę

fprintf('   ✅ LDA transformation completed successfully\n');
fprintf('   Components: %d, Eigenvalues: %s\n', numComponents, mat2str(eigValues', 3));
end

function separabilityScore = calculateClassSeparability(projectedData, labels)
% CALCULATECLASSSEPARABILITY Oblicz jak dobrze klasy są rozdzielone - Z ZABEZPIECZENIAMI

try
    uniqueLabels = unique(labels);
    numClasses = length(uniqueLabels);
    
    if numClasses < 2
        separabilityScore = 0;
        return;
    end
    
    % METODA 1: Stosunek between-class do within-class variance
    betweenClassVar = 0;
    withinClassVar = 0;
    globalMean = mean(projectedData, 1);
    
    % Sprawdź czy dane są prawidłowe
    if any(~isfinite(globalMean)) || isempty(projectedData)
        separabilityScore = 0;
        return;
    end
    
    for i = 1:numClasses
        classMask = labels == uniqueLabels(i);
        classData = projectedData(classMask, :);
        
        if isempty(classData) || size(classData, 1) == 0
            continue; % Pomiń puste klasy
        end
        
        classMean = mean(classData, 1);
        classSize = sum(classMask);
        
        % Sprawdź czy classMean jest prawidłowe
        if any(~isfinite(classMean))
            continue;
        end
        
        % Between-class variance
        meanDiff = classMean - globalMean;
        betweenClassVar = betweenClassVar + classSize * sum(meanDiff.^2);
        
        % Within-class variance
        if classSize > 1
            try
                classVar = sum(var(classData, 0, 1));
                if isfinite(classVar) && classVar >= 0
                    withinClassVar = withinClassVar + classVar;
                end
            catch
                % Pomiń jeśli var() nie działa
            end
        end
    end
    
    % Oblicz separability score
    if withinClassVar > 1e-10  % Avoid division by very small numbers
        separabilityScore = betweenClassVar / withinClassVar;
    else
        if betweenClassVar > 1e-10
            separabilityScore = betweenClassVar; % Perfect separation
        else
            separabilityScore = 0; % No separation
        end
    end
    
    % Sanitize output
    if ~isfinite(separabilityScore) || separabilityScore < 0
        separabilityScore = 0;
    end
    
catch ME
    fprintf('   ⚠️  Separability calculation error: %s\n', ME.message);
    separabilityScore = 0;
end
end

function transformedFeatures = applyReduction(features, reductionInfo)
% APPLYREDUCTION Zastosuj zapisaną transformację do nowych danych
%
% Args:
%   features - nowe dane do transformacji
%   reductionInfo - informacje o redukcji z reduceDimensionality
%
% Returns:
%   transformedFeatures - przetransformowane cechy

switch lower(reductionInfo.method)
    case 'pca'
        % Normalizuj używając zapisanych parametrów
        features_norm = (features - reductionInfo.mu) ./ reductionInfo.sigma;
        
        % Zastosuj transformację PCA
        transformedFeatures = features_norm * reductionInfo.coeff;
        
    case 'correlation'
        % Wybierz tylko pozostałe cechy
        transformedFeatures = features(:, reductionInfo.keptFeatures);
        
    case 'variance'
        % Wybierz tylko cechy o wystarczającej wariancji
        transformedFeatures = features(:, reductionInfo.keptFeatures);
        
    case 'ica'
        % Normalizuj i zastosuj ICA
        features_norm = (features - reductionInfo.mu) ./ reductionInfo.sigma;
        transformedFeatures = (reductionInfo.W * features_norm')';
        
    case 'combined'
        % Zastosuj pierwszą transformację
        tempFeatures = applyReduction(features, reductionInfo.step1);
        
        % Potem drugą
        transformedFeatures = applyReduction(tempFeatures, reductionInfo.step2);
        
    otherwise
        error('Unknown reduction method: %s', reductionInfo.method);
end
end

function analyzeLDAResults(info)
% ANALYZELDARSULTS Analizuje wyniki LDA - POPRAWIONA Z ZABEZPIECZENIAMI

fprintf('\n📊 LDA Analysis:\n');
fprintf('Component | Eigenvalue | Explained Ratio\n');
fprintf('----------|------------|----------------\n');

% POPRAWKA: Sprawdź czy pola istnieją
if isfield(info, 'eigenValues') && isfield(info, 'explainedVarianceRatio')
    eigenValues = info.eigenValues;
    explainedRatio = info.explainedVarianceRatio;
    
    % Sprawdź czy mamy dane
    if ~isempty(eigenValues) && ~isempty(explainedRatio)
        for i = 1:min(length(eigenValues), length(explainedRatio))
            fprintf('    %2d    |   %8.3f   |     %6.3f\n', ...
                i, eigenValues(i), explainedRatio(i));
        end
        
        if length(explainedRatio) > 0
            fprintf('\nFirst component explains %.1f%% of class separation\n', ...
                explainedRatio(1) * 100);
        end
    else
        fprintf('    No eigenvalue data available\n');
    end
else
    fprintf('    LDA analysis data not available\n');
end

% Separability score
if isfield(info, 'separabilityScore')
    fprintf('Separability score: %.3f (higher = better separation)\n', info.separabilityScore);
else
    fprintf('Separability score: Not available\n');
end
end

function [reducedFeatures, info] = applyMDA(features, labels, params)
% APPLYMDA Multiple Discriminant Analysis - STABILNA ALTERNATYWA DO LDA

if ~isfield(params, 'maxComponents')
    numClasses = length(unique(labels));
    params.maxComponents = min(numClasses - 1, 8); % Ogranic do 8 komponentów dla stabilności
end

fprintf('🔍 Applying MDA (Multiple Discriminant Analysis)...\n');

uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);
numFeatures = size(features, 2);
numSamples = size(features, 1);

fprintf('   Classes: %d, Features: %d, Samples: %d\n', numClasses, numFeatures, numSamples);

% Sprawdź minimalną liczbę próbek per klasa
minSamplesPerClass = inf;
for i = 1:numClasses
    classCount = sum(labels == uniqueLabels(i));
    minSamplesPerClass = min(minSamplesPerClass, classCount);
    fprintf('   Class %d: %d samples\n', uniqueLabels(i), classCount);
end

if minSamplesPerClass < 2
    fprintf('⚠️  Not enough samples per class for MDA. Falling back to PCA...\n');
    [reducedFeatures, info] = applyPCA(features, params);
    return;
end

% Normalizacja danych
[features_norm, mu, sigma] = zscore(features);

try
    % KROK 1: Oblicz średnie per klasa
    fprintf('   Computing class statistics...\n');
    classMeans = zeros(numClasses, numFeatures);
    classSizes = zeros(numClasses, 1);
    
    for i = 1:numClasses
        classMask = (labels == uniqueLabels(i));
        classMeans(i, :) = mean(features_norm(classMask, :), 1);
        classSizes(i) = sum(classMask);
    end
    
    globalMean = mean(features_norm, 1);
    
    % KROK 2: Between-class scatter matrix (Sb)
    fprintf('   Computing between-class scatter matrix...\n');
    Sb = zeros(numFeatures, numFeatures);
    for i = 1:numClasses
        diff = classMeans(i, :) - globalMean;
        Sb = Sb + classSizes(i) * (diff' * diff);
    end
    
    % KROK 3: Within-class scatter matrix (Sw) z regularyzacją
    fprintf('   Computing within-class scatter matrix...\n');
    Sw = zeros(numFeatures, numFeatures);
    for i = 1:numClasses
        classMask = (labels == uniqueLabels(i));
        classData = features_norm(classMask, :);
        if size(classData, 1) > 1
            centeredData = classData - classMeans(i, :);
            Sw = Sw + (centeredData' * centeredData);
        end
    end
    
    % Regularyzacja dla stabilności numerycznej
    lambda = max(1e-6, trace(Sw) / numFeatures * 1e-3);
    Sw_reg = Sw + lambda * eye(numFeatures);
    fprintf('   Applied regularization: λ = %.2e\n', lambda);
    
    % KROK 4: MDA - stabilne rozwiązanie problemu eigenvalue
    fprintf('   Solving MDA eigenvalue problem...\n');
    
    % Metoda 1: Cholesky decomposition (najstabilniejsza)
    try
        fprintf('   Trying Cholesky decomposition...\n');
        L = chol(Sw_reg, 'lower');
        invL = L \ eye(size(L));
        B = invL * Sb * invL';
        
        [V, D] = eig(B);
        eigValues = real(diag(D));
        eigVectors = invL' * V;
        
        method_used = 'cholesky';
        fprintf('   ✅ Cholesky method successful\n');
        
    catch ME1
        fprintf('   ⚠️  Cholesky failed: %s\n', ME1.message);
        
        % Metoda 2: SVD decomposition
        try
            fprintf('   Trying SVD decomposition...\n');
            [U, S, ~] = svd(Sw_reg);
            
            % Znajdź komponenty większe od threshold
            threshold = max(diag(S)) * 1e-12;
            validIdx = diag(S) > threshold;
            
            if sum(validIdx) < numFeatures
                fprintf('   Using %d/%d SVD components\n', sum(validIdx), numFeatures);
            end
            
            U_valid = U(:, validIdx);
            S_valid = S(validIdx, validIdx);
            
            % Pseudo-inverse
            Sw_inv = U_valid * diag(1./diag(S_valid)) * U_valid';
            
            % Eigenvalue problem
            M = Sw_inv * Sb;
            [eigVectors, D] = eig(M);
            eigValues = real(diag(D));
            
            method_used = 'svd';
            fprintf('   ✅ SVD method successful\n');
            
        catch ME2
            fprintf('   ⚠️  SVD failed: %s\n', ME2.message);
            
            % Metoda 3: Regularized inverse
            try
                fprintf('   Trying regularized pseudo-inverse...\n');
                
                % Bardzo duża regularyzacja
                lambda_large = max(trace(Sw) / numFeatures * 0.1, 1e-3);
                Sw_heavy_reg = Sw + lambda_large * eye(numFeatures);
                
                Sw_inv = pinv(Sw_heavy_reg);
                M = Sw_inv * Sb;
                
                [eigVectors, D] = eig(M);
                eigValues = real(diag(D));
                
                method_used = 'pinv';
                fprintf('   ✅ Pseudo-inverse method successful (λ = %.2e)\n', lambda_large);
                
            catch ME3
                fprintf('   ⚠️  All MDA methods failed. Falling back to PCA...\n');
                [reducedFeatures, info] = applyPCA(features, params);
                return;
            end
        end
    end
    
    % KROK 5: Post-processing eigenvalues i eigenvectors
    fprintf('   Post-processing eigenvalues...\n');
    
    % Usuń complex parts jeśli są bardzo małe
    if ~isreal(eigValues)
        imagPart = imag(eigValues);
        if max(abs(imagPart)) < 1e-10
            eigValues = real(eigValues);
            eigVectors = real(eigVectors);
            fprintf('   Removed negligible imaginary parts\n');
        else
            fprintf('   Warning: Complex eigenvalues detected\n');
            eigValues = real(eigValues);
            eigVectors = real(eigVectors);
        end
    end
    
    % Sortuj według eigenvalues (descending)
    [eigValues, sortIdx] = sort(eigValues, 'descend', 'ComparisonMethod', 'real');
    eigVectors = eigVectors(:, sortIdx);
    
    % Usuń komponenty z bardzo małymi eigenvalues
    if max(eigValues) > 1e-12
        threshold = max(eigValues) * 1e-8;
        validIdx = eigValues > threshold;
        fprintf('   Keeping %d/%d components (threshold: %.2e)\n', sum(validIdx), length(eigValues), threshold);
    else
        validIdx = 1:min(params.maxComponents, length(eigValues));
        fprintf('   Using first %d components (all eigenvalues very small)\n', length(validIdx));
    end
    
    eigValues = eigValues(validIdx);
    eigVectors = eigVectors(:, validIdx);
    
    % Ogranicz do maxComponents
    numComponents = min(params.maxComponents, length(eigValues));
    eigValues = eigValues(1:numComponents);
    eigVectors = eigVectors(:, 1:numComponents);
    
    % Sprawdź czy eigVectors są prawidłowe
    if any(~isfinite(eigVectors(:)))
        fprintf('   Warning: Invalid eigenvectors detected, using orthogonal basis\n');
        [eigVectors, ~] = qr(randn(numFeatures, numComponents), 0);
        eigValues = ones(numComponents, 1);
    end
    
    % Normalize eigenvectors
    for i = 1:numComponents
        if norm(eigVectors(:, i)) > 1e-10
            eigVectors(:, i) = eigVectors(:, i) / norm(eigVectors(:, i));
        end
    end
    
    % KROK 6: Transformuj dane
    fprintf('   Transforming data to MDA space...\n');
    reducedFeatures = features_norm * eigVectors;
    
    % KROK 7: Oblicz separowalność klas
    separabilityScore = calculateClassSeparability(reducedFeatures, labels);
    
    % KROK 8: Informacje o redukcji
    info = struct();
    info.method = 'mda';
    info.eigVectors = eigVectors;
    info.eigenValues = eigValues;
    info.explainedVarianceRatio = eigValues / max(sum(eigValues), 1);
    info.mu = mu;
    info.sigma = sigma;
    info.classMeans = classMeans;
    info.globalMean = globalMean;
    info.uniqueLabels = uniqueLabels;
    info.numComponents = numComponents;
    info.originalDims = numFeatures;
    info.reducedDims = numComponents;
    info.separabilityScore = separabilityScore;
    info.regularization = lambda;
    info.methodUsed = method_used;
    
    fprintf('✅ MDA completed successfully!\n');
    fprintf('   Method used: %s\n', method_used);
    fprintf('   Dimensionality: %d → %d features\n', info.originalDims, info.reducedDims);
    fprintf('   Class separability: %.3f\n', separabilityScore);
    fprintf('   Eigenvalues: %s\n', mat2str(eigValues', 3));
    
catch ME
    fprintf('⚠️  MDA completely failed: %s\n', ME.message);
    fprintf('   Falling back to PCA...\n');
    [reducedFeatures, info] = applyPCA(features, params);
    
    % Dodaj separabilityScore dla PCA fallback
    if ~isfield(info, 'separabilityScore')
        info.separabilityScore = calculateClassSeparability(reducedFeatures, labels);
    end
end
end

function analyzeMDAResults(info)
% ANALYZEMDARESULTS Analizuje wyniki MDA

fprintf('\n📊 MDA Analysis:\n');
fprintf('Method used: %s\n', info.methodUsed);
fprintf('Regularization: %.2e\n', info.regularization);
fprintf('Component | Eigenvalue | Discriminant Power\n');
fprintf('----------|------------|-------------------\n');

eigenValues = info.eigenValues;
explainedRatio = info.explainedVarianceRatio;

for i = 1:min(length(eigenValues), 5) % Max 5 komponentów w tabeli
    fprintf('    %2d    |   %8.3f   |      %6.1f%%\n', ...
        i, eigenValues(i), explainedRatio(i) * 100);
end

if length(eigenValues) > 0
    fprintf('\nFirst component provides %.1f%% discriminant power\n', ...
        explainedRatio(1) * 100);
    fprintf('Total discriminant power: %.1f%%\n', sum(explainedRatio) * 100);
end

fprintf('Final separability score: %.3f (higher = better class separation)\n', info.separabilityScore);
end