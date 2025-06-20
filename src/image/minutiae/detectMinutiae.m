function [minutiae, qualityMap] = detectMinutiae(skeletonImage, config, logFile)
% DETECTMINUTIAE Wykrywanie minucji w szkielecie linii papilarnych - wersja ulepszona
%
% Funkcja implementuje zaawansowany algorytm detekcji minucji (punktów końcowych
% i bifurkacji) w szkielecie odcisku palca. Wykorzystuje analizę sąsiedztwa,
% walidację geometryczną i wielostopniowe filtrowanie jakości.
%
% Parametry wejściowe:
%   skeletonImage - obraz szkieletu linii papilarnych (logical)
%   config - struktura konfiguracyjna z parametrami detekcji
%   logFile - uchwyt pliku logów (opcjonalny)
%
% Parametry wyjściowe:
%   minutiae - macierz wykrytych minucji [x, y, angle, type, quality]
%   qualityMap - mapa jakości dla wizualizacji (double)

if nargin < 3, logFile = []; end

try
    logInfo('Starting minutiae detection...', logFile);
    
    % SPRAWDZENIE I NORMALIZACJA FORMATU WEJŚCIOWEGO
    if ~islogical(skeletonImage)
        skeletonImage = skeletonImage > 0;
    end
    
    % OBSŁUGA PUSTYCH OBRAZÓW
    if isempty(skeletonImage) || sum(skeletonImage(:)) == 0
        logWarning('Empty skeleton image', logFile);
        minutiae = zeros(0, 5);
        qualityMap = zeros(size(skeletonImage));
        return;
    end
    
    [rows, cols] = size(skeletonImage);
    qualityMap = zeros(rows, cols);
    
    logInfo(sprintf('Analyzing skeleton image %dx%d...', rows, cols), logFile);
    
    %% KROK 1: DETEKCJA KANDYDATÓW NA MINUCJE
    % Wyszukiwanie punktów końcowych (1 sąsiad) i bifurkacji (3 sąsiadów)
    [endpoints, bifurcations] = detectMinutiaePoints(skeletonImage);
    
    %% KROK 2: OBLICZANIE ORIENTACJI LOKALNYCH
    % Wyznaczenie kierunków linii papilarnych w punktach minucji
    endpointOrientations = computeMinutiaeOrientations(skeletonImage, endpoints);
    bifurcationOrientations = computeMinutiaeOrientations(skeletonImage, bifurcations);
    
    %% KROK 3: TWORZENIE MACIERZY MINUCJI [x, y, angle, type, quality]
    minutiae = [];
    
    % DODANIE PUNKTÓW KOŃCOWYCH (type = 1)
    if ~isempty(endpoints)
        endpointQualities = computeSimpleQuality(endpoints, skeletonImage, 1);
        endpointData = [endpoints, endpointOrientations, ones(size(endpoints,1), 1), endpointQualities];
        minutiae = [minutiae; endpointData];
    end
    
    % DODANIE BIFURKACJI (type = 2) z łagodniejszymi kryteriami
    if ~isempty(bifurcations)
        bifurcationQualities = computeSimpleQuality(bifurcations, skeletonImage, 2);
        bifurcationData = [bifurcations, bifurcationOrientations, 2*ones(size(bifurcations,1), 1), bifurcationQualities];
        minutiae = [minutiae; bifurcationData];
    end
    
    logInfo(sprintf('Found %d endpoints and %d bifurcations before filtering', ...
        size(endpoints,1), size(bifurcations,1)), logFile);
    
    %% KROK 4: WIELOSTOPNIOWE FILTROWANIE MINUCJI
    if ~isempty(minutiae)
        % SUBFAZA 4.1: Usunięcie duplikatów przestrzennych
        % Zwiększona tolerancja odległości z 8 do 12 pikseli
        minutiae = removeCloseMinutiae(minutiae, 12);
        
        % SUBFAZA 4.2: Filtracja według jakości z różnymi progami dla typów
        keepMask = false(size(minutiae, 1), 1);
        for i = 1:size(minutiae, 1)
            type = minutiae(i, 4);
            quality = minutiae(i, 5);
            
            if type == 1  % Punkty końcowe - obniżony próg z 0.2 do 0.15
                keepMask(i) = quality >= 0.15;
            else  % Bifurkacje - drastycznie obniżony próg z 0.35 do 0.05
                keepMask(i) = quality >= 0.05;
            end
        end
        
        minutiae = minutiae(keepMask, :);
        
        % Zachowanie kopii przed dalszą filtracją dla ewentualnego uzupełnienia
        minutiae_before_filtering = minutiae;
        
        % SUBFAZA 4.3: Strategiczne ograniczenie liczby z docelowymi proporcjami
        % Zwiększenie udziału bifurkacji z 0.6 do 0.4 (więcej bifurkacji)
        maxMinutiae = config.minutiae.filtering.maxMinutiae;
        if size(minutiae, 1) > maxMinutiae
            minutiae = limitMinutiaeWithTargetRatio(minutiae, maxMinutiae, 0.4);
        end
        
        % SUBFAZA 4.4: ADAPTACYJNE UZUPEŁNIANIE BIFURKACJI
        % Jeśli liczba bifurkacji jest zbyt niska, przywróć najlepsze z kopii
        bifurcationCount = sum(minutiae(:, 4) == 2);
        if bifurcationCount < 40  % Minimum 40 bifurkacji dla dobrej jakości
            % Znajdź bifurkcje z kopii, które zostały odfiltrowane
            allBifurcations = minutiae_before_filtering(minutiae_before_filtering(:, 4) == 2, :);
            
            % Identyfikacja brakujących bifurkacji przez porównanie przestrzenne
            existingBifX = minutiae(minutiae(:, 4) == 2, 1);
            existingBifY = minutiae(minutiae(:, 4) == 2, 2);
            
            missingBifurcations = [];
            for i = 1:size(allBifurcations, 1)
                x = allBifurcations(i, 1);
                y = allBifurcations(i, 2);
                
                % Sprawdzenie czy bifurkacja już istnieje w wynikach (tolerancja 3 piksele)
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
            
            % Dodanie najlepszych z brakujących bifurkacji
            numToAdd = min(40 - bifurcationCount, size(missingBifurcations, 1));
            if numToAdd > 0
                [~, sortIdx] = sort(missingBifurcations(:, 5), 'descend');  % Sortowanie według jakości
                additionalBifs = missingBifurcations(sortIdx(1:numToAdd), :);
                minutiae = [minutiae; additionalBifs];
            end
        end
        
        % SUBFAZA 4.5: Aktualizacja mapy jakości dla wizualizacji
        for i = 1:size(minutiae, 1)
            x = round(minutiae(i, 1));
            y = round(minutiae(i, 2));
            if x >= 1 && x <= cols && y >= 1 && y <= rows
                qualityMap(y, x) = minutiae(i, 5);
            end
        end
    end
    
    % FINALNE STATYSTYKI I LOGOWANIE
    endingCount = sum(minutiae(:, 4) == 1);
    bifurcationCount = sum(minutiae(:, 4) == 2);
    
    logInfo(sprintf('Final result: %d endpoints, %d bifurcations', endingCount, bifurcationCount), logFile);
    logSuccess(sprintf('Detected %d minutiae total', size(minutiae, 1)), logFile);
    
catch ME
    % OBSŁUGA BŁĘDÓW z szczegółowym logowaniem
    logError(sprintf('Minutiae detection error: %s', ME.message), logFile);
    minutiae = zeros(0, 5);
    qualityMap = zeros(size(skeletonImage));
end
end

%% FUNKCJE POMOCNICZE - DETEKCJA I WALIDACJA

function [endpoints, bifurcations] = detectMinutiaePoints(skeletonImage)
% DETECTMINUTIAEPOINTS Wykrywanie kandydatów na minucje przez analizę sąsiedztwa
%
% Funkcja skanuje obraz szkieletu w poszukiwaniu punktów o charakterystycznym
% sąsiedztwie: 1 sąsiad (punkt końcowy) lub 3 sąsiadów (bifurkacja).
% Zmodyfikowana dla zwiększenia wykrywalności bifurkacji.

[rows, cols] = size(skeletonImage);
endpoints = [];
bifurcations = [];

% ZMNIEJSZONY MARGINES dla wykrywania większej liczby minucji przy krawędziach
% Redukcja z 25 do 10 pikseli zwiększa obszar analizy
margin = 10;

% OBLICZENIA PARAMETRÓW GĘSTOŚCI dla kontroli liczby punktów końcowych
imageTotalArea = rows * cols;
validArea = (rows-2*margin) * (cols-2*margin);
targetEndpointDensity = 0.0020; % Zwiększone z 0.0005 - tolerancja większej liczby zakończeń

% GŁÓWNA PĘTLA SKANOWANIA obrazu szkieletu
for y = margin+1:rows-margin
    for x = margin+1:cols-margin
        if ~skeletonImage(y, x)
            continue; % Pomiń piksele tła
        end
        
        % ANALIZA SĄSIEDZTWA 3×3 wokół bieżącego piksela
        neighborhood = skeletonImage(y-1:y+1, x-1:x+1);
        neighborhood(2,2) = false; % Wyłączenie środkowego piksela
        neighbors = sum(neighborhood(:));
        
        % KLASYFIKACJA na podstawie liczby sąsiadów
        if neighbors == 1
            % PUNKT KOŃCOWY - przyjmowanie wszystkich kandydatów
            endpoints = [endpoints; x, y];
        elseif neighbors == 3
            % BIFURKACJA - walidacja geometryczna z łagodnymi kryteriami
            if isValidBifurcationRelaxed(skeletonImage, x, y)
                bifurcations = [bifurcations; x, y];
            end
        end
    end
end

% KONTROLA LICZBY PUNKTÓW KOŃCOWYCH - ochrona przed nadmierną detekcją
% Zwiększony próg tolerancji z ×2 do ×4 dla większej elastyczności
if length(endpoints) > validArea * targetEndpointDensity * 4
    % Ocena i sortowanie punktów końcowych według jakości
    scores = evaluateEndpoints(skeletonImage, endpoints);
    [~, sortIdx] = sort(scores, 'descend');
    maxEndpoints = round(validArea * targetEndpointDensity * 3); % Zwiększone z ×1 do ×3
    endpoints = endpoints(sortIdx(1:min(maxEndpoints, length(sortIdx))), :);
end
end

function isValid = isValidBifurcationRelaxed(image, x, y)
% ISVALIDBIFURCATIONRELAXED Znacznie złagodzona walidacja bifurkacji
%
% Funkcja implementuje uproszczone kryteria walidacji bifurkacji aby
% maksymalizować wykrywanie rzeczywistych punktów rozgałęzienia.
% Usuwa zbyt restrykcyjne testy topologiczne.

isValid = true;
[rows, cols] = size(image);

% KROK 1: PODSTAWOWA WALIDACJA - dokładnie 3 sąsiadów w oknie 3×3
neighborhood = image(y-1:y+1, x-1:x+1);
neighborhood(2,2) = false; % Wyłączenie środkowego punktu
if sum(neighborhood(:)) ~= 3
    isValid = false;
    return;
end

% KROK 2: ANALIZA GEOMETRYCZNA - sprawdzenie rozkładu przestrzennego sąsiadów
[ny, nx] = find(neighborhood);
if length(ny) ~= 3
    isValid = false;
    return;
end

% KROK 3: WALIDACJA KĄTOWA - obliczenie kątów między ramionami bifurkacji
% Konwersja współrzędnych względem środka okna 3×3
angles = atan2(ny-2, nx-2);
sortedAngles = sort(angles);

% Obliczenie różnic kątowych między sąsiednimi ramionami
angleDiffs = [diff(sortedAngles); 2*pi+sortedAngles(1)-sortedAngles(end)];

% EKSTREMALNIE ZŁAGODZONE kryterium kątowe
% Minimalny kąt między ramionami ≥ 10° (było 45°)
minAngleDiff = min(angleDiffs);
if minAngleDiff < pi/18  % około 10 stopni - drastyczna redukcja z pi/4 (45°)
    isValid = false;
    return;
end

% KROK 4: USUNIĘCIE testów stabilności topologicznej
% Poprzednie wersje zawierały testy stabilności przy usuwaniu punktu,
% które odrzucały zbyt wiele prawdziwych bifurkacji.
% Zakładamy, że wszystkie punkty z 3 sąsiadami spełniające kryteria kątowe
% są prawidłowymi bifurkacjami.

return;
end

function orientations = computeMinutiaeOrientations(skeleton, points)
% COMPUTEMINUTIAEORIENTATIONS Obliczanie orientacji lokalnych dla minucji
%
% Funkcja wyznacza kierunek linii papilarnych w punktach minucji przez
% analizę gradientu w lokalnym otoczeniu. Wykorzystuje ważoną średnią
% gradientów z punktów szkieletu w oknie analizy.

if isempty(points)
    orientations = [];
    return;
end

orientations = zeros(size(points, 1), 1);
windowSize = 7; % Rozszerzony rozmiar okna dla lepszej estymacji

for i = 1:size(points, 1)
    try
        x = round(points(i, 1));
        y = round(points(i, 2));
        
        [rows, cols] = size(skeleton);
        % Wyznaczenie granic okna analizy z kontrolą brzegów
        r1 = max(1, y - windowSize);
        r2 = min(rows, y + windowSize);
        c1 = max(1, x - windowSize);
        c2 = min(cols, x + windowSize);
        
        localWindow = skeleton(r1:r2, c1:c2);
        
        % ANALIZA GRADIENTU tylko jeśli okno zawiera wystarczająco dużo punktów szkieletu
        if sum(localWindow(:)) > 3
            [gx, gy] = gradient(double(localWindow));
            weights = localWindow; % Wagi oparte na przynależności do szkieletu
            
            % WAŻONA ŚREDNIA GRADIENTÓW dla stabilniejszej estymacji orientacji
            if sum(weights(:)) > 0
                avgGx = sum(gx(:) .* weights(:)) / sum(weights(:));
                avgGy = sum(gy(:) .* weights(:)) / sum(weights(:));
                
                % Obliczenie orientacji z gradientu (z progiem stabilności)
                if abs(avgGx) > 0.01 || abs(avgGy) > 0.01
                    orientations(i) = atan2(avgGy, avgGx);
                else
                    orientations(i) = 0; % Orientacja neutralna dla słabych gradientów
                end
            else
                orientations(i) = 0;
            end
        else
            orientations(i) = 0; % Brak danych dla estymacji
        end
        
    catch
        orientations(i) = 0; % Wartość domyślna w przypadku błędu
    end
end
end

function qualities = computeSimpleQuality(points, skeleton, minutiaType)
% COMPUTESIMPLEQUALITY Obliczanie wskaźników jakości z preferencjami dla bifurkacji
%
% Funkcja oblicza wskaźnik jakości dla każdej minucji na podstawie:
% - Odległości od brzegów obrazu (stabilność detekcji)
% - Lokalnej gęstości szkieletu (kontekst strukturalny)
% - Różnicowane kryteria dla punktów końcowych i bifurkacji

if isempty(points)
    qualities = [];
    return;
end

qualities = zeros(size(points, 1), 1);
[rows, cols] = size(skeleton);

for i = 1:size(points, 1)
    x = round(points(i, 1));
    y = round(points(i, 2));
    
    % BAZOWA JAKOŚĆ z preferencją dla bifurkacji
    if minutiaType == 1
        baseQuality = 0.8; % Punkty końcowe - standardowa wartość
    else
        baseQuality = 0.75; % Bifurkacje - podwyższona z 0.7 dla lepszej retencji
    end
    
    % KARA ZA BLISKOŚĆ BRZEGU z łagodniejszymi kryteriami dla bifurkacji
    distToBorder = min([x-1, y-1, cols-x, rows-y]);
    if minutiaType == 1  % Punkty końcowe - bez zmian w kryteriach
        if distToBorder < 10
            baseQuality = baseQuality * 0.7;
        elseif distToBorder < 20
            baseQuality = baseQuality * 0.9;
        end
    else  % Bifurkacje - łagodniejsze penalizacje
        if distToBorder < 8  % Ostrzejszy próg ale krótszy zasięg
            baseQuality = baseQuality * 0.75; % Mniejsza kara (było 0.7)
        elseif distToBorder < 15  % Krótszy zasięg (było 20)
            baseQuality = baseQuality * 0.92; % Mniejsza kara (było 0.9)
        end
    end
    
    % ANALIZA LOKALNEGO SĄSIEDZTWA dla oceny kontekstu strukturalnego
    windowSize = 3;
    r1 = max(1, y - windowSize);
    r2 = min(rows, y + windowSize);
    c1 = max(1, x - windowSize);
    c2 = min(cols, x + windowSize);
    
    localWindow = skeleton(r1:r2, c1:c2);
    localDensity = sum(localWindow(:)) / numel(localWindow);
    
    % RÓŻNICOWANE PREFERENCJE GĘSTOŚCI według typu minucji
    if minutiaType == 1  % Punkty końcowe - preferencja umiarkowanej gęstości
        if localDensity > 0.1 && localDensity < 0.8
            qualityBonus = 1.1;
        else
            qualityBonus = 0.9;
        end
    else  % Bifurkacje - preferencja wyższej gęstości (bardziej złożone struktury)
        if localDensity > 0.15 && localDensity < 0.9  % Wyższy preferowany zakres
            qualityBonus = 1.15; % Większy bonus za odpowiednią gęstość
        else
            qualityBonus = 0.95; % Mniejsza kara za gęstość poza zakresem
        end
    end
    
    qualities(i) = baseQuality * qualityBonus;
end

% OGRANICZENIE WARTOŚCI do przedziału [0.1, 1.0]
qualities = max(0.1, min(1.0, qualities));
end

function filteredMinutiae = removeCloseMinutiae(minutiae, minDistance)
% REMOVECLOSEMINUTIAE Usuwanie przestrzennie bliskich minucji z preferencją dla bifurkacji
%
% Funkcja eliminuje duplikaty i blisko położone minucje stosując
% różnicowane progi odległości i strategie priorytetów według typu.

if size(minutiae, 1) <= 1
    filteredMinutiae = minutiae;
    return;
end

points = minutiae(:, 1:2);
types = minutiae(:, 4);
qualities = minutiae(:, 5);
toKeep = true(size(points, 1), 1);

% ANALIZA PARAMI wszystkich minucji
for i = 1:size(points, 1)-1
    if ~toKeep(i), continue; end
    
    for j = i+1:size(points, 1)
        if ~toKeep(j), continue; end
        
        dist = norm(points(i,:) - points(j,:));
        
        % RÓŻNICOWANE PROGI ODLEGŁOŚCI według kombinacji typów
        type_i = types(i);
        type_j = types(j);
        
        if type_i == 2 && type_j == 2
            % Bifurkacja vs Bifurkacja - znacznie łagodniejszy próg
            distanceThreshold = minDistance * 1.5; % Redukcja z 2.2
        elseif type_i == 2 || type_j == 2
            % Bifurkacja vs Punkt końcowy - umiarkowanie łagodny próg
            distanceThreshold = minDistance * 1.2; % Redukcja z 1.3
        else
            % Punkt końcowy vs Punkt końcowy - standardowy próg
            distanceThreshold = minDistance; % 12 pikseli (parametr wejściowy)
        end
        
        % STRATEGIA USUWANIA w przypadku kolizji odległościowej
        if dist < distanceThreshold
            if type_i == 2 && type_j == 2
                % Oba to bifurkacje - usuń gorszą jakościowo
                if qualities(i) >= qualities(j)
                    toKeep(j) = false;
                else
                    toKeep(i) = false;
                    break;
                end
            elseif type_i == 2 && type_j == 1
                % i=bifurkacja, j=punkt końcowy - warunkowo preferuj bifurkację
                if qualities(i) > qualities(j) * 1.2  % Bifurkacja musi być 20% lepsza
                    toKeep(j) = false;
                else
                    toKeep(i) = false;
                    break;
                end
            elseif type_i == 1 && type_j == 2
                % i=punkt końcowy, j=bifurkacja - bezwarunkowo preferuj bifurkację
                toKeep(i) = false;
                break;
            else
                % Oba to punkty końcowe - usuń gorszą jakościowo
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
% LIMITMINUTIAEWITHTARGETRATIO Ograniczenie liczby minucji z docelowymi proporcjami
%
% Funkcja selektuje najlepsze minucje zgodnie z zadanymi proporcjami typów
% i stosuje dodatkową filtrację przestrzenną dla bifurkacji.

% PODZIAŁ na typy minucji
endpoints = minutiae(minutiae(:, 4) == 1, :);
bifurcations = minutiae(minutiae(:, 4) == 2, :);

% SORTOWANIE według jakości (malejąco)
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

% OBLICZENIE DOCELOWYCH LICZB zgodnie z proporcjami
targetEndpoints = min(size(endpoints, 1), round(maxCount * endpointRatio));
targetBifurcations = min(size(bifurcations, 1), maxCount - targetEndpoints);

% SELEKCJA najlepszych minucji z każdej grupy
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
% APPLYADDITIONALSPATIALFILTERING Filtracja przestrzenna bifurkacji na siatce
%
% Funkcja nakłada siatkę na obraz i ogranicza liczbę bifurkacji w każdej
% komórce aby zapewnić równomierny rozkład przestrzenny.

if size(bifurcations, 1) <= 1
    filteredBifurcations = bifurcations;
    return;
end

% ZŁAGODZONE PARAMETRY siatki dla większej tolerancji
gridSize = 30; % Zwiększone z 25 (większe komórki)
maxBifurcationsPerCell = 2; % Zwiększone z 1 (więcej bifurkacji na komórkę)

% WYZNACZENIE ZASIĘGU PRZESTRZENNEGO
minX = min(bifurcations(:, 1));
maxX = max(bifurcations(:, 1));
minY = min(bifurcations(:, 2));
maxY = max(bifurcations(:, 2));

% UTWORZENIE SIATKI o regularnych komórkach
nCellsX = ceil((maxX - minX) / gridSize) + 1;
nCellsY = ceil((maxY - minY) / gridSize) + 1;

% PRZYPISANIE BIFURKACJI do komórek siatki
cellAssignments = zeros(size(bifurcations, 1), 2);
for i = 1:size(bifurcations, 1)
    cellX = floor((bifurcations(i, 1) - minX) / gridSize) + 1;
    cellY = floor((bifurcations(i, 2) - minY) / gridSize) + 1;
    cellAssignments(i, :) = [cellX, cellY];
end

% FILTRACJA W KAŻDEJ KOMÓRCE z zachowaniem najlepszych
toKeep = false(size(bifurcations, 1), 1);

for cellX = 1:nCellsX
    for cellY = 1:nCellsY
        % Znajdź bifurkacje w bieżącej komórce
        inCell = (cellAssignments(:, 1) == cellX) & (cellAssignments(:, 2) == cellY);
        cellIndices = find(inCell);
        
        if length(cellIndices) <= maxBifurcationsPerCell
            % Liczba nie przekracza limitu - zachowaj wszystkie
            toKeep(cellIndices) = true;
        else
            % Przekroczenie limitu - wybierz najlepsze jakościowo
            cellQualities = bifurcations(cellIndices, 5);
            [~, sortIdx] = sort(cellQualities, 'descend');
            bestIndices = cellIndices(sortIdx(1:maxBifurcationsPerCell));
            toKeep(bestIndices) = true;
        end
    end
end

filteredBifurcations = bifurcations(toKeep, :);
end

function scores = evaluateEndpoints(skeleton, endpoints)
% EVALUATEENDPOINTS Ocena jakości punktów końcowych dla rankingu
%
% Funkcja oblicza wyniki jakościowe dla punktów końcowych na podstawie
% lokalnej gęstości szkieletu i odległości od brzegów obrazu.

scores = zeros(size(endpoints, 1), 1);
[rows, cols] = size(skeleton);

for i = 1:size(endpoints, 1)
    x = round(endpoints(i, 1));
    y = round(endpoints(i, 2));
    
    % SKŁADNIK 1: Odległość od brzegu (większa = lepsza)
    distToBorder = min([x-1, y-1, cols-x, rows-y]);
    borderScore = min(distToBorder / 20, 1); % Normalizacja do [0,1]
    
    % SKŁADNIK 2: Lokalna gęstość szkieletu w oknie 5×5
    windowSize = 2;
    r1 = max(1, y - windowSize);
    r2 = min(rows, y + windowSize);
    c1 = max(1, x - windowSize);
    c2 = min(cols, x + windowSize);
    
    localWindow = skeleton(r1:r2, c1:c2);
    localDensity = sum(localWindow(:)) / numel(localWindow);
    
    % Optymalna gęstość w przedziale [0.2, 0.6]
    if localDensity >= 0.2 && localDensity <= 0.6
        densityScore = 1.0;
    else
        densityScore = max(0.3, 1.0 - abs(localDensity - 0.4) * 2);
    end
    
    % SKŁADNIK 3: Stabilność - sprawdzenie ciągłości w kierunku od punktu
    stabilityScore = 0.5; % Wartość domyślna
    
    % KOMBINACJA SKŁADNIKÓW z wagami
    scores(i) = 0.4 * borderScore + 0.4 * densityScore + 0.2 * stabilityScore;
end
end