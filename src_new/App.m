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
    fprintf('\n===== ETAP 1: WCZYTYWANIE OBRAZÓW =====\n');
    etap1Start = tic;
    
    [images, labels] = loadImages(config, logFile);
    
    etap1Time = toc(etap1Start);
    fprintf('✓ Wczytano %d obrazów w %.2f sekund\n', length(images), etap1Time);
    
    % ETAP 2: PREPROCESSING
    fprintf('\n===== ETAP 2: PREPROCESSING OBRAZÓW =====\n');
    etap2Start = tic;
    
    processedImages = cell(size(images));
    successCount = 0;
    failureCount = 0;
    
    fprintf('Przetwarzanie %d obrazów: ', length(images));
    
    for i = 1:length(images)
        try
            processedImages{i} = preprocessing(images{i}, logFile, false);
            successCount = successCount + 1;
            
            if mod(i, 10) == 0
                fprintf('.');
                progressMsg = sprintf('   Przetworzono %d/%d obrazów...', i, length(images));
                logInfo(progressMsg, logFile);
            end
            
        catch ME
            fprintf('x');
            logWarning(sprintf('Preprocessing failed for image %d: %s', i, ME.message), logFile);
            img = images{i};
            if size(img, 3) == 3, img = rgb2gray(img); end
            processedImages{i} = imbinarize(img);
            failureCount = failureCount + 1;
        end
    end
    
    etap2Time = toc(etap2Start);
    fprintf(' ukończono.\n');
    fprintf('✓ Preprocessing: %d sukcesów, %d błędów w %.2f sekund\n', ...
        successCount, failureCount, etap2Time);
    
    % ETAP 3: EKSTRAKCJA MINUCJI
    fprintf('\n===== ETAP 3: EKSTRAKCJA MINUCJI =====\n');
    etap3Start = tic;
    
    allMinutiae = extractAllMinutiae(processedImages, labels, config, logFile);
    
    etap3Time = toc(etap3Start);
    fprintf('✓ Ekstrakcja minucji ukończona w %.2f sekund\n', etap3Time);
    
    % ETAP 4: EKSTRAKCJA CECH
    fprintf('\n===== ETAP 4: EKSTRAKCJA CECH Z MINUCJI =====\n');
    etap4Start = tic;
    
    allFeatures = extractMinutiaeFeatures(allMinutiae, labels, config, logFile);
    
    etap4Time = toc(etap4Start);
    fprintf('✓ Ekstrakcja cech: macierz %dx%d w %.2f sekund\n', ...
        size(allFeatures, 1), size(allFeatures, 2), etap4Time);
    
    % ETAP 5: WIZUALIZACJE
    fprintf('\n===== ETAP 5: GENEROWANIE WIZUALIZACJI =====\n');
    etap5Start = tic;
    
    % Wizualizacje minucji (przykład)
    if ~isempty(images) && ~isempty(allMinutiae)
        sampleIdx = find(~cellfun(@isempty, allMinutiae), 1);
        if ~isempty(sampleIdx)
            fprintf('Wizualizacja przykładowych minucji... ');
            visualizeMinutiae(images{sampleIdx}, processedImages{sampleIdx}, ...
                allMinutiae{sampleIdx}, config.figuresPath, sprintf('sample_%d', sampleIdx), logFile);
            fprintf('ukończona.\n');
        end
    end
    
    % Statystyki minucji
    fprintf('Generowanie statystyk minucji... ');
    visualizeMinutiaeStatistics(allMinutiae, labels, config.figuresPath, logFile);
    fprintf('ukończone.\n');
    
    % Analiza cech
    fprintf('Generowanie wizualizacji cech... ');
    visualizeFeatures(allFeatures, labels, config.figuresPath, logFile);
    fprintf('ukończone.\n');
    
    etap5Time = toc(etap5Start);
    fprintf('✓ Wizualizacje ukończone w %.2f sekund\n', etap5Time);
    
    % PODSUMOWANIE
    totalTime = toc(systemStart);
    
    fprintf('\n%s\n', repmat('=', 1, 50));
    fprintf('🎉 PIPELINE UKOŃCZONY POMYŚLNIE!\n');
    fprintf('%s\n', repmat('=', 1, 50));
    
    % Oblicz łączną liczbę minucji używając cellfun
    totalMinutiae = sum(cellfun(@(m) size(m.all, 1), allMinutiae));
    
    fprintf('📊 Obrazów: %d | Minucji: %d | Cechy: %dx%d\n', ...
        length(images), totalMinutiae, size(allFeatures, 1), size(allFeatures, 2));
    
    fprintf('\n⏱️ CZASY WYKONANIA:\n');
    fprintf('   1️⃣ Wczytywanie:   %6.2f s\n', etap1Time);
    fprintf('   2️⃣ Preprocessing: %6.2f s\n', etap2Time);
    fprintf('   3️⃣ Minucje:       %6.2f s\n', etap3Time);
    fprintf('   4️⃣ Cechy:         %6.2f s\n', etap4Time);
    fprintf('   5️⃣ Wizualizacje:  %6.2f s\n', etap5Time);
    fprintf('   🕒 ŁĄCZNIE:       %6.2f s\n', totalTime);
    
    % Zapisz wyniki do workspace
    assignin('base', 'images', images);
    assignin('base', 'labels', labels);
    assignin('base', 'processedImages', processedImages);
    assignin('base', 'allMinutiae', allMinutiae);
    assignin('base', 'allFeatures', allFeatures);
    
    fprintf('\n📋 Zmienne zapisane w workspace.\n');
    fprintf('   (images, labels, processedImages, allMinutiae, allFeatures)\n\n');
    
    closeLog(logFile, totalTime);
    
catch ME
    totalTime = toc(systemStart);
    fprintf('\n❌ BŁĄD W APLIKACJI: %s\n', ME.message);
    
    if ~isempty(ME.stack)
        fprintf('Lokalizacja: %s, linia %d\n', ME.stack(1).name, ME.stack(1).line);
    end
    
    closeLog(logFile, totalTime);
    rethrow(ME);
end
end