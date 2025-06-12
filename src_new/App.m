function App()
% TESTAPP Aplikacja testująca pipeline do ekstrakcji cech odcisków palców
%
% Etapy:
% 1. Wczytanie obrazów
% 2. Preprocessing
% 3. Ekstrakcja minucji
% 4. Ekstrakcja cech
% 5. Wizualizacje

clc;
fprintf('TEST APLIKACJI - PIPELINE DO CECH\n');
fprintf('%s\n', repmat('=', 1, 50));

try
    % Dodaj ścieżki
    addpath('config');
    addpath(genpath('utils'));
    addpath(genpath('image'));
    addpath(genpath('core'));
    
    % Załaduj konfigurację
    config = loadConfig();
    
    % Przygotuj log
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    logFile = fullfile(config.logsPath, sprintf('test_app_%s.log', timestamp));
    
    fprintf('Log: %s\n\n', logFile);
    
    systemStart = tic;
    
    % ETAP 1: WCZYTANIE OBRAZÓW
    fprintf('ETAP 1: Wczytywanie obrazów...\n');
    etap1Start = tic;
    
    [images, labels] = loadImages(config, logFile);
    
    etap1Time = toc(etap1Start);
    fprintf('ETAP 1 ukończony w %.2f sekund\n\n', etap1Time);
    
    % ETAP 2: PREPROCESSING
    fprintf('ETAP 2: Preprocessing obrazów...\n');
    etap2Start = tic;
    
    processedImages = cell(size(images));
    successCount = 0;
    failureCount = 0;
    
    for i = 1:length(images)
        try
            processedImages{i} = preprocessing(images{i}, logFile, false);
            successCount = successCount + 1;
            
            if mod(i, 10) == 0
                progressMsg = sprintf('   Przetworzono %d/%d obrazów...', i, length(images));
                fprintf('%s\n', progressMsg);
                logInfo(progressMsg, logFile);
            end
            
        catch ME
            logWarning(sprintf('Preprocessing failed for image %d: %s', i, ME.message), logFile);
            img = images{i};
            if size(img, 3) == 3, img = rgb2gray(img); end
            processedImages{i} = imbinarize(img);
            failureCount = failureCount + 1;
        end
    end
    
    etap2Time = toc(etap2Start);
    fprintf('ETAP 2 ukończony w %.2f sekund (%d sukces, %d błędów)\n\n', ...
        etap2Time, successCount, failureCount);
    
    % ETAP 3: EKSTRAKCJA MINUCJI
    fprintf('ETAP 3: Ekstrakcja minucji...\n');
    etap3Start = tic;
    
    allMinutiae = extractAllMinutiae(processedImages, labels, config, logFile);
    
    etap3Time = toc(etap3Start);
    fprintf('ETAP 3 ukończony w %.2f sekund\n\n', etap3Time);
    
    % ETAP 4: EKSTRAKCJA CECH
    fprintf('ETAP 4: Ekstrakcja cech z minucji...\n');
    etap4Start = tic;
    
    allFeatures = extractMinutiaeFeatures(allMinutiae, labels, config, logFile);
    
    etap4Time = toc(etap4Start);
    fprintf('ETAP 4 ukończony w %.2f sekund\n\n', etap4Time);
    
    % ETAP 5: WIZUALIZACJE
    fprintf('ETAP 5: Generowanie wizualizacji...\n');
    etap5Start = tic;
    
    % Wizualizacje minucji (przykład)
    if ~isempty(images) && ~isempty(allMinutiae)
        sampleIdx = find(~cellfun(@isempty, allMinutiae), 1);
        if ~isempty(sampleIdx)
            visualizeMinutiae(images{sampleIdx}, processedImages{sampleIdx}, ...
                allMinutiae{sampleIdx}, config.figuresPath, sprintf('sample_%d', sampleIdx), logFile);
        end
    end
    
    % Statystyki minucji
    visualizeMinutiaeStatistics(allMinutiae, labels, config.figuresPath, logFile);
    
    % Analiza cech
    visualizeFeatures(allFeatures, labels, config.figuresPath, logFile);
    
    etap5Time = toc(etap5Start);
    fprintf('ETAP 5 ukończony w %.2f sekund\n\n', etap5Time);
    
    % PODSUMOWANIE
    totalTime = toc(systemStart);
    
    fprintf('PIPELINE UKOŃCZONY POMYŚLNIE!\n');
    fprintf('%s\n', repmat('=', 1, 50));
    fprintf('STATYSTYKI:\n');
    fprintf('   Obrazów wczytanych: %d\n', length(images));
    fprintf('   Preprocessing: %d sukces, %d błędów\n', successCount, failureCount);
    fprintf('   Minucji ekstraktowanych: %d obrazów\n', length(allMinutiae));
    fprintf('   Macierz cech: %d x %d\n', size(allFeatures, 1), size(allFeatures, 2));
    fprintf('\nCZASY WYKONANIA:\n');
    fprintf('   Etap 1 (Wczytywanie): %.2f s\n', etap1Time);
    fprintf('   Etap 2 (Preprocessing): %.2f s\n', etap2Time);
    fprintf('   Etap 3 (Minucje): %.2f s\n', etap3Time);
    fprintf('   Etap 4 (Cechy): %.2f s\n', etap4Time);
    fprintf('   Etap 5 (Wizualizacje): %.2f s\n', etap5Time);
    fprintf('   ŁĄCZNIE: %.2f s\n', totalTime);
    
    % Zapisz wyniki do workspace
    assignin('base', 'images', images);
    assignin('base', 'labels', labels);
    assignin('base', 'processedImages', processedImages);
    assignin('base', 'allMinutiae', allMinutiae);
    assignin('base', 'allFeatures', allFeatures);
    
    fprintf('\nZmienne zapisane w workspace:\n');
    fprintf('   - images, labels\n');
    fprintf('   - processedImages\n');
    fprintf('   - allMinutiae\n');
    fprintf('   - allFeatures\n');
    
    closeLog(logFile, totalTime);
    
catch ME
    totalTime = toc(systemStart);
    fprintf('\nBŁĄD W APLIKACJI: %s\n', ME.message);
    
    if ~isempty(ME.stack)
        fprintf('Lokalizacja: %s, linia %d\n', ME.stack(1).name, ME.stack(1).line);
    end
    
    closeLog(logFile, totalTime);
    rethrow(ME);
end
end