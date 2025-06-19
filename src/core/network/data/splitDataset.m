function [trainData, valData, testData] = splitDataset(features, labels, metadata, splitRatio)
% SPLITDATASET Stratyfikowany podział zbioru cech na train/val/test z stałą liczbą próbek
%
% Funkcja wykonuje stratyfikowany podział macierzy cech na zbiory treningowy,
% walidacyjny i testowy, zapewniając równomierną reprezentację każdej klasy.
% Używa stałej liczby próbek per klasa zamiast proporcji procentowych dla
% lepszej kontroli nad balansowaniem małych zbiorów danych.
%
% Parametry wejściowe:
%   features - macierz cech [samples × features] (output feature extraction)
%   labels - wektor etykiet klas [samples × 1] (ID palców)
%   metadata - struktura metadanych z nazwami palców (metadata.fingerNames)
%   splitRatio - [train_count, val_count, test_count] liczba próbek per klasa
%                domyślnie: [7, 3, 4] = 7 train + 3 val + 4 test per klasa
%
% Parametry wyjściowe:
%   trainData - struktura: {features, labels, indices}
%   valData - struktura: {features, labels, indices}
%   testData - struktura: {features, labels, indices}
%
% Algorytm:
%   1. Wykrywanie i konwersja proporcji na stałe liczby jeśli potrzeba
%   2. Analiza dostępności próbek per klasa
%   3. Stratyfikowany podział z adaptacyjnym dostosowaniem dla małych klas
%   4. Randomizacja kolejności w każdym zbiorze
%   5. Weryfikacja balansu klas i raportowanie statystyk
%
% Przykład użycia:
%   [train, val, test] = splitDataset(featureMatrix, labels, metadata, [9,2,3]);

if nargin < 4
    % Domyślne stałe liczby próbek per klasa - sprawdzone empirycznie
    splitRatio = [7, 3, 4]; % Train: 7, Val: 3, Test: 4 próbek per klasa
end

fprintf('\n🔄 Creating stratified dataset split...\n');

% Wykrywanie formatu splitRatio i konwersja jeśli to proporcje
if all(splitRatio <= 1) && abs(sum(splitRatio) - 1) < 0.1
    % Wykryto format proporcjonalny - konwertuj na stałe liczby
    fprintf('⚠️  Converting proportions to fixed counts...\n');
    
    % Znajdź minimalną liczbę próbek per klasa jako ograniczenie górne
    uniqueLabels = unique(labels);
    minSamplesPerClass = inf;
    for i = 1:length(uniqueLabels)
        classCount = sum(labels == uniqueLabels(i));
        minSamplesPerClass = min(minSamplesPerClass, classCount);
    end
    
    % Konwertuj proporcje na liczby z buforem bezpieczeństwa
    totalSamples = round(minSamplesPerClass * 0.9); % 90% dostępnych próbek
    splitCounts = round(splitRatio * totalSamples);
    
    % Walidacja - upewnij się że suma nie przekracza dostępnych próbek
    if sum(splitCounts) > minSamplesPerClass
        fprintf('⚠️  Adjusting counts to fit available samples...\n');
        splitCounts = [4, 2, 2]; % Konserwatywny fallback
    end
    
    splitRatio = splitCounts;
    fprintf('🔧 Using fixed counts: Train=%d, Val=%d, Test=%d per class\n', ...
        splitRatio(1), splitRatio(2), splitRatio(3));
else
    % Format już zawiera stałe liczby próbek
    fprintf('📊 Using fixed counts: Train=%d, Val=%d, Test=%d per class\n', ...
        splitRatio(1), splitRatio(2), splitRatio(3));
end

trainCount = splitRatio(1);
valCount = splitRatio(2);
testCount = splitRatio(3);
totalNeededPerClass = trainCount + valCount + testCount;

uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);

trainIndices = [];
valIndices = [];
testIndices = [];

% Analiza dostępności próbek - sprawdź czy każda klasa ma wystarczająco danych
fprintf('\n🔍 Checking class sample availability:\n');
for i = 1:numClasses
    classLabel = uniqueLabels(i);
    classCount = sum(labels == classLabel);
    fingerName = metadata.fingerNames{classLabel};
    
    fprintf('  %s: %d samples available, %d needed\n', ...
        fingerName, classCount, totalNeededPerClass);
    
    if classCount < totalNeededPerClass
        fprintf('  ⚠️  WARNING: Not enough samples for %s!\n', fingerName);
    end
end

% Stratyfikowany podział z stałą liczbą próbek per klasa
fprintf('\n📦 Splitting with fixed counts per class:\n');
for i = 1:numClasses
    classLabel = uniqueLabels(i);
    classIndices = find(labels == classLabel);
    numSamples = length(classIndices);
    
    % Randomizacja kolejności indeksów klasy
    classIndices = classIndices(randperm(numSamples));
    
    % Określ liczbę próbek dla każdego zbioru z ograniczeniem dostępności
    currentTrainCount = min(trainCount, numSamples);
    currentValCount = min(valCount, max(0, numSamples - currentTrainCount));
    currentTestCount = min(testCount, max(0, numSamples - currentTrainCount - currentValCount));
    
    % Adaptacyjne dostosowanie dla bardzo małych klas
    if numSamples < totalNeededPerClass
        totalAvailable = numSamples;
        ratio = [trainCount, valCount, testCount] / totalNeededPerClass;
        
        % Proporcjonalne skalowanie z minimum 1 próbka gdzie możliwe
        currentTrainCount = max(1, round(totalAvailable * ratio(1)));
        currentValCount = max(1, round(totalAvailable * ratio(2)));
        currentTestCount = max(0, totalAvailable - currentTrainCount - currentValCount);
        
        % Kontrola spójności - nie przekraczaj dostępnych próbek
        if currentTrainCount + currentValCount + currentTestCount > totalAvailable
            currentTestCount = totalAvailable - currentTrainCount - currentValCount;
        end
    end
    
    % Przypisanie indeksów do odpowiednich zbiorów
    if currentTrainCount > 0
        trainIndices = [trainIndices; classIndices(1:currentTrainCount)];
    end
    
    if currentValCount > 0
        valStart = currentTrainCount + 1;
        valEnd = currentTrainCount + currentValCount;
        valIndices = [valIndices; classIndices(valStart:valEnd)];
    end
    
    if currentTestCount > 0
        testStart = currentTrainCount + currentValCount + 1;
        testEnd = currentTrainCount + currentValCount + currentTestCount;
        testIndices = [testIndices; classIndices(testStart:testEnd)];
    end
    
    fingerName = metadata.fingerNames{classLabel};
    fprintf('  %s: %d samples -> Train:%d, Val:%d, Test:%d\n', ...
        fingerName, numSamples, currentTrainCount, currentValCount, currentTestCount);
end

% Finalna randomizacja kolejności w każdym zbiorze
trainIndices = trainIndices(randperm(length(trainIndices)));
valIndices = valIndices(randperm(length(valIndices)));
testIndices = testIndices(randperm(length(testIndices)));

% Tworzenie struktur danych wyjściowych
trainData = struct();
trainData.features = features(trainIndices, :);
trainData.labels = labels(trainIndices);
trainData.indices = trainIndices;

valData = struct();
valData.features = features(valIndices, :);
valData.labels = labels(valIndices);
valData.indices = valIndices;

testData = struct();
testData.features = features(testIndices, :);
testData.labels = labels(testIndices);
testData.indices = testIndices;

% Raportowanie statystyk końcowych
fprintf('\n📊 Final dataset sizes:\n');
fprintf('  Training:   %d samples\n', length(trainIndices));
fprintf('  Validation: %d samples\n', length(valIndices));
fprintf('  Testing:    %d samples\n', length(testIndices));
fprintf('  Total:      %d samples\n', length(labels));

% Weryfikacja balansu klas w końcowych zbiorach
fprintf('\n🎯 Final class distribution:\n');
for i = 1:numClasses
    fingerName = metadata.fingerNames{uniqueLabels(i)};
    trainClassCount = sum(trainData.labels == uniqueLabels(i));
    valClassCount = sum(valData.labels == uniqueLabels(i));
    testClassCount = sum(testData.labels == uniqueLabels(i));
    
    fprintf('  %s: Train=%d, Val=%d, Test=%d\n', ...
        fingerName, trainClassCount, valClassCount, testClassCount);
end

fprintf('✅ Stratified dataset split completed!\n');
end