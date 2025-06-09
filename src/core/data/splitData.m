function [trainData, valData, testData] = splitData(images, labels, config, logFile)
% SPLITDATA Dzieli zbiór danych na treningowy, walidacyjny i testowy
%   [trainData, valData, testData] = SPLITDATA(images, labels, config, logFile)
%   dzieli zbiór obrazów odcisków palców na zbiory treningowy, walidacyjny i
%   testowy zgodnie z podanymi w konfiguracji liczbami próbek.

% Czas rozpoczęcia
ticStart = tic;

% Sprawdzenie poprawności danych wejściowych
assert(length(images) == length(labels), 'Liczba obrazów nie jest równa liczbie etykiet');

% Liczba próbek dla każdego zbioru
trainSamples = config.trainSamples;
valSamples = config.valSamples;
testSamples = config.testSamples;

% Sprawdzenie czy suma próbek jest poprawna
expectedSamplesPerFinger = trainSamples + valSamples + testSamples;
assert(expectedSamplesPerFinger == config.samplesPerFinger, ...
    'Suma próbek (%d) nie jest zgodna z oczekiwaną liczbą próbek na palec (%d)', ...
    expectedSamplesPerFinger, config.samplesPerFinger);

% Liczba wszystkich próbek
numSamples = length(images);

% Liczba unikalnych klas (palców)
uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);

% Kontener na indeksy próbek dla każdego zbioru
trainIdx = [];
valIdx = [];
testIdx = [];

% Dla każdej klasy osobno wykonujemy podział stratyfikowany
for i = 1:numClasses
    % Indeksy próbek z danej klasy
    classIdx = find(labels == uniqueLabels(i));
    numClassSamples = length(classIdx);
    
    % Sprawdź czy mamy wystarczającą liczbę próbek
    if numClassSamples < expectedSamplesPerFinger
        warning(['Klasa %d ma tylko %d próbek, oczekiwano %d. ' ...
            'Dostosowuję podział proporcjonalnie.'], ...
            i, numClassSamples, expectedSamplesPerFinger);
        
        % Dostosowanie liczby próbek proporcjonalnie
        actualTrainSamples = floor(numClassSamples * (trainSamples / expectedSamplesPerFinger));
        actualValSamples = floor(numClassSamples * (valSamples / expectedSamplesPerFinger));
        actualTestSamples = numClassSamples - actualTrainSamples - actualValSamples;
    else
        % Użyj dokładnych liczb próbek
        actualTrainSamples = trainSamples;
        actualValSamples = valSamples;
        actualTestSamples = testSamples;
    end
    
    % Losowe przemieszanie indeksów
    classIdx = classIdx(randperm(numClassSamples));
    
    % Podział indeksów
    trainClassIdx = classIdx(1:actualTrainSamples);
    valClassIdx = classIdx(actualTrainSamples+1:actualTrainSamples+actualValSamples);
    testClassIdx = classIdx(actualTrainSamples+actualValSamples+1:end);
    
    % Dodanie do głównych list
    trainIdx = [trainIdx; trainClassIdx(:)];
    valIdx = [valIdx; valClassIdx(:)];
    testIdx = [testIdx; testClassIdx(:)];
end

% Tworzenie struktur danych wyjściowych
trainData.images = images(trainIdx);
trainData.labels = labels(trainIdx);
trainData.indices = trainIdx;  % Zapisanie indeksów

valData.images = images(valIdx);
valData.labels = labels(valIdx);
valData.indices = valIdx;      % Zapisanie indeksów

testData.images = images(testIdx);
testData.labels = labels(testIdx);
testData.indices = testIdx;    % Zapisanie indeksów

% Wyświetlenie podsumowania
timeElapsed = toc(ticStart);

% Logowanie informacji o podziale danych, jeśli podano plik dziennika
if nargin >= 4 && ~isempty(logFile)
    logInfo(sprintf('  Podział danych: %d próbek treningowych, %d walidacyjnych, %d testowych', ...
        length(trainData.labels), length(valData.labels), length(testData.labels)), logFile);
end
end