function minutiae = detectMinutiae(skeletonImage, mask, orientation)
% DETECTMINUTIAE Wykrywa minucje (punkty końcowe i rozwidlenia) na obrazie szkieletowym
%
% Input:
%   skeletonImage - obraz szkieletowy (binarny)
%   mask - maska segmentacji odcisku palca
%   orientation - mapa orientacji (opcjonalna)
%
% Output:
%   minutiae - struktura z polami:
%     .endpoints - punkty końcowe [x, y, orientation]
%     .bifurcations - rozwidlenia [x, y, orientation]
%     .all - wszystkie minucje [x, y, type, orientation]

if nargin < 3, orientation = []; end

% Inicjalizacja wyników
minutiae = struct();
minutiae.endpoints = [];
minutiae.bifurcations = [];
minutiae.all = [];

% Sprawdź obraz wejściowy
if isempty(skeletonImage) || sum(skeletonImage(:)) == 0
    fprintf('   ⚠️ Pusty obraz szkieletowy - brak minucji\n');
    return;
end

% Zastosuj maskę
skeletonImage = skeletonImage & mask;

% Znajdź piksele szkieletu
[rows, cols] = size(skeletonImage);
[skelY, skelX] = find(skeletonImage);

if length(skelX) < 10  % Za mało punktów szkieletu
    fprintf('   ⚠️ Za mało punktów szkieletu (%d) - brak minucji\n', length(skelX));
    return;
end

fprintf('   🔍 Analizuję %d punktów szkieletu...\n', length(skelX));

% Przeanalizuj każdy punkt szkieletu
endpointCount = 0;
bifurcationCount = 0;

% UPROSZCZONE KRYTERIA DETEKCJI
for i = 1:length(skelX)
    x = skelX(i);
    y = skelY(i);
    
    % ZWIĘKSZ MARGINES OD BRZEGU
    if x <= 5 || x >= cols-4 || y <= 5 || y >= rows-4  % Było 3, teraz 5
        continue;
    end
    
    % Wyodrębnij okno 3x3 wokół punktu
    neighborhood = skeletonImage(y-1:y+1, x-1:x+1);
    
    % Policz sąsiadów (bez środkowego punktu)
    neighbors = sum(neighborhood(:)) - neighborhood(2,2);
    
    % ZAOSTRZĘNE KRYTERIA
    if neighbors == 1
        % PUNKT KOŃCOWY - dodaj dodatkową weryfikację
        if isValidMinutiae(skeletonImage, x, y, 'endpoint')
            endpointCount = endpointCount + 1;
            pointOrientation = computeMinutiaeOrientation(skeletonImage, x, y, 'endpoint', orientation);
            minutiae.endpoints = [minutiae.endpoints; x, y, pointOrientation];
            minutiae.all = [minutiae.all; x, y, 1, pointOrientation];
        end
        
    elseif neighbors == 3  % TYLKO 3, nie >=3!
        % ROZWIDLENIE - dodaj dodatkową weryfikację
        if isValidMinutiae(skeletonImage, x, y, 'bifurcation')
            bifurcationCount = bifurcationCount + 1;
            pointOrientation = computeMinutiaeOrientation(skeletonImage, x, y, 'bifurcation', orientation);
            minutiae.bifurcations = [minutiae.bifurcations; x, y, pointOrientation];
            minutiae.all = [minutiae.all; x, y, 2, pointOrientation];
        end
    end
end

% ZWIĘKSZ MINIMALNĄ ODLEGŁOŚĆ
minutiae = filterCloseMinutiae(minutiae, 25); % Było 15, teraz 25!

% ZAOSTRZĘ FILTRACJĘ JAKOŚCI
minutiae = filterLowQualityMinutiae(minutiae, skeletonImage);

% DODAJ JESZCZE JEDNĄ FILTRACJĘ - PRÓG MAKSYMALNY
minutiae = limitMaxMinutiae(minutiae, 150); % Maksymalnie 150 minucji na obraz

% Podsumowanie
totalMinutiae = size(minutiae.all, 1);
fprintf('   ✅ Wykryto minucje: %d punktów końcowych, %d rozwidleń (łącznie: %d)\n', ...
    size(minutiae.endpoints, 1), size(minutiae.bifurcations, 1), totalMinutiae);

if totalMinutiae == 0
    fprintf('   ⚠️ Nie wykryto żadnych minucji!\n');
end
end

function orientation = computeMinutiaeOrientation(skeletonImage, x, y, type, orientationMap)
% Oblicza orientację minucji

if ~isempty(orientationMap) && x <= size(orientationMap,2) && y <= size(orientationMap,1)
    % Użyj gotowej mapy orientacji
    orientation = orientationMap(y, x);
else
    % Oblicz orientację lokalnie
    [rows, cols] = size(skeletonImage);
    windowSize = 7;
    
    % Granice okna
    y1 = max(1, y - windowSize);
    y2 = min(rows, y + windowSize);
    x1 = max(1, x - windowSize);
    x2 = min(cols, x + windowSize);
    
    % Wyodrębnij okno
    window = skeletonImage(y1:y2, x1:x2);
    
    if strcmp(type, 'endpoint')
        % Dla punktu końcowego - znajdź kierunek linii
        orientation = computeEndpointOrientation(window, x-x1+1, y-y1+1);
    else
        % Dla rozwidlenia - średnia orientacja
        orientation = computeBifurcationOrientation(window, x-x1+1, y-y1+1);
    end
end
end

function orientation = computeEndpointOrientation(window, cx, cy)
% Oblicza orientację punktu końcowego

% Znajdź punkty szkieletu w oknie
[py, px] = find(window);

if length(px) < 2
    orientation = 0;
    return;
end

% Usuń punkt centralny
distances = sqrt((px - cx).^2 + (py - cy).^2);
[~, centerIdx] = min(distances);
px(centerIdx) = [];
py(centerIdx) = [];

if isempty(px)
    orientation = 0;
    return;
end

% Znajdź najbliższy punkt (kierunek linii)
distances = sqrt((px - cx).^2 + (py - cy).^2);
[~, nearestIdx] = min(distances);

% Oblicz kąt
dx = px(nearestIdx) - cx;
dy = py(nearestIdx) - cy;
orientation = atan2(dy, dx);
end

function orientation = computeBifurcationOrientation(window, cx, cy)
% Oblicza orientację rozwidlenia (średnia kierunków)

% Znajdź punkty szkieletu
[py, px] = find(window);

if length(px) < 3
    orientation = 0;
    return;
end

% Usuń punkt centralny
distances = sqrt((px - cx).^2 + (py - cy).^2);
[~, centerIdx] = min(distances);
px(centerIdx) = [];
py(centerIdx) = [];

% Oblicz średnią orientację
angles = atan2(py - cy, px - cx);
orientation = mean(angles);
end

function filteredMinutiae = filterCloseMinutiae(minutiae, minDistance)
% Usuwa minucje zbyt blisko siebie

filteredMinutiae = minutiae;

if size(minutiae.all, 1) < 2
    return;
end

% Oblicz macierz odległości
points = minutiae.all(:, 1:2);
numPoints = size(points, 1);
toRemove = false(numPoints, 1);

for i = 1:numPoints-1
    if toRemove(i), continue; end
    
    for j = i+1:numPoints
        if toRemove(j), continue; end
        
        % Oblicz odległość
        dist = sqrt(sum((points(i,:) - points(j,:)).^2));
        
        if dist < minDistance
            % Usuń punkt o gorszej "jakości" (tutaj: losowo drugi)
            toRemove(j) = true;
        end
    end
end

% Filtruj wyniki
if any(toRemove)
    filteredMinutiae.all = minutiae.all(~toRemove, :);
    
    % Odbuduj endpoints i bifurcations
    filteredMinutiae.endpoints = filteredMinutiae.all(filteredMinutiae.all(:,3) == 1, [1,2,4]);
    filteredMinutiae.bifurcations = filteredMinutiae.all(filteredMinutiae.all(:,3) == 2, [1,2,4]);
    
    fprintf('   🧹 Filtracja: usunięto %d bliskich minucji\n', sum(toRemove));
end
end

function filteredMinutiae = filterLowQualityMinutiae(minutiae, skeletonImage)
% Uproszczona filtracja jakości

filteredMinutiae = minutiae;

if size(minutiae.all, 1) < 1
    return;
end

% BARDZO ŁAGODNE KRYTERIA - tylko podstawowa weryfikacja
toKeep = true(size(minutiae.all, 1), 1);

for i = 1:size(minutiae.all, 1)
    x = minutiae.all(i, 1);
    y = minutiae.all(i, 2);
    
    % Sprawdź czy punkt jest w obrazie i ma przynajmniej jeden sąsiad
    [rows, cols] = size(skeletonImage);
    if x > 1 && x < cols && y > 1 && y < rows
        % Wyodrębnij okno 3x3
        window = skeletonImage(y-1:y+1, x-1:x+1);
        neighbors = sum(window(:)) - window(2,2);
        
        % Zachowaj tylko jeśli ma sensowną liczbę sąsiadów
        if neighbors < 1 || neighbors > 8
            toKeep(i) = false;
        end
    else
        toKeep(i) = false;
    end
end

% Zastosuj filtr
filteredMinutiae.all = minutiae.all(toKeep, :);
filteredMinutiae.endpoints = filteredMinutiae.all(filteredMinutiae.all(:,3) == 1, [1,2,4]);
filteredMinutiae.bifurcations = filteredMinutiae.all(filteredMinutiae.all(:,3) == 2, [1,2,4]);

removedCount = sum(~toKeep);
if removedCount > 0
    fprintf('   🧹 Filtracja jakości: usunięto %d minucji\n', removedCount);
end
end

function isValid = isValidEndpoint(skeletonImage, x, y)
% Weryfikuje jakość punktu końcowego

isValid = false;

% Wyodrębnij okno 3x3
window = skeletonImage(y-1:y+1, x-1:x+1);

% Policz sąsiadów
neighbors = sum(window(:)) - window(2,2);

% Kryteria:
% 1. Dokładnie 1 sąsiad
% 2. Sąsiad nie może być w bezpośrednim sąsiedztwie (zapewnia minimalną "ramkę")
if neighbors == 1 && all(window([1,3,7,9]) == 0)
    isValid = true;
end
end

function isValid = isValidBifurcation(skeletonImage, x, y)
% Weryfikuje jakość rozwidlenia

isValid = false;

% Wyodrębnij okno 3x3
window = skeletonImage(y-1:y+1, x-1:x+1);

% Policz sąsiadów
neighbors = sum(window(:)) - window(2,2);

% Kryteria:
% 1. Dokładnie 3 sąsiadów
% 2. Brak sąsiadów w rogach (zapewnia minimalną "ramkę")
if neighbors == 3 && all(window([1,3,7,9]) == 0)
    isValid = true;
end
end

function limitedMinutiae = limitMaxMinutiae(minutiae, maxCount)
% Ogranicza liczbę minucji do maksymalnej wartości

if size(minutiae.all, 1) <= maxCount
    limitedMinutiae = minutiae;
    return;
end

% Sortuj minucje według jakości (tutaj: losowo, ale można dodać metrykę jakości)
allMinutiae = minutiae.all;
indices = randperm(size(allMinutiae, 1));
selectedIndices = indices(1:maxCount);

% Zachowaj tylko wybrane minucje
limitedMinutiae.all = allMinutiae(selectedIndices, :);

% Odbuduj endpoints i bifurcations
limitedMinutiae.endpoints = limitedMinutiae.all(limitedMinutiae.all(:,3) == 1, [1,2,4]);
limitedMinutiae.bifurcations = limitedMinutiae.all(limitedMinutiae.all(:,3) == 2, [1,2,4]);

removedCount = size(allMinutiae, 1) - maxCount;
fprintf('   🔢 Ograniczono do %d minucji (usunięto %d)\n', maxCount, removedCount);
end

function isValid = isValidMinutiae(skeletonImage, x, y, type)
% Dodatkowa weryfikacja jakości minucji

% Sprawdź okno 5x5 wokół punktu
[rows, cols] = size(skeletonImage);
y1 = max(1, y-2); y2 = min(rows, y+2);
x1 = max(1, x-2); x2 = min(cols, x+2);

window = skeletonImage(y1:y2, x1:x2);
density = sum(window(:)) / numel(window);

% Odrzuć minucje w obszarach o za niskiej lub za wysokiej gęstości
if density < 0.1 || density > 0.8
    isValid = false;
    return;
end

% Dodatkowe kryteria dla każdego typu
if strcmp(type, 'endpoint')
    isValid = density > 0.15 && density < 0.5;
else % bifurcation
    isValid = density > 0.2 && density < 0.7;
end
end