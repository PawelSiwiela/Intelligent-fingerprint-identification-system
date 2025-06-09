function features = extractMinutiaeFeatures(minutiae, imageSize, method, logFile)
% EXTRACTMINUTIAEFEATURES Ekstraktuje wektor cech z wykrytych minucji
%
% Input:
%   minutiae - struktura z wykrytymi minucjami (z detectMinutiae)
%   imageSize - rozmiar obrazu [height, width]
%   method - metoda ekstraktowania ('simple', 'normalized', 'statistical')
%   logFile - plik logu (opcjonalny)
%
% Output:
%   features - wektor cech liczbowych

try
    if nargin < 3, method = 'normalized'; end
    if nargin < 4, logFile = []; end
    
    logInfo('    Extracting minutiae features...', logFile);
    
    switch lower(method)
        case 'simple'
            features = extractSimpleFeatures(minutiae, imageSize);
        case 'normalized'
            features = extractNormalizedFeatures(minutiae, imageSize);
        case 'statistical'
            features = extractStatisticalFeatures(minutiae, imageSize);
        otherwise
            features = extractNormalizedFeatures(minutiae, imageSize);
    end
    
    logInfo(sprintf('    Extracted %d features using %s method', length(features), method), logFile);
    
catch ME
    logError(sprintf('Error extracting features: %s', ME.message), logFile);
    features = zeros(1, 20); % Fallback
end
end

function features = extractSimpleFeatures(minutiae, imageSize)
% Podstawowe cechy - 9 wartości
features = [
    size(minutiae.endpoints, 1),      % Liczba zakończeń
    size(minutiae.bifurcations, 1),   % Liczba bifurkacji
    size(minutiae.lakes, 1),          % Liczba oczek
    size(minutiae.dots, 1),           % Liczba kropek
    minutiae.count                    % Łączna liczba minucji
    ];

% Średnie pozycje
if ~isempty(minutiae.endpoints)
    features = [features, mean(minutiae.endpoints(:,1)), mean(minutiae.endpoints(:,2))];
else
    features = [features, 0, 0];
end

if ~isempty(minutiae.bifurcations)
    features = [features, mean(minutiae.bifurcations(:,1)), mean(minutiae.bifurcations(:,2))];
else
    features = [features, 0, 0];
end
end

function features = extractNormalizedFeatures(minutiae, imageSize)
% Znormalizowane cechy - 17 wartości
height = imageSize(1);
width = imageSize(2);
totalPixels = height * width;

% Podstawowe liczniki (znormalizowane)
features = [
    size(minutiae.endpoints, 1) / 100,
    size(minutiae.bifurcations, 1) / 100,
    size(minutiae.lakes, 1) / 100,
    size(minutiae.dots, 1) / 100,
    minutiae.count / 100,
    minutiae.count / (totalPixels / 10000)  % gęstość
    ];

% Rozkład przestrzenny endpoints
if ~isempty(minutiae.endpoints)
    norm_x = minutiae.endpoints(:,1) / width;
    norm_y = minutiae.endpoints(:,2) / height;
    features = [features, mean(norm_x), std(norm_x), mean(norm_y), std(norm_y)];
else
    features = [features, 0, 0, 0, 0];
end

% Rozkład przestrzenny bifurcations
if ~isempty(minutiae.bifurcations)
    norm_x = minutiae.bifurcations(:,1) / width;
    norm_y = minutiae.bifurcations(:,2) / height;
    features = [features, mean(norm_x), std(norm_x), mean(norm_y), std(norm_y)];
else
    features = [features, 0, 0, 0, 0];
end

% Proporcje typów
if minutiae.count > 0
    features = [features, ...
        size(minutiae.endpoints, 1) / minutiae.count, ...
        size(minutiae.bifurcations, 1) / minutiae.count];
else
    features = [features, 0, 0];
end
end

function features = extractStatisticalFeatures(minutiae, imageSize)
% Zaawansowane cechy statystyczne - ~25 wartości
features = extractNormalizedFeatures(minutiae, imageSize);

height = imageSize(1);
width = imageSize(2);
all_minutiae = [minutiae.endpoints; minutiae.bifurcations];

% Statystyki odległości
if size(all_minutiae, 1) > 1
    distances = pdist(all_minutiae);
    features = [features, mean(distances), std(distances), min(distances), max(distances)];
else
    features = [features, 0, 0, 0, 0];
end

% Analiza kwadrantów
if ~isempty(all_minutiae)
    mid_x = width / 2;
    mid_y = height / 2;
    
    q1 = sum(all_minutiae(:,1) <= mid_x & all_minutiae(:,2) <= mid_y);
    q2 = sum(all_minutiae(:,1) > mid_x & all_minutiae(:,2) <= mid_y);
    q3 = sum(all_minutiae(:,1) <= mid_x & all_minutiae(:,2) > mid_y);
    q4 = sum(all_minutiae(:,1) > mid_x & all_minutiae(:,2) > mid_y);
    
    if minutiae.count > 0
        features = [features, [q1, q2, q3, q4] / minutiae.count];
    else
        features = [features, 0, 0, 0, 0];
    end
else
    features = [features, 0, 0, 0, 0];
end

% Asymetria i kurtoza (używając built-in)
if size(all_minutiae, 1) > 2
    x_coords = all_minutiae(:,1) / width;
    y_coords = all_minutiae(:,2) / height;
    
    features = [features, ...
        skewness(x_coords), skewness(y_coords), ...
        kurtosis(x_coords), kurtosis(y_coords)];
else
    features = [features, 0, 0, 0, 0];
end
end