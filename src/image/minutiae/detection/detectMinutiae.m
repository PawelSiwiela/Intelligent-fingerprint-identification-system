function minutiae = detectMinutiae(binaryImage, logFile)
% DETECTMINUTIAE Wykrywa minucje w szkielecie odcisku palca
%
% Input:
%   binaryImage - przetworzony obraz binarny
%   logFile - plik logu (opcjonalny)
%
% Output:
%   minutiae - struktura z wykrytymi minucjami:
%     .endpoints - [N x 2] zakończenia linii [x, y]
%     .bifurcations - [M x 2] rozgałęzienia [x, y]
%     .lakes - [K x 4] oczka [x, y, width, height]
%     .dots - [L x 2] izolowane kropki [x, y]
%     .count - całkowita liczba minucji

try
    if nargin < 2, logFile = []; end
    
    % Walidacja wejścia
    if isempty(binaryImage)
        error('Input image is empty');
    end
    
    % Konwersja do logicznego
    if ~islogical(binaryImage)
        binaryImage = binaryImage > 0.5;
    end
    
    % Sprawdź pokrycie
    whitePixels = sum(binaryImage(:));
    totalPixels = numel(binaryImage);
    coverage = whitePixels / totalPixels;
    
    logInfo(sprintf('    Binary image coverage: %.2f%% (%d white pixels)', coverage*100, whitePixels), logFile);
    
    if coverage < 0.01
        logWarning('Binary image has very low coverage', logFile);
    end
    
    logInfo('    Creating skeleton...', logFile);
    
    % KROK 1: Szkieletyzacja - PODSTAWA!
    skeleton = bwmorph(binaryImage, 'thin', inf);
    skeleton = bwmorph(skeleton, 'clean'); % usuń izolowane piksele
    
    % Sprawdź szkielet
    skelPixels = sum(skeleton(:));
    logInfo(sprintf('    Skeleton has %d pixels', skelPixels), logFile);
    
    if skelPixels == 0
        logWarning('Skeleton is empty!', logFile);
        skeleton = bwmorph(binaryImage, 'skel', inf);
        skelPixels = sum(skeleton(:));
    end
    
    % KROK 2: Wykryj ZAKOŃCZENIA na SZKIELECIE (nie na binaryImage!)
    logInfo('    Detecting endpoints...', logFile);
    endpoints_img = bwmorph(skeleton, 'endpoints');  % ✅ NA SZKIELECIE!
    [y_end, x_end] = find(endpoints_img);
    endpoints = [x_end, y_end];
    
    logInfo(sprintf('    Found %d raw endpoints', size(endpoints, 1)), logFile);
    
    % KROK 3: Wykryj ROZGAŁĘZIENIA na SZKIELECIE
    logInfo('    Detecting bifurcations...', logFile);
    bifurcations_img = bwmorph(skeleton, 'branchpoints');  % ✅ NA SZKIELECIE!
    [y_bif, x_bif] = find(bifurcations_img);
    bifurcations = [x_bif, y_bif];
    
    logInfo(sprintf('    Found %d raw bifurcations', size(bifurcations, 1)), logFile);
    
    % KROK 4: BARDZIEJ AGRESYWNE FILTROWANIE brzegów
    [h, w] = size(binaryImage);
    margin = 30; % ZWIĘKSZONE z 20 na 30
    
    % Filtruj zakończenia
    if ~isempty(endpoints)
        valid = endpoints(:,1) > margin & endpoints(:,1) < w-margin & ...
            endpoints(:,2) > margin & endpoints(:,2) < h-margin;
        endpoints = endpoints(valid, :);
        logInfo(sprintf('    After border filtering: %d endpoints', size(endpoints, 1)), logFile);
    end
    
    % Filtruj bifurkacje
    if ~isempty(bifurcations)
        valid = bifurcations(:,1) > margin & bifurcations(:,1) < w-margin & ...
            bifurcations(:,2) > margin & bifurcations(:,2) < h-margin;
        bifurcations = bifurcations(valid, :);
        logInfo(sprintf('    After border filtering: %d bifurcations', size(bifurcations, 1)), logFile);
    end
    
    % KROK 5: ZWIĘKSZONE FILTROWANIE odległości
    if ~isempty(endpoints)
        endpoints = filterCloseMinutiae(endpoints, 10); % ZWIĘKSZONE z 5 na 10
        logInfo(sprintf('    After distance filtering: %d endpoints', size(endpoints, 1)), logFile);
    end
    
    if ~isempty(bifurcations)
        bifurcations = filterCloseMinutiae(bifurcations, 10); % ZWIĘKSZONE z 5 na 10
        logInfo(sprintf('    After distance filtering: %d bifurcations', size(bifurcations, 1)), logFile);
    end
    
    % KROK 5.5: DODATKOWE FILTROWANIE - ogranicz maksymalną liczbę
    maxEndpoints = 100;  % Maksymalnie 100 endpoints
    maxBifurcations = 50; % Maksymalnie 50 bifurcations
    
    if size(endpoints, 1) > maxEndpoints
        % Wybierz najlepsze endpoints (najbardziej w środku obrazu)
        center_x = w/2;
        center_y = h/2;
        distances = sqrt((endpoints(:,1) - center_x).^2 + (endpoints(:,2) - center_y).^2);
        [~, sortIdx] = sort(distances);
        endpoints = endpoints(sortIdx(1:maxEndpoints), :);
        logInfo(sprintf('    Limited to %d best endpoints', size(endpoints, 1)), logFile);
    end
    
    if size(bifurcations, 1) > maxBifurcations
        % Wybierz najlepsze bifurcations
        center_x = w/2;
        center_y = h/2;
        distances = sqrt((bifurcations(:,1) - center_x).^2 + (bifurcations(:,2) - center_y).^2);
        [~, sortIdx] = sort(distances);
        bifurcations = bifurcations(sortIdx(1:maxBifurcations), :);
        logInfo(sprintf('    Limited to %d best bifurcations', size(bifurcations, 1)), logFile);
    end
    
    % KROK 6: Wykryj oczka i kropki (uproszczone)
    logInfo('    Detecting lakes and dots...', logFile);
    lakes = detectLakesSimple(binaryImage);
    dots = detectDotsSimple(skeleton);
    
    % KROK 7: Utwórz strukturę wynikową
    minutiae = struct();
    minutiae.endpoints = endpoints;
    minutiae.bifurcations = bifurcations;
    minutiae.lakes = lakes;
    minutiae.dots = dots;
    minutiae.count = size(endpoints, 1) + size(bifurcations, 1) + size(lakes, 1) + size(dots, 1);
    
    logInfo(sprintf('    FINAL RESULT: %d endpoints, %d bifurcations, %d lakes, %d dots (total: %d)', ...
        size(endpoints, 1), size(bifurcations, 1), size(lakes, 1), size(dots, 1), minutiae.count), logFile);
    
catch ME
    logError(sprintf('Error detecting minutiae: %s', ME.message), logFile);
    
    % Fallback - pusta struktura
    minutiae = struct();
    minutiae.endpoints = [];
    minutiae.bifurcations = [];
    minutiae.lakes = [];
    minutiae.dots = [];
    minutiae.count = 0;
end
end

function filteredMinutiae = filterCloseMinutiae(minutiae, minDistance)
% Usuń minucje które są zbyt blisko siebie
if isempty(minutiae)
    filteredMinutiae = minutiae;
    return;
end

filteredMinutiae = [];
used = false(size(minutiae, 1), 1);

for i = 1:size(minutiae, 1)
    if used(i)
        continue;
    end
    
    % Dodaj tę minucję
    filteredMinutiae = [filteredMinutiae; minutiae(i, :)];
    used(i) = true;
    
    % Oznacz wszystkie bliskie jako użyte
    for j = i+1:size(minutiae, 1)
        if ~used(j)
            dist = sqrt(sum((minutiae(i, :) - minutiae(j, :)).^2));
            if dist < minDistance
                used(j) = true;
            end
        end
    end
end
end

function lakes = detectLakesSimple(binaryImage)
% Uproszczone wykrywanie oczek - bardziej restrykcyjne
lakes = [];

try
    % Znajdź dziury w obrazie
    filled = imfill(binaryImage, 'holes');
    holes = filled & ~binaryImage;
    
    % Znajdź połączone komponenty dziur
    cc = bwconncomp(holes);
    
    for i = 1:cc.NumObjects
        area = length(cc.PixelIdxList{i});
        
        % JESZCZE BARDZIEJ RESTRYKCYJNE
        if area >= 30 && area <= 200  % ZWIĘKSZONE z 20 na 30
            [y, x] = ind2sub(size(holes), cc.PixelIdxList{i});
            width = max(x) - min(x) + 1;
            height = max(y) - min(y) + 1;
            
            aspect_ratio = max(width, height) / min(width, height);
            if aspect_ratio < 2.5  % ZMNIEJSZONE z 3 na 2.5
                center_x = round(mean(x));
                center_y = round(mean(y));
                lakes = [lakes; center_x, center_y, width, height];
            end
        end
    end
    
    % Ogranicz liczbę oczek
    if size(lakes, 1) > 20
        lakes = lakes(1:20, :);
    end
catch
    lakes = [];
end
end

function dots = detectDotsSimple(skeleton)
% Uproszczone wykrywanie kropek - bardzo restrykcyjne
dots = [];

try
    cc = bwconncomp(skeleton);
    
    for i = 1:cc.NumObjects
        area = length(cc.PixelIdxList{i});
        if area == 1  % TYLKO POJEDYNCZE PIKSELE (zmniejszone z 2 na 1)
            [y, x] = ind2sub(size(skeleton), cc.PixelIdxList{i});
            center_x = round(mean(x));
            center_y = round(mean(y));
            dots = [dots; center_x, center_y];
        end
    end
    
    % Ogranicz liczbę kropek
    if size(dots, 1) > 10
        dots = dots(1:10, :);
    end
catch
    dots = [];
end
end