function filteredMinutiae = filterMinutiae(minutiae, config, logFile)
% FILTERMINUTIAE Filtruje wykryte minucje według kryteriów jakości i przestrzennych
%
% Funkcja wykonuje wielopoziomową filtrację wykrytych minucji, eliminując
% punkty o niskiej jakości oraz ograniczając liczbę minucji do najlepszych
% kandydatów zgodnie z parametrami konfiguracyjnymi.
%
% Parametry wejściowe:
%   minutiae - macierz wykrytych minucji [x, y, angle, type, quality]
%              gdzie: x,y - współrzędne, angle - orientacja w radianach,
%                     type - typ (1=ending, 2=bifurcation), quality - jakość (0-1)
%   config - struktura konfiguracyjna zawierająca parametry filtracji
%   logFile - uchwyt do pliku logów (opcjonalny)
%
% Parametry wyjściowe:
%   filteredMinutiae - macierz przefiltrowanych minucji w tym samym formacie
%
% Algorytm filtracji:
%   1. Filtracja według jakości - usuwa minucje poniżej progu jakości
%   2. Ograniczenie liczby - zachowuje tylko najlepsze minucje wg. jakości
%   3. Ranking według jakości w porządku malejącym
%
% Przykład użycia:
%   filteredMinutiae = filterMinutiae(detectedMinutiae, config, logFile);

if nargin < 3, logFile = []; end

try
    if isempty(minutiae)
        logWarning('No minutiae to filter', logFile);
        filteredMinutiae = [];
        return;
    end
    
    logInfo(sprintf('Filtering %d minutiae...', size(minutiae, 1)), logFile);
    
    % Parametry filtracji z konfiguracji
    qualityThresh = config.minutiae.filtering.qualityThreshold; % Próg jakości (np. 0.3)
    maxMinutiae = config.minutiae.filtering.maxMinutiae;         % Maksymalna liczba minucji (np. 50)
    
    % ETAP 1: Filtracja według jakości
    % Zachowaj tylko minucje o jakości >= progu jakości
    qualityMask = minutiae(:, 5) >= qualityThresh;
    filteredMinutiae = minutiae(qualityMask, :);
    
    logInfo(sprintf('After quality filtering: %d minutiae', size(filteredMinutiae, 1)), logFile);
    
    % ETAP 2: Ograniczenie liczby minucji do najlepszych
    % Sortuj według jakości (kolumna 5) w porządku malejącym
    if size(filteredMinutiae, 1) > maxMinutiae
        [~, sortIdx] = sort(filteredMinutiae(:, 5), 'descend');
        filteredMinutiae = filteredMinutiae(sortIdx(1:maxMinutiae), :);
        logInfo(sprintf('Limited to top %d minutiae', maxMinutiae), logFile);
    end
    
    logSuccess(sprintf('Final minutiae count: %d', size(filteredMinutiae, 1)), logFile);
    
catch ME
    logError(sprintf('Minutiae filtering error: %s', ME.message), logFile);
    filteredMinutiae = [];
end
end