function filteredMinutiae = filterMinutiae(minutiae, config, logFile)
% FILTERMINUTIAE Filtrowanie minucji według jakości i limitów liczbowych
%
% Funkcja przeprowadza wieloetapowe filtrowanie wykrytych minucji w celu
% usunięcia punktów o niskiej jakości i ograniczenia ich liczby do
% optymalnej wartości dla dalszego przetwarzania. Zachowuje najlepsze
% minucje według wskaźnika jakości.
%
% Parametry wejściowe:
%   minutiae - macierz minucji [x, y, angle, type, quality]
%   config - struktura konfiguracyjna z parametrami filtrowania
%   logFile - uchwyt pliku logów (opcjonalny)
%
% Parametry wyjściowe:
%   filteredMinutiae - odfiltrowana macierz minucji o wysokiej jakości

if nargin < 3, logFile = []; end

try
    % SPRAWDZENIE DANYCH WEJŚCIOWYCH
    if isempty(minutiae)
        logWarning('No minutiae to filter - empty input matrix', logFile);
        filteredMinutiae = [];
        return;
    end
    
    logInfo(sprintf('Starting minutiae filtering process: %d initial minutiae', size(minutiae, 1)), logFile);
    
    % POBRANIE PARAMETRÓW FILTROWANIA z konfiguracji
    qualityThresh = config.minutiae.filtering.qualityThreshold;  % Minimalny próg jakości (np. 0.3)
    maxMinutiae = config.minutiae.filtering.maxMinutiae;         % Maksymalna liczba minucji (np. 100)
    
    % KROK 1: FILTROWANIE WEDŁUG JAKOŚCI
    % Usuwa minucje o jakości poniżej progu - eliminuje artefakty i błędne detekcje
    qualityMask = minutiae(:, 5) >= qualityThresh;
    filteredMinutiae = minutiae(qualityMask, :);
    
    logInfo(sprintf('After quality filtering (threshold %.2f): %d minutiae remaining', ...
        qualityThresh, size(filteredMinutiae, 1)), logFile);
    
    % KROK 2: OGRANICZENIE LICZBY MINUCJI
    % Zachowuje tylko najlepsze minucje jeśli ich liczba przekracza limit
    if size(filteredMinutiae, 1) > maxMinutiae
        % Sortowanie malejące według jakości (kolumna 5)
        [~, sortIdx] = sort(filteredMinutiae(:, 5), 'descend');
        % Wybór top N najlepszych minucji
        filteredMinutiae = filteredMinutiae(sortIdx(1:maxMinutiae), :);
        logInfo(sprintf('Limited to top %d highest quality minutiae', maxMinutiae), logFile);
    end
    
    % PODSUMOWANIE WYNIKÓW FILTROWANIA
    reductionPercent = (1 - size(filteredMinutiae, 1) / size(minutiae, 1)) * 100;
    logSuccess(sprintf('Filtering completed: %d final minutiae (%.1f%% reduction)', ...
        size(filteredMinutiae, 1), reductionPercent), logFile);
    
catch ME
    % OBSŁUGA BŁĘDÓW - logowanie szczegółów i zwrócenie pustego wyniku
    logError(sprintf('Minutiae filtering failed: %s', ME.message), logFile);
    filteredMinutiae = [];
end
end