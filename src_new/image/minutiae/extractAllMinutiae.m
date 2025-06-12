function allMinutiae = extractAllMinutiae(images, labels, config, logFile)
% EXTRACTALLMINUTIAE Ekstraktuje minucje ze wszystkich obrazów

if nargin < 4, logFile = []; end

try
    logInfo('=== EKSTRAKCJA MINUCJI ===', logFile);
    
    % ✅ NAPRAWKA - użyj domyślnych wartości jeśli brak config.minutiae
    if isfield(config, 'minutiae')
        minDistance = config.minutiae.minDistance;
        maxMinutiae = config.minutiae.maxMinutiae;
    else
        minDistance = 8;
        maxMinutiae = 200;
    end
    
    logInfo(sprintf('Konfiguracja: minDistance=%d, maxMinutiae=%d', minDistance, maxMinutiae), logFile);
    
    numImages = length(images);
    allMinutiae = cell(numImages, 1);
    
    fprintf('🔬 Ekstrakcja minucji z %d obrazów...\n', numImages);
    
    successCount = 0;
    failureCount = 0;
    totalMinutiae = 0;
    
    for i = 1:numImages
        try
            if isempty(images{i})
                allMinutiae{i} = [];
                failureCount = failureCount + 1;
                continue;
            end
            
            minutiae = detectMinutiae(images{i});
            
            if ~isempty(minutiae) && ~isempty(minutiae.all)
                allMinutiae{i} = minutiae;
                totalMinutiae = totalMinutiae + size(minutiae.all, 1);
                successCount = successCount + 1;
                
                if i <= 3
                    fprintf('   🔍 Obraz %d: E=%d, B=%d, Total=%d\n', i, ...
                        size(minutiae.endpoints, 1), size(minutiae.bifurcations, 1), size(minutiae.all, 1));
                end
                
            else
                allMinutiae{i} = [];
                failureCount = failureCount + 1;
            end
            
            if mod(i, 10) == 0
                fprintf('   📊 Przetworzono %d/%d obrazów...\n', i, numImages);
            end
            
        catch ME
            logWarning(sprintf('Błąd ekstrakcji minucji dla obrazu %d: %s', i, ME.message), logFile);
            allMinutiae{i} = [];
            failureCount = failureCount + 1;
        end
    end
    
    fprintf('\n📋 EKSTRAKCJA MINUCJI UKOŃCZONA:\n');
    fprintf('   📊 Łącznie: %d minucji\n', totalMinutiae);
    fprintf('   📈 Średnio: %.1f minucji/obraz\n', totalMinutiae / max(1, successCount));
    fprintf('   ✅ Sukces: %d/%d obrazów\n', successCount, numImages);
    
    logInfo(sprintf('Ekstraktowano łącznie %d minucji (%d sukces, %d błędów)', ...
        totalMinutiae, successCount, failureCount), logFile);
    
catch ME
    logError(sprintf('Błąd ogólny ekstrakcji minucji: %s', ME.message), logFile);
    allMinutiae = cell(length(images), 1);
end
end