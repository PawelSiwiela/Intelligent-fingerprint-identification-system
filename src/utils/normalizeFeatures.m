function normalizedFeatures = normalizeFeatures(features, method, referenceStats)
% NORMALIZEFEATURES Normalizuje wektory cech różnymi metodami
%
% Argumenty:
%   features - macierz cech [samples x features] lub wektor [1 x features]
%   method - metoda normalizacji: 'minmax', 'zscore', 'robust', 'unit'
%   referenceStats - (opcjonalne) statystyki referencyjne dla zbioru treningowego
%
% Output:
%   normalizedFeatures - znormalizowane cechy

if nargin < 2
    method = 'minmax'; % Domyślna metoda
end

if nargin < 3
    referenceStats = [];
end

% Sprawdź czy to wektor czy macierz
if isvector(features)
    features = features(:)'; % Zapewnij wiersz
    singleVector = true;
else
    singleVector = false;
end

[numSamples, numFeatures] = size(features);

switch lower(method)
    case 'minmax'
        % Min-Max normalizacja do [0, 1]
        if isempty(referenceStats)
            minVals = min(features, [], 1);
            maxVals = max(features, [], 1);
        else
            minVals = referenceStats.minVals;
            maxVals = referenceStats.maxVals;
        end
        
        ranges = maxVals - minVals;
        ranges(ranges == 0) = 1; % Unikaj dzielenia przez zero
        
        normalizedFeatures = (features - minVals) ./ ranges;
        
    case 'zscore'
        % Z-score normalizacja (średnia=0, std=1)
        if isempty(referenceStats)
            meanVals = mean(features, 1);
            stdVals = std(features, 0, 1);
        else
            meanVals = referenceStats.meanVals;
            stdVals = referenceStats.stdVals;
        end
        
        stdVals(stdVals == 0) = 1; % Unikaj dzielenia przez zero
        
        normalizedFeatures = (features - meanVals) ./ stdVals;
        
    case 'robust'
        % Robust normalizacja (mediana, MAD)
        if isempty(referenceStats)
            medianVals = median(features, 1);
            madVals = mad(features, 1, 1); % Median Absolute Deviation
        else
            medianVals = referenceStats.medianVals;
            madVals = referenceStats.madVals;
        end
        
        madVals(madVals == 0) = 1;
        
        normalizedFeatures = (features - medianVals) ./ madVals;
        
    case 'unit'
        % Unit vector normalizacja (norma euklidesowa = 1)
        norms = sqrt(sum(features.^2, 2));
        norms(norms == 0) = 1;
        
        normalizedFeatures = features ./ norms;
        
    otherwise
        warning('Unknown normalization method: %s. Using zscore.', method);
        normalizedFeatures = normalizeFeatures(features, 'zscore', referenceStats);
end

% Usuń NaN i Inf
normalizedFeatures(~isfinite(normalizedFeatures)) = 0;

% Przywróć oryginalny kształt jeśli to był wektor
if singleVector
    normalizedFeatures = normalizedFeatures(:)';
end
end

function stats = computeNormalizationStats(features, method)
% COMPUTENORMALIZATIONSTATS Oblicza statystyki do normalizacji
% Użyj tej funkcji na zbiorze treningowym

switch lower(method)
    case 'minmax'
        stats.minVals = min(features, [], 1);
        stats.maxVals = max(features, [], 1);
        
    case 'zscore'
        stats.meanVals = mean(features, 1);
        stats.stdVals = std(features, 0, 1);
        
    case 'robust'
        stats.medianVals = median(features, 1);
        stats.madVals = mad(features, 1, 1);
        
    case 'unit'
        stats = []; % Unit normalization nie wymaga statystyk
        
    otherwise
        error('Unknown normalization method: %s', method);
end
end