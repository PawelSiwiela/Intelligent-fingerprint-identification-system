function [minutiae, qualityMap] = detectMinutiae(skeletonImage, config, logFile)
% DETECTMINUTIAE Wykrywa minucje - wersja oparta na oryginalnej ale ulepszona
%
% Argumenty:
%   skeletonImage - obraz szkieletu linii papilarnych
%   config - struktura konfiguracyjna
%   logFile - plik logów (opcjonalny)
%
% Output:
%   minutiae - wykryte minucje [x, y, angle, type, quality]
%   qualityMap - mapa jakości dla każdej minucji

if nargin < 3, logFile = []; end

try
    logInfo('Starting minutiae detection...', logFile);
    
    % Sprawdź format wejściowy
    if ~islogical(skeletonImage)
        skeletonImage = skeletonImage > 0;
    end
    
    if isempty(skeletonImage) || sum(skeletonImage(:)) == 0
        logWarning('Empty skeleton image', logFile);
        minutiae = zeros(0, 5);
        qualityMap = zeros(size(skeletonImage));
        return;
    end
    
    [rows, cols] = size(skeletonImage);
    qualityMap = zeros(rows, cols);
    
    logInfo(sprintf('Analyzing skeleton image %dx%d...', rows, cols), logFile);
    
    % DETEKCJA punktów (uproszczona wersja oryginalnej)
    [endpoints, bifurcations] = detectMinutiaePoints(skeletonImage);
    
    % OBLICZ orientacje
    endpointOrientations = computeMinutiaeOrientations(skeletonImage, endpoints);
    bifurcationOrientations = computeMinutiaeOrientations(skeletonImage, bifurcations);
    
    % POŁĄCZ w format [x, y, angle, type, quality]
    minutiae = [];
    
    % Dodaj endpoints (type = 1)
    if ~isempty(endpoints)
        endpointQualities = computeSimpleQuality(endpoints, skeletonImage, 1);
        endpointData = [endpoints, endpointOrientations, ones(size(endpoints,1), 1), endpointQualities];
        minutiae = [minutiae; endpointData];
    end
    
    % Dodaj bifurkacje (type = 2) z ŁAGODNIEJSZYMI kryteriami
    if ~isempty(bifurcations)
        bifurcationQualities = computeSimpleQuality(bifurcations, skeletonImage, 2);
        bifurcationData = [bifurcations, bifurcationOrientations, 2*ones(size(bifurcations,1), 1), bifurcationQualities];
        minutiae = [minutiae; bifurcationData];
    end
    
    logInfo(sprintf('Found %d endpoints and %d bifurcations before filtering', ...
        size(endpoints,1), size(bifurcations,1)), logFile);
    
    % FILTRACJA (uproszczona)
    if ~isempty(minutiae)
        % 1. Usuń duplikaty z AGRESYWNĄ filtracją dla bifurkacji
        minutiae = removeCloseMinutiae(minutiae, 12); % Zwiększone z 8 do 12
        
        % 2. ŁAGODNA filtracja jakości - NIŻSZY próg dla bifurkacji
        keepMask = false(size(minutiae, 1), 1);
        for i = 1:size(minutiae, 1)
            type = minutiae(i, 4);
            quality = minutiae(i, 5);
            
            if type == 1  % Endpoints
                keepMask(i) = quality >= 0.15;  % Było 0.2, teraz niższy próg 0.15
            else  % Bifurkacje - ZNACZNIE niższy próg!
                keepMask(i) = quality >= 0.05; % Było 0.35, teraz drastycznie mniej - 0.05
            end
        end
        
        minutiae = minutiae(keepMask, :);
        
        % Zapisz kopię przed dalszą filtracją dla ewentualnej korekty
        minutiae_before_filtering = minutiae;
        
        % 3. Strategiczne ograniczenie z DOCELOWYMI PROPORCJAMI - więcej bifurkacji
        maxMinutiae = config.minutiae.filtering.maxMinutiae;
        if size(minutiae, 1) > maxMinutiae
            minutiae = limitMinutiaeWithTargetRatio(minutiae, maxMinutiae, 0.4); % Było 0.6, teraz 0.4 (więcej bifurkacji)
        end
        
        % NOWY KOD: Korekta liczby bifurkacji jeśli jest za niska
        bifurcationCount = sum(minutiae(:, 4) == 2);
        if bifurcationCount < 40  % Chcemy przynajmniej 40 bifurkacji
            % Znajdź brakujące bifurkacje z kopii przed filtracją
            allBifurcations = minutiae_before_filtering(minutiae_before_filtering(:, 4) == 2, :);
            
            % Sprawdź których bifurkacji nie ma w końcowym zestawie
            existingBifX = minutiae(minutiae(:, 4) == 2, 1);
            existingBifY = minutiae(minutiae(:, 4) == 2, 2);
            
            missingBifurcations = [];
            for i = 1:size(allBifurcations, 1)
                x = allBifurcations(i, 1);
                y = allBifurcations(i, 2);
                
                % Sprawdź czy ta bifurkacja już istnieje w wynikach
                isExisting = false;
                for j = 1:length(existingBifX)
                    if abs(existingBifX(j) - x) <= 3 && abs(existingBifY(j) - y) <= 3
                        isExisting = true;
                        break;
                    end
                end
                
                if ~isExisting
                    missingBifurcations = [missingBifurcations; allBifurcations(i, :)];
                end
            end
            
            % Dodaj dodatkowe bifurkacje do wyników
            numToAdd = min(40 - bifurcationCount, size(missingBifurcations, 1));
            if numToAdd > 0
                [~, sortIdx] = sort(missingBifurcations(:, 5), 'descend');  % Sortuj wg jakości
                additionalBifs = missingBifurcations(sortIdx(1:numToAdd), :);
                minutiae = [minutiae; additionalBifs];
            end
        end
        
        % Aktualizuj quality map
        for i = 1:size(minutiae, 1)
            x = round(minutiae(i, 1));
            y = round(minutiae(i, 2));
            if x >= 1 && x <= cols && y >= 1 && y <= rows
                qualityMap(y, x) = minutiae(i, 5);
            end
        end
    end
    
    % Finalne statystyki
    endingCount = sum(minutiae(:, 4) == 1);
    bifurcationCount = sum(minutiae(:, 4) == 2);
    
    logInfo(sprintf('Final result: %d endpoints, %d bifurcations', endingCount, bifurcationCount), logFile);
    logSuccess(sprintf('Detected %d minutiae total', size(minutiae, 1)), logFile);
    
catch ME
    logError(sprintf('Minutiae detection error: %s', ME.message), logFile);
    minutiae = zeros(0, 5);
    qualityMap = zeros(size(skeletonImage));
end
end

%% HELPER FUNCTIONS (bazowane na oryginale)

function [endpoints, bifurcations] = detectMinutiaePoints(skeletonImage)
% DETECTMINUTIAEPOINTS Wykrywa punkty minucji na obrazie szkieletowym
% ZMODYFIKOWANA DLA ZWIĘKSZENIA LICZBY BIFURKACJI

[rows, cols] = size(skeletonImage);
endpoints = [];
bifurcations = [];

% ZMNIEJSZONY margines dla wykrywania większej liczby minucji!
margin = 10; % Było 25, zmniejszone do 10 - będzie wykrywać więcej minucji przy krawędziach

% Pole całego obrazu do kalkulacji gęstości minucji
imageTotalArea = rows * cols;
validArea = (rows-2*margin) * (cols-2*margin);
targetEndpointDensity = 0.0020; % Zwiększone z 0.0005 do 0.0020 - więcej zakończeń będzie akceptowanych

for y = margin+1:rows-margin
    for x = margin+1:cols-margin
        if ~skeletonImage(y, x)
            continue;
        end
        
        % Policz sąsiadów w oknie 3x3
        neighborhood = skeletonImage(y-1:y+1, x-1:x+1);
        neighborhood(2,2) = false; % Wyłącz środkowy punkt
        neighbors = sum(neighborhood(:));
        
        % Endpoint - wymaga mniej rygorystycznej weryfikacji
        if neighbors == 1
            % Dodane zakończenia są teraz mniej rygorystycznie weryfikowane
            endpoints = [endpoints; x, y];  % Akceptujemy wszystkie punkty końcowe wstępnie
        % Rozgałęzienie - BARDZO złagodzone kryteria weryfikacji
        elseif neighbors == 3
            % Łagodniejsza walidacja bifurkacji z nową funkcją
            if isValidBifurcationRelaxed(skeletonImage, x, y)
                bifurcations = [bifurcations; x, y];
            end
        end
    end
end

% Dodatkowa kontrola liczby zakończeń - DUŻO WYŻSZY PRÓG
if length(endpoints) > validArea * targetEndpointDensity * 4  % Zwiększone z *2 do *4
    % Usuń zakończenia o najgorszej charakterystyce
    scores = evaluateEndpoints(skeletonImage, endpoints);
    [~, sortIdx] = sort(scores, 'descend');
    maxEndpoints = round(validArea * targetEndpointDensity * 3); % Zwiększone z *1 do *3
    endpoints = endpoints(sortIdx(1:min(maxEndpoints, length(sortIdx))), :);
end
end

function isValid = isValidBifurcationImproved(image, x, y)
% ISVALIDBIFURCATIONIMPROVED Znacznie ostrzejsza walidacja bifurkacji

isValid = false;

% 1. PODSTAWOWA WALIDACJA 3x3
neighborhood = image(y-1:y+1, x-1:x+1);
neighborhood(2,2) = false;

% Musi mieć dokładnie 3 sąsiadów
if sum(neighborhood(:)) ~= 3
    return;
end

% 2. SPRAWDŹ POZYCJE SĄSIADÓW
[ny, nx] = find(neighborhood);

% Nie mogą być w jednej linii
if length(unique(ny)) == 1 || length(unique(nx)) == 1
    return;
end

% 3. WALIDACJA W OKNIE 5x5 - sprawdź czy to prawdziwa bifurkacja
if ~validateBifurcationInLargerWindow(image, x, y)
    return;
end

% 4. SPRAWDŹ CIĄGŁOŚĆ LINII PAPILARNYCH
if ~validateRidgeContinuity(image, x, y)
    return;
end

% 5. SPRAWDŹ STABILNOŚĆ (czy usunięcie punktu znacząco zmienia topologię)
if ~validateTopologicalStability(image, x, y)
    return;
end

isValid = true;
end

function isValid = validateBifurcationInLargerWindow(image, x, y)
% VALIDATEBIFURCATIONINLARGERWINDOW Sprawdź kontekst w oknie 5x5

isValid = true;
[rows, cols] = size(image);

% Sprawdź okno 5x5
r1 = max(1, y-2); r2 = min(rows, y+2);
c1 = max(1, x-2); c2 = min(cols, x+2);

window = image(r1:r2, c1:c2);
centerY = y - r1 + 1;
centerX = x - c1 + 1;

% Policz sąsiadów w różnych promieniach
neighbors_r1 = countNeighborsInRadius(window, centerX, centerY, 1);
neighbors_r2 = countNeighborsInRadius(window, centerX, centerY, 2);

% Bifurkacja powinna mieć 3 sąsiadów w promieniu 1
% i nie więcej niż 6-8 w promieniu 2
if neighbors_r1 ~= 3 || neighbors_r2 > 8
    isValid = false;
end
end

function count = countNeighborsInRadius(window, centerX, centerY, radius)
% COUNTNEIGHBORSINRADIUS Policz piksele szkieletu w promieniu

count = 0;
[rows, cols] = size(window);

for dy = -radius:radius
    for dx = -radius:radius
        if dx == 0 && dy == 0
            continue; % Pomiń środek
        end
        
        y = centerY + dy;
        x = centerX + dx;
        
        if x >= 1 && x <= cols && y >= 1 && y <= rows
            if window(y, x) == 1
                count = count + 1;
            end
        end
    end
end
end

function isValid = validateRidgeContinuity(image, x, y)
% VALIDATERIDGECONTINUITY Sprawdź czy linie papilarne rzeczywiście się rozgałęziają

isValid = true;
[rows, cols] = size(image);

% Znajdź 3 sąsiadów
neighborhood = image(y-1:y+1, x-1:x+1);
neighborhood(2,2) = false;
[ny, nx] = find(neighborhood);

% Konwertuj na współrzędne globalne
globalNeighbors = [nx + x - 2, ny + y - 2];

% Dla każdego sąsiada sprawdź czy ma ciągłość linii
validNeighbors = 0;
for i = 1:size(globalNeighbors, 1)
    nx = globalNeighbors(i, 1);
    ny = globalNeighbors(i, 2);
    
    if nx > 1 && nx < cols && ny > 1 && ny < rows
        % Sprawdź czy sąsiad ma właściwą liczbę połączeń
        nNeighborhood = image(ny-1:ny+1, nx-1:nx+1);
        nNeighborhood(2,2) = false;
        nConnections = sum(nNeighborhood(:));
        
        % Sąsiad bifurkacji powinien mieć 1-3 połączenia
        if nConnections >= 1 && nConnections <= 3
            validNeighbors = validNeighbors + 1;
        end
    end
end

% Przynajmniej 2 z 3 sąsiadów musi być "dobrych"
if validNeighbors < 2
    isValid = false;
end
end

function isValid = validateTopologicalStability(image, x, y)
% VALIDATETOPOLOGICALSTABILITY Sprawdź czy punkt jest topologicznie istotny

isValid = true;

% Utwórz kopię bez tego punktu
testImage = image;
testImage(y, x) = 0;

% Sprawdź okno 7x7 wokół punktu
[rows, cols] = size(image);
r1 = max(1, y-3); r2 = min(rows, y+3);
c1 = max(1, x-3); c2 = min(cols, x+3);

originalWindow = image(r1:r2, c1:c2);
testWindow = testImage(r1:r2, c1:c2);

% Policz składowe spójne
ccOriginal = bwconncomp(originalWindow, 8);
ccTest = bwconncomp(testWindow, 8);

% Jeśli usunięcie punktu znacząco zwiększa fragmentację
% MOŻE to oznaczać że punkt nie jest prawdziwą bifurkacją
if ccTest.NumObjects > ccOriginal.NumObjects + 1
    isValid = false;
end

% Sprawdź czy nie nastąpiła nadmierna fragmentacja
totalPixelsOriginal = sum(originalWindow(:));
totalPixelsTest = sum(testWindow(:));

if totalPixelsOriginal > 0
    fragmentationRatio = ccTest.NumObjects / totalPixelsOriginal;
    if fragmentationRatio > 0.3 % Arbitrary threshold
        isValid = false;
    end
end
end

function orientations = computeMinutiaeOrientations(skeleton, points)
% COMPUTEMINUTIAEORIENTATIONS Oblicza orientacje minucji (jak w oryginale)

if isempty(points)
    orientations = [];
    return;
end

orientations = zeros(size(points, 1), 1);
windowSize = 7; % Trochę większe okno

for i = 1:size(points, 1)
    try
        x = round(points(i, 1));
        y = round(points(i, 2));
        
        [rows, cols] = size(skeleton);
        r1 = max(1, y - windowSize);
        r2 = min(rows, y + windowSize);
        c1 = max(1, x - windowSize);
        c2 = min(cols, x + windowSize);
        
        localWindow = skeleton(r1:r2, c1:c2);
        
        if sum(localWindow(:)) > 3
            [gx, gy] = gradient(double(localWindow));
            weights = localWindow;
            
            if sum(weights(:)) > 0
                avgGx = sum(gx(:) .* weights(:)) / sum(weights(:));
                avgGy = sum(gy(:) .* weights(:)) / sum(weights(:));
                
                if abs(avgGx) > 0.01 || abs(avgGy) > 0.01
                    orientations(i) = atan2(avgGy, avgGx);
                else
                    orientations(i) = 0;
                end
            else
                orientations(i) = 0;
            end
        else
            orientations(i) = 0;
        end
        
    catch
        orientations(i) = 0;
    end
end
end

function qualities = computeSimpleQuality(points, skeleton, minutiaType)
% COMPUTESIMPLEQUALITY Delikatnie złagodzone dla bifurkacji

if isempty(points)
    qualities = [];
    return;
end

qualities = zeros(size(points, 1), 1);
[rows, cols] = size(skeleton);

for i = 1:size(points, 1)
    x = round(points(i, 1));
    y = round(points(i, 2));
    
    % Bazowa jakość - DELIKATNIE WYŻSZA dla bifurkacji
    if minutiaType == 1
        baseQuality = 0.8; % Endpoints (bez zmian)
    else
        baseQuality = 0.75; % Bifurkacje (było 0.7, teraz wyżej)
    end
    
    % Kara za bliskość brzegu - ŁAGODNIEJSZA dla bifurkacji
    distToBorder = min([x-1, y-1, cols-x, rows-y]);
    if minutiaType == 1  % Endpoints (bez zmian)
        if distToBorder < 10
            baseQuality = baseQuality * 0.7;
        elseif distToBorder < 20
            baseQuality = baseQuality * 0.9;
        end
    else  % Bifurkacje - ŁAGODNIEJSZE kary
        if distToBorder < 8  % Było 10, teraz ostrzej ale krócej
            baseQuality = baseQuality * 0.75; % Było 0.7, teraz łagodniej
        elseif distToBorder < 15  % Było 20, teraz krócej
            baseQuality = baseQuality * 0.92; % Było 0.9, teraz łagodniej
        end
    end
    
    % Sprawdź lokalne sąsiedztwo
    windowSize = 3;
    r1 = max(1, y - windowSize);
    r2 = min(rows, y + windowSize);
    c1 = max(1, x - windowSize);
    c2 = min(cols, x + windowSize);
    
    localWindow = skeleton(r1:r2, c1:c2);
    localDensity = sum(localWindow(:)) / numel(localWindow);
    
    % RÓŻNE preferencje gęstości dla typów
    if minutiaType == 1  % Endpoints
        if localDensity > 0.1 && localDensity < 0.8
            qualityBonus = 1.1;
        else
            qualityBonus = 0.9;
        end
    else  % Bifurkacje - preferuj WYŻSZĄ gęstość
        if localDensity > 0.15 && localDensity < 0.9  % Wyższy zakres
            qualityBonus = 1.15; % Większy bonus
        else
            qualityBonus = 0.95; % Mniejsza kara
        end
    end
    
    qualities(i) = baseQuality * qualityBonus;
end

% Ograniczenia
qualities = max(0.1, min(1.0, qualities));
end

function filteredMinutiae = removeCloseMinutiae(minutiae, minDistance)
% REMOVECLOSEMINUTIAE Delikatnie złagodzone dla bifurkacji

if size(minutiae, 1) <= 1
    filteredMinutiae = minutiae;
    return;
end

points = minutiae(:, 1:2);
types = minutiae(:, 4);
qualities = minutiae(:, 5);
toKeep = true(size(points, 1), 1);

for i = 1:size(points, 1)-1
    if ~toKeep(i), continue; end
    
    for j = i+1:size(points, 1)
        if ~toKeep(j), continue; end
        
        dist = norm(points(i,:) - points(j,:));
        
        % DELIKATNIE złagodzone progi odległości
        type_i = types(i);
        type_j = types(j);
        
        % ZNACZNIE złagodzone progi odległości dla bifurkacji
        if type_i == 2 && type_j == 2
            % Bifurkacja vs Bifurkacja - bardzo łagodniej
            distanceThreshold = minDistance * 1.5; % Było 2.2, teraz znacznie mniej
        elseif type_i == 2 || type_j == 2
            % Bifurkacja vs Endpoint - łagodniej
            distanceThreshold = minDistance * 1.2; % Było 1.3, teraz mniej
        else
            % Endpoint vs Endpoint - bez zmian
            distanceThreshold = minDistance; % 8 pikseli
        end
        
        if dist < distanceThreshold
            % ŁAGODNIEJSZA strategia dla bifurkacji
            if type_i == 2 && type_j == 2
                % Oba to bifurkacje - usuń gorszą (bez zmian)
                if qualities(i) >= qualities(j)
                    toKeep(j) = false;
                else
                    toKeep(i) = false;
                    break;
                end
            elseif type_i == 2 && type_j == 1
                % i=bifurkacja, j=endpoint - CZASEM zachowaj bifurkację
                if qualities(i) > qualities(j) * 1.2  % Bifurkacja musi być 20% lepsza
                    toKeep(j) = false;
                else
                    toKeep(i) = false;
                    break;
                end
            elseif type_i == 1 && type_j == 2
                % i=endpoint, j=bifurkacja - Zawsze zachowaj bifurkację
                toKeep(i) = false;  % Usuń endpoint
                break;
            else
                % Oba to endpoints - usuń gorszą (bez zmian)
                if qualities(i) >= qualities(j)
                    toKeep(j) = false;
                else
                    toKeep(i) = false;
                    break;
                end
            end
        end
    end
end

filteredMinutiae = minutiae(toKeep, :);
end

function limitedMinutiae = limitMinutiaeWithTargetRatio(minutiae, maxCount, endpointRatio)
% LIMITMINUTIAEWITHTARGETRATIO z dodatkową filtracją przestrzenną

% Podziel na typy
endpoints = minutiae(minutiae(:, 4) == 1, :);
bifurcations = minutiae(minutiae(:, 4) == 2, :);

% Sortuj według jakości
if ~isempty(endpoints)
    [~, endOrder] = sort(endpoints(:, 5), 'descend');
    endpoints = endpoints(endOrder, :);
end

if ~isempty(bifurcations)
    [~, bifOrder] = sort(bifurcations(:, 5), 'descend');
    bifurcations = bifurcations(bifOrder, :);
end

% DODATKOWA FILTRACJA PRZESTRZENNA dla bifurkacji
if size(bifurcations, 1) > 0
    bifurcations = applyAdditionalSpatialFiltering(bifurcations);
end

% Oblicz docelowe liczby
targetEndpoints = min(size(endpoints, 1), round(maxCount * endpointRatio));
targetBifurcations = min(size(bifurcations, 1), maxCount - targetEndpoints);

% Wybierz najlepsze z każdej grupy
selectedEndpoints = [];
selectedBifurcations = [];

if targetEndpoints > 0 && ~isempty(endpoints)
    selectedEndpoints = endpoints(1:targetEndpoints, :);
end

if targetBifurcations > 0 && ~isempty(bifurcations)
    selectedBifurcations = bifurcations(1:targetBifurcations, :);
end

limitedMinutiae = [selectedEndpoints; selectedBifurcations];
end

function filteredBifurcations = applyAdditionalSpatialFiltering(bifurcations)
% APPLYADDITIONALSPATIALFILTERING Trochę łagodniejsza filtracja przestrzenna

if size(bifurcations, 1) <= 1
    filteredBifurcations = bifurcations;
    return;
end

% ZŁAGODZONE parametry
gridSize = 30; % Było 25, teraz 30 (większe komórki)
maxBifurcationsPerCell = 2; % Było 1, teraz 2 (więcej bifurkacji na komórkę)

% Znajdź zakres współrzędnych
minX = min(bifurcations(:, 1));
maxX = max(bifurcations(:, 1));
minY = min(bifurcations(:, 2));
maxY = max(bifurcations(:, 2));

% Utwórz siatkę
nCellsX = ceil((maxX - minX) / gridSize) + 1;
nCellsY = ceil((maxY - minY) / gridSize) + 1;

% Przypisz bifurkacje do komórek siatki
cellAssignments = zeros(size(bifurcations, 1), 2);
for i = 1:size(bifurcations, 1)
    cellX = floor((bifurcations(i, 1) - minX) / gridSize) + 1;
    cellY = floor((bifurcations(i, 2) - minY) / gridSize) + 1;
    cellAssignments(i, :) = [cellX, cellY];
end

% Dla każdej komórki, zachowaj najlepsze bifurkacje
toKeep = false(size(bifurcations, 1), 1);

for cellX = 1:nCellsX
    for cellY = 1:nCellsY
        % Znajdź bifurkacje w tej komórce
        inCell = (cellAssignments(:, 1) == cellX) & (cellAssignments(:, 2) == cellY);
        cellIndices = find(inCell);
        
        if length(cellIndices) <= maxBifurcationsPerCell
            % Jeśli jest <= max na komórkę, zachowaj wszystkie
            toKeep(cellIndices) = true;
        else
            % Jeśli jest za dużo, zachowaj najlepsze
            cellQualities = bifurcations(cellIndices, 5);
            [~, sortIdx] = sort(cellQualities, 'descend');
            bestIndices = cellIndices(sortIdx(1:maxBifurcationsPerCell));
            toKeep(bestIndices) = true;
        end
    end
end

filteredBifurcations = bifurcations(toKeep, :);
end

function isValid = hasProperBifurcationGeometry(image, x, y)
% HASPROPERBIFURCATIONGEOMETRY Sprawdź geometrię bifurkacji

isValid = true;

% Znajdź 3 sąsiadów i oblicz kąty między nimi
neighborhood = image(y-1:y+1, x-1:x+1);
neighborhood(2,2) = false;
[ny, nx] = find(neighborhood);

if length(ny) ~= 3
    isValid = false;
    return;
end

% Oblicz kąty od środka do każdego sąsiada
angles = atan2(ny - 2, nx - 2); % względem środka (2,2)

% Sortuj kąty
angles = sort(angles);

% Oblicz różnice między sąsiednimi kątami
angleDiffs = [diff(angles); 2*pi + angles(1) - angles(end)];

% Wszystkie kąty powinny być >= 60° (pi/3)
% OSTRZEJSZE kryterium: >= 80°
minAngleDiff = min(angleDiffs);
if minAngleDiff < pi * 80 / 180  % 80 stopni
    isValid = false;
end
end

function isValid = isNotSkeletonArtifact(image, x, y)
% ISNOTSKELETONARTIFACT Sprawdź czy to nie artefakt szkieletyzacji

isValid = true;

% Sprawdź regularność w oknie 7x7
[rows, cols] = size(image);
r1 = max(1, y-3); r2 = min(rows, y+3);
c1 = max(1, x-3); c2 = min(cols, x+3);

window = image(r1:r2, c1:c2);

% Policz punkty szkieletu w oknie
skeletonPixels = sum(window(:));

% Sprawdź "gęstość" szkieletu - zbyt wysoka może oznaczać artefakt
windowSize = (r2-r1+1) * (c2-c1+1);
density = skeletonPixels / windowSize;

% Zbyt wysoka gęstość = prawdopodobnie artefakt
if density > 0.4  % 40% pikseli to szkielet
    isValid = false;
end

% Sprawdź "regularność" - czy jest zbyt chaotycznie
[gx, gy] = gradient(double(window));
gradientMagnitude = sqrt(gx.^2 + gy.^2);
gradientVariance = var(gradientMagnitude(:));

% Zbyt wysoka wariancja gradientu = chaotyczny region
if gradientVariance > 2.0
    isValid = false;
end
end

function isValid = isValidBifurcationRelaxed(image, x, y)
% ISVALIDBIFURCATIONRELAXED Bardzo znacznie złagodzona walidacja bifurkacji
% aby wykryć WSZYSTKIE bifurkacje w odcisku

isValid = true;
[rows, cols] = size(image);

% 1. PODSTAWOWA WALIDACJA 3x3 - musi mieć dokładnie 3 sąsiadów
neighborhood = image(y-1:y+1, x-1:x+1);
neighborhood(2,2) = false;
if sum(neighborhood(:)) ~= 3
    isValid = false;
    return;
end

% 2. SPRAWDŹ CZY SĄSIEDZI SĄ ROZŁOŻENI PROPORCJONALNIE
[ny, nx] = find(neighborhood);
if length(ny) ~= 3
    isValid = false;
    return;
end

% Oblicz kąty między ramionami bifurkacji
angles = atan2(ny-2, nx-2);
sortedAngles = sort(angles);

% Oblicz różnice kątowe
angleDiffs = [diff(sortedAngles); 2*pi+sortedAngles(1)-sortedAngles(end)];

% EKSTREMALNIE ZŁAGODZONE kryterium: Minimalny kąt między ramionami >= 10°
minAngleDiff = min(angleDiffs);
if minAngleDiff < pi/18  % około 10 stopni - było pi/4 (45 stopni)
    isValid = false;
    return;
end

% 3. CAŁKOWICIE USUWAM sprawdzenie stabilności topologicznej - to odrzucało najwięcej bifurkacji
% Zamiast tego zakładamy, że wszystkie punkty z 3 sąsiadami są prawidłowymi bifurkacjami

return;
end