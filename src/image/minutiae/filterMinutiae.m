function filteredMinutiae = filterMinutiae(minutiae, config, logFile)
% FILTERMINUTIAE Filtruje minucje według jakości i innych kryteriów
%
% Argumenty:
%   minutiae - wykryte minucje [x, y, angle, type, quality]
%   config - struktura konfiguracyjna
%   logFile - plik logów (opcjonalny)
%
% Output:
%   filteredMinutiae - odfiltrowane minucje

if nargin < 3, logFile = []; end

try
    if isempty(minutiae)
        logWarning('No minutiae to filter', logFile);
        filteredMinutiae = [];
        return;
    end
    
    logInfo(sprintf('Filtering %d minutiae...', size(minutiae, 1)), logFile);
    
    % Parametry z konfiguracji
    qualityThresh = config.minutiae.filtering.qualityThreshold;
    maxMinutiae = config.minutiae.filtering.maxMinutiae;
    
    % Filtruj według jakości
    qualityMask = minutiae(:, 5) >= qualityThresh;
    filteredMinutiae = minutiae(qualityMask, :);
    
    logInfo(sprintf('After quality filtering: %d minutiae', size(filteredMinutiae, 1)), logFile);
    
    % Ogranicz liczbę minucji (zachowaj najlepsze)
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