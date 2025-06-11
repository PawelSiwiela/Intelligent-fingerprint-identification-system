function results = fingerprintRecognition(config, logFile)
% FINGERPRINTRECOGNITION Główny system rozpoznawania odcisków palców
%
% Input:
%   config - konfiguracja systemu z loadConfig()
%   logFile - plik logów (opcjonalny)
%
% Output:
%   results - struktura z wynikami przygotowania danych

if nargin < 2, logFile = []; end

logInfo('=== SYSTEM ROZPOZNAWANIA ODCISKÓW PALCÓW ===', logFile);
systemStart = tic;

try
    % ======================================================================
    % ETAP 1: PRZYGOTOWANIE DANYCH
    % ======================================================================
    logInfo('ETAP 1: Przygotowanie danych...', logFile);
    [trainData, valData, testData] = prepareData(config, logFile);
    
    % Sprawdź czy dane zostały poprawnie przygotowane
    if isempty(trainData.images) || isempty(testData.images)
        error('Brak danych treningowych lub testowych po przygotowaniu');
    end
    
    % ======================================================================
    % ETAP 2: EKSTRAKCJA MINUCJI
    % ======================================================================
    logInfo('ETAP 2: Ekstrakcja minucji...', logFile);
    [trainMinutiae, valMinutiae, testMinutiae] = extractAllMinutiae(trainData, valData, testData, config, logFile);
    
    % Dodaj minucje do wyników
    results.trainMinutiae = trainMinutiae;
    results.valMinutiae = valMinutiae;
    results.testMinutiae = testMinutiae;
    
    % ======================================================================
    % ETAP 3: EKSTRAKCJA CECH Z MINUCJI
    % ======================================================================
    logInfo('ETAP 3: Ekstrakcja cech z minucji...', logFile);
    [trainFeatures, valFeatures, testFeatures] = extractMinutiaeFeatures(trainMinutiae, valMinutiae, testMinutiae, config, logFile);
    
    % Dodaj cechy do wyników
    results.trainFeatures = trainFeatures;
    results.valFeatures = valFeatures;
    results.testFeatures = testFeatures;
    
    % ======================================================================
    % ETAP 3.5: WERYFIKACJA EKSTRAKCJI CECH
    % ======================================================================
    try
        verifyFeatureExtraction(trainFeatures, valFeatures, testFeatures, trainMinutiae, valMinutiae, testMinutiae);
        
    catch ME
        logWarning(sprintf('Błąd weryfikacji cech: %s', ME.message), logFile);
    end
    
    % ======================================================================
    % ETAP 4: WIZUALIZACJE (jeśli wybrano) - WSZYSTKIE W JEDNYM MIEJSCU
    % ======================================================================
    if isfield(config, 'saveFigures') && config.saveFigures
        logInfo('ETAP 4: Generowanie kompletnych wizualizacji...', logFile);
        try
            % Utwórz folder na wizualizacje
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            vizDir = fullfile(config.figuresPath, sprintf('system_output_%s', timestamp));
            if ~exist(vizDir, 'dir')
                mkdir(vizDir);
                logInfo(sprintf('Utworzono folder wizualizacji: %s', vizDir), logFile);
            end
            
            % PRZEKAŻ WSZYSTKIE DANE DO WIZUALIZACJI (dane + minucje + cechy)
            minutiaeForViz = struct();
            minutiaeForViz.trainMinutiae = trainMinutiae;
            minutiaeForViz.valMinutiae = valMinutiae;
            minutiaeForViz.testMinutiae = testMinutiae;
            
            featuresForViz = struct();
            featuresForViz.trainFeatures = trainFeatures;
            featuresForViz.valFeatures = valFeatures;
            featuresForViz.testFeatures = testFeatures;
            
            generateSystemVisualizations(trainData, valData, testData, vizDir, logFile, minutiaeForViz, featuresForViz);
            
            % Dodaj ścieżkę do wyników
            results.visualizations.outputDir = vizDir;
            
            logSuccess('Kompletne wizualizacje wygenerowane pomyślnie!', logFile);
            fprintf('📊 Wizualizacje zapisane w: %s\n', vizDir);
            
        catch ME
            logWarning(sprintf('Błąd podczas generowania wizualizacji: %s', ME.message), logFile);
        end
    else
        logInfo('Pomijam generowanie wizualizacji (nie wybrano)', logFile);
    end
    
    % ======================================================================
    % PODSUMOWANIE
    % ======================================================================
    totalTime = toc(systemStart);
    
    % Zbierz wyniki
    results = struct();
    results.success = true;
    results.totalTime = totalTime;
    results.trainData = trainData;
    results.valData = valData;
    results.testData = testData;
    
    % Podstawowe statystyki
    results.stats.trainSamples = length(trainData.labels);
    results.stats.valSamples = length(valData.labels);
    results.stats.testSamples = length(testData.labels);
    results.stats.totalSamples = results.stats.trainSamples + results.stats.valSamples + results.stats.testSamples;
    
    logSuccess(sprintf('System ukończony w %.2f sekund!', totalTime), logFile);
    
    % Wyświetl podsumowanie
    fprintf('\n✅ SYSTEM UKOŃCZONY!\n');
    fprintf('📊 Przygotowano dane: Train=%d, Val=%d, Test=%d\n', ...
        results.stats.trainSamples, results.stats.valSamples, results.stats.testSamples);
    fprintf('⏱️  Całkowity czas: %.2f sekund\n', totalTime);
    
catch ME
    totalTime = toc(systemStart);
    logError(sprintf('Błąd w systemie: %s', ME.message), logFile);
    
    % Zwróć informacje o błędzie
    results = struct();
    results.success = false;
    results.error = ME.message;
    results.totalTime = totalTime;
    
    fprintf('\n❌ BŁĄD SYSTEMU: %s\n', ME.message);
end

% Zamknij log
closeLog(logFile, results.totalTime);
end

% USUŃ WSZYSTKIE FUNKCJE LOKALNE!
