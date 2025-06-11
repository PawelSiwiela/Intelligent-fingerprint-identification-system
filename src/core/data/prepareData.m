function [trainData, valData, testData] = prepareData(config, logFile)
% PREPAREDATA Przygotowuje dane do treningu - główna funkcja
%
% Input:
%   config - konfiguracja systemu z loadConfig()
%   logFile - plik logów (opcjonalny)
%
% Output:
%   trainData - struktura z danymi treningowymi
%   valData - struktura z danymi walidacyjnymi
%   testData - struktura z danymi testowymi

if nargin < 2, logFile = []; end

logInfo('=== PRZYGOTOWANIE DANYCH ===', logFile);

% KROK 1: Wczytaj wszystkie obrazy
logInfo('KROK 1: Wczytywanie obrazów...', logFile);
tic;
[images, labels] = loadImages(config, logFile);
loadTime = toc;
logInfo(sprintf('Wczytano %d obrazów w %.2f sekund', length(images), loadTime), logFile);

% KROK 2: Preprocessing wszystkich obrazów
logInfo('KROK 2: Preprocessing wszystkich obrazów...', logFile);
tic;
processedImages = cell(size(images));
successCount = 0;
failureCount = 0;

for i = 1:length(images)
    try
        processedImages{i} = preprocessing(images{i}, logFile, false);
        successCount = successCount + 1;
        
        % Progress indicator co 10 obrazów
        if mod(i, 10) == 0
            fprintf('  Przetworzono %d/%d obrazów...\n', i, length(images));
        end
        
    catch ME
        logWarning(sprintf('Preprocessing failed for image %d: %s', i, ME.message), logFile);
        failureCount = failureCount + 1;
        
        % Fallback - podstawowa binaryzacja
        img = images{i};
        if size(img, 3) == 3, img = rgb2gray(img); end
        processedImages{i} = imbinarize(img);
    end
end

preprocessTime = toc;
logInfo(sprintf('Preprocessing ukończony: %d sukces, %d błędów w %.2f sekund', ...
    successCount, failureCount, preprocessTime), logFile);

% KROK 3: Podział na zbiory treningowy, walidacyjny i testowy
logInfo('KROK 3: Podział danych na zbiory...', logFile);
tic;
[trainData, valData, testData] = splitData(processedImages, labels, config, logFile);
splitTime = toc;

% KROK 4: Podsumowanie
totalTime = loadTime + preprocessTime + splitTime;
logInfo(sprintf('=== PRZYGOTOWANIE DANYCH UKOŃCZONE w %.2f sekund ===', totalTime), logFile);

% Wyświetl podsumowanie w konsoli
fprintf('\n📊 PODSUMOWANIE PRZYGOTOWANIA DANYCH:\n');
fprintf('  📂 Wczytywanie: %.2fs\n', loadTime);
fprintf('  🔧 Preprocessing: %.2fs (%d sukces, %d błędów)\n', preprocessTime, successCount, failureCount);
fprintf('  📋 Podział: %.2fs\n', splitTime);
fprintf('  ⏱️  Łącznie: %.2fs\n', totalTime);
fprintf('  📈 Zbiory: Train=%d, Val=%d, Test=%d\n', ...
    length(trainData.labels), length(valData.labels), length(testData.labels));

% Dodatkowe informacje w logach
logInfo(sprintf('Rozkład czasów: Load=%.2fs, Preprocess=%.2fs, Split=%.2fs', ...
    loadTime, preprocessTime, splitTime), logFile);
for finger = 1:5
    trainCount = sum(trainData.labels == finger);
    valCount = sum(valData.labels == finger);
    testCount = sum(testData.labels == finger);
    logInfo(sprintf('Palec %d: Train=%d, Val=%d, Test=%d', ...
        finger, trainCount, valCount, testCount), logFile);
end
end