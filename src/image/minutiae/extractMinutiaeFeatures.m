function features = extractMinutiaeFeatures(minutiae, config, logFile)
% EXTRACTMINUTIAEFEATURES Ekstrakcja kompaktowego wektora cech z minucji
%
% Funkcja przekształca zbiór minucji w kompaktowy wektor liczbowy (~55 cech)
% gotowy do użycia w algorytmach klasyfikacji. Zamiast cech per-minutia
% (które generowałyby tysiące wymiarów), oblicza agregowane statystyki
% lokalne i globalne cechy geometryczne.
%
% Parametry wejściowe:
%   minutiae - macierz minucji [x, y, angle, type, quality]
%   config - struktura konfiguracyjna z parametrami ekstrakcji
%   logFile - uchwyt pliku logów (opcjonalny)
%
% Parametry wyjściowe:
%   features - wektor cech numerycznych o stałym rozmiarze (55 elementów)

if nargin < 3, logFile = []; end

try
    % SPRAWDZENIE DANYCH WEJŚCIOWYCH
    if isempty(minutiae)
        logWarning('No minutiae for feature extraction - returning zero vector', logFile);
        features = createEmptyFeatureVector();
        return;
    end
    
    logInfo(sprintf('Extracting compact feature vector from %d minutiae...', size(minutiae, 1)), logFile);
    
    % POBRANIE PARAMETRÓW EKSTRAKCJI z konfiguracji
    neighborRadius = config.minutiae.features.neighborhoodRadius;  % Promień sąsiedztwa (np. 50 pikseli)
    maxNeighbors = config.minutiae.features.maxNeighbors;          % Maksymalna liczba sąsiadów (np. 8)
    
    %% CZĘŚĆ 1: AGREGOWANE CECHY LOKALNE (30 cech)
    % Analizuje relacje między minucjami i agreguje je do statystyk globalnych
    aggregatedFeatures = computeAggregatedLocalFeatures(minutiae, neighborRadius, maxNeighbors);
    
    %% CZĘŚĆ 2: CECHY GLOBALNE GEOMETRYCZNE (25 cech)
    % Oblicza właściwości całego zbioru minucji: rozkład, kształt, jakość
    globalFeatures = computeCompactGlobalFeatures(minutiae);
    
    %% CZĘŚĆ 3: KOMBINACJA W JEDEN WEKTOR NUMERYCZNY
    % Łączy obie grupy cech w wektor o stałym rozmiarze 55 elementów
    features = combineToFeatureVector(aggregatedFeatures, globalFeatures);
    
    logSuccess(sprintf('Successfully extracted %d-dimensional feature vector', length(features)), logFile);
    
catch ME
    % OBSŁUGA BŁĘDÓW - zwrócenie zerowego wektora w przypadku niepowodzenia
    logError(sprintf('Feature extraction failed: %s', ME.message), logFile);
    features = createEmptyFeatureVector();
end
end

function aggregatedFeatures = computeAggregatedLocalFeatures(minutiae, neighborRadius, maxNeighbors)
% COMPUTEAGGREGATEDLOCALFEATURES Obliczanie zagregowanych cech relacyjnych (30 cech)
%
% Funkcja analizuje relacje przestrzenne między minucjami (odległości,
% orientacje względne, liczby linii papilarnych) i agreguje je do
% statystyk opisujących całą strukturę odcisku, zamiast tworzyć cechy
% dla każdej pary minucji osobno.

aggregatedFeatures = struct();

% INICJALIZACJA kolekcji wszystkich pomiarów lokalnych
allDistances = [];           % Odległości między sąsiednimi minucjami
allRelativeOrientations = []; % Różnice orientacji między sąsiadami
allRidgeCounts = [];         % Liczby linii papilarnych między minucjami
allNeighborCounts = [];      % Liczby sąsiadów dla każdej minucji

% ITERACJA przez wszystkie minucje - zbieranie pomiarów lokalnych
for i = 1:size(minutiae, 1)
    currentMinutia = minutiae(i, :);
    % Znajdź sąsiednie minucje w określonym promieniu
    neighbors = findNeighborMinutiae(currentMinutia, minutiae, neighborRadius, maxNeighbors);
    
    if ~isempty(neighbors)
        % POMIARY ODLEGŁOŚCI euklidesowych do sąsiadów
        distances = sqrt((neighbors(:,1) - currentMinutia(1)).^2 + ...
            (neighbors(:,2) - currentMinutia(2)).^2);
        allDistances = [allDistances; distances];
        
        % POMIARY ORIENTACJI WZGLĘDNYCH (różnice kątów)
        relativeOrientations = neighbors(:,3) - currentMinutia(3);
        % Normalizacja do zakresu [-π, π] dla spójności
        relativeOrientations = mod(relativeOrientations + pi, 2*pi) - pi;
        allRelativeOrientations = [allRelativeOrientations; relativeOrientations];
        
        % POMIARY LICZBY LINII PAPILARNYCH między minucjami
        ridgeCounts = computeRidgeCountsBetweenMinutiae(currentMinutia, neighbors);
        allRidgeCounts = [allRidgeCounts; ridgeCounts];
        
        % LICZBA SĄSIADÓW dla bieżącej minucji
        allNeighborCounts = [allNeighborCounts; size(neighbors, 1)];
    end
end

%% AGREGACJA DO STATYSTYK OPISOWYCH (30 cech łącznie)

% GRUPA 1: STATYSTYKI ODLEGŁOŚCI (6 cech)
% Opisują rozkład przestrzenny minucji
aggregatedFeatures.dist_mean = safeMean(allDistances);     % Średnia odległość między sąsiadami
aggregatedFeatures.dist_std = safeStd(allDistances);       % Odchylenie standardowe odległości
aggregatedFeatures.dist_min = safeMin(allDistances);       % Minimalna odległość
aggregatedFeatures.dist_max = safeMax(allDistances);       % Maksymalna odległość
aggregatedFeatures.dist_median = safeMedian(allDistances); % Mediana odległości
aggregatedFeatures.dist_range = safeMax(allDistances) - safeMin(allDistances); % Rozstęp odległości

% GRUPA 2: STATYSTYKI ORIENTACJI WZGLĘDNYCH (8 cech)
% Opisują lokalne wzorce kierunków linii papilarnych
aggregatedFeatures.orient_mean = safeMean(allRelativeOrientations);  % Średni kierunek względny
aggregatedFeatures.orient_std = safeStd(allRelativeOrientations);    % Odchylenie kierunków
aggregatedFeatures.orient_var = safeVar(allRelativeOrientations);    % Wariancja kierunków
aggregatedFeatures.orient_entropy = computeOrientationEntropy(allRelativeOrientations); % Entropia rozkłładu

% HISTOGRAM ORIENTACJI WZGLĘDNYCH (4 binów × 4 cechy)
% Rozkład kierunków w kwadrantach: [-π,-π/2], [-π/2,0], [0,π/2], [π/2,π]
orientBins = [-pi, -pi/2, 0, pi/2, pi];
[orientHist, ~] = histcounts(allRelativeOrientations, orientBins);
if sum(orientHist) > 0
    orientHist = orientHist / sum(orientHist); % Normalizacja do prawdopodobieństw
end
aggregatedFeatures.orient_hist_1 = orientHist(1); % Udział kierunków -π do -π/2
aggregatedFeatures.orient_hist_2 = orientHist(2); % Udział kierunków -π/2 do 0
aggregatedFeatures.orient_hist_3 = orientHist(3); % Udział kierunków 0 do π/2
aggregatedFeatures.orient_hist_4 = orientHist(4); % Udział kierunków π/2 do π

% GRUPA 3: STATYSTYKI LICZBY LINII PAPILARNYCH (6 cech)
% Opisują gęstość i strukturę linii papilarnych między minucjami
aggregatedFeatures.ridge_mean = safeMean(allRidgeCounts);     % Średnia liczba linii
aggregatedFeatures.ridge_std = safeStd(allRidgeCounts);       % Odchylenie liczby linii
aggregatedFeatures.ridge_min = safeMin(allRidgeCounts);       % Minimalna liczba linii
aggregatedFeatures.ridge_max = safeMax(allRidgeCounts);       % Maksymalna liczba linii
aggregatedFeatures.ridge_median = safeMedian(allRidgeCounts); % Mediana liczby linii
aggregatedFeatures.ridge_mode = safeMode(allRidgeCounts);     % Najczęstsza liczba linii

% GRUPA 4: STATYSTYKI SĄSIEDZTWA (6 cech)
% Opisują lokalną gęstość i łączność minucji
aggregatedFeatures.neighbors_mean = safeMean(allNeighborCounts);     % Średnia liczba sąsiadów
aggregatedFeatures.neighbors_std = safeStd(allNeighborCounts);       % Odchylenie liczby sąsiadów
aggregatedFeatures.neighbors_min = safeMin(allNeighborCounts);       % Minimalna liczba sąsiadów
aggregatedFeatures.neighbors_max = safeMax(allNeighborCounts);       % Maksymalna liczba sąsiadów
aggregatedFeatures.neighbors_median = safeMedian(allNeighborCounts); % Mediana liczby sąsiadów
aggregatedFeatures.neighbors_total = length(allNeighborCounts);      % Całkowita liczba analizowanych minucji
end

function globalFeatures = computeCompactGlobalFeatures(minutiae)
% COMPUTECOMPACTGLOBALFEATURES Obliczanie globalnych cech geometrycznych (25 cech)
%
% Funkcja analizuje całościowe właściwości zbioru minucji: rozkład przestrzenny,
% właściwości geometryczne, statystyki jakości i proporcje typów minucji.
% Cechy są niezależne od liczby minucji i kolejności ich występowania.

globalFeatures = struct();

% OBSŁUGA PUSTEGO ZBIORU MINUCJI
if isempty(minutiae)
    % Zwróć strukturę wypełnioną zerami dla zachowania spójności wymiarów
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

%% GRUPA 1: PODSTAWOWE STATYSTYKI ZBIORU (4 cechy)
globalFeatures.totalCount = size(minutiae, 1);              % Całkowita liczba minucji
globalFeatures.endingCount = sum(minutiae(:, 4) == 1);      % Liczba punktów końcowych
globalFeatures.bifurcationCount = sum(minutiae(:, 4) == 2); % Liczba bifurkacji
globalFeatures.averageQuality = mean(minutiae(:, 5));       % Średnia jakość minucji

%% GRUPA 2: CHARAKTERYSTYKI PRZESTRZENNE (8 cech)
% Centralne tendencje rozkładu przestrzennego
globalFeatures.centroidX = mean(minutiae(:, 1));            % Środek masy - współrzędna X
globalFeatures.centroidY = mean(minutiae(:, 2));            % Środek masy - współrzędna Y
globalFeatures.spreadX = std(minutiae(:, 1));               % Rozrzut w kierunku X
globalFeatures.spreadY = std(minutiae(:, 2));               % Rozrzut w kierunku Y

% Prostokąt ograniczający (bounding box)
globalFeatures.boundingBoxWidth = max(minutiae(:, 1)) - min(minutiae(:, 1));   % Szerokość
globalFeatures.boundingBoxHeight = max(minutiae(:, 2)) - min(minutiae(:, 2));  % Wysokość
globalFeatures.boundingBoxArea = globalFeatures.boundingBoxWidth * globalFeatures.boundingBoxHeight; % Pole

% Gęstość przestrzenna minucji
globalFeatures.minutiaeDensity = globalFeatures.totalCount / max(globalFeatures.boundingBoxArea, 1);

%% GRUPA 3: ANALIZA ORIENTACJI DOMINUJĄCEJ (3 cechy)
orientations = minutiae(:, 3);
% Podział orientacji na 18 binów (po 10 stopni) w zakresie [0, π]
orientationBins = 0:pi/18:pi;
[counts, ~] = histcounts(mod(orientations, pi), orientationBins);
[~, maxBin] = max(counts);
% Orientacja dominująca - środek najliczniejszego binu
globalFeatures.dominantOrientation = orientationBins(maxBin) + pi/36;

globalFeatures.orientationVariance = var(orientations);     % Wariancja orientacji
globalFeatures.orientationEntropy = computeOrientationEntropy(orientations); % Entropia rozkładu orientacji

%% GRUPA 4: STATYSTYKI JAKOŚCI (4 cechy)
globalFeatures.qualityStd = std(minutiae(:, 5));            % Odchylenie standardowe jakości
globalFeatures.minQuality = min(minutiae(:, 5));            % Minimalna jakość
globalFeatures.maxQuality = max(minutiae(:, 5));            % Maksymalna jakość
globalFeatures.highQualityRatio = sum(minutiae(:, 5) > 0.7) / globalFeatures.totalCount; % Udział wysokiej jakości

%% GRUPA 5: PROPORCJE TYPÓW MINUCJI (2 cechy)
globalFeatures.endingRatio = globalFeatures.endingCount / globalFeatures.totalCount;        % Proporcja punktów końcowych
globalFeatures.bifurcationRatio = globalFeatures.bifurcationCount / globalFeatures.totalCount; % Proporcja bifurkacji

%% GRUPA 6: ZAAWANSOWANE CECHY GEOMETRYCZNE (4 cechy)
% Współczynnik kształtu prostokąta ograniczającego
globalFeatures.aspectRatio = globalFeatures.boundingBoxWidth / max(globalFeatures.boundingBoxHeight, 1);
% Miara kompaktności - stosunek obwodu do liczby minucji
globalFeatures.compactness = (globalFeatures.boundingBoxWidth + globalFeatures.boundingBoxHeight) / globalFeatures.totalCount;

% ANALIZA WYPUKŁEJ OTOCZKI (convex hull)
if size(minutiae, 1) >= 3
    try
        % Oblicz wypukłą otoczkę punktów minucji
        hull = convhull(minutiae(:, 1), minutiae(:, 2));
        globalFeatures.convexHullArea = polyarea(minutiae(hull, 1), minutiae(hull, 2));
        % Solidność - stosunek liczby punktów do pola wypukłej otoczki
        globalFeatures.solidity = globalFeatures.totalCount / max(globalFeatures.convexHullArea, 1);
    catch
        % Fallback w przypadku błędu geometrycznego
        globalFeatures.convexHullArea = globalFeatures.boundingBoxArea;
        globalFeatures.solidity = globalFeatures.minutiaeDensity;
    end
else
    % Za mało punktów do utworzenia wypukłej otoczki
    globalFeatures.convexHullArea = globalFeatures.boundingBoxArea;
    globalFeatures.solidity = globalFeatures.minutiaeDensity;
end
end

function featureVector = combineToFeatureVector(aggregatedFeatures, globalFeatures)
% COMBINETOFEATUREVECTOR Łączenie cech w jednolity wektor numeryczny
%
% Funkcja konwertuje struktury zawierające cechy agregowane i globalne
% na jeden wektor liczbowy o stałym rozmiarze, gotowy do użycia w
% algorytmach uczenia maszynowego. Obsługuje wartości NaN i nieskończone.

% KONWERSJA STRUKTUR NA WEKTORY LICZBOWE
% Cechy agregowane (30 elementów)
aggFields = fieldnames(aggregatedFeatures);
aggValues = [];
for i = 1:length(aggFields)
    aggValues(end+1) = aggregatedFeatures.(aggFields{i});
end

% Cechy globalne (25 elementów)
globalFields = fieldnames(globalFeatures);
globalValues = [];
for i = 1:length(globalFields)
    globalValues(end+1) = globalFeatures.(globalFields{i});
end

% ŁĄCZENIE W JEDEN WEKTOR (55 elementów łącznie)
featureVector = [aggValues, globalValues];

% OCZYSZCZENIE NIEPRAWIDŁOWYCH WARTOŚCI
% Zastąpienie NaN, Inf, -Inf wartościami zerowymi dla stabilności numerycznej
featureVector(~isfinite(featureVector)) = 0;
end

function emptyVector = createEmptyFeatureVector()
% CREATEEMPTYFEATUREVECTOR Tworzenie pustego wektora cech o standardowym rozmiarze
%
% Funkcja zwraca wektor zerowy o stałym rozmiarze odpowiadającym
% pełnemu wektorowi cech. Używane w przypadku braku minucji lub błędów.
%
% Rozmiar: 30 (cechy agregowane) + 25 (cechy globalne) = 55 cech

emptyVector = zeros(1, 55);
end

%% FUNKCJE POMOCNICZE - BEZPIECZNE OPERACJE STATYSTYCZNE

function result = safeMean(data)
% SAFEMEAN Bezpieczne obliczenie średniej arytmetycznej
if isempty(data), result = 0; else, result = mean(data); end
end

function result = safeStd(data)
% SAFESTD Bezpieczne obliczenie odchylenia standardowego
if length(data) <= 1, result = 0; else, result = std(data); end
end

function result = safeVar(data)
% SAFEVAR Bezpieczne obliczenie wariancji
if length(data) <= 1, result = 0; else, result = var(data); end
end

function result = safeMin(data)
% SAFEMIN Bezpieczne znalezienie wartości minimalnej
if isempty(data), result = 0; else, result = min(data); end
end

function result = safeMax(data)
% SAFEMAX Bezpieczne znalezienie wartości maksymalnej
if isempty(data), result = 0; else, result = max(data); end
end

function result = safeMedian(data)
% SAFEMEDIAN Bezpieczne obliczenie mediany
if isempty(data), result = 0; else, result = median(data); end
end

function result = safeMode(data)
% SAFEMODE Bezpieczne obliczenie modalnej (najczęstszej wartości)
if isempty(data), result = 0; else, result = mode(data); end
end

function neighbors = findNeighborMinutiae(currentMinutia, allMinutiae, radius, maxNeighbors)
% FINDNEIGHBORMINUTIAE Wyszukiwanie sąsiednich minucji w określonym promieniu
%
% Funkcja znajduje minucje położone w zadanym promieniu euklidesowym
% od bieżącej minucji i ogranicza ich liczbę do najbliższych sąsiadów.
%
% Parametry wejściowe:
%   currentMinutia - analizowana minucja [x, y, angle, type, quality]
%   allMinutiae - wszystkie minucje w obrazie
%   radius - promień sąsiedztwa w pikselach
%   maxNeighbors - maksymalna liczba sąsiadów do zwrócenia
%
% Parametry wyjściowe:
%   neighbors - macierz sąsiednich minucji

% OBLICZENIE ODLEGŁOŚCI EUKLIDESOWYCH do wszystkich minucji
distances = sqrt((allMinutiae(:,1) - currentMinutia(1)).^2 + ...
    (allMinutiae(:,2) - currentMinutia(2)).^2);

% WYKLUCZENIE SAMEJ SIEBIE (odległość = 0)
distances(distances == 0) = inf;

% FILTROWANIE według promienia sąsiedztwa
inRadius = distances <= radius;
neighborIndices = find(inRadius);
neighborDistances = distances(inRadius);

% OGRANICZENIE do maxNeighbors najbliższych sąsiadów
if length(neighborIndices) > maxNeighbors
    [~, sortIdx] = sort(neighborDistances);
    neighborIndices = neighborIndices(sortIdx(1:maxNeighbors));
end

neighbors = allMinutiae(neighborIndices, :);
end

function ridgeCounts = computeRidgeCountsBetweenMinutiae(currentMinutia, neighbors)
% COMPUTERIDGECOUNTSBETWEENMINUTIAE Estymacja liczby linii papilarnych między minucjami
%
% Funkcja oblicza przybliżoną liczbę linii papilarnych przecinających
% odcinek łączący dwie minucje. Wykorzystuje założenia o średniej
% gęstości linii papilarnych i wpływie orientacji względnej.
%
% Parametry wejściowe:
%   currentMinutia - minucja początkowa [x, y, angle, type, quality]
%   neighbors - macierz sąsiednich minucji
%
% Parametry wyjściowe:
%   ridgeCounts - wektor liczb linii dla każdego sąsiada

ridgeCounts = zeros(size(neighbors, 1), 1);

for i = 1:size(neighbors, 1)
    neighbor = neighbors(i, :);
    
    % OBLICZENIE ODLEGŁOŚCI EUKLIDESOWEJ między minucjami
    distance = sqrt((neighbor(1) - currentMinutia(1))^2 + ...
        (neighbor(2) - currentMinutia(2))^2);
    
    % ESTYMACJA na podstawie średniej gęstości linii papilarnych
    % Typowa odległość między liniami papilarnymi: 10-15 pikseli
    averageRidgeSpacing = 12; % pikseli między liniami
    
    % Przybliżona liczba linii na podstawie odległości
    estimatedRidgeCount = round(distance / averageRidgeSpacing);
    
    % KOREKTA na podstawie orientacji względnej linii papilarnych
    orientationDiff = abs(neighbor(3) - currentMinutia(3));
    orientationDiff = min(orientationDiff, 2*pi - orientationDiff); % najmniejszy kąt
    
    % Współczynnik korekcyjny zależny od orientacji względnej
    if orientationDiff < pi/4 % 45 stopni - linie równoległe
        correctionFactor = 1.2; % więcej przecięć przez podobne orientacje
    elseif orientationDiff > 3*pi/4 % 135 stopni - linie prostopadłe
        correctionFactor = 0.8; % mniej przecięć przez różne orientacje
    else
        correctionFactor = 1.0; % orientacje pośrednie
    end
    
    % Ostateczna liczba linii z korekcją (minimum 1)
    ridgeCounts(i) = max(1, round(estimatedRidgeCount * correctionFactor));
end
end

function entropy = computeOrientationEntropy(orientations)
% COMPUTEORIENTATIONENTROPY Obliczanie entropii rozkładu orientacji
%
% Funkcja mierzy różnorodność kierunków orientacji w zbiorze minucji.
% Wysoka entropia oznacza równomierny rozkład orientacji (kompleksowy wzór),
% niska entropia wskazuje na dominację określonych kierunków.
%
% Parametry wejściowe:
%   orientations - wektor orientacji w radianach
%
% Parametry wyjściowe:
%   entropy - entropia informacyjna w bitach

if isempty(orientations)
    entropy = 0;
    return;
end

% DYSKRETYZACJA orientacji na równomierne biny
numBins = 18; % 18 binów × 10 stopni = pełny zakres 180 stopni
binEdges = 0:pi/numBins:pi;

% OBLICZENIE HISTOGRAMU (normalizacja orientacji do zakresu [0, π])
[counts, ~] = histcounts(mod(orientations, pi), binEdges);

% KONWERSJA na prawdopodobieństwa
probabilities = counts / sum(counts);

% USUNIĘCIE zerowych prawdopodobieństw (niedefiniowane w logarytmie)
probabilities = probabilities(probabilities > 0);

% OBLICZENIE ENTROPII SHANNONA: H = -∑(p * log₂(p))
if isempty(probabilities)
    entropy = 0;
else
    entropy = -sum(probabilities .* log2(probabilities));
end
end