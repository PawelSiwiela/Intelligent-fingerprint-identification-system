function minutiae = detectMinutiae(skeletonImage)
% DETECTMINUTIAE Wykrywa minucje w obrazie szkieletowym
%
% Argumenty:
%   skeletonImage - obraz binarny ze szkieletem linii papilarnych
%
% Output:
%   minutiae - struktura z wykrytymi minucjami

try
    if ~islogical(skeletonImage)
        skeletonImage = skeletonImage > 0;
    end
    
    if isempty(skeletonImage) || sum(skeletonImage(:)) == 0
        minutiae = createEmptyMinutiae();
        return;
    end
    
    % Czyszczenie szkieletu
    cleanSkeleton = bwmorph(skeletonImage, 'clean');
    cleanSkeleton = bwmorph(cleanSkeleton, 'spur', 1);
    
    % Detekcja punktów
    [endpoints, bifurcations] = detectMinutiaePoints(cleanSkeleton);
    
    % Oblicz orientacje
    endpointOrientations = computeMinutiaeOrientations(cleanSkeleton, endpoints);
    bifurcationOrientations = computeMinutiaeOrientations(cleanSkeleton, bifurcations);
    
    % Utwórz strukturę minucji
    minutiae = struct();
    minutiae.endpoints = [endpoints, endpointOrientations];
    minutiae.bifurcations = [bifurcations, bifurcationOrientations];
    
    % Wszystkie minucje z typem: 1=endpoint, 2=bifurcation
    minutiae.all = [
        [endpoints, ones(size(endpoints,1), 1), endpointOrientations];
        [bifurcations, 2*ones(size(bifurcations,1), 1), bifurcationOrientations]
        ];
    
    % Filtracja jakości
    minutiae = filterMinutiae(minutiae, skeletonImage);
    
catch ME
    minutiae = createEmptyMinutiae();
    fprintf('   Błąd detekcji minucji: %s\n', ME.message);
end
end

function [endpoints, bifurcations] = detectMinutiaePoints(skeletonImage)
% Wykrywa punkty końcowe i rozwidlenia

[rows, cols] = size(skeletonImage);
endpoints = [];
bifurcations = [];
margin = 10;

for y = margin+1:rows-margin
    for x = margin+1:cols-margin
        if ~skeletonImage(y, x)
            continue;
        end
        
        neighborhood = skeletonImage(y-1:y+1, x-1:x+1);
        neighborhood(2,2) = false;
        neighbors = sum(neighborhood(:));
        
        if neighbors == 1
            endpoints = [endpoints; x, y];
        elseif neighbors == 3
            bifurcations = [bifurcations; x, y];
        end
    end
end

end

function orientations = computeMinutiaeOrientations(skeleton, points)
% Oblicza orientacje minucji

if isempty(points)
    orientations = [];
    return;
end

orientations = zeros(size(points, 1), 1);
windowSize = 5;

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
        
    catch
        orientations(i) = 0;
    end
end
end

function filteredMinutiae = filterMinutiae(minutiae, skeletonImage)
% Filtruje minucje

filteredMinutiae = minutiae;

if isempty(minutiae.all)
    return;
end

% Usuń minucje zbyt blisko siebie
minDistance = 8;
filteredMinutiae = filterCloseMinutiae(filteredMinutiae, minDistance);

% Usuń minucje o złej jakości
filteredMinutiae = filterLowQualityMinutiae(filteredMinutiae, skeletonImage);

% Ograniczenie liczby
maxMinutiae = 200;
if size(filteredMinutiae.all, 1) > maxMinutiae
    filteredMinutiae = limitMaxMinutiae(filteredMinutiae, maxMinutiae);
end
end

function filteredMinutiae = filterCloseMinutiae(minutiae, minDistance)
% Usuwa minucje zbyt blisko siebie

if size(minutiae.all, 1) <= 1
    filteredMinutiae = minutiae;
    return;
end

points = minutiae.all(:, 1:2);
toKeep = true(size(points, 1), 1);

for i = 1:size(points, 1)-1
    if ~toKeep(i), continue; end
    
    for j = i+1:size(points, 1)
        if ~toKeep(j), continue; end
        
        dist = norm(points(i,:) - points(j,:));
        
        if dist < minDistance
            toKeep(j) = false;
        end
    end
end

filteredMinutiae = minutiae;
filteredMinutiae.all = minutiae.all(toKeep, :);
filteredMinutiae.endpoints = filteredMinutiae.all(filteredMinutiae.all(:,3) == 1, [1,2,4]);
filteredMinutiae.bifurcations = filteredMinutiae.all(filteredMinutiae.all(:,3) == 2, [1,2,4]);
end

function filteredMinutiae = filterLowQualityMinutiae(minutiae, skeletonImage)
% Filtruje minucje niskiej jakości

filteredMinutiae = minutiae;

if size(minutiae.all, 1) == 0
    return;
end

toKeep = true(size(minutiae.all, 1), 1);
[rows, cols] = size(skeletonImage);

for i = 1:size(minutiae.all, 1)
    x = round(minutiae.all(i, 1));
    y = round(minutiae.all(i, 2));
    
    if x < 1 || x > cols || y < 1 || y > rows
        toKeep(i) = false;
        continue;
    end
    
    if x > 1 && x < cols && y > 1 && y < rows
        window = skeletonImage(y-1:y+1, x-1:x+1);
        neighbors = sum(window(:)) - window(2,2);
        
        if neighbors == 0 || neighbors > 8
            toKeep(i) = false;
        end
    end
end

filteredMinutiae.all = minutiae.all(toKeep, :);
filteredMinutiae.endpoints = filteredMinutiae.all(filteredMinutiae.all(:,3) == 1, [1,2,4]);
filteredMinutiae.bifurcations = filteredMinutiae.all(filteredMinutiae.all(:,3) == 2, [1,2,4]);
end

function limitedMinutiae = limitMaxMinutiae(minutiae, maxCount)
% Ogranicza liczbę minucji

if size(minutiae.all, 1) <= maxCount
    limitedMinutiae = minutiae;
    return;
end

indices = randperm(size(minutiae.all, 1));
selectedIndices = sort(indices(1:maxCount));

limitedMinutiae = minutiae;
limitedMinutiae.all = minutiae.all(selectedIndices, :);
limitedMinutiae.endpoints = limitedMinutiae.all(limitedMinutiae.all(:,3) == 1, [1,2,4]);
limitedMinutiae.bifurcations = limitedMinutiae.all(limitedMinutiae.all(:,3) == 2, [1,2,4]);
end

function minutiae = createEmptyMinutiae()
% Tworzy pustą strukturę minucji

minutiae = struct();
minutiae.endpoints = [];
minutiae.bifurcations = [];
minutiae.all = [];
end