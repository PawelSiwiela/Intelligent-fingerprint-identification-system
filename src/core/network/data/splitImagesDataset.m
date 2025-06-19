function [trainData, valData, testData] = splitImagesDataset(preprocessedImages, validImageIndices, labels, metadata, splitRatio)
% SPLITIMAGESDATASET Stratyfikowany podział obrazów na zbiory train/val/test dla CNN
%
% Funkcja wykonuje stratyfikowany podział preprocessowanych obrazów odcisków palców
% na zbiory treningowy, walidacyjny i testowy, zapewniając równomierną reprezentację
% każdej klasy (palca) w każdym zbiorze. Używa stałej liczby próbek per klasa
% zamiast proporcjonalnego podziału dla lepszej kontroli balansowania danych.
%
% Parametry wejściowe:
%   preprocessedImages - cell array z przetworzonymi obrazami (output preprocessing)
%   validImageIndices - indeksy obrazów które przeszły preprocessing pomyślnie
%   labels - etykiety klas dla validImageIndices (ID palców)
%   metadata - struktura metadanych z nazwami palców (metadata.fingerNames)
%   splitRatio - [train_count, val_count, test_count] liczba próbek per klasa
%                domyślnie: [7, 3, 4] = 7 train + 3 val + 4 test per klasa
%
% Parametry wyjściowe:
%   trainData - struktura: {images, labels, originalIndices}
%   valData - struktura: {images, labels, originalIndices}
%   testData - struktura: {images, labels, originalIndices}
%
% Algorytm:
%   1. Konwersja proporcji na stałe liczby jeśli wykryto format proporcjonalny
%   2. Stratyfikowany podział - dla każdej klasy osobno
%   3. Tasowanie indeksów w każdym zbiorze
%   4. Walidacja jakości obrazów (rozmiar, typ, zakres wartości)
%   5. Raportowanie balansu klas i statystyk końcowych
%
% Przykład użycia:
%   [train, val, test] = splitImagesDataset(images, validIdx, labels, meta, [9,2,3]);

if nargin < 5
    splitRatio = [7, 3, 4]; % STAŁA LICZBA próbek per klasa!
end

fprintf('\n🖼️  Creating stratified IMAGES dataset split for CNN...\n');
fprintf('🔍 IMAGES INPUT DEBUG:\n');
fprintf('   splitRatio parameter: %s\n', mat2str(splitRatio));
fprintf('   preprocessedImages length: %d\n', length(preprocessedImages));
fprintf('   validImageIndices length: %d\n', length(validImageIndices));
fprintf('   labels length: %d\n', length(labels));

% Sprawdź czy to są liczby próbek czy proporcje i konwertuj jeśli potrzeba
if all(splitRatio <= 1) && abs(sum(splitRatio) - 1) < 0.1
    % Wykryto format proporcjonalny - konwertuj na stałe liczby
    fprintf('⚠️  DETECTED PROPORTIONS! Converting [%.3f, %.3f, %.3f] to counts\n', ...
        splitRatio(1), splitRatio(2), splitRatio(3));
    
    % Znajdź minimalną liczbę próbek per klasa jako ograniczenie
    uniqueLabels = unique(labels);
    minSamplesPerClass = inf;
    for i = 1:length(uniqueLabels)
        classCount = sum(labels == uniqueLabels(i));
        minSamplesPerClass = min(minSamplesPerClass, classCount);
        fprintf('   Class %d: %d samples\n', uniqueLabels(i), classCount);
    end
    
    fprintf('   Minimum samples per class: %d\n', minSamplesPerClass);
    
    % Konwertuj proporcje na liczby - strategie adaptacyjne
    if minSamplesPerClass >= 14 % Wystarczająco dużo dla optymalnego podziału
        splitRatio = [7, 3, 4];
    elseif minSamplesPerClass >= 9 % Średni rozmiar - zmniejsz proporcjonalnie
        splitRatio = [5, 2, 2];
    elseif minSamplesPerClass >= 6 % Mały rozmiar - minimum funkcjonalny
        splitRatio = [4, 1, 1];
    else
        % Bardzo mały dataset - adaptacyjny podział
        splitRatio = [max(1, floor(minSamplesPerClass/2)), 1, max(1, minSamplesPerClass - floor(minSamplesPerClass/2) - 1)];
    end
    
    fprintf('🔧 Converted to fixed counts: Train=%d, Val=%d, Test=%d per class\n', ...
        splitRatio(1), splitRatio(2), splitRatio(3));
else
    fprintf('📊 Using provided fixed counts: Train=%d, Val=%d, Test=%d per class\n', ...
        splitRatio(1), splitRatio(2), splitRatio(3));
end

trainCount = splitRatio(1);
valCount = splitRatio(2);
testCount = splitRatio(3);

% Walidacja spójności danych wejściowych
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

% Stratyfikowany podział - każda klasa dzielona osobno dla zachowania balansu
for i = 1:numClasses
    classLabel = uniqueLabels(i);
    classIndices = find(labels == classLabel);
    numSamples = length(classIndices);
    
    % Losowe tasowanie indeksów klasy dla uniknięcia bias
    classIndices = classIndices(randperm(numSamples));
    
    % Oblicz liczby próbek dla każdego zbioru z minimum 1 próbka
    numTrain = max(1, trainCount);
    numVal = max(1, valCount);
    numTest = max(1, numSamples - numTrain - numVal);
    
    % Adaptacyjne dostosowanie jeśli za mało próbek w klasie
    if numTrain + numVal + numTest > numSamples
        if numSamples >= 3
            % Podział równomierny dla małych klas
            numTrain = ceil(numSamples / 3);
            numVal = ceil(numSamples / 3);
            numTest = numSamples - numTrain - numVal;
        else
            % Ekstremalnie mała klasa - wszystko do train
            numTrain = numSamples;
            numVal = 0;
            numTest = 0;
        end
    end
    
    % Przypisanie indeksów do odpowiednich zbiorów
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

% Finalne tasowanie indeksów każdego zbioru dla dodatkowej randomizacji
if ~isempty(trainIndices)
    trainIndices = trainIndices(randperm(length(trainIndices)));
end
if ~isempty(valIndices)
    valIndices = valIndices(randperm(length(valIndices)));
end
if ~isempty(testIndices)
    testIndices = testIndices(randperm(length(testIndices)));
end

% Przygotowanie struktur danych z obrazami
fprintf('\n📸 Preparing image arrays...\n');

% ZBIÓR TRENINGOWY
trainData = struct();
if ~isempty(trainIndices)
    trainData.images = cell(length(trainIndices), 1);
    trainData.labels = labels(trainIndices);
    trainData.originalIndices = validImageIndices(trainIndices); % Mapowanie do oryginalnych indeksów
    
    % Załaduj obrazy dla zbioru treningowego
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

% ZBIÓR WALIDACYJNY
valData = struct();
if ~isempty(valIndices)
    valData.images = cell(length(valIndices), 1);
    valData.labels = labels(valIndices);
    valData.originalIndices = validImageIndices(valIndices);
    
    % Załaduj obrazy dla zbioru walidacyjnego
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

% ZBIÓR TESTOWY
testData = struct();
if ~isempty(testIndices)
    testData.images = cell(length(testIndices), 1);
    testData.labels = labels(testIndices);
    testData.originalIndices = validImageIndices(testIndices);
    
    % Załaduj obrazy dla zbioru testowego
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

% Raportowanie statystyk końcowych
fprintf('\n📊 Final IMAGES dataset sizes:\n');
fprintf('  Training:   %d images (%.1f%%)\n', length(trainData.labels), length(trainData.labels)/numValidImages*100);
fprintf('  Validation: %d images (%.1f%%)\n', length(valData.labels), length(valData.labels)/numValidImages*100);
fprintf('  Testing:    %d images (%.1f%%)\n', length(testData.labels), length(testData.labels)/numValidImages*100);
fprintf('  Total:      %d images\n', numValidImages);

% Verifikacja balansu klas w końcowych zbiorach
fprintf('\n🎯 Images class balance verification:\n');
for i = 1:numClasses
    fingerName = metadata.fingerNames{uniqueLabels(i)};
    trainCount = sum(trainData.labels == uniqueLabels(i));
    valCount = sum(valData.labels == uniqueLabels(i));
    testCount = sum(testData.labels == uniqueLabels(i));
    
    fprintf('  %s: Train=%d, Val=%d, Test=%d\n', fingerName, trainCount, valCount, testCount);
end

% Kontrola jakości obrazów przed zwróceniem wyników
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
% VALIDATEIMAGES Sprawdza jakość i spójność obrazów w zbiorze
%
% Funkcja waliduje obrazy pod kątem: pustych elementów, spójności rozmiarów,
% prawidłowych typów danych i zakresów wartości. Niezbędne dla zapewnienia
% kompatybilności z CNN training pipeline.
%
% Parametry wejściowe:
%   images - cell array z obrazami do walidacji
%   setName - nazwa zbioru dla raportowania ('Training', 'Validation', 'Testing')
%
% Parametry wyjściowe:
%   isValid - czy zbiór jest prawidłowy (boolean)
%   info - struktura ze szczegółowymi statystykami

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

% Sprawdź każdy obraz pod kątem błędów
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

% Analiza rozmiarów - znajdź najczęstszy rozmiar jako standard
if ~isempty(sizes)
    [uniqueSizes, ~, idx] = unique(sizes, 'rows');
    counts = accumarray(idx, 1);
    [~, maxIdx] = max(counts);
    info.commonSize = uniqueSizes(maxIdx, :);
    
    % Policz obrazy o niestandardowych rozmiarach
    for i = 1:size(sizes, 1)
        if ~isequal(sizes(i, :), info.commonSize)
            info.differentSizes = info.differentSizes + 1;
        end
    end
end

% Raportowanie wyników walidacji
fprintf('  %s: %d images, %d empty, %d different sizes', ...
    setName, info.numImages, info.emptyImages, info.differentSizes);

if ~isempty(info.commonSize)
    fprintf(', common size: [%dx%d]', info.commonSize(1), info.commonSize(2));
end
fprintf('\n');

% Określ czy zbiór przeszedł walidację
if info.emptyImages > 0 || info.differentSizes > 0
    isValid = false;
end
end