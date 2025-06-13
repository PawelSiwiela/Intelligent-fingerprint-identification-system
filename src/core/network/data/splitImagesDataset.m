function [trainData, valData, testData] = splitImagesDataset(preprocessedImages, validImageIndices, labels, metadata, splitRatio)
% SPLITIMAGESDATASET Stratified podział obrazów na train/val/test dla CNN
%
% Args:
%   preprocessedImages - cell array z przetworzonymi obrazami
%   validImageIndices - indeksy obrazów które zostały poprawnie przetworzone
%   labels - etykiety klas dla validImageIndices
%   metadata - metadane z nazwami palców
%   splitRatio - [train_ratio, val_ratio, test_ratio] np. [0.7, 0.15, 0.15]
%
% Returns:
%   trainData, valData, testData - struktury z polami: images, labels, indices

if nargin < 5
    splitRatio = [0.7, 0.15, 0.15]; % Standardowy podział
end

fprintf('\n🖼️  Creating stratified IMAGES dataset split for CNN...\n');

% Normalizuj ratios
splitRatio = splitRatio / sum(splitRatio);

% Sprawdź czy mamy prawidłowe dane
if length(validImageIndices) ~= length(labels)
    error('Length mismatch: validImageIndices=%d, labels=%d', ...
        length(validImageIndices), length(labels));
end

uniqueLabels = unique(labels);
numClasses = length(uniqueLabels);
numValidImages = length(validImageIndices);

trainIndices = [];
valIndices = [];
testIndices = [];

fprintf('Total valid images: %d\n', numValidImages);
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
    numTrain = max(1, round(numSamples * splitRatio(1))); % Co najmniej 1 próbka
    numVal = max(1, round(numSamples * splitRatio(2)));
    numTest = max(1, numSamples - numTrain - numVal); % Reszta, co najmniej 1
    
    % Jeśli za mało próbek, dostosuj
    if numTrain + numVal + numTest > numSamples
        if numSamples >= 3
            numTrain = ceil(numSamples / 3);
            numVal = ceil(numSamples / 3);
            numTest = numSamples - numTrain - numVal;
        else
            % Bardzo mało próbek - daj wszystko do train
            numTrain = numSamples;
            numVal = 0;
            numTest = 0;
        end
    end
    
    % Podziel indeksy
    if numTrain > 0
        trainIndices = [trainIndices; classIndices(1:numTrain)];
    end
    if numVal > 0
        valIndices = [valIndices; classIndices(numTrain+1:numTrain+numVal)];
    end
    if numTest > 0
        testIndices = [testIndices; classIndices(numTrain+numVal+1:numTrain+numVal+numTest)];
    end
    
    fingerName = metadata.fingerNames{classLabel};
    fprintf('  %s: %d images -> Train:%d, Val:%d, Test:%d\n', ...
        fingerName, numSamples, numTrain, numVal, numTest);
end

% Przetasuj finalne indeksy
if ~isempty(trainIndices)
    trainIndices = trainIndices(randperm(length(trainIndices)));
end
if ~isempty(valIndices)
    valIndices = valIndices(randperm(length(valIndices)));
end
if ~isempty(testIndices)
    testIndices = testIndices(randperm(length(testIndices)));
end

% Przygotuj obrazy dla każdego zbioru
fprintf('\n📸 Preparing image arrays...\n');

% TRAINING DATA
trainData = struct();
if ~isempty(trainIndices)
    trainData.images = cell(length(trainIndices), 1);
    trainData.labels = labels(trainIndices);
    trainData.originalIndices = validImageIndices(trainIndices); % Indeksy w oryginalnym zbiorze
    
    for i = 1:length(trainIndices)
        originalImageIdx = validImageIndices(trainIndices(i));
        trainData.images{i} = preprocessedImages{originalImageIdx};
    end
    
    fprintf('  Training: %d images loaded\n', length(trainIndices));
else
    trainData.images = {};
    trainData.labels = [];
    trainData.originalIndices = [];
    fprintf('  Training: 0 images (not enough data)\n');
end

% VALIDATION DATA
valData = struct();
if ~isempty(valIndices)
    valData.images = cell(length(valIndices), 1);
    valData.labels = labels(valIndices);
    valData.originalIndices = validImageIndices(valIndices);
    
    for i = 1:length(valIndices)
        originalImageIdx = validImageIndices(valIndices(i));
        valData.images{i} = preprocessedImages{originalImageIdx};
    end
    
    fprintf('  Validation: %d images loaded\n', length(valIndices));
else
    valData.images = {};
    valData.labels = [];
    valData.originalIndices = [];
    fprintf('  Validation: 0 images (not enough data)\n');
end

% TEST DATA
testData = struct();
if ~isempty(testIndices)
    testData.images = cell(length(testIndices), 1);
    testData.labels = labels(testIndices);
    testData.originalIndices = validImageIndices(testIndices);
    
    for i = 1:length(testIndices)
        originalImageIdx = validImageIndices(testIndices(i));
        testData.images{i} = preprocessedImages{originalImageIdx};
    end
    
    fprintf('  Testing: %d images loaded\n', length(testIndices));
else
    testData.images = {};
    testData.labels = [];
    testData.originalIndices = [];
    fprintf('  Testing: 0 images (not enough data)\n');
end

% Podsumowanie
fprintf('\n📊 Final IMAGES dataset sizes:\n');
fprintf('  Training:   %d images (%.1f%%)\n', length(trainData.labels), length(trainData.labels)/numValidImages*100);
fprintf('  Validation: %d images (%.1f%%)\n', length(valData.labels), length(valData.labels)/numValidImages*100);
fprintf('  Testing:    %d images (%.1f%%)\n', length(testData.labels), length(testData.labels)/numValidImages*100);
fprintf('  Total:      %d images\n', numValidImages);

% Sprawdź balans klas
fprintf('\n🎯 Images class balance verification:\n');
for i = 1:numClasses
    fingerName = metadata.fingerNames{uniqueLabels(i)};
    trainCount = sum(trainData.labels == uniqueLabels(i));
    valCount = sum(valData.labels == uniqueLabels(i));
    testCount = sum(testData.labels == uniqueLabels(i));
    
    fprintf('  %s: Train=%d, Val=%d, Test=%d\n', fingerName, trainCount, valCount, testCount);
end

% Sprawdź czy obrazy są prawidłowe
fprintf('\n🔍 Image validation:\n');
[trainValid, trainInfo] = validateImages(trainData.images, 'Training');
[valValid, valInfo] = validateImages(valData.images, 'Validation');
[testValid, testInfo] = validateImages(testData.images, 'Testing');

if trainValid && valValid && testValid
    fprintf('✅ All image sets are valid for CNN training!\n');
else
    fprintf('⚠️  Some image sets have issues - check validation output\n');
end

fprintf('✅ Stratified IMAGES dataset split completed!\n');
end

function [isValid, info] = validateImages(images, setName)
% VALIDATEIMAGES Sprawdza czy obrazy są prawidłowe dla CNN

isValid = true;
info = struct();

if isempty(images)
    fprintf('  %s: No images to validate\n', setName);
    isValid = false;
    return;
end

info.numImages = length(images);
info.emptyImages = 0;
info.differentSizes = 0;
info.commonSize = [];

% Sprawdź każdy obraz
sizes = [];
for i = 1:length(images)
    img = images{i};
    
    if isempty(img)
        info.emptyImages = info.emptyImages + 1;
        isValid = false;
    else
        sizes(end+1, :) = size(img);
    end
end

% Znajdź najczęstszy rozmiar
if ~isempty(sizes)
    [uniqueSizes, ~, idx] = unique(sizes, 'rows');
    counts = accumarray(idx, 1);
    [~, maxIdx] = max(counts);
    info.commonSize = uniqueSizes(maxIdx, :);
    
    % Policz ile obrazów ma inny rozmiar
    for i = 1:size(sizes, 1)
        if ~isequal(sizes(i, :), info.commonSize)
            info.differentSizes = info.differentSizes + 1;
        end
    end
end

% Raportuj
fprintf('  %s: %d images, %d empty, %d different sizes', ...
    setName, info.numImages, info.emptyImages, info.differentSizes);

if ~isempty(info.commonSize)
    fprintf(', common size: [%dx%d]', info.commonSize(1), info.commonSize(2));
end
fprintf('\n');

if info.emptyImages > 0 || info.differentSizes > 0
    isValid = false;
end
end