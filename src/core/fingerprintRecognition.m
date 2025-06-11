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
    % ETAP 1: PRZYGOTOWANIE DANYCH (jedyny dostępny etap)
    % ======================================================================
    logInfo('ETAP 1: Przygotowanie danych...', logFile);
    [trainData, valData, testData] = prepareData(config, logFile);
    
    % Sprawdź czy dane zostały poprawnie przygotowane
    if isempty(trainData.images) || isempty(testData.images)
        error('Brak danych treningowych lub testowych po przygotowaniu');
    end
    
    % ======================================================================
    % ETAP 2: WIZUALIZACJE (jeśli wybrano)
    % ======================================================================
    if isfield(config, 'saveFigures') && config.saveFigures
        logInfo('ETAP 2: Generowanie wizualizacji...', logFile);
        try
            % Utwórz folder na wizualizacje
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            vizDir = fullfile(config.figuresPath, sprintf('system_output_%s', timestamp));
            if ~exist(vizDir, 'dir')
                mkdir(vizDir);
                logInfo(sprintf('Utworzono folder wizualizacji: %s', vizDir), logFile);
            end
            
            % WYWOŁAJ ZEWNĘTRZNĄ FUNKCJĘ
            generateSystemVisualizations(trainData, valData, testData, vizDir, logFile);
            
            % Dodaj ścieżkę do wyników
            results.visualizations.outputDir = vizDir;
            
            logSuccess('Wizualizacje wygenerowane pomyślnie!', logFile);
            fprintf('📊 Wizualizacje zapisane w: %s\n', vizDir);
            
        catch ME
            logWarning(sprintf('Błąd podczas generowania wizualizacji: %s', ME.message), logFile);
        end
    else
        logInfo('Pomijam generowanie wizualizacji (nie wybrano)', logFile);
    end
    
    % ======================================================================
    % PODSUMOWANIE (tylko to co mamy)
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
    
    logSuccess(sprintf('Przygotowanie danych ukończone w %.2f sekund!', totalTime), logFile);
    
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
