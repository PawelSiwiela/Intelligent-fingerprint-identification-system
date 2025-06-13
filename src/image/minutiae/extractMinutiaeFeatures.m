function features = extractMinutiaeFeatures(minutiae, config, logFile)
% EXTRACTMINUTIAEFEATURES Ekstraktuje kompaktne cechy z minucji
% Cel: ~100 cech zamiast tysięcy

if nargin < 3, logFile = []; end

try
    if isempty(minutiae)
        logWarning('No minutiae for feature extraction', logFile);
        features = createEmptyFeatureVector();
        return;
    end
    
    logInfo(sprintf('Extracting compact features from %d minutiae...', size(minutiae, 1)), logFile);
    
    % Parametry z konfiguracji
    neighborRadius = config.minutiae.features.neighborhoodRadius;
    maxNeighbors = config.minutiae.features.maxNeighbors;
    
    %% AGREGOWANE CECHY LOKALNE (zamiast per-minutia)
    aggregatedFeatures = computeAggregatedLocalFeatures(minutiae, neighborRadius, maxNeighbors);
    
    %% CECHY GLOBALNE
    globalFeatures = computeCompactGlobalFeatures(minutiae);
    
    %% POŁĄCZ W JEDEN WEKTOR (~100 wartości)
    features = combineToFeatureVector(aggregatedFeatures, globalFeatures);
    
    logSuccess(sprintf('Extracted %d compact features', length(features)), logFile);
    
catch ME
    logError(sprintf('Feature extraction error: %s', ME.message), logFile);
    features = createEmptyFeatureVector();
end
end

function aggregatedFeatures = computeAggregatedLocalFeatures(minutiae, neighborRadius, maxNeighbors)
% COMPUTEAGGREGATEDLOCALFEATURES Agreguje cechy lokalne do statystyk globalnych
% Zamiast cech per-minutia, oblicza statystyki dla całego zbioru

    aggregatedFeatures = struct();
    
    allDistances = [];
    allRelativeOrientations = [];
    allRidgeCounts = [];
    allNeighborCounts = [];
    
    % Zbierz wszystkie cechy lokalne
    for i = 1:size(minutiae, 1)
        currentMinutia = minutiae(i, :);
        neighbors = findNeighborMinutiae(currentMinutia, minutiae, neighborRadius, maxNeighbors);
        
        if ~isempty(neighbors)
            % Odległości
            distances = sqrt((neighbors(:,1) - currentMinutia(1)).^2 + ...
                           (neighbors(:,2) - currentMinutia(2)).^2);
            allDistances = [allDistances; distances];
            
            % Orientacje względne
            relativeOrientations = neighbors(:,3) - currentMinutia(3);
            relativeOrientations = mod(relativeOrientations + pi, 2*pi) - pi;
            allRelativeOrientations = [allRelativeOrientations; relativeOrientations];
            
            % Ridge counts
            ridgeCounts = computeRidgeCountsBetweenMinutiae(currentMinutia, neighbors);
            allRidgeCounts = [allRidgeCounts; ridgeCounts];
            
            % Liczba sąsiadów
            allNeighborCounts = [allNeighborCounts; size(neighbors, 1)];
        end
    end
    
    %% STATYSTYKI AGREGOWANE (30 cech)
    % Odległości (6 cech)
    aggregatedFeatures.dist_mean = safeMean(allDistances);
    aggregatedFeatures.dist_std = safeStd(allDistances);
    aggregatedFeatures.dist_min = safeMin(allDistances);
    aggregatedFeatures.dist_max = safeMax(allDistances);
    aggregatedFeatures.dist_median = safeMedian(allDistances);
    aggregatedFeatures.dist_range = safeMax(allDistances) - safeMin(allDistances);
    
    % Orientacje względne (8 cech)
    aggregatedFeatures.orient_mean = safeMean(allRelativeOrientations);
    aggregatedFeatures.orient_std = safeStd(allRelativeOrientations);
    aggregatedFeatures.orient_var = safeVar(allRelativeOrientations);
    aggregatedFeatures.orient_entropy = computeOrientationEntropy(allRelativeOrientations);
    
    % Histogramy orientacji (4 biny)
    orientBins = [-pi, -pi/2, 0, pi/2, pi];
    [orientHist, ~] = histcounts(allRelativeOrientations, orientBins);
    if sum(orientHist) > 0
        orientHist = orientHist / sum(orientHist); % Normalizuj
    end
    aggregatedFeatures.orient_hist_1 = orientHist(1);
    aggregatedFeatures.orient_hist_2 = orientHist(2);
    aggregatedFeatures.orient_hist_3 = orientHist(3);
    aggregatedFeatures.orient_hist_4 = orientHist(4);
    
    % Ridge counts (6 cech)
    aggregatedFeatures.ridge_mean = safeMean(allRidgeCounts);
    aggregatedFeatures.ridge_std = safeStd(allRidgeCounts);
    aggregatedFeatures.ridge_min = safeMin(allRidgeCounts);
    aggregatedFeatures.ridge_max = safeMax(allRidgeCounts);
    aggregatedFeatures.ridge_median = safeMedian(allRidgeCounts);
    aggregatedFeatures.ridge_mode = safeMode(allRidgeCounts);
    
    % Liczba sąsiadów (6 cech)
    aggregatedFeatures.neighbors_mean = safeMean(allNeighborCounts);
    aggregatedFeatures.neighbors_std = safeStd(allNeighborCounts);
    aggregatedFeatures.neighbors_min = safeMin(allNeighborCounts);
    aggregatedFeatures.neighbors_max = safeMax(allNeighborCounts);
    aggregatedFeatures.neighbors_median = safeMedian(allNeighborCounts);
    aggregatedFeatures.neighbors_total = length(allNeighborCounts);
end

function globalFeatures = computeCompactGlobalFeatures(minutiae)
% COMPUTECOMPACTGLOBALFEATURES Oblicza kompaktne cechy globalne (25 cech)

    globalFeatures = struct();
    
    if isempty(minutiae)
        % Zwróć zerowe cechy
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
    
    % Istniejące cechy globalne (21 cech) + 4 nowe
    globalFeatures.totalCount = size(minutiae, 1);
    globalFeatures.endingCount = sum(minutiae(:, 4) == 1);
    globalFeatures.bifurcationCount = sum(minutiae(:, 4) == 2);
    globalFeatures.averageQuality = mean(minutiae(:, 5));
    
    globalFeatures.centroidX = mean(minutiae(:, 1));
    globalFeatures.centroidY = mean(minutiae(:, 2));
    globalFeatures.spreadX = std(minutiae(:, 1));
    globalFeatures.spreadY = std(minutiae(:, 2));
    
    globalFeatures.boundingBoxWidth = max(minutiae(:, 1)) - min(minutiae(:, 1));
    globalFeatures.boundingBoxHeight = max(minutiae(:, 2)) - min(minutiae(:, 2));
    globalFeatures.boundingBoxArea = globalFeatures.boundingBoxWidth * globalFeatures.boundingBoxHeight;
    
    orientations = minutiae(:, 3);
    orientationBins = 0:pi/18:pi;
    [counts, ~] = histcounts(mod(orientations, pi), orientationBins);
    [~, maxBin] = max(counts);
    globalFeatures.dominantOrientation = orientationBins(maxBin) + pi/36;
    
    globalFeatures.orientationVariance = var(orientations);
    globalFeatures.orientationEntropy = computeOrientationEntropy(orientations);
    globalFeatures.minutiaeDensity = globalFeatures.totalCount / max(globalFeatures.boundingBoxArea, 1);
    
    globalFeatures.qualityStd = std(minutiae(:, 5));
    globalFeatures.minQuality = min(minutiae(:, 5));
    globalFeatures.maxQuality = max(minutiae(:, 5));
    globalFeatures.highQualityRatio = sum(minutiae(:, 5) > 0.7) / globalFeatures.totalCount;
    
    globalFeatures.endingRatio = globalFeatures.endingCount / globalFeatures.totalCount;
    globalFeatures.bifurcationRatio = globalFeatures.bifurcationCount / globalFeatures.totalCount;
    
    % NOWE CECHY GEOMETRYCZNE (4 cechy)
    globalFeatures.aspectRatio = globalFeatures.boundingBoxWidth / max(globalFeatures.boundingBoxHeight, 1);
    globalFeatures.compactness = (globalFeatures.boundingBoxWidth + globalFeatures.boundingBoxHeight) / globalFeatures.totalCount;
    
    % Convex hull i solidity
    if size(minutiae, 1) >= 3
        try
            hull = convhull(minutiae(:, 1), minutiae(:, 2));
            globalFeatures.convexHullArea = polyarea(minutiae(hull, 1), minutiae(hull, 2));
            globalFeatures.solidity = globalFeatures.totalCount / max(globalFeatures.convexHullArea, 1);
        catch
            globalFeatures.convexHullArea = globalFeatures.boundingBoxArea;
            globalFeatures.solidity = globalFeatures.minutiaeDensity;
        end
    else
        globalFeatures.convexHullArea = globalFeatures.boundingBoxArea;
        globalFeatures.solidity = globalFeatures.minutiaeDensity;
    end
end

function featureVector = combineToFeatureVector(aggregatedFeatures, globalFeatures)
% COMBINETOFEATUREVECTOR Łączy wszystkie cechy w jeden wektor numeryczny
% Cel: ~100 wartości

    % Konwertuj struktury na wektory
    aggFields = fieldnames(aggregatedFeatures);
    aggValues = [];
    for i = 1:length(aggFields)
        aggValues(end+1) = aggregatedFeatures.(aggFields{i});
    end
    
    globalFields = fieldnames(globalFeatures);
    globalValues = [];
    for i = 1:length(globalFields)
        globalValues(end+1) = globalFeatures.(globalFields{i});
    end
    
    % Połącz w jeden wektor
    featureVector = [aggValues, globalValues];
    
    % Zastąp NaN i Inf zerami
    featureVector(~isfinite(featureVector)) = 0;
end

function emptyVector = createEmptyFeatureVector()
% CREATEEMPTYFEATUREVECTOR Tworzy pusty wektor cech o stałym rozmiarze
    % 30 (agregowane) + 25 (globalne) = 55 cech
    emptyVector = zeros(1, 55);
end

%% HELPER FUNCTIONS dla bezpiecznych operacji
function result = safeMean(data)
    if isempty(data), result = 0; else, result = mean(data); end
end

function result = safeStd(data)
    if length(data) <= 1, result = 0; else, result = std(data); end
end

function result = safeVar(data)
    if length(data) <= 1, result = 0; else, result = var(data); end
end

function result = safeMin(data)
    if isempty(data), result = 0; else, result = min(data); end
end

function result = safeMax(data)
    if isempty(data), result = 0; else, result = max(data); end
end

function result = safeMedian(data)
    if isempty(data), result = 0; else, result = median(data); end
end

function result = safeMode(data)
    if isempty(data), result = 0; else, result = mode(data); end
end

function neighbors = findNeighborMinutiae(currentMinutia, allMinutiae, radius, maxNeighbors)
% FINDNEIGHBORMINUTIAE Znajduje sąsiednie minucje w określonym promieniu
    distances = sqrt((allMinutiae(:,1) - currentMinutia(1)).^2 + ...
                    (allMinutiae(:,2) - currentMinutia(2)).^2);
    
    % Wykluczy samą siebie (odległość = 0)
    distances(distances == 0) = inf;
    
    % Znajdź sąsiadów w promieniu
    inRadius = distances <= radius;
    neighborIndices = find(inRadius);
    neighborDistances = distances(inRadius);
    
    % Ogranicz do maxNeighbors najbliższych
    if length(neighborIndices) > maxNeighbors
        [~, sortIdx] = sort(neighborDistances);
        neighborIndices = neighborIndices(sortIdx(1:maxNeighbors));
    end
    
    neighbors = allMinutiae(neighborIndices, :);
end

function ridgeCounts = computeRidgeCountsBetweenMinutiae(currentMinutia, neighbors)
% COMPUTERIDGECOUNTSBETWEENMINUTIAE Oblicza liczbę linii papilarnych między minucjami
    ridgeCounts = zeros(size(neighbors, 1), 1);
    
    for i = 1:size(neighbors, 1)
        neighbor = neighbors(i, :);
        
        % Oblicz odległość między minucjami
        distance = sqrt((neighbor(1) - currentMinutia(1))^2 + ...
                       (neighbor(2) - currentMinutia(2))^2);
        
        % Szacowana częstotliwość linii papilarnych (około 10-15 pikseli między liniami)
        averageRidgeSpacing = 12; % pikseli
        
        % Przybliżona liczba linii na podstawie odległości
        estimatedRidgeCount = round(distance / averageRidgeSpacing);
        
        % Korekta na podstawie orientacji względnej
        orientationDiff = abs(neighbor(3) - currentMinutia(3));
        orientationDiff = min(orientationDiff, 2*pi - orientationDiff); % najmniejszy kąt
        
        % Jeśli orientacje są podobne, linie są równoległe -> więcej przecięć
        if orientationDiff < pi/4 % 45 stopni
            correctionFactor = 1.2;
        elseif orientationDiff > 3*pi/4 % 135 stopni
            correctionFactor = 0.8;
        else
            correctionFactor = 1.0;
        end
        
        ridgeCounts(i) = max(1, round(estimatedRidgeCount * correctionFactor));
    end
end

function entropy = computeOrientationEntropy(orientations)
% COMPUTEORIENTATIONENTROPY Oblicza entropię rozkładu orientacji
    if isempty(orientations)
        entropy = 0;
        return;
    end
    
    % Podziel orientacje na biny
    numBins = 18; % 10-stopniowe biny
    binEdges = 0:pi/numBins:pi;
    
    % Oblicz histogram (normalizuj orientacje do [0, pi])
    [counts, ~] = histcounts(mod(orientations, pi), binEdges);
    
    % Oblicz prawdopodobieństwa
    probabilities = counts / sum(counts);
    
    % Usuń zerowe prawdopodobieństwa
    probabilities = probabilities(probabilities > 0);
    
    % Oblicz entropię
    if isempty(probabilities)
        entropy = 0;
    else
        entropy = -sum(probabilities .* log2(probabilities));
    end
end