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
    
    logInfo('    Detecting minutiae...', logFile);
    
    % KROK 1: Szkieletyzacja (cienkie linie 1-piksel)
    skeleton = bwmorph(binaryImage, 'thin', inf);
    skeleton = bwmorph(skeleton, 'clean'); % usuń artefakty
    
    % KROK 2: Wykryj ZAKOŃCZENIA (endpoints)
    endpoints_img = bwmorph(skeleton, 'endpoints');
    [y_end, x_end] = find(endpoints_img);
    endpoints = [x_end, y_end];
    
    % KROK 3: Wykryj ROZGAŁĘZIENIA (bifurcations)
    bifurcations_img = bwmorph(skeleton, 'branchpoints');
    [y_bif, x_bif] = find(bifurcations_img);
    bifurcations = [x_bif, y_bif];
    
    % KROK 4: Wykryj OCZKA (lakes) - zamknięte obszary
    lakes = detectLakes(binaryImage);
    
    % KROK 5: Wykryj KROPKI (dots) - izolowane piksele
    dots = detectDots(skeleton);
    
    % KROK 6: Filtrowanie brzegów
    [h, w] = size(binaryImage);
    margin = 15;
    
    % Filtruj zakończenia
    if ~isempty(endpoints)
        valid = endpoints(:,1) > margin & endpoints(:,1) < w-margin & ...
            endpoints(:,2) > margin & endpoints(:,2) < h-margin;
        endpoints = endpoints(valid, :);
    end
    
    % Filtruj bifurkacje
    if ~isempty(bifurcations)
        valid = bifurcations(:,1) > margin & bifurcations(:,1) < w-margin & ...
            bifurcations(:,2) > margin & bifurcations(:,2) < h-margin;
        bifurcations = bifurcations(valid, :);
    end
    
    % Utwórz strukturę wynikową
    minutiae = struct();
    minutiae.endpoints = endpoints;
    minutiae.bifurcations = bifurcations;
    minutiae.lakes = lakes;
    minutiae.dots = dots;
    minutiae.count = size(endpoints, 1) + size(bifurcations, 1) + size(lakes, 1) + size(dots, 1);
    
    logInfo(sprintf('    Found: %d endpoints, %d bifurcations, %d lakes, %d dots (total: %d)', ...
        size(endpoints, 1), size(bifurcations, 1), size(lakes, 1), size(dots, 1), minutiae.count), logFile);
    
catch ME
    logError(sprintf('Error detecting minutiae: %s', ME.message), logFile);
    
    % Fallback
    minutiae = struct();
    minutiae.endpoints = [];
    minutiae.bifurcations = [];
    minutiae.lakes = [];
    minutiae.dots = [];
    minutiae.count = 0;
end
end

function lakes = detectLakes(binaryImage)
% DETECTLAKES Wykrywa oczka (zamknięte obszary)

% Znajdź dziury w obrazie
holes = imfill(binaryImage, 'holes') & ~binaryImage;

% Analizuj każdą dziurę
cc = bwconncomp(holes);
lakes = [];

for i = 1:cc.NumObjects
    % Pobierz współrzędne dziury
    [y, x] = ind2sub(size(holes), cc.PixelIdxList{i});
    
    % Oblicz rozmiar dziury
    width = max(x) - min(x) + 1;
    height = max(y) - min(y) + 1;
    area = length(cc.PixelIdxList{i});
    
    % Filtruj na podstawie rozmiaru (oczka nie powinny być za duże ani za małe)
    if area >= 10 && area <= 500 && width >= 3 && height >= 3
        center_x = round(mean(x));
        center_y = round(mean(y));
        lakes = [lakes; center_x, center_y, width, height];
    end
end
end

function dots = detectDots(skeleton)
% DETECTDOTS Wykrywa izolowane kropki

% Znajdź pojedyncze piksele (bez sąsiadów)
se = strel('square', 3);
isolated = skeleton & ~imdilate(skeleton, se) | skeleton;

% Znajdź małe komponenty (1-3 piksele)
cc = bwconncomp(isolated);
dots = [];

for i = 1:cc.NumObjects
    if length(cc.PixelIdxList{i}) <= 3  % Maksymalnie 3 piksele
        [y, x] = ind2sub(size(skeleton), cc.PixelIdxList{i});
        center_x = round(mean(x));
        center_y = round(mean(y));
        dots = [dots; center_x, center_y];
    end
end
end