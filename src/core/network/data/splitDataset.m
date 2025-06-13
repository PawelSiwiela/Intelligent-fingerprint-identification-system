function [trainData, valData, testData] = splitDataset(features, labels, metadata, splitRatio)
% SPLITDATASET Równomierny podział stratified na train/val/test
%
% Args:
%   features - macierz cech [samples x features]
%   labels - etykiety klas [samples x 1]
%   metadata - metadane z nazwami palców
%   splitRatio - [train_ratio, val_ratio, test_ratio] np. [0.7, 0.15, 0.15]
%
% Returns:
%   trainData, valData, testData - struktury z polami: features, labels, indices

if nargin < 4
    % splitRatio = [0.6, 0.2, 0.2]; % Większy val/test set
    splitRatio = [0.5, 0.25, 0.25]; % Jeszcze większy val/test
end

fprintf('\n🔄 Creating stratified dataset split...\n');

% Normalizuj ratios
splitRatio = splitRatio / sum(splitRatio);

uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);

trainIndices = [];
valIndices = [];
testIndices = [];

fprintf('Split ratios: Train=%.1f%%, Val=%.1f%%, Test=%.1f%%\n', ...
    splitRatio(1)*100, splitRatio(2)*100, splitRatio(3)*100);

% Stratified split dla każdej klasy
for i = 1:numClasses
    classLabel = uniqueLabels(i);
    classIndices = find(labels == classLabel);
    numSamples = length(classIndices);
    
    % Przetasuj indeksy klasy
    classIndices = classIndices(randperm(numSamples));
    
    % Oblicz liczby próbek dla każdego zbioru
    numTrain = round(numSamples * splitRatio(1));
    numVal = round(numSamples * splitRatio(2));
    numTest = numSamples - numTrain - numVal; % Reszta
    
    % Podziel indeksy
    trainIndices = [trainIndices; classIndices(1:numTrain)];
    valIndices = [valIndices; classIndices(numTrain+1:numTrain+numVal)];
    testIndices = [testIndices; classIndices(numTrain+numVal+1:end)];
    
    fingerName = metadata.fingerNames{classLabel};
    fprintf('  %s: %d samples -> Train:%d, Val:%d, Test:%d\n', ...
        fingerName, numSamples, numTrain, numVal, numTest);
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
fprintf('  Training:   %d samples (%.1f%%)\n', length(trainIndices), length(trainIndices)/length(labels)*100);
fprintf('  Validation: %d samples (%.1f%%)\n', length(valIndices), length(valIndices)/length(labels)*100);
fprintf('  Testing:    %d samples (%.1f%%)\n', length(testIndices), length(testIndices)/length(labels)*100);
fprintf('  Total:      %d samples\n', length(labels));

% Sprawdź balans klas
fprintf('\n🎯 Class balance verification:\n');
for i = 1:numClasses
    fingerName = metadata.fingerNames{uniqueLabels(i)};
    trainCount = sum(trainData.labels == uniqueLabels(i));
    valCount = sum(valData.labels == uniqueLabels(i));
    testCount = sum(testData.labels == uniqueLabels(i));
    
    fprintf('  %s: Train=%d, Val=%d, Test=%d\n', fingerName, trainCount, valCount, testCount);
end

fprintf('✅ Stratified dataset split completed!\n');
end