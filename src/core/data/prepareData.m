function [trainData, valData, testData, dataInfo] = prepareData(config, logFile)
% PREPAREDATA Przygotowuje dane do treningu i ewaluacji
%   [trainData, valData, testData, dataInfo] = PREPAREDATA(config, logFile)
%   wczytuje i przetwarza obrazy odcisków palców, a następnie dzieli je
%   na zbiory treningowy, walidacyjny i testowy.
%
%   Parametry:
%     config - struktura zawierająca konfigurację
%     logFile - plik logu
%
%   Wyjście:
%     trainData - struktura zawierająca dane treningowe
%     valData - struktura zawierająca dane walidacyjne
%     testData - struktura zawierająca dane testowe
%     dataInfo - dodatkowe informacje o danych

% Czas rozpoczęcia
ticStart = tic;

logInfo('  Rozpoczynam przygotowanie danych...', logFile);

% Wczytanie obrazów
[images, labels] = loadImages(config, logFile);

% Informacje o wczytanych danych
dataInfo = struct();
dataInfo.numSamples = length(images);
dataInfo.uniqueLabels = unique(labels);
dataInfo.numClasses = length(dataInfo.uniqueLabels);
dataInfo.samplesPerClass = arrayfun(@(c) sum(labels == c), dataInfo.uniqueLabels);

logInfo(sprintf('  Wczytano %d próbek z %d klas', dataInfo.numSamples, dataInfo.numClasses), logFile);

% Sprawdzenie rozmiarów obrazów...
imageSizes = cellfun(@size, images, 'UniformOutput', false);
uniqueSizes = unique(cat(1, imageSizes{:}), 'rows');

% Logowanie informacji o rozmiarach obrazów
logInfo(sprintf('  Znaleziono %d różnych rozmiarów obrazów:', size(uniqueSizes, 1)), logFile);
for i = 1:size(uniqueSizes, 1)
    logInfo(sprintf('    - %dx%d: %d obrazów', ...
        uniqueSizes(i,1), uniqueSizes(i,2), ...
        sum(cellfun(@(x) isequal(size(x), uniqueSizes(i,:)), imageSizes))), logFile);
end

% Przeskalowanie obrazów (jeśli potrzebne)
if config.standardizeSize && size(uniqueSizes, 1) > 1
    logWarning('  Uwaga: Obrazy mają różne rozmiary. Przeprowadzam normalizację rozmiaru.', logFile);
    
    for i = 1:length(images)
        images{i} = imresize(images{i}, config.imageSize);
    end
    
    logInfo(sprintf('  Znormalizowano wszystkie obrazy do rozmiaru %dx%d', ...
        config.imageSize(1), config.imageSize(2)), logFile);
else
    logInfo('  Zachowano oryginalne rozmiary obrazów', logFile);
end

% NAJPIERW: Podział danych na zbiory treningowy, walidacyjny i testowy
[trainData, valData, testData] = splitData(images, labels, config, logFile);

% Utwórz katalog figur, jeśli nie istnieje
if ~exist(config.figuresPath, 'dir')
    mkdir(config.figuresPath);
    logInfo(sprintf('  Utworzono katalog figur: %s', config.figuresPath), logFile);
end

% Znajdź wszystkie próbki klasy 1
class1Indices = find(labels == 1);
logInfo(sprintf('  Znaleziono %d próbek dla klasy 1', length(class1Indices)), logFile);

% PREPROCESSING Z RÓŻNYMI METODAMI
methods = {'basic', 'hybrid', 'gabor', 'advanced'};
processedImagesSets = cell(length(methods), 1);

for methodIdx = 1:length(methods)
    currentMethod = methods{methodIdx};
    logInfo(sprintf('  Preprocessing metodą: %s', currentMethod), logFile);
    
    processedImagesSets{methodIdx} = cell(size(images));
    
    for i = 1:length(images)
        fingerClass = labels(i);
        
        % Preprocessing z wybraną metodą
        processedImagesSets{methodIdx}{i} = preprocessImageAdvanced(images{i}, config, logFile, fingerClass, currentMethod);
        
        % Zapisz wizualizacje dla klasy 1
        if fingerClass == 1
            sampleIdx = find(class1Indices == i, 1);
            if ~isempty(sampleIdx)
                visualizationPath = fullfile(config.figuresPath, ...
                    sprintf('class1_sample%d_%s.png', sampleIdx, currentMethod));
                
                % Utwórz porównawczą wizualizację
                visualizeMethodComparison(images{i}, processedImagesSets{methodIdx}{i}, ...
                    config, visualizationPath, currentMethod, sampleIdx);
                
                logInfo(sprintf('  Zapisano wizualizację %s dla klasy 1, próbka %d', currentMethod, sampleIdx), logFile);
            end
        end
    end
    
    % Wyświetl postęp
    logInfo(sprintf('  Zakończono preprocessing metodą %s', currentMethod), logFile);
end

% Dodaj wszystkie wersje do struktur danych
for methodIdx = 1:length(methods)
    trainData.processedImagesSets{methodIdx} = processedImagesSets{methodIdx}(trainData.indices);
    valData.processedImagesSets{methodIdx} = processedImagesSets{methodIdx}(valData.indices);
    testData.processedImagesSets{methodIdx} = processedImagesSets{methodIdx}(testData.indices);
end

trainData.methods = methods;
valData.methods = methods;
testData.methods = methods;

% Dodanie podstawowych przetworzonych obrazów (dla kompatybilności wstecznej)
trainData.processedImages = processedImagesSets{1}(trainData.indices); % basic method
valData.processedImages = processedImagesSets{1}(valData.indices);
testData.processedImages = processedImagesSets{1}(testData.indices);

% Uzupełnienie informacji o danych
dataInfo.trainSize = length(trainData.labels);
dataInfo.valSize = length(valData.labels);
dataInfo.testSize = length(testData.labels);
dataInfo.imageSize = size(images{1});

% Po zakończeniu wszystkich metod, utwórz porównawcze wizualizacje
logInfo('  Tworzę porównawcze wizualizacje metod...', logFile);

for i = 1:length(class1Indices)
    try
        imgIdx = class1Indices(i);
        sampleIdx = i;
        
        % Pobierz przetworzone obrazy wszystkimi metodami dla tej próbki
        sampleProcessedImages = cell(length(methods), 1);
        for methodIdx = 1:length(methods)
            sampleProcessedImages{methodIdx} = processedImagesSets{methodIdx}{imgIdx};
        end
        
        % Sprawdź czy mamy wszystkie potrzebne obrazy
        if all(~cellfun(@isempty, sampleProcessedImages))
            % Utwórz wizualizację porównawczą wszystkich metod
            comparisonPath = fullfile(config.figuresPath, ...
                sprintf('class1_sample%d_ALL_METHODS.png', sampleIdx));
            
            visualizeAllMethods(images{imgIdx}, sampleProcessedImages, methods, ...
                config, comparisonPath, sampleIdx);
            
            logInfo(sprintf('  Zapisano porównanie wszystkich metod dla próbki %d', sampleIdx), logFile);
        else
            logWarning(sprintf('  Pominięto próbkę %d - brak niektórych przetworzonych obrazów', sampleIdx), logFile);
        end
        
    catch vizError
        logError(sprintf('  Błąd wizualizacji dla próbki %d: %s', sampleIdx, vizError.message), logFile);
        continue;
    end
end

% Wyświetlenie podsumowania
timeElapsed = toc(ticStart);
logSuccess(sprintf('  Przygotowanie danych zakończone w %.2f sekund', timeElapsed), logFile);
end