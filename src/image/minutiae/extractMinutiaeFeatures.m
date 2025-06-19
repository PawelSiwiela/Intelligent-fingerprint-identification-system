function features = extractMinutiaeFeatures(minutiae, config, logFile)
% EXTRACTMINUTIAEFEATURES Ekstraktuje kompaktowy wektor cech z wykrytych minucji
%
% Funkcja przekształca zmienną liczbę minucji w stały wektor cech o rozmiarze
% około 55 elementów. Zamiast cech per-minucja (które generują tysiące wartości),
% funkcja oblicza statystyki agregowane i globalne charakterystyki odcisku.
%
% Parametry wejściowe:
%   minutiae - macierz wykrytych minucji [x, y, angle, type, quality]
%   config - struktura konfiguracyjna z parametrami ekstrakcji cech
%   logFile - uchwyt do pliku logów (opcjonalny)
%
% Parametry wyjściowe:
%   features - wektor cech o stałym rozmiarze (~55 elementów)
%              składający się z cech agregowanych i globalnych
%
% Struktura wektora cech:
%   - Cechy agregowane (30 elem.): statystyki odległości, orientacji, ridge counts
%   - Cechy globalne (25 elem.): liczniki, centroidy, rozprzestrzenienie, jakość
%
% Przykład użycia:
%   featureVector = extractMinutiaeFeatures(minutiae, config, logFile);

if nargin < 3, logFile = []; end

try
    if isempty(minutiae)
        logWarning('No minutiae for feature extraction', logFile);
        features = createEmptyFeatureVector();
        return;
    end
    
    logInfo(sprintf('Extracting compact features from %d minutiae...', size(minutiae, 1)), logFile);
    
    % Parametry ekstrakcji cech z konfiguracji
    neighborRadius = config.minutiae.features.neighborhoodRadius;  % Promień sąsiedztwa (np. 50 pikseli)
    maxNeighbors = config.minutiae.features.maxNeighbors;          % Maks. liczba sąsiadów (np. 8)
    
    %% CECHY AGREGOWANE LOKALNE (30 cech)
    % Zamiast cech per-minucja, oblicza statystyki globalne dla całego zbioru
    aggregatedFeatures = computeAggregatedLocalFeatures(minutiae, neighborRadius, maxNeighbors);
    
    %% CECHY GLOBALNE (25 cech)
    % Charakterystyki całego odcisku palca
    globalFeatures = computeCompactGlobalFeatures(minutiae);
    
    %% POŁĄCZENIE W JEDEN WEKTOR CECH
    % Konwersja struktur na numeryczny wektor o stałym rozmiarze
    features = combineToFeatureVector(aggregatedFeatures, globalFeatures);
    
    logSuccess(sprintf('Extracted %d compact features', length(features)), logFile);
    
catch ME
    logError(sprintf('Feature extraction error: %s', ME.message), logFile);
    features = createEmptyFeatureVector();
end
end

function aggregatedFeatures = computeAggregatedLocalFeatures(minutiae, neighborRadius, maxNeighbors)
% COMPUTEAGGREGATEDLOCALFEATURES Oblicza statystyki agregowane cech lokalnych
%
% Funkcja analizuje relacje między minucjami (odległości, orientacje, ridge counts)
% i przekształca je w globalne statystyki zamiast przechowywać cechy per-minucja.
% To drastycznie redukuje wymiarowość zachowując kluczowe informacje.
%
% Parametry wejściowe:
%   minutiae - macierz minucji [x, y, angle, type, quality]
%   neighborRadius - promień wyszukiwania sąsiadów w pikselach
%   maxNeighbors - maksymalna liczba sąsiadów do analizy
%
% Parametry wyjściowe:
%   aggregatedFeatures - struktura z 30 cechami agregatów lokalnych

aggregatedFeatures = struct();

% Kolekcje wszystkich cech lokalnych do agregacji
allDistances = [];
allRelativeOrientations = [];
allRidgeCounts = [];
allNeighborCounts = [];

% ANALIZA SĄSIEDZTW - zbieranie danych lokalnych
for i = 1:size(minutiae, 1)
    currentMinutia = minutiae(i, :);
    neighbors = findNeighborMinutiae(currentMinutia, minutiae, neighborRadius, maxNeighbors);
    
    if ~isempty(neighbors)
        % Odległości euklidesowe do sąsiadów
        distances = sqrt((neighbors(:,1) - currentMinutia(1)).^2 + ...
            (neighbors(:,2) - currentMinutia(2)).^2);
        allDistances = [allDistances; distances];
        
        % Orientacje względne (różnice kątów)
        relativeOrientations = neighbors(:,3) - currentMinutia(3);
        % Normalizacja do zakresu [-π, π]
        relativeOrientations = mod(relativeOrientations + pi, 2*pi) - pi;
        allRelativeOrientations = [allRelativeOrientations; relativeOrientations];
        
        % Szacowana liczba linii papilarnych między minucjami
        ridgeCounts = computeRidgeCountsBetweenMinutiae(currentMinutia, neighbors);
        allRidgeCounts = [allRidgeCounts; ridgeCounts];
        
        % Liczba sąsiadów dla każdej minucji
        allNeighborCounts = [allNeighborCounts; size(neighbors, 1)];
    end
end

%% STATYSTYKI ODLEGŁOŚCI (6 cech)
% Podstawowe statystyki rozkładu odległości między sąsiadami
aggregatedFeatures.dist_mean = safeMean(allDistances);      % Średnia odległość
aggregatedFeatures.dist_std = safeStd(allDistances);        % Odchylenie standardowe
aggregatedFeatures.dist_min = safeMin(allDistances);        % Minimalna odległość
aggregatedFeatures.dist_max = safeMax(allDistances);        % Maksymalna odległość
aggregatedFeatures.dist_median = safeMedian(allDistances);  % Mediana
aggregatedFeatures.dist_range = safeMax(allDistances) - safeMin(allDistances); % Rozstęp

%% STATYSTYKI ORIENTACJI WZGLĘDNYCH (8 cech)
% Analiza rozkładu różnic kątowych między sąsiadami
aggregatedFeatures.orient_mean = safeMean(allRelativeOrientations);  % Średni kierunek względny
aggregatedFeatures.orient_std = safeStd(allRelativeOrientations);    % Zmienność kierunków
aggregatedFeatures.orient_var = safeVar(allRelativeOrientations);    % Wariancja kierunków
aggregatedFeatures.orient_entropy = computeOrientationEntropy(allRelativeOrientations); % Entropia rozkładu

% Histogram orientacji względnych (4 biny po 45°)
orientBins = [-pi, -pi/2, 0, pi/2, pi];
[orientHist, ~] = histcounts(allRelativeOrientations, orientBins);
if sum(orientHist) > 0
    orientHist = orientHist / sum(orientHist); % Normalizacja do prawdopodobieństw
end
aggregatedFeatures.orient_hist_1 = orientHist(1); % [-180°, -90°]
aggregatedFeatures.orient_hist_2 = orientHist(2); % [-90°, 0°]
aggregatedFeatures.orient_hist_3 = orientHist(3); % [0°, 90°]
aggregatedFeatures.orient_hist_4 = orientHist(4); % [90°, 180°]

%% STATYSTYKI RIDGE COUNTS (6 cech)
% Liczba linii papilarnych przecinanych między minucjami
aggregatedFeatures.ridge_mean = safeMean(allRidgeCounts);     % Średnia liczba linii
aggregatedFeatures.ridge_std = safeStd(allRidgeCounts);       % Zmienność liczby linii
aggregatedFeatures.ridge_min = safeMin(allRidgeCounts);       % Minimalna liczba linii
aggregatedFeatures.ridge_max = safeMax(allRidgeCounts);       % Maksymalna liczba linii
aggregatedFeatures.ridge_median = safeMedian(allRidgeCounts); % Mediana liczby linii
aggregatedFeatures.ridge_mode = safeMode(allRidgeCounts);     % Najczęstsza liczba linii

%% STATYSTYKI LICZBY SĄSIADÓW (6 cech)
% Charakterystyka gęstości lokalnej minucji
aggregatedFeatures.neighbors_mean = safeMean(allNeighborCounts);     % Średnia liczba sąsiadów
aggregatedFeatures.neighbors_std = safeStd(allNeighborCounts);       % Zmienność liczby sąsiadów
aggregatedFeatures.neighbors_min = safeMin(allNeighborCounts);       % Min. liczba sąsiadów
aggregatedFeatures.neighbors_max = safeMax(allNeighborCounts);       % Max. liczba sąsiadów
aggregatedFeatures.neighbors_median = safeMedian(allNeighborCounts); % Mediana liczby sąsiadów
aggregatedFeatures.neighbors_total = length(allNeighborCounts);      % Całkowita liczba relacji
end

function globalFeatures = computeCompactGlobalFeatures(minutiae)
% COMPUTECOMPACTGLOBALFEATURES Oblicza globalne charakterystyki odcisku palca
%
% Funkcja ekstraktuje 25 cech opisujących całościowe właściwości odcisku:
% liczniki minucji, rozmieszczenie przestrzenne, jakość, kształt i topologię.
%
% Parametry wejściowe:
%   minutiae - macierz minucji [x, y, angle, type, quality]
%
% Parametry wyjściowe:
%   globalFeatures - struktura z 25 cechami globalnymi

globalFeatures = struct();

if isempty(minutiae)
    % Zwróć zerowe cechy dla pustego zbioru minucji
    fields = {'totalCount', 'endingCount', 'bifurcationCount', 'averageQuality', ...
        'centroidX', 'centroidY', 'spreadX', 'spreadY', 'boundingBoxWidth', ...
        'boundingBoxHeight', 'boundingBoxArea', 'dominantOrientation', ...
        'orientationVariance', 'orientationEntropy', 'minutiaeDensity', ...
        'qualityStd', 'minQuality', 'maxQuality', 'highQualityRatio', ...
        'endingRatio', 'bifurcationRatio', 'aspectRatio', 'compactness', ...
        'convexHullArea', 'solidity'};
    for i = 1:length(fields)
        globalFeatures.(fields{i}) = 0;
    end
    return;
end

%% LICZNIKI PODSTAWOWE (4 cechy)
globalFeatures.totalCount = size(minutiae, 1);                    % Całkowita liczba minucji
globalFeatures.endingCount = sum(minutiae(:, 4) == 1);            % Liczba endings
globalFeatures.bifurcationCount = sum(minutiae(:, 4) == 2);       % Liczba bifurcations
globalFeatures.averageQuality = mean(minutiae(:, 5));             % Średnia jakość

%% CHARAKTERYSTYKI PRZESTRZENNE (8 cech)
globalFeatures.centroidX = mean(minutiae(:, 1));                  % Środek masy X
globalFeatures.centroidY = mean(minutiae(:, 2));                  % Środek masy Y
globalFeatures.spreadX = std(minutiae(:, 1));                     % Rozprzestrzenienie X
globalFeatures.spreadY = std(minutiae(:, 2));                     % Rozprzestrzenienie Y

% Prostokąt ograniczający (bounding box)
globalFeatures.boundingBoxWidth = max(minutiae(:, 1)) - min(minutiae(:, 1));   % Szerokość BB
globalFeatures.boundingBoxHeight = max(minutiae(:, 2)) - min(minutiae(:, 2));  % Wysokość BB
globalFeatures.boundingBoxArea = globalFeatures.boundingBoxWidth * globalFeatures.boundingBoxHeight; % Pole BB

%% ANALIZA ORIENTACJI (3 cechy)
orientations = minutiae(:, 3);

% Dominująca orientacja (najczęstszy kierunek linii papilarnych)
orientationBins = 0:pi/18:pi; % 18 binów po 10°
[counts, ~] = histcounts(mod(orientations, pi), orientationBins);
[~, maxBin] = max(counts);
globalFeatures.dominantOrientation = orientationBins(maxBin) + pi/36; % Środek binu

globalFeatures.orientationVariance = var(orientations);           % Wariancja orientacji
globalFeatures.orientationEntropy = computeOrientationEntropy(orientations); % Entropia orientacji

%% METRYKI GĘSTOŚCI I JAKOŚCI (5 cech)
globalFeatures.minutiaeDensity = globalFeatures.totalCount / max(globalFeatures.boundingBoxArea, 1); % Gęstość
globalFeatures.qualityStd = std(minutiae(:, 5));              % Odchylenie std jakości
globalFeatures.minQuality = min(minutiae(:, 5));              % Minimalna jakość
globalFeatures.maxQuality = max(minutiae(:, 5));              % Maksymalna jakość
globalFeatures.highQualityRatio = sum(minutiae(:, 5) > 0.7) / globalFeatures.totalCount; % Odsetek wysokiej jakości

%% STOSUNKI TYPÓW MINUCJI (2 cechy)
globalFeatures.endingRatio = globalFeatures.endingCount / globalFeatures.totalCount;        % Odsetek endings
globalFeatures.bifurcationRatio = globalFeatures.bifurcationCount / globalFeatures.totalCount; % Odsetek bifurcations

%% CECHY GEOMETRYCZNE KSZTAŁTU (4 cechy)
globalFeatures.aspectRatio = globalFeatures.boundingBoxWidth / max(globalFeatures.boundingBoxHeight, 1); % Proporcje BB
globalFeatures.compactness = (globalFeatures.boundingBoxWidth + globalFeatures.boundingBoxHeight) / globalFeatures.totalCount; % Kompaktowość

% Analiza convex hull (otoczka wypukła) i solidity
if size(minutiae, 1) >= 3
    try
        hull = convhull(minutiae(:, 1), minutiae(:, 2));
        globalFeatures.convexHullArea = polyarea(minutiae(hull, 1), minutiae(hull, 2)); % Pole otoczki wypukłej
        globalFeatures.solidity = globalFeatures.totalCount / max(globalFeatures.convexHullArea, 1); % Solidność
    catch
        % Fallback w przypadku błędu convhull
        globalFeatures.convexHullArea = globalFeatures.boundingBoxArea;
        globalFeatures.solidity = globalFeatures.minutiaeDensity;
    end
else
    % Za mało punktów dla convhull
    globalFeatures.convexHullArea = globalFeatures.boundingBoxArea;
    globalFeatures.solidity = globalFeatures.minutiaeDensity;
end
end

function featureVector = combineToFeatureVector(aggregatedFeatures, globalFeatures)
% COMBINETOFEATUREVECTOR Łączy wszystkie cechy w jeden numeryczny wektor
%
% Funkcja konwertuje struktury cech na wektor numeryczny o stałym rozmiarze.
% Wszystkie wartości NaN i nieskończone są zastępowane zerami dla stabilności.
%
% Parametry wejściowe:
%   aggregatedFeatures - struktura z cechami agregowanymi (30 cech)
%   globalFeatures - struktura z cechami globalnymi (25 cech)
%
% Parametry wyjściowe:
%   featureVector - wektor numeryczny o rozmiarze 55 elementów

% Konwersja struktury agregowanej na wektor
aggFields = fieldnames(aggregatedFeatures);
aggValues = [];
for i = 1:length(aggFields)
    aggValues(end+1) = aggregatedFeatures.(aggFields{i});
end

% Konwersja struktury globalnej na wektor
globalFields = fieldnames(globalFeatures);
globalValues = [];
for i = 1:length(globalFields)
    globalValues(end+1) = globalFeatures.(globalFields{i});
end

% Połączenie w jeden wektor: [cechy_agregowane, cechy_globalne]
featureVector = [aggValues, globalValues];

% Czyszczenie danych - zastąp NaN i Inf zerami
featureVector(~isfinite(featureVector)) = 0;
end

function emptyVector = createEmptyFeatureVector()
% CREATEEMPTYFEATUREVECTOR Tworzy pusty wektor cech o standardowym rozmiarze
%
% Funkcja zwraca wektor zer o rozmiarze odpowiadającym pełnemu wektorowi cech.
% Używane jako fallback gdy ekstrakcja cech nie powiodła się.
%
% Parametry wyjściowe:
%   emptyVector - wektor zer o rozmiarze 55 elementów

% 30 (cechy agregowane) + 25 (cechy globalne) = 55 cech całkowicie
emptyVector = zeros(1, 55);
end

%% FUNKCJE POMOCNICZE dla bezpiecznych operacji statystycznych

function result = safeMean(data)
% SAFEMEAN Bezpieczne obliczanie średniej z obsługą pustych danych
if isempty(data), result = 0; else, result = mean(data); end
end

function result = safeStd(data)
% SAFESTD Bezpieczne obliczanie odchylenia standardowego
if length(data) <= 1, result = 0; else, result = std(data); end
end

function result = safeVar(data)
% SAFEVAR Bezpieczne obliczanie wariancji
if length(data) <= 1, result = 0; else, result = var(data); end
end

function result = safeMin(data)
% SAFEMIN Bezpieczne znajdowanie minimum
if isempty(data), result = 0; else, result = min(data); end
end

function result = safeMax(data)
% SAFEMAX Bezpieczne znajdowanie maksimum
if isempty(data), result = 0; else, result = max(data); end
end

function result = safeMedian(data)
% SAFEMEDIAN Bezpieczne obliczanie mediany
if isempty(data), result = 0; else, result = median(data); end
end

function result = safeMode(data)
% SAFEMODE Bezpieczne znajdowanie mody (najczęstszej wartości)
if isempty(data), result = 0; else, result = mode(data); end
end

function neighbors = findNeighborMinutiae(currentMinutia, allMinutiae, radius, maxNeighbors)
% FINDNEIGHBORMINUTIAE Znajduje sąsiednie minucje w określonym promieniu
%
% Funkcja wyszukuje minucje w zadanym promieniu od aktualnej minucji,
% wykluczając ją samą, i ogranicza wynik do maksymalnej liczby najbliższych sąsiadów.
%
% Parametry wejściowe:
%   currentMinutia - aktualnie analizowana minucja [x, y, angle, type, quality]
%   allMinutiae - macierz wszystkich minucji w obrazie
%   radius - promień wyszukiwania w pikselach
%   maxNeighbors - maksymalna liczba zwracanych sąsiadów
%
% Parametry wyjściowe:
%   neighbors - macierz sąsiednich minucji

% Oblicz odległości euklidesowe do wszystkich minucji
distances = sqrt((allMinutiae(:,1) - currentMinutia(1)).^2 + ...
    (allMinutiae(:,2) - currentMinutia(2)).^2);

% Wykluczy samą siebie (odległość = 0)
distances(distances == 0) = inf;

% Znajdź sąsiadów w określonym promieniu
inRadius = distances <= radius;
neighborIndices = find(inRadius);
neighborDistances = distances(inRadius);

% Ogranicz do maxNeighbors najbliższych sąsiadów
if length(neighborIndices) > maxNeighbors
    [~, sortIdx] = sort(neighborDistances);
    neighborIndices = neighborIndices(sortIdx(1:maxNeighbors));
end

neighbors = allMinutiae(neighborIndices, :);
end

function ridgeCounts = computeRidgeCountsBetweenMinutiae(currentMinutia, neighbors)
% COMPUTERIDGECOUNTSBETWEENMINUTIAE Szacuje liczbę linii papilarnych między minucjami
%
% Funkcja oblicza przybliżoną liczbę linii papilarnych przecinanych na odcinku
% między aktualną minucją a każdym z jej sąsiadów. Wykorzystuje typową częstotliwość
% linii papilarnych i korekty oparte na orientacji względnej.
%
% Parametry wejściowe:
%   currentMinutia - aktualnie analizowana minucja [x, y, angle, type, quality]
%   neighbors - macierz sąsiednich minucji
%
% Parametry wyjściowe:
%   ridgeCounts - wektor z liczbą linii papilarnych do każdego sąsiada

ridgeCounts = zeros(size(neighbors, 1), 1);

for i = 1:size(neighbors, 1)
    neighbor = neighbors(i, :);
    
    % Oblicz odległość euklidesową między minucjami
    distance = sqrt((neighbor(1) - currentMinutia(1))^2 + ...
        (neighbor(2) - currentMinutia(2))^2);
    
    % Typowa częstotliwość linii papilarnych w odciskach palców
    averageRidgeSpacing = 12; % pikseli między liniami (typowo 10-15)
    
    % Podstawowa liczba linii na podstawie odległości
    estimatedRidgeCount = round(distance / averageRidgeSpacing);
    
    % Korekta na podstawie różnicy orientacji względnej
    orientationDiff = abs(neighbor(3) - currentMinutia(3));
    orientationDiff = min(orientationDiff, 2*pi - orientationDiff); % Najmniejszy kąt
    
    % Współczynnik korekty zależny od orientacji względnej
    if orientationDiff < pi/4 % 45 stopni - linie równoległe
        correctionFactor = 1.2; % Więcej przecięć
    elseif orientationDiff > 3*pi/4 % 135 stopni - linie przeciwne
        correctionFactor = 0.8; % Mniej przecięć
    else
        correctionFactor = 1.0; % Bez korekty
    end
    
    % Finalna liczba linii (minimum 1)
    ridgeCounts(i) = max(1, round(estimatedRidgeCount * correctionFactor));
end
end

function entropy = computeOrientationEntropy(orientations)
% COMPUTEORIENTATIONENTROPY Oblicza entropię rozkładu orientacji minucji
%
% Funkcja mierzy różnorodność kierunków linii papilarnych poprzez obliczenie
% entropii Shannona histogram orientacji. Wysoka entropia oznacza większą
% różnorodność kierunków, niska - dominację określonych orientacji.
%
% Parametry wejściowe:
%   orientations - wektor orientacji w radianach
%
% Parametry wyjściowe:
%   entropy - entropia rozkładu orientacji (bits)

if isempty(orientations)
    entropy = 0;
    return;
end

% Podziel orientacje na 18 binów (po 10 stopni)
numBins = 18;
binEdges = 0:pi/numBins:pi;

% Oblicz histogram - normalizuj orientacje do zakresu [0, π]
[counts, ~] = histcounts(mod(orientations, pi), binEdges);

% Konwersja na prawdopodobieństwa
probabilities = counts / sum(counts);

% Usuń zerowe prawdopodobieństwa (log(0) = -∞)
probabilities = probabilities(probabilities > 0);

% Oblicz entropię Shannona: H = -Σ(p * log2(p))
if isempty(probabilities)
    entropy = 0;
else
    entropy = -sum(probabilities .* log2(probabilities));
end
end