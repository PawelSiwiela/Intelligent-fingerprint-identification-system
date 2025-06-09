function [trainData, valData, testData, dataInfo] = prepareData(config, logFile)
% PREPAREDATA Przygotowuje dane do treningu i ewaluacji
%   [trainData, valData, testData, dataInfo] = PREPAREDATA(config, logFile)
%   wczytuje i przetwarza obrazy odcisków palców, a następnie dzieli je
%   na zbiory treningowy, walidacyjny i testowy.
%
%   Parametry:
%     config - struktura zawierająca konfigurację
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

% Sprawdzenie, czy obrazy mają ten sam rozmiar
imageSizes = cellfun(@size, images, 'UniformOutput', false);
uniqueSizes = unique(cat(1, imageSizes{:}), 'rows');

if size(uniqueSizes, 1) > 1
    logWarning('  Uwaga: Obrazy mają różne rozmiary. Przeprowadzam normalizację rozmiaru.', logFile);
    
    % Wybierz rozmiar docelowy
    if isfield(config, 'imageSize')
        targetSize = config.imageSize;
    else
        % Użyj mediany rozmiarów jako docelowego rozmiaru
        medianSize = median(cat(1, imageSizes{:}), 1);
        targetSize = round(medianSize(1:2));
    end
    
    logInfo(sprintf('  Normalizuję wszystkie obrazy do rozmiaru %dx%d', targetSize(1), targetSize(2)), logFile);
    
    % Przeskalowanie obrazów do jednolitego rozmiaru
    for i = 1:length(images)
        images{i} = imresize(images{i}, targetSize);
    end
end

% Podział danych na zbiory treningowy, walidacyjny i testowy
[trainData, valData, testData] = splitData(images, labels, config, logFile);

% Uzupełnienie informacji o danych
dataInfo.trainSize = length(trainData.labels);
dataInfo.valSize = length(valData.labels);
dataInfo.testSize = length(testData.labels);
dataInfo.imageSize = size(images{1});

% Wyświetlenie podsumowania
timeElapsed = toc(ticStart);
logSuccess(sprintf('  Przygotowanie danych zakończone w %.2f sekund', timeElapsed), logFile);
end