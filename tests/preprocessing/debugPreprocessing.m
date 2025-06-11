function debugPreprocessing()
% DEBUGPREPROCESSING Test preprocessing pipeline na wszystkich obrazach

close all;
clear all;
clc;

fprintf('🔍 TEST PREPROCESSING - WSZYSTKIE OBRAZY\n');
fprintf('%s\n', repmat('=', 1, 50));

% Setup ścieżek
currentDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(currentDir));
addpath(genpath(fullfile(projectRoot, 'src')));

% Setup logFile
systemConfig = loadConfig();
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
logFile = fullfile(systemConfig.logsPath, sprintf('debug_preprocessing_all_%s.log', timestamp));

% Utwórz dedykowany folder na wyniki
outputDir = fullfile(systemConfig.figuresPath, sprintf('preprocessing_data_%s', timestamp));
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
    fprintf('📁 Utworzono folder: %s\n', outputDir);
end

% Wczytaj wszystkie obrazy
fprintf('📂 Wczytywanie obrazów...\n');
[images, labels] = loadImages(systemConfig, logFile);
numImages = length(images);
fprintf('✅ Wczytano %d obrazów\n\n', numImages);

% Przygotuj kontener na wyniki
results = struct();
results.times = zeros(1, numImages);
results.coverages = zeros(1, numImages);
results.errors = {};
results.success = true(1, numImages);

% PRZETWÓRZ WSZYSTKIE OBRAZY
fprintf('🔧 Preprocessing wszystkich obrazów...\n');
totalStart = tic;

fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};

for i = 1:numImages
    fprintf('  [%d/%d] %s... ', i, numImages, fingerNames{labels(i)});
    
    try
        % Preprocessing pojedynczego obrazu
        tic;
        processedImage = preprocessing(images{i}, logFile, false);
        elapsed = toc;
        
        % Oblicz metryki
        coverage = sum(processedImage(:)) / numel(processedImage) * 100;
        
        % Zapisz wyniki
        results.times(i) = elapsed;
        results.coverages(i) = coverage;
        
        fprintf('✅ %.3fs, %.2f%% ', elapsed, coverage);
        
        % ZAPISZ PORÓWNANIE (BEZ WYŚWIETLANIA)
        saveSingleComparison(images{i}, processedImage, i, labels(i), ...
            fingerNames{labels(i)}, elapsed, coverage, outputDir);
        
        fprintf('💾\n');
        
    catch ME
        % Zapisz błąd
        results.success(i) = false;
        results.errors{end+1} = sprintf('Obraz %d: %s', i, ME.message);
        fprintf('❌ BŁĄD: %s\n', ME.message);
    end
end

totalTime = toc(totalStart);

% ZAPISZ PODSUMOWANIE
saveSummaryReport(results, fingerNames, labels, totalTime, numImages, outputDir);

% PODSUMOWANIE W KONSOLI
fprintf('\n%s\n', repmat('=', 1, 50));
fprintf('📊 PODSUMOWANIE KOŃCOWE\n');
fprintf('%s\n', repmat('=', 1, 50));

successCount = sum(results.success);
failureCount = numImages - successCount;

fprintf('✅ Sukces: %d/%d obrazów (%.1f%%)\n', successCount, numImages, (successCount/numImages)*100);
fprintf('❌ Błędy: %d/%d obrazów (%.1f%%)\n', failureCount, numImages, (failureCount/numImages)*100);
fprintf('⏱️  Całkowity czas: %.2f sekund\n', totalTime);

if successCount > 0
    fprintf('⏱️  Średni czas na obraz: %.3f sekund\n', mean(results.times(results.success)));
    fprintf('📈 Średnie pokrycie: %.2f%%\n', mean(results.coverages(results.success)));
end

% ANALIZA WEDŁUG PALCÓW
fprintf('\n👆 ANALIZA WEDŁUG PALCÓW:\n');
for finger = 1:5
    fingerMask = labels == finger & results.success;
    if sum(fingerMask) > 0
        fingerCoverages = results.coverages(fingerMask);
        fingerTimes = results.times(fingerMask);
        fprintf('  %s: %d obrazów, śr.pokrycie=%.2f%%, śr.czas=%.3fs\n', ...
            fingerNames{finger}, sum(fingerMask), mean(fingerCoverages), mean(fingerTimes));
    else
        fprintf('  %s: brak udanych procesowań\n', fingerNames{finger});
    end
end

% WYPISZ BŁĘDY
if ~isempty(results.errors)
    fprintf('\n❌ SZCZEGÓŁY BŁĘDÓW:\n');
    for i = 1:length(results.errors)
        fprintf('   %s\n', results.errors{i});
    end
end

fprintf('\n✅ Test zakończony!\n');
fprintf('📁 Wszystkie wyniki zapisane w: %s\n', outputDir);
end

function saveSingleComparison(originalImage, processedImage, imageIndex, fingerLabel, fingerName, processingTime, coverage, outputDir)
% Zapisuje porównanie przed/po bez wyświetlania

% Utwórz niewidoczną figurę
fig = figure('Visible', 'off', 'Position', [0, 0, 800, 400]);

try
    % Oryginalny obraz
    subplot(1, 2, 1);
    imshow(originalImage);
    title(sprintf('ORYGINALNY\n%s (Palec %d)', fingerName, fingerLabel), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    % Dodaj informacje o rozmiarze
    [h, w] = size(originalImage);
    xlabel(sprintf('Rozmiar: %dx%d pikseli', h, w), 'FontSize', 10);
    
    % Przetworzony obraz
    subplot(1, 2, 2);
    imshow(processedImage);
    title(sprintf('PO PREPROCESSING\nPokrycie: %.2f%%', coverage), ...
        'FontSize', 14, 'FontWeight', 'bold', 'Color', getColorForCoverage(coverage));
    
    % Dodaj informacje o czasie
    xlabel(sprintf('Czas: %.3f s', processingTime), 'FontSize', 10);
    
    % Główny tytuł
    sgtitle(sprintf('OBRAZ #%d - %s', imageIndex, fingerName), ...
        'FontSize', 16, 'FontWeight', 'bold');
    
    % Zapisz figurę
    filename = sprintf('img_%03d_%s_palec%d.png', imageIndex, ...
        lower(strrep(strrep(fingerName, 'ą', 'a'), 'ś', 's')), fingerLabel);
    savePath = fullfile(outputDir, filename);
    
    % Zapisz w dobrej jakości
    print(fig, savePath, '-dpng', '-r200');
    
catch ME
    warning('Nie udało się zapisać porównania dla obrazu %d: %s', imageIndex, ME.message);
end

% Zamknij figurę
close(fig);
end

function saveSummaryReport(results, fingerNames, labels, totalTime, numImages, outputDir)
% Zapisuje raport podsumowujący w pliku tekstowym i jako wykres

successCount = sum(results.success);

% === RAPORT TEKSTOWY ===
reportFile = fullfile(outputDir, 'preprocessing_report.txt');
fid = fopen(reportFile, 'w');

if fid ~= -1
    fprintf(fid, '=== RAPORT PREPROCESSING ===\n');
    fprintf(fid, 'Data: %s\n', datestr(now));
    fprintf(fid, 'Obrazów przetworzonych: %d/%d (%.1f%%)\n', successCount, numImages, (successCount/numImages)*100);
    fprintf(fid, 'Całkowity czas: %.2f sekund\n', totalTime);
    
    if successCount > 0
        fprintf(fid, 'Średni czas na obraz: %.3f sekund\n', mean(results.times(results.success)));
        fprintf(fid, 'Średnie pokrycie: %.2f%%\n', mean(results.coverages(results.success)));
        
        fprintf(fid, '\n=== STATYSTYKI WEDŁUG PALCÓW ===\n');
        for finger = 1:5
            fingerMask = labels == finger & results.success;
            if sum(fingerMask) > 0
                fingerCoverages = results.coverages(fingerMask);
                fingerTimes = results.times(fingerMask);
                fprintf(fid, '%s: %d obrazów, śr.pokrycie=%.2f%%, śr.czas=%.3fs\n', ...
                    fingerNames{finger}, sum(fingerMask), mean(fingerCoverages), mean(fingerTimes));
            end
        end
    end
    
    if ~isempty(results.errors)
        fprintf(fid, '\n=== BŁĘDY ===\n');
        for i = 1:length(results.errors)
            fprintf(fid, '%s\n', results.errors{i});
        end
    end
    
    fclose(fid);
end

% === WYKRES PODSUMOWUJĄCY ===
if successCount > 0
    fig = figure('Visible', 'off', 'Position', [0, 0, 1200, 800]);
    
    try
        % 1. Histogram czasów
        subplot(2, 3, 1);
        validTimes = results.times(results.success);
        histogram(validTimes, min(20, length(validTimes)));
        xlabel('Czas [s]');
        ylabel('Liczba obrazów');
        title('Rozkład czasów przetwarzania');
        grid on;
        
        % 2. Histogram pokryć
        subplot(2, 3, 2);
        validCoverages = results.coverages(results.success);
        histogram(validCoverages, min(20, length(validCoverages)));
        xlabel('Pokrycie [%]');
        ylabel('Liczba obrazów');
        title('Rozkład pokrycia');
        grid on;
        
        % 3. Czas vs pokrycie
        subplot(2, 3, 3);
        scatter(validTimes, validCoverages, 30, 'filled');
        xlabel('Czas [s]');
        ylabel('Pokrycie [%]');
        title('Czas vs Pokrycie');
        grid on;
        
        % 4. Pokrycie według palców
        subplot(2, 3, 4);
        fingerCoverages = zeros(1, 5);
        fingerCounts = zeros(1, 5);
        for finger = 1:5
            fingerMask = labels == finger & results.success;
            if sum(fingerMask) > 0
                fingerCoverages(finger) = mean(results.coverages(fingerMask));
                fingerCounts(finger) = sum(fingerMask);
            end
        end
        bar(fingerCoverages);
        set(gca, 'XTickLabel', fingerNames);
        xtickangle(45);
        ylabel('Średnie pokrycie [%]');
        title('Pokrycie według palców');
        grid on;
        
        % 5. Czas według palców
        subplot(2, 3, 5);
        fingerTimes = zeros(1, 5);
        for finger = 1:5
            fingerMask = labels == finger & results.success;
            if sum(fingerMask) > 0
                fingerTimes(finger) = mean(results.times(fingerMask));
            end
        end
        bar(fingerTimes);
        set(gca, 'XTickLabel', fingerNames);
        xtickangle(45);
        ylabel('Średni czas [s]');
        title('Czas według palców');
        grid on;
        
        % 6. Statystyki tekstowe
        subplot(2, 3, 6);
        axis off;
        statsText = sprintf('PODSUMOWANIE\n\n');
        statsText = [statsText sprintf('Sukces: %d/%d (%.1f%%)\n', successCount, numImages, (successCount/numImages)*100)];
        statsText = [statsText sprintf('Całkowity czas: %.1fs\n', totalTime)];
        statsText = [statsText sprintf('Średni czas: %.3fs\n', mean(validTimes))];
        statsText = [statsText sprintf('Średnie pokrycie: %.2f%%\n', mean(validCoverages))];
        statsText = [statsText sprintf('\nMin pokrycie: %.2f%%\n', min(validCoverages))];
        statsText = [statsText sprintf('Max pokrycie: %.2f%%\n', max(validCoverages))];
        
        text(0.1, 0.9, statsText, 'FontSize', 12, 'VerticalAlignment', 'top', ...
            'HorizontalAlignment', 'left', 'FontName', 'Courier');
        
        sgtitle(sprintf('Analiza preprocessing - %s', datestr(now)), ...
            'FontSize', 16, 'FontWeight', 'bold');
        
        % Zapisz wykres
        summaryPath = fullfile(outputDir, 'preprocessing_summary.png');
        print(fig, summaryPath, '-dpng', '-r200');
        
        close(fig);
        
    catch ME
        close(fig);
    end
end
end

function color = getColorForCoverage(coverage)
% Zwraca kolor tekstu w zależności od pokrycia

if coverage < 1
    color = [0.8, 0, 0];      % Czerwony - bardzo słabe
elseif coverage < 3
    color = [0.8, 0.4, 0];    % Pomarańczowy - słabe
elseif coverage < 10
    color = [0, 0.6, 0];      % Zielony - dobre
else
    color = [0, 0, 0.8];      % Niebieski - bardzo dobre
end
end