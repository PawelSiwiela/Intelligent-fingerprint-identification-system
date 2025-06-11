function results = fingerprintRecognition(config, logFile)
% FINGERPRINTRECOGNITION Główny system rozpoznawania odcisków palców
%
% Input:
%   config - konfiguracja systemu z loadConfig()
%   logFile - plik logów (opcjonalny)
%
% Output:
%   results - struktura z wynikami kompletnego systemu

if nargin < 2, logFile = []; end

logInfo('=== SYSTEM ROZPOZNAWANIA ODCISKÓW PALCÓW ===', logFile);
systemStart = tic;

try
    % ======================================================================
    % ETAP 1: PRZYGOTOWANIE DANYCH
    % ======================================================================
    logInfo('ETAP 1: Przygotowanie danych...', logFile);
    [trainData, valData, testData] = prepareData(config, logFile);
    
    if isempty(trainData.images) || isempty(testData.images)
        error('Brak danych treningowych lub testowych po przygotowaniu');
    end
    
    % ======================================================================
    % ETAP 2: EKSTRAKCJA MINUCJI
    % ======================================================================
    logInfo('ETAP 2: Ekstrakcja minucji...', logFile);
    [trainMinutiae, valMinutiae, testMinutiae] = extractAllMinutiae(trainData, valData, testData, config, logFile);
    
    % ======================================================================
    % ETAP 3: EKSTRAKCJA CECH Z MINUCJI
    % ======================================================================
    logInfo('ETAP 3: Ekstrakcja cech z minucji...', logFile);
    [trainFeatures, valFeatures, testFeatures] = extractMinutiaeFeatures(trainMinutiae, valMinutiae, testMinutiae, config, logFile);
    
    % ======================================================================
    % ETAP 4: WIZUALIZACJE
    % ======================================================================
    if isfield(config, 'saveFigures') && config.saveFigures
        logInfo('ETAP 4: Generowanie wizualizacji...', logFile);
        try
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            vizDir = fullfile(config.figuresPath, sprintf('system_output_%s', timestamp));
            if ~exist(vizDir, 'dir')
                mkdir(vizDir);
            end
            
            minutiaeForViz = struct();
            minutiaeForViz.trainMinutiae = trainMinutiae;
            minutiaeForViz.valMinutiae = valMinutiae;
            minutiaeForViz.testMinutiae = testMinutiae;
            
            featuresForViz = struct();
            featuresForViz.trainFeatures = trainFeatures;
            featuresForViz.valFeatures = valFeatures;
            featuresForViz.testFeatures = testFeatures;
            
            generateSystemVisualizations(trainData, valData, testData, vizDir, logFile, minutiaeForViz, featuresForViz);
            
            logSuccess('Wizualizacje wygenerowane pomyślnie!', logFile);
            fprintf('📊 Wizualizacje zapisane w: %s\n', vizDir);
            
        catch ME
            logWarning(sprintf('Błąd podczas generowania wizualizacji: %s', ME.message), logFile);
        end
    end
    
    % ======================================================================
    % ETAP 5: SIECI NEURONOWE - PATTERNNET VS CNN
    % ======================================================================
    logInfo('ETAP 5: Porównanie sieci neuronowych PatternNet vs CNN...', logFile);
    
    try
        % Przygotuj dane dla sieci neuronowych
        X = [trainFeatures; valFeatures; testFeatures];
        
        % Przygotuj etykiety one-hot encoding
        allLabels = [trainData.labels(:); valData.labels(:); testData.labels(:)];
        Y = zeros(length(allLabels), 5);
        for i = 1:length(allLabels)
            if allLabels(i) >= 1 && allLabels(i) <= 5
                Y(i, allLabels(i)) = 1;
            end
        end
        
        fingerLabels = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};
        
        % Konfiguracja sieci
        networkConfig = struct();
        networkConfig.scenario = 'fingerprints';
        networkConfig.population_size = 4;
        networkConfig.num_generations = 2;
        networkConfig.mutation_rate = 0.15;
        networkConfig.optimization_method = 'genetic';
        networkConfig.show_visualizations = false;
        
        logInfo('📊 Dane przygotowane: %d próbek × %d cech → %d klas palców', ...
            size(X,1), size(X,2), size(Y,2), logFile);
        
        % Uruchom porównanie sieci
        networkResults = compareNetworks(X, Y, fingerLabels, networkConfig);
        
        % Zapisz wyniki
        results.networks = networkResults;
        
        % Podsumowanie
        if isfield(networkResults, 'patternnet') && isfield(networkResults.patternnet, 'evaluation')
            patternAccuracy = networkResults.patternnet.evaluation.accuracy * 100;
            logSuccess('✅ PatternNet dokładność: %.2f%%', patternAccuracy, logFile);
        end
        
        if isfield(networkResults, 'cnn') && isfield(networkResults.cnn, 'evaluation')
            cnnAccuracy = networkResults.cnn.evaluation.accuracy * 100;
            logSuccess('✅ CNN dokładność: %.2f%%', cnnAccuracy, logFile);
        end
        
        if isfield(networkResults, 'comparison') && isfield(networkResults.comparison, 'winner')
            winner = networkResults.comparison.winner;
            logSuccess('🏆 Zwycięzca: %s', upper(winner), logFile);
        end
        
    catch ME
        logError(sprintf('Błąd w ETAPIE 5 (sieci neuronowe): %s', ME.message), logFile);
        fprintf('❌ Błąd sieci neuronowych: %s\n', ME.message);
        
        results.networks = struct();
        results.networks.error = ME.message;
        results.networks.success = false;
    end
    
    % ======================================================================
    % PODSUMOWANIE
    % ======================================================================
    totalTime = toc(systemStart);
    
    results.success = true;
    results.totalTime = totalTime;
    results.trainData = trainData;
    results.valData = valData;
    results.testData = testData;
    results.trainMinutiae = trainMinutiae;
    results.valMinutiae = valMinutiae;
    results.testMinutiae = testMinutiae;
    results.trainFeatures = trainFeatures;
    results.valFeatures = valFeatures;
    results.testFeatures = testFeatures;
    
    if exist('vizDir', 'var')
        results.visualizations.outputDir = vizDir;
    end
    
    results.stats.trainSamples = length(trainData.labels);
    results.stats.valSamples = length(valData.labels);
    results.stats.testSamples = length(testData.labels);
    results.stats.totalSamples = results.stats.trainSamples + results.stats.valSamples + results.stats.testSamples;
    
    totalMinutiae = cellfun(@(x) size(x.all,1), [trainMinutiae; valMinutiae; testMinutiae]);
    results.stats.avgMinutiaePerImage = mean(totalMinutiae);
    
    logSuccess(sprintf('KOMPLETNY SYSTEM ukończony w %.2f sekund!', totalTime), logFile);
    
    fprintf('\n✅ KOMPLETNY SYSTEM UKOŃCZONY!\n');
    fprintf('📊 Dane: Train=%d, Val=%d, Test=%d\n', ...
        results.stats.trainSamples, results.stats.valSamples, results.stats.testSamples);
    fprintf('🔍 Średnio %.1f minucji na obraz\n', results.stats.avgMinutiaePerImage);
    if isfield(results, 'networks') && isfield(results.networks, 'comparison')
        fprintf('🧠 Najlepsza sieć: %s\n', upper(results.networks.comparison.winner));
    end
    fprintf('⏱️  Całkowity czas: %.2f sekund\n', totalTime);
    
catch ME
    totalTime = toc(systemStart);
    logError(sprintf('Błąd w systemie: %s', ME.message), logFile);
    
    results = struct();
    results.success = false;
    results.error = ME.message;
    results.totalTime = totalTime;
    
    fprintf('\n❌ BŁĄD SYSTEMU: %s\n', ME.message);
end

closeLog(logFile, results.totalTime);
end

