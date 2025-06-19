function [minutiae, qualityMap] = detectMinutiae(skeletonImage, config, logFile)
% DETECTMINUTIAE Wykrywa minucje w obrazie szkieletu odcisku palca - wersja ulepszona
%
% Funkcja implementuje zaawansowany algorytm detekcji minucji z wielopoziomową
% walidacją i mechanizmami fallback. Wykrywa endings i bifurcations w szkielecie
% linii papilarnych z kontrolą jakości i filtracją artefaktów.
%
% Parametry wejściowe:
%   skeletonImage - obraz szkieletu linii papilarnych (logical lub binarny)
%   config - struktura konfiguracyjna z parametrami detekcji
%   logFile - uchwyt do pliku logów (opcjonalny)
%
% Parametry wyjściowe:
%   minutiae - macierz wykrytych minucji [x, y, angle, type, quality]
%             gdzie: type=1 (ending), type=2 (bifurcation)
%   qualityMap - mapa jakości minucji (macierz 2D)
%
% Algorytm:
%   1. Detekcja kandydatów na minucje (analiza sąsiedztwa 3x3)
%   2. Wielopoziomowa walidacja bifurcacji (geometria, topologia, stabilność)
%   3. Obliczanie orientacji i jakości dla każdej minucji
%   4. Filtracja przestrzenna i jakościowa z mechanizmami fallback
%
% Przykład użycia:
%   [minutiae, qualityMap] = detectMinutiae(skeletonImg, config, logFile);

if nargin < 3, logFile = []; end

try
    logInfo('Starting minutiae detection...', logFile);
    
    % Konwersja do formatu logicznego jeśli potrzebna
    if ~islogical(skeletonImage)
        skeletonImage = skeletonImage > 0;
    end
    
    % Sprawdzenie czy obraz nie jest pusty
    if isempty(skeletonImage) || sum(skeletonImage(:)) == 0
        logWarning('Empty skeleton image', logFile);
        minutiae = zeros(0, 5);
        qualityMap = zeros(size(skeletonImage));
        return;
    end
    
    [rows, cols] = size(skeletonImage);
    qualityMap = zeros(rows, cols);
    
    logInfo(sprintf('Analyzing skeleton image %dx%d...', rows, cols), logFile);
    
    % ETAP 1: DETEKCJA KANDYDATÓW NA MINUCJE
    % Identyfikuje potencjalne endings i bifurcations na podstawie liczby sąsiadów
    [endpoints, bifurcations] = detectMinutiaePoints(skeletonImage);
    
    % ETAP 2: OBLICZANIE ORIENTACJI
    % Szacuje kierunek linii papilarnych w okolicy każdej minucji
    endpointOrientations = computeMinutiaeOrientations(skeletonImage, endpoints);
    bifurcationOrientations = computeMinutiaeOrientations(skeletonImage, bifurcations);
    
    % ETAP 3: FORMATOWANIE DANYCH MINUCJI
    % Łączy współrzędne, orientacje, typy i jakość w jednolitą strukturę
    minutiae = [];
    
    % Dodaj endings (typ = 1)
    if ~isempty(endpoints)
        endpointQualities = computeSimpleQuality(endpoints, skeletonImage, 1);
        endpointData = [endpoints, endpointOrientations, ones(size(endpoints,1), 1), endpointQualities];
        minutiae = [minutiae; endpointData];
    end
    
    % Dodaj bifurcations (typ = 2) z łagodniejszymi kryteriami jakości
    if ~isempty(bifurcations)
        bifurcationQualities = computeSimpleQuality(bifurcations, skeletonImage, 2);
        bifurcationData = [bifurcations, bifurcationOrientations, 2*ones(size(bifurcations,1), 1), bifurcationQualities];
        minutiae = [minutiae; bifurcationData];
    end
    
    logInfo(sprintf('Found %d endpoints and %d bifurcations before filtering', ...
        size(endpoints,1), size(bifurcations,1)), logFile);
    
    % ETAP 4: FILTRACJA I OPTYMALIZACJA
    if ~isempty(minutiae)
        % Usuń duplikaty i bliskie minucje (zwiększony próg dla bifurcacji)
        minutiae = removeCloseMinutiae(minutiae, 12);
        
        % Filtracja jakościowa z różnymi progami dla typów minucji
        keepMask = false(size(minutiae, 1), 1);
        for i = 1:size(minutiae, 1)
            type = minutiae(i, 4);
            quality = minutiae(i, 5);
            
            if type == 1  % Endings - standardowy próg
                keepMask(i) = quality >= 0.2;
            else  % Bifurcations - łagodniejszy próg (było 0.4, teraz 0.35)
                keepMask(i) = quality >= 0.35;
            end
        end
        
        minutiae = minutiae(keepMask, :);
        
        % Strategiczne ograniczenie liczby z docelowymi proporcjami
        maxMinutiae = config.minutiae.filtering.maxMinutiae;
        if size(minutiae, 1) > maxMinutiae
            minutiae = limitMinutiaeWithTargetRatio(minutiae, maxMinutiae, 0.6); % 60% endpoints
        end
        
        % Aktualizacja mapy jakości
        for i = 1:size(minutiae, 1)
            x = round(minutiae(i, 1));
            y = round(minutiae(i, 2));
            if x >= 1 && x <= cols && y >= 1 && y <= rows
                qualityMap(y, x) = minutiae(i, 5);
            end
        end
    end
    
    % ETAP 5: STATYSTYKI KOŃCOWE
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

%% FUNKCJE POMOCNICZE DETEKCJI

function [endpoints, bifurcations] = detectMinutiaePoints(skeletonImage)
% DETECTMINUTIAEPOINTS Wykrywa kandydatów na minucje z ulepszoną detekcją bifurcacji
%
% Funkcja analizuje każdy piksel szkieletu i klasyfikuje go jako endpoint
% (1 sąsiad) lub bifurcation (3 sąsiadów) na podstawie analizy sąsiedztwa 3x3.
% Bifurcations podlegają dodatkowej walidacji geometrycznej i topologicznej.
%
% Parametry wejściowe:
%   skeletonImage - obraz szkieletu (logical)
%
% Parametry wyjściowe:
%   endpoints - macierz współrzędnych endings [x, y]
%   bifurcations - macierz współrzędnych bifurcations [x, y]

[rows, cols] = size(skeletonImage);
endpoints = [];
bifurcations = [];
margin = 20; % Zwiększony margines dla stabilniejszej detekcji bifurcacji

% Przeskanuj obraz z pominięciem marginesów
for y = margin+1:rows-margin
    for x = margin+1:cols-margin
        if ~skeletonImage(y, x)
            continue; % Pomiń piksele tła
        end
        
        % Analiza sąsiedztwa 3x3
        neighborhood = skeletonImage(y-1:y+1, x-1:x+1);
        neighborhood(2,2) = false; % Wyłącz środkowy punkt
        neighbors = sum(neighborhood(:));
        
        if neighbors == 1
            % Ending - punkt z jednym sąsiadem
            endpoints = [endpoints; x, y];
        elseif neighbors == 3
            % Potencjalna bifurcation - wymaga dodatkowej walidacji
            if isValidBifurcationImproved(skeletonImage, x, y)
                bifurcations = [bifurcations; x, y];
            end
        end
    end
end
end

function isValid = isValidBifurcationImproved(image, x, y)
% ISVALIDBIFURCATIONIMPROVED Wielopoziomowa walidacja bifurcacji
%
% Funkcja implementuje zaawansowany algorytm walidacji bifurkacji obejmujący:
% - Walidację podstawową (dokładnie 3 sąsiadów w odpowiednich pozycjach)
% - Analizę kontekstu w większym oknie (5x5)
% - Sprawdzenie ciągłości linii papilarnych
% - Test stabilności topologicznej
%
% Parametry wejściowe:
%   image - obraz szkieletu
%   x, y - współrzędne kandydata na bifurcję
%
% Parametry wyjściowe:
%   isValid - true jeśli punkt jest prawdziwą bifurcacją

isValid = false;

% TEST 1: Podstawowa walidacja 3x3
neighborhood = image(y-1:y+1, x-1:x+1);
neighborhood(2,2) = false;

% Musi mieć dokładnie 3 sąsiadów
if sum(neighborhood(:)) ~= 3
    return;
end

% TEST 2: Sprawdź pozycje sąsiadów
[ny, nx] = find(neighborhood);

% Sąsiedzi nie mogą być w jednej linii (artefakt szkieletyzacji)
if length(unique(ny)) == 1 || length(unique(nx)) == 1
    return;
end

% TEST 3: Walidacja w większym oknie (5x5)
if ~validateBifurcationInLargerWindow(image, x, y)
    return;
end

% TEST 4: Sprawdź ciągłość linii papilarnych
if ~validateRidgeContinuity(image, x, y)
    return;
end

% TEST 5: Test stabilności topologicznej
if ~validateTopologicalStability(image, x, y)
    return;
end

isValid = true;
end

function isValid = validateBifurcationInLargerWindow(image, x, y)
% VALIDATEBIFURCATIONINLARGERWINDOW Sprawdza kontekst bifurcacji w oknie 5x5
%
% Funkcja analizuje rozkład pikseli szkieletu w większym oknie wokół kandydata
% na bifurcację, sprawdzając czy lokalna topologia jest zgodna z prawdziwą bifurcacją.

isValid = true;
[rows, cols] = size(image);

% Określ granice okna 5x5
r1 = max(1, y-2); r2 = min(rows, y+2);
c1 = max(1, x-2); c2 = min(cols, x+2);

window = image(r1:r2, c1:c2);
centerY = y - r1 + 1;
centerX = x - c1 + 1;

% Policz sąsiadów w różnych promieniach
neighbors_r1 = countNeighborsInRadius(window, centerX, centerY, 1);
neighbors_r2 = countNeighborsInRadius(window, centerX, centerY, 2);

% Kryteria dla prawdziwej bifurcacji:
% - Dokładnie 3 sąsiadów w promieniu 1
% - Nie więcej niż 8 sąsiadów w promieniu 2 (unika zbyt gęstych regionów)
if neighbors_r1 ~= 3 || neighbors_r2 > 8
    isValid = false;
end
end

function count = countNeighborsInRadius(window, centerX, centerY, radius)
% COUNTNEIGHBORSINRADIUS Liczy piksele szkieletu w określonym promieniu
%
% Funkcja pomocnicza zliczająca liczbę pikseli szkieletu w okręgu o zadanym
% promieniu wokół środkowego punktu, wykluczając sam środek.

count = 0;
[rows, cols] = size(window);

for dy = -radius:radius
    for dx = -radius:radius
        if dx == 0 && dy == 0
            continue; % Pomiń środek
        end
        
        y = centerY + dy;
        x = centerX + dx;
        
        % Sprawdź czy punkt mieści się w oknie i czy należy do szkieletu
        if x >= 1 && x <= cols && y >= 1 && y <= rows
            if window(y, x) == 1
                count = count + 1;
            end
        end
    end
end
end

function isValid = validateRidgeContinuity(image, x, y)
% VALIDATERIDGECONTINUITY Sprawdza ciągłość linii papilarnych w bifurcacji
%
% Funkcja weryfikuje czy trzy gałęzie bifurkacji rzeczywiście reprezentują
% ciągłe linie papilarne poprzez analizę połączeń każdego z trzech sąsiadów.

isValid = true;
[rows, cols] = size(image);

% Znajdź 3 sąsiadów bifurkacji
neighborhood = image(y-1:y+1, x-1:x+1);
neighborhood(2,2) = false;
[ny, nx] = find(neighborhood);

% Konwertuj na współrzędne globalne
globalNeighbors = [nx + x - 2, ny + y - 2];

% Dla każdego sąsiada sprawdź jakość jego połączeń
validNeighbors = 0;
for i = 1:size(globalNeighbors, 1)
    nx = globalNeighbors(i, 1);
    ny = globalNeighbors(i, 2);
    
    if nx > 1 && nx < cols && ny > 1 && ny < rows
        % Sprawdź sąsiedztwo tego sąsiada
        nNeighborhood = image(ny-1:ny+1, nx-1:nx+1);
        nNeighborhood(2,2) = false;
        nConnections = sum(nNeighborhood(:));
        
        % Sąsiad bifurcacji powinien mieć 1-3 połączenia (normalny fragment linii)
        if nConnections >= 1 && nConnections <= 3
            validNeighbors = validNeighbors + 1;
        end
    end
end

% Przynajmniej 2 z 3 sąsiadów musi reprezentować poprawne linie papilarne
if validNeighbors < 2
    isValid = false;
end
end

function isValid = validateTopologicalStability(image, x, y)
% VALIDATETOPOLOGICALSTABILITY Test stabilności topologicznej bifurcacji
%
% Funkcja sprawdza czy usunięcie kandydata na bifurcję powoduje rozsądną
% zmianę w topologii szkieletu. Nadmierna fragmentacja może wskazywać
% na artefakt szkieletyzacji a nie prawdziwą bifurcację.

isValid = true;

% Utwórz kopię obrazu bez testowanego punktu
testImage = image;
testImage(y, x) = 0;

% Analizuj okno 7x7 wokół punktu
[rows, cols] = size(image);
r1 = max(1, y-3); r2 = min(rows, y+3);
c1 = max(1, x-3); c2 = min(cols, x+3);

originalWindow = image(r1:r2, c1:c2);
testWindow = testImage(r1:r2, c1:c2);

% Policz składowe spójne przed i po usunięciu punktu
ccOriginal = bwconncomp(originalWindow, 8);
ccTest = bwconncomp(testWindow, 8);

% Jeśli usunięcie punktu znacząco zwiększa fragmentację,
% może to oznaczać że punkt nie jest prawdziwą bifurcacją
if ccTest.NumObjects > ccOriginal.NumObjects + 1
    isValid = false;
end

% Dodatkowy test: sprawdź stopień fragmentacji
totalPixelsOriginal = sum(originalWindow(:));
if totalPixelsOriginal > 0
    fragmentationRatio = ccTest.NumObjects / totalPixelsOriginal;
    % Jeśli fragmentacja przekracza 30%, prawdopodobnie to artefakt
    if fragmentationRatio > 0.3
        isValid = false;
    end
end
end

function orientations = computeMinutiaeOrientations(skeleton, points)
% COMPUTEMINUTIAEORIENTATIONS Oblicza orientacje minucji metodą gradientową
%
% Funkcja szacuje kierunek linii papilarnych w okolicy każdej minucji poprzez
% analizę gradientów w lokalnym oknie. Używa średniego ważonego gradientu
% z wagami pochodzącymi z pikseli szkieletu.
%
% Parametry wejściowe:
%   skeleton - obraz szkieletu linii papilarnych
%   points - macierz współrzędnych minucji [x, y]
%
% Parametry wyjściowe:
%   orientations - wektor orientacji w radianach

if isempty(points)
    orientations = [];
    return;
end

orientations = zeros(size(points, 1), 1);
windowSize = 7; % Rozmiar okna analizy

for i = 1:size(points, 1)
    try
        x = round(points(i, 1));
        y = round(points(i, 2));
        
        [rows, cols] = size(skeleton);
        % Określ granice lokalnego okna
        r1 = max(1, y - windowSize);
        r2 = min(rows, y + windowSize);
        c1 = max(1, x - windowSize);
        c2 = min(cols, x + windowSize);
        
        localWindow = skeleton(r1:r2, c1:c2);
        
        % Oblicz orientację tylko jeśli okno zawiera wystarczająco pikseli szkieletu
        if sum(localWindow(:)) > 3
            % Oblicz gradienty w lokalnym oknie
            [gx, gy] = gradient(double(localWindow));
            weights = localWindow; % Wagi z pikseli szkieletu
            
            if sum(weights(:)) > 0
                % Średnia ważona gradientów
                avgGx = sum(gx(:) .* weights(:)) / sum(weights(:));
                avgGy = sum(gy(:) .* weights(:)) / sum(weights(:));
                
                % Oblicz orientację z gradientów
                if abs(avgGx) > 0.01 || abs(avgGy) > 0.01
                    orientations(i) = atan2(avgGy, avgGx);
                else
                    orientations(i) = 0; % Gradient zbyt mały
                end
            else
                orientations(i) = 0;
            end
        else
            orientations(i) = 0; % Za mało danych w oknie
        end
        
    catch
        orientations(i) = 0; % Fallback w przypadku błędu
    end
end
end

function qualities = computeSimpleQuality(points, skeleton, minutiaType)
% COMPUTESIMPLEQUALITY Oblicza jakość minucji z różnymi kryteriami dla typów
%
% Funkcja ocenia jakość każdej minucji na podstawie pozycji względem brzegów,
% lokalnej gęstości szkieletu i typu minucji. Bifurcations otrzymują
% łagodniejsze kryteria ze względu na większą trudność ich detekcji.
%
% Parametry wejściowe:
%   points - macierz współrzędnych minucji [x, y]
%   skeleton - obraz szkieletu
%   minutiaType - typ minucji (1=ending, 2=bifurcation)
%
% Parametry wyjściowe:
%   qualities - wektor jakości w zakresie [0.1, 1.0]

if isempty(points)
    qualities = [];
    return;
end

qualities = zeros(size(points, 1), 1);
[rows, cols] = size(skeleton);

for i = 1:size(points, 1)
    x = round(points(i, 1));
    y = round(points(i, 2));
    
    % BAZOWA JAKOŚĆ - różna dla typów minucji
    if minutiaType == 1
        baseQuality = 0.8; % Endings - standardowa bazowa jakość
    else
        baseQuality = 0.75; % Bifurcations - nieco wyższa (było 0.7)
    end
    
    % KARA ZA BLISKOŚĆ BRZEGU - łagodniejsza dla bifurcacji
    distToBorder = min([x-1, y-1, cols-x, rows-y]);
    if minutiaType == 1  % Endings - standardowe kryteria
        if distToBorder < 10
            baseQuality = baseQuality * 0.7;  % Mocna kara za brzeg
        elseif distToBorder < 20
            baseQuality = baseQuality * 0.9;  % Lekka kara za bliskość brzegu
        end
    else  % Bifurcations - łagodniejsze kryteria
        if distToBorder < 8   % Zmniejszony próg krytyczny (było 10)
            baseQuality = baseQuality * 0.75; % Łagodniejsza kara (było 0.7)
        elseif distToBorder < 15  % Zmniejszony próg ostrzeżenia (było 20)
            baseQuality = baseQuality * 0.92; % Łagodniejsza kara (było 0.9)
        end
    end
    
    % ANALIZA LOKALNEGO SĄSIEDZTWA
    windowSize = 3;
    r1 = max(1, y - windowSize);
    r2 = min(rows, y + windowSize);
    c1 = max(1, x - windowSize);
    c2 = min(cols, x + windowSize);
    
    localWindow = skeleton(r1:r2, c1:c2);
    localDensity = sum(localWindow(:)) / numel(localWindow);
    
    % RÓŻNE PREFERENCJE GĘSTOŚCI dla typów minucji
    if minutiaType == 1  % Endings - preferują umiarkowaną gęstość
        if localDensity > 0.1 && localDensity < 0.8
            qualityBonus = 1.1;  % Bonus za optymalną gęstość
        else
            qualityBonus = 0.9;  % Kara za zbyt niską/wysoką gęstość
        end
    else  % Bifurcations - preferują wyższą gęstość
        if localDensity > 0.15 && localDensity < 0.9  % Wyższy preferowany zakres
            qualityBonus = 1.15; % Większy bonus
        else
            qualityBonus = 0.95; % Mniejsza kara
        end
    end
    
    % FINALNA JAKOŚĆ
    qualities(i) = baseQuality * qualityBonus;
end

% Ograniczenia jakości do rozsądnego zakresu
qualities = max(0.1, min(1.0, qualities));
end

function filteredMinutiae = removeCloseMinutiae(minutiae, minDistance)
% REMOVECLOSEMINUTIAE Usuwa bliskie minucje z preferencjami dla bifurcacji
%
% Funkcja eliminuje minucje znajdujące się zbyt blisko siebie, używając
% różnych progów odległości i strategii wyboru w zależności od typów minucji.
% Bifurcations otrzymują łagodniejsze traktowanie ze względu na rzadkość.

if size(minutiae, 1) <= 1
    filteredMinutiae = minutiae;
    return;
end

points = minutiae(:, 1:2);
types = minutiae(:, 4);
qualities = minutiae(:, 5);
toKeep = true(size(points, 1), 1);

% Analiza par minucji pod kątem bliskości
for i = 1:size(points, 1)-1
    if ~toKeep(i), continue; end
    
    for j = i+1:size(points, 1)
        if ~toKeep(j), continue; end
        
        dist = norm(points(i,:) - points(j,:));
        
        % PROGI ODLEGŁOŚCI zależne od typów minucji
        type_i = types(i);
        type_j = types(j);
        
        if type_i == 2 && type_j == 2
            % Bifurcation vs Bifurcation - najbardziej łagodny próg
            distanceThreshold = minDistance * 2.2; % 26.4 pikseli
        elseif type_i == 2 || type_j == 2
            % Bifurcation vs Ending - umiarkowany próg
            distanceThreshold = minDistance * 1.3; % 15.6 pikseli
        else
            % Ending vs Ending - standardowy próg
            distanceThreshold = minDistance; % 12 pikseli
        end
        
        % STRATEGIA WYBORU gdy minucje są za blisko
        if dist < distanceThreshold
            if type_i == 2 && type_j == 2
                % Oba to bifurcations - usuń gorszą jakościowo
                if qualities(i) >= qualities(j)
                    toKeep(j) = false;
                else
                    toKeep(i) = false;
                    break;
                end
            elseif type_i == 2 && type_j == 1
                % Bifurcation vs Ending - bifurcation musi być 20% lepsza żeby zostać
                if qualities(i) > qualities(j) * 1.2
                    toKeep(j) = false;
                else
                    toKeep(i) = false;
                    break;
                end
            elseif type_i == 1 && type_j == 2
                % Ending vs Bifurcation - bifurcation musi być 20% lepsza żeby zostać
                if qualities(j) > qualities(i) * 1.2
                    toKeep(i) = false;
                    break;
                else
                    toKeep(j) = false;
                end
            else
                % Oba to endings - usuń gorszą jakościowo
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
% LIMITMINUTIAEWITHTARGETRATIO Ogranicza liczbę minucji z kontrolą proporcji
%
% Funkcja ogranicza liczbę minucji do maksymalnej wartości, starając się
% zachować zadane proporcje między endings a bifurcations. Dodatkowo
% stosuje filtrację przestrzenną dla bifurcacji.

% Podział na typy
endpoints = minutiae(minutiae(:, 4) == 1, :);
bifurcations = minutiae(minutiae(:, 4) == 2, :);

% Sortowanie według jakości (najlepsze pierwsze)
if ~isempty(endpoints)
    [~, endOrder] = sort(endpoints(:, 5), 'descend');
    endpoints = endpoints(endOrder, :);
end

if ~isempty(bifurcations)
    [~, bifOrder] = sort(bifurcations(:, 5), 'descend');
    bifurcations = bifurcations(bifOrder, :);
end

% DODATKOWA FILTRACJA PRZESTRZENNA dla bifurcacji
if size(bifurcations, 1) > 0
    bifurcations = applyAdditionalSpatialFiltering(bifurcations);
end

% Obliczenie docelowych liczb z zachowaniem proporcji
targetEndpoints = min(size(endpoints, 1), round(maxCount * endpointRatio));
targetBifurcations = min(size(bifurcations, 1), maxCount - targetEndpoints);

% Wybór najlepszych z każdej grupy
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
% APPLYADDITIONALSPATIALFILTERING Dodatkowa filtracja przestrzenna bifurcacji
%
% Funkcja stosuje siatkę przestrzenną i ogranicza liczbę bifurcacji na komórkę
% siatki, zapobiegając nadmiernej koncentracji bifurcacji w jednym miejscu.

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

% Dla każdej komórki, zachowaj najlepsze bifurcje
toKeep = false(size(bifurcations, 1), 1);

for cellX = 1:nCellsX
    for cellY = 1:nCellsY
        % Znajdź bifurkcje w tej komórce
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
