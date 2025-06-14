function [trainData, valData, testData] = splitDataset(features, labels, metadata, splitRatio)
% SPLITDATASET Równomierny podział stratified na train/val/test
%
% Args:
%   features - macierz cech [samples x features]
%   labels - etykiety klas [samples x 1]
%   metadata - metadane z nazwami palców
%   splitRatio - [train_count, val_count, test_count] LICZBA PRÓBEK per klasa
%
% Returns:
%   trainData, valData, testData - struktury z polami: features, labels, indices

if nargin < 4
    % STAŁA LICZBA PRÓBEK per klasa zamiast proporcji
    splitRatio = [7, 3, 4]; % Train: 7, Val: 3, Test: 4 próbek per klasa
end

fprintf('\n🔄 Creating stratified dataset split...\n');

% Sprawdź czy to są liczby próbek czy proporcje
if all(splitRatio <= 1) && abs(sum(splitRatio) - 1) < 0.1
    % To są proporcje - konwertuj na liczby próbek
    fprintf('⚠️  Converting proportions to fixed counts...\n');
    
    % Znajdź minimalną liczbę próbek per klasa
    uniqueLabels = unique(labels);
    minSamplesPerClass = inf;
    for i = 1:length(uniqueLabels)
        classCount = sum(labels == uniqueLabels(i));
        minSamplesPerClass = min(minSamplesPerClass, classCount);
    end
    
    % Konwertuj proporcje na liczby
    totalSamples = round(minSamplesPerClass * 0.9); % 90% dostępnych próbek
    splitCounts = round(splitRatio * totalSamples);
    
    % Upewnij się że suma nie przekracza dostępnych próbek
    if sum(splitCounts) > minSamplesPerClass
        fprintf('⚠️  Adjusting counts to fit available samples...\n');
        splitCounts = [4, 2, 2]; % Fallback
    end
    
    splitRatio = splitCounts;
    fprintf('🔧 Using fixed counts: Train=%d, Val=%d, Test=%d per class\n', ...
        splitRatio(1), splitRatio(2), splitRatio(3));
else
    % To już są liczby próbek
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

% Sprawdź czy każda klasa ma wystarczająco próbek
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

% STAŁY PODZIAŁ dla każdej klasy
fprintf('\n📦 Splitting with fixed counts per class:\n');
for i = 1:numClasses
    classLabel = uniqueLabels(i);
    classIndices = find(labels == classLabel);
    numSamples = length(classIndices);
    
    % Przetasuj indeksy klasy
    classIndices = classIndices(randperm(numSamples));
    
    % STAŁA LICZBA próbek per split
    currentTrainCount = min(trainCount, numSamples);
    currentValCount = min(valCount, max(0, numSamples - currentTrainCount));
    currentTestCount = min(testCount, max(0, numSamples - currentTrainCount - currentValCount));
    
    % Jeśli za mało próbek, dostosuj proporcjonalnie
    if numSamples < totalNeededPerClass
        totalAvailable = numSamples;
        ratio = [trainCount, valCount, testCount] / totalNeededPerClass;
        
        currentTrainCount = max(1, round(totalAvailable * ratio(1)));
        currentValCount = max(1, round(totalAvailable * ratio(2)));
        currentTestCount = max(0, totalAvailable - currentTrainCount - currentValCount);
        
        % Upewnij się że nie przekraczamy dostępnych próbek
        if currentTrainCount + currentValCount + currentTestCount > totalAvailable
            currentTestCount = totalAvailable - currentTrainCount - currentValCount;
        end
    end
    
    % Podziel indeksy
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

% Przetasuj finalne indeksy
trainIndices = trainIndices(randperm(length(trainIndices)));
valIndices = valIndices(randperm(length(valIndices)));
testIndices = testIndices(randperm(length(testIndices)));

% Utwórz struktury danych
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

% Podsumowanie
fprintf('\n📊 Final dataset sizes:\n');
fprintf('  Training:   %d samples\n', length(trainIndices));
fprintf('  Validation: %d samples\n', length(valIndices));
fprintf('  Testing:    %d samples\n', length(testIndices));
fprintf('  Total:      %d samples\n', length(labels));

% Sprawdź balans klas
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