function filteredMinutiae = filterMinutiae(minutiae, filterOptions)
% FILTERMINUTIAE Filtruje minucje według zadanych kryteriów
%
% Argumenty:
%   minutiae - struktura z minucjami
%   filterOptions - opcje filtrowania
%
% Output:
%   filteredMinutiae - przefiltrowane minucje

if nargin < 2
    filterOptions = struct();
end

% Domyślne opcje filtrowania
if ~isfield(filterOptions, 'maxCount'), filterOptions.maxCount = 80; end
if ~isfield(filterOptions, 'minDistance'), filterOptions.minDistance = 8; end
if ~isfield(filterOptions, 'borderMargin'), filterOptions.borderMargin = 15; end

try
    % Rozpocznij od wszystkich minucji
    allPoints = minutiae.all;
    
    if isempty(allPoints)
        filteredMinutiae = minutiae;
        return;
    end
    
    % FILTR 1: Usuń minucje zbyt blisko brzegów
    validPoints = filterBorderMinutiae(allPoints, filterOptions.borderMargin);
    
    % FILTR 2: Usuń minucje zbyt blisko siebie
    validPoints = filterCloseMinutiae(validPoints, filterOptions.minDistance);
    
    % FILTR 3: Ogranicz liczbę do najlepszych
    if size(validPoints, 1) > filterOptions.maxCount
        validPoints = selectBestMinutiae(validPoints, filterOptions.maxCount);
    end
    
    % Odbuduj strukturę
    filteredMinutiae = struct();
    filteredMinutiae.all = validPoints;
    
    % Podziel na endpoints i bifurcations
    filteredMinutiae.endpoints = validPoints(validPoints(:,3) == 1, [1,2,4]);
    filteredMinutiae.bifurcations = validPoints(validPoints(:,3) == 2, [1,2,4]);
    
catch ME
    % W przypadku błędu, zwróć oryginalne minucje
    filteredMinutiae = minutiae;
end
end

function validPoints = filterBorderMinutiae(points, margin)
% Usuwa minucje zbyt blisko brzegów

if isempty(points)
    validPoints = points;
    return;
end

% Zakładamy standardowy rozmiar obrazu lub używamy min/max współrzędnych
maxX = max(points(:, 1)) + 50;
maxY = max(points(:, 2)) + 50;

% Filtruj punkty
validMask = (points(:, 1) > margin) & (points(:, 1) < maxX - margin) & ...
    (points(:, 2) > margin) & (points(:, 2) < maxY - margin);

validPoints = points(validMask, :);
end

function validPoints = filterCloseMinutiae(points, minDistance)
% Usuwa minucje zbyt blisko siebie

if size(points, 1) <= 1
    validPoints = points;
    return;
end

numPoints = size(points, 1);
keepMask = true(numPoints, 1);

for i = 1:numPoints-1
    if ~keepMask(i), continue; end
    
    for j = i+1:numPoints
        if ~keepMask(j), continue; end
        
        % Oblicz odległość
        dist = sqrt((points(i,1) - points(j,1))^2 + (points(i,2) - points(j,2))^2);
        
        % Jeśli za blisko, usuń punkt o niższej jakości (lub drugi)
        if dist < minDistance
            keepMask(j) = false;
        end
    end
end

validPoints = points(keepMask, :);
end

function bestPoints = selectBestMinutiae(points, maxCount)
% Wybiera najlepsze minucje (na razie losowo, można ulepszyć)

if size(points, 1) <= maxCount
    bestPoints = points;
    return;
end

% Prosty wybór - pierwsze maxCount punktów
% (można ulepszyć o ocenę jakości)
indices = randperm(size(points, 1));
selectedIndices = indices(1:maxCount);

bestPoints = points(selectedIndices, :);
end