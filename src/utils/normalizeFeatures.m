function normalizedFeatures = normalizeFeatures(features, method, referenceStats)
% NORMALIZEFEATURES Normalizuje wektory cech różnymi metodami
%
% Funkcja implementuje różne metody normalizacji danych numerycznych
% cech odcisków palców w celu zapewnienia stabilności treningu sieci
% neuronowych i porównywalności między różnymi cechami.
%
% Parametry wejściowe:
%   features - macierz cech [samples x features] lub wektor [1 x features]
%   method - metoda normalizacji: 'minmax', 'zscore', 'robust', 'unit'
%   referenceStats - (opcjonalne) statystyki referencyjne dla zbioru treningowego
%
% Dane wyjściowe:
%   normalizedFeatures - znormalizowane cechy
%
% Dostępne metody:
%   'minmax' - normalizacja do przedziału [0,1]
%   'zscore' - standaryzacja (średnia=0, odchylenie=1)
%   'robust' - odporna na outliers (mediana, MAD)
%   'unit' - normalizacja do wektora jednostkowego

if nargin < 2
    method = 'minmax'; % Domyślna metoda
end

if nargin < 3
    referenceStats = [];
end

% SPRAWDŹ czy to wektor czy macierz
if isvector(features)
    features = features(:)'; % Zapewnij format wiersza
    singleVector = true;
else
    singleVector = false;
end

[numSamples, numFeatures] = size(features);

switch lower(method)
    case 'minmax'
        % MIN-MAX normalizacja do zakresu [0, 1]
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
        % Z-SCORE normalizacja (średnia=0, odchylenie standardowe=1)
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
        % ROBUST normalizacja (mediana, MAD - odporna na outliers)
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
        % UNIT VECTOR normalizacja (norma euklidesowa = 1)
        norms = sqrt(sum(features.^2, 2));
        norms(norms == 0) = 1;
        
        normalizedFeatures = features ./ norms;
        
    otherwise
        warning('Unknown normalization method: %s. Using zscore.', method);
        normalizedFeatures = normalizeFeatures(features, 'zscore', referenceStats);
end

% USUŃ wartości NaN i Inf (zabezpieczenie)
normalizedFeatures(~isfinite(normalizedFeatures)) = 0;

% PRZYWRÓĆ oryginalny kształt jeśli to był pojedynczy wektor
if singleVector
    normalizedFeatures = normalizedFeatures(:)';
end
end

function stats = computeNormalizationStats(features, method)
% COMPUTENORMALIZATIONSTATS Oblicza statystyki do normalizacji
%
% Funkcja pomocnicza do obliczania statystyk normalizacyjnych na zbiorze
% treningowym, które później mogą być zastosowane do zbioru testowego
% w celu zachowania spójności normalizacji.
%
% Parametry wejściowe:
%   features - macierz cech zbioru treningowego
%   method - metoda normalizacji
%
% Dane wyjściowe:
%   stats - struktura ze statystykami dla danej metody

switch lower(method)
    case 'minmax'
        % STATYSTYKI dla min-max normalizacji
        stats.minVals = min(features, [], 1);
        stats.maxVals = max(features, [], 1);
        
    case 'zscore'
        % STATYSTYKI dla z-score normalizacji
        stats.meanVals = mean(features, 1);
        stats.stdVals = std(features, 0, 1);
        
    case 'robust'
        % STATYSTYKI dla robust normalizacji
        stats.medianVals = median(features, 1);
        stats.madVals = mad(features, 1, 1);
        
    case 'unit'
        % UNIT normalization nie wymaga statystyk referencyjnych
        stats = [];
        
    otherwise
        error('Unknown normalization method: %s', method);
end
end