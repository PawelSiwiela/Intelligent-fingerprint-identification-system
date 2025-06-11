function [trainData, valData, testData] = splitData(images, labels, config, logFile)
% SPLITDATA Dzieli dane na zbiory treningowy, walidacyjny i testowy
%
% Input:
%   images - cell array przetworzonych obrazów
%   labels - wektor etykiet (1-5)
%   config - konfiguracja z loadConfig()
%   logFile - plik logów (opcjonalny)
%
% Output:
%   trainData - struktura: .images (cell), .labels (vector)
%   valData - struktura: .images (cell), .labels (vector)
%   testData - struktura: .images (cell), .labels (vector)

if nargin < 4, logFile = []; end

% Inicjalizacja struktur danych
trainData = struct('images', {{}}, 'labels', []);
valData = struct('images', {{}}, 'labels', []);
testData = struct('images', {{}}, 'labels', []);

% Nazwa palców dla logowania
fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};

logInfo('Rozpoczęto podział danych...', logFile);

% Ustaw seed dla powtarzalności
if isfield(config, 'experiment') && isfield(config.experiment, 'randomSeed')
    rng(config.experiment.randomSeed);
    logInfo(sprintf('Ustawiono random seed: %d', config.experiment.randomSeed), logFile);
else
    rng(42); % Domyślny seed
    logInfo('Ustawiono domyślny random seed: 42', logFile);
end

% Podział dla każdego palca osobno
for finger = 1:5
    fingerIndices = find(labels == finger);
    numSamples = length(fingerIndices);
    
    logInfo(sprintf('Palec %d (%s): %d próbek', finger, fingerNames{finger}, numSamples), logFile);
    
    % Sprawdź czy jest wystarczająco próbek
    requiredSamples = config.trainSamples + config.valSamples + config.testSamples;
    if numSamples < requiredSamples
        logWarning(sprintf('Palec %d: tylko %d próbek (wymagane %d)', ...
            finger, numSamples, requiredSamples), logFile);
    end
    
    % Losowo pomieszaj indeksy dla tego palca
    shuffledIndices = fingerIndices(randperm(length(fingerIndices)));
    
    % Oblicz rzeczywiste liczby próbek (jeśli za mało danych)
    actualTrain = min(config.trainSamples, numSamples);
    remainingSamples = numSamples - actualTrain;
    
    actualVal = min(config.valSamples, remainingSamples);
    remainingSamples = remainingSamples - actualVal;
    
    actualTest = min(config.testSamples, remainingSamples);
    
    logInfo(sprintf('  Rzeczywisty podział: Train=%d, Val=%d, Test=%d', ...
        actualTrain, actualVal, actualTest), logFile);
    
    % ZBIÓR TRENINGOWY
    if actualTrain > 0
        trainIndices = shuffledIndices(1:actualTrain);
        trainData.images = [trainData.images, images(trainIndices)];
        trainData.labels = [trainData.labels, labels(trainIndices)];
    end
    
    % ZBIÓR WALIDACYJNY
    if actualVal > 0
        valStart = actualTrain + 1;
        valEnd = actualTrain + actualVal;
        valIndices = shuffledIndices(valStart:valEnd);
        valData.images = [valData.images, images(valIndices)];
        valData.labels = [valData.labels, labels(valIndices)];
    end
    
    % ZBIÓR TESTOWY
    if actualTest > 0
        testStart = actualTrain + actualVal + 1;
        testEnd = actualTrain + actualVal + actualTest;
        testIndices = shuffledIndices(testStart:testEnd);
        testData.images = [testData.images, images(testIndices)];
        testData.labels = [testData.labels, labels(testIndices)];
    end
end

% Konwertuj labels z cell arrays na vectors (jeśli potrzeba)
if iscell(trainData.labels), trainData.labels = cell2mat(trainData.labels); end
if iscell(valData.labels), valData.labels = cell2mat(valData.labels); end
if iscell(testData.labels), testData.labels = cell2mat(testData.labels); end

% Podsumowanie końcowe
totalTrain = length(trainData.labels);
totalVal = length(valData.labels);
totalTest = length(testData.labels);
totalAll = totalTrain + totalVal + totalTest;

logInfo(sprintf('Podział ukończony: %d próbek podzielonych na Train=%d, Val=%d, Test=%d', ...
    totalAll, totalTrain, totalVal, totalTest), logFile);

% Sprawdź balans klas
fprintf('\n📋 SZCZEGÓŁOWY PODZIAŁ DANYCH:\n');
fprintf('%-12s | %-5s | %-3s | %-4s | %-4s\n', 'Palec', 'Train', 'Val', 'Test', 'Suma');
fprintf('%s\n', repmat('-', 1, 45));

for finger = 1:5
    trainCount = sum(trainData.labels == finger);
    valCount = sum(valData.labels == finger);
    testCount = sum(testData.labels == finger);
    totalCount = trainCount + valCount + testCount;
    
    fprintf('%-12s | %-5d | %-3d | %-4d | %-4d\n', ...
        fingerNames{finger}, trainCount, valCount, testCount, totalCount);
    
    logInfo(sprintf('Palec %d końcowy podział: Train=%d, Val=%d, Test=%d, Suma=%d', ...
        finger, trainCount, valCount, testCount, totalCount), logFile);
end

fprintf('%s\n', repmat('-', 1, 45));
fprintf('%-12s | %-5d | %-3d | %-4d | %-4d\n', ...
    'ŁĄCZNIE', totalTrain, totalVal, totalTest, totalAll);

% Sprawdź czy dane są zbalansowane
minSamples = min([totalTrain, totalVal, totalTest]);
maxSamples = max([totalTrain, totalVal, totalTest]);
balanceRatio = minSamples / maxSamples;

if balanceRatio > 0.8
    logInfo(sprintf('Dane są dobrze zbalansowane (stosunek: %.2f)', balanceRatio), logFile);
else
    logWarning(sprintf('Dane są niezbalansowane (stosunek: %.2f)', balanceRatio), logFile);
end

logInfo('Podział danych zakończony pomyślnie', logFile);
end