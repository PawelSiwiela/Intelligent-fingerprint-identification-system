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
            
            % Generuj podstawowe wizualizacje
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

function generateSystemVisualizations(trainData, valData, testData, outputDir, logFile)
% Generuje podstawowe wizualizacje systemu

% 1. Przykładowe obrazy z każdego zbioru
showDatasetSamples(trainData, 'Training', outputDir);
showDatasetSamples(valData, 'Validation', outputDir);
showDatasetSamples(testData, 'Test', outputDir);

logInfo('Wygenerowano wizualizacje systemowe', logFile);
end

function showDatasetSamples(data, datasetName, outputDir)
% Pokazuje przykładowe obrazy z danego zbioru

if isempty(data.images), return; end

figure('Visible', 'off', 'Position', [0, 0, 1000, 600]);

% Pokaż po jednym przykładzie z każdego palca
sampleCount = 0;
for finger = 1:5
    fingerIndices = find(data.labels == finger);
    if ~isempty(fingerIndices)
        sampleCount = sampleCount + 1;
        subplot(2, 3, sampleCount);
        
        idx = fingerIndices(1);
        imshow(data.images{idx});
        
        coverage = sum(data.images{idx}(:)) / numel(data.images{idx}) * 100;
        title(sprintf('Palec %d\nPokrycie: %.1f%%', finger, coverage), ...
            'FontSize', 12, 'FontWeight', 'bold');
    end
end

sgtitle(sprintf('%s Dataset Samples (%d images)', datasetName, length(data.images)), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Zapisz
savePath = fullfile(outputDir, sprintf('%s_samples.png', lower(datasetName)));
print(gcf, savePath, '-dpng', '-r150');
close(gcf);
end
