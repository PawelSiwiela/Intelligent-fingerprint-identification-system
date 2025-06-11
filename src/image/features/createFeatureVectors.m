function featureVector = createFeatureVectors(minutiae, params)
% CREATEFEATUREVECTORS Tworzy wektor cech z minucji pojedynczego obrazu
%
% Input:
%   minutiae - struktura z minucjami (endpoints, bifurcations, all)
%   params - parametry ekstrakcji
%
% Output:
%   featureVector - wektor cech [1 x N]

% Inicjalizacja
featureVector = [];

% Sprawdź czy są minucje
if isempty(minutiae) || isempty(minutiae.all) || size(minutiae.all, 1) == 0
    % Brak minucji - zwróć wektor zerowy
    featureDim = params.gridSize(1) * params.gridSize(2) + ...
        params.orientationBins + ...
        params.distanceBins + ...
        6; % podstawowe statystyki
    featureVector = zeros(1, featureDim);
    return;
end

% ======================================================================
% 1. PODSTAWOWE STATYSTYKI MINUCJI (6 cech)
% ======================================================================
stats = computeBasicStatistics(minutiae);
featureVector = [featureVector, stats];

% ======================================================================
% 2. MAPA GĘSTOŚCI MINUCJI (64 cechy dla siatki 8x8)
% ======================================================================
densityMap = computeDensityMap(minutiae, params);
featureVector = [featureVector, densityMap(:)'];

% ======================================================================
% 3. HISTOGRAM ORIENTACJI (36 cech dla 36 binów)
% ======================================================================
orientationHist = computeOrientationHistogram(minutiae, params);
featureVector = [featureVector, orientationHist];

% ======================================================================
% 4. ROZKŁAD ODLEGŁOŚCI MIĘDZY MINUCJAMI (16 cech)
% ======================================================================
distanceHist = computeDistanceHistogram(minutiae, params);
featureVector = [featureVector, distanceHist];

% Sprawdź rozmiar
expectedDim = 6 + params.gridSize(1)*params.gridSize(2) + params.orientationBins + params.distanceBins;
if length(featureVector) ~= expectedDim
    warning('Nieprawidłowy rozmiar wektora cech: %d, oczekiwano %d', ...
        length(featureVector), expectedDim);
end
end

function stats = computeBasicStatistics(minutiae)
% Oblicza podstawowe statystyki minucji

% Liczby minucji
numEndpoints = size(minutiae.endpoints, 1);
numBifurcations = size(minutiae.bifurcations, 1);
totalMinutiae = size(minutiae.all, 1);

% Proporcje
if totalMinutiae > 0
    endpointRatio = numEndpoints / totalMinutiae;
    bifurcationRatio = numBifurcations / totalMinutiae;
else
    endpointRatio = 0;
    bifurcationRatio = 0;
end

% Gęstość minucji (minucje na jednostkę powierzchni)
% Zakładamy standardowy rozmiar obrazu 300x300
imageArea = 300 * 300;
minutiaeDensity = totalMinutiae / imageArea;

stats = [numEndpoints, numBifurcations, totalMinutiae, ...
    endpointRatio, bifurcationRatio, minutiaeDensity];
end

function densityMap = computeDensityMap(minutiae, params)
% Tworzy mapę gęstości minucji na siatce

gridRows = params.gridSize(1);
gridCols = params.gridSize(2);
imageSize = params.imageSize;

densityMap = zeros(gridRows, gridCols);

if isempty(minutiae.all)
    return;
end

% Rozmiar każdej komórki siatki
cellHeight = imageSize(1) / gridRows;
cellWidth = imageSize(2) / gridCols;

% Dla każdej minucji znajdź odpowiednią komórkę
for i = 1:size(minutiae.all, 1)
    x = minutiae.all(i, 1);
    y = minutiae.all(i, 2);
    
    % Skaluj współrzędne do rozmiaru obrazu (jeśli potrzeba)
    % Zakładamy że współrzędne są już w odpowiednim zakresie
    
    % Znajdź indeksy komórki
    gridRow = min(gridRows, max(1, ceil(y / cellHeight)));
    gridCol = min(gridCols, max(1, ceil(x / cellWidth)));
    
    % Zwiększ licznik w tej komórce
    densityMap(gridRow, gridCol) = densityMap(gridRow, gridCol) + 1;
end

% Normalizuj przez całkowitą liczbę minucji
if size(minutiae.all, 1) > 0
    densityMap = densityMap / size(minutiae.all, 1);
end
end

function orientationHist = computeOrientationHistogram(minutiae, params)
% Oblicza histogram orientacji minucji

numBins = params.orientationBins;
orientationHist = zeros(1, numBins);

if isempty(minutiae.all) || size(minutiae.all, 2) < 4
    return;
end

% Pobierz orientacje (4. kolumna)
orientations = minutiae.all(:, 4);

% Konwertuj orientacje do zakresu [0, 2π]
orientations = mod(orientations, 2*pi);

% Określ szerokość każdego bina
binWidth = 2*pi / numBins;

% Przypisz orientacje do binów
for i = 1:length(orientations)
    binIndex = min(numBins, floor(orientations(i) / binWidth) + 1);
    orientationHist(binIndex) = orientationHist(binIndex) + 1;
end

% Normalizuj przez liczbę minucji
if length(orientations) > 0
    orientationHist = orientationHist / length(orientations);
end
end

function distanceHist = computeDistanceHistogram(minutiae, params)
% Oblicza histogram odległości między minucjami

numBins = params.distanceBins;
distanceHist = zeros(1, numBins);

if isempty(minutiae.all) || size(minutiae.all, 1) < 2
    return;
end

% Oblicz wszystkie odległości między parami minucji
positions = minutiae.all(:, 1:2); % x, y
numMinutiae = size(positions, 1);
distances = [];

for i = 1:numMinutiae-1
    for j = i+1:numMinutiae
        dist = sqrt(sum((positions(i,:) - positions(j,:)).^2));
        distances = [distances, dist];
    end
end

if isempty(distances)
    return;
end

% Określ zakres odległości
maxDistance = sqrt(sum(params.imageSize.^2)); % Przekątna obrazu
binWidth = maxDistance / numBins;

% Przypisz odległości do binów
for i = 1:length(distances)
    binIndex = min(numBins, floor(distances(i) / binWidth) + 1);
    distanceHist(binIndex) = distanceHist(binIndex) + 1;
end

% Normalizuj przez liczbę par
if length(distances) > 0
    distanceHist = distanceHist / length(distances);
end
end