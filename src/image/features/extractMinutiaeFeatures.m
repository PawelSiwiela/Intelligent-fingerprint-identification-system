function [trainFeatures, valFeatures, testFeatures] = extractMinutiaeFeatures(trainMinutiae, valMinutiae, testMinutiae, config, logFile)
% EXTRACTMINUTIAEFEATURES Ekstraktuje cechy z minucji dla wszystkich zbiorów
%
% Input:
%   trainMinutiae, valMinutiae, testMinutiae - minucje z każdego zbioru
%   config - konfiguracja systemu
%   logFile - plik logów
%
% Output:
%   trainFeatures, valFeatures, testFeatures - wektory cech dla każdego zbioru

% Parametry ekstrakcji cech
params = struct();
params.imageSize = [300, 300];           % Standardowy rozmiar obrazu
params.gridSize = [8, 8];                % Siatka 8x8 dla map gęstości
params.orientationBins = 36;             % 36 binów dla histogramu orientacji (co 10°)
params.distanceBins = 16;                 % 16 binów dla rozkładu odległości
params.normalizeFeatures = true;         % Normalizacja cech

logInfo('  Parametry ekstrakcji cech:', logFile);
logInfo(sprintf('    Rozmiar obrazu: %dx%d', params.imageSize), logFile);
logInfo(sprintf('    Siatka gęstości: %dx%d', params.gridSize), logFile);
logInfo(sprintf('    Biny orientacji: %d', params.orientationBins), logFile);

% Ekstraktuj cechy z każdego zbioru
fprintf('   📊 Ekstrakcja cech z minucji...\n');

trainFeatures = extractFeaturesFromDataset(trainMinutiae, 'Training', params, logFile);
valFeatures = extractFeaturesFromDataset(valMinutiae, 'Validation', params, logFile);
testFeatures = extractFeaturesFromDataset(testMinutiae, 'Test', params, logFile);

% Podsumowanie
trainSamples = size(trainFeatures, 1);
valSamples = size(valFeatures, 1);
testSamples = size(testFeatures, 1);
featureDim = size(trainFeatures, 2);

logInfo(sprintf('Ekstrakcja cech ukończona: %d wymiarów cech', featureDim), logFile);
logInfo(sprintf('Train: %d próbek, Val: %d próbek, Test: %d próbek', ...
    trainSamples, valSamples, testSamples), logFile);

fprintf('   ✅ Wektory cech: Train=%dx%d, Val=%dx%d, Test=%dx%d\n', ...
    trainSamples, featureDim, valSamples, featureDim, testSamples, featureDim);
end

function features = extractFeaturesFromDataset(minutiaeData, datasetName, params, logFile)
% Ekstraktuje cechy z jednego zbioru danych

numSamples = length(minutiaeData);
features = [];

fprintf('     %s: przetwarzanie %d obrazów...\n', datasetName, numSamples);

for i = 1:numSamples
    try
        % Ekstraktuj cechy z minucji tego obrazu
        imageFeatures = createFeatureVectors(minutiaeData{i}, params);
        
        % Dodaj do macierzy cech
        if isempty(features)
            features = imageFeatures;
        else
            features = [features; imageFeatures];
        end
        
    catch ME
        logWarning(sprintf('Błąd ekstrakcji cech dla obrazu %d w %s: %s', ...
            i, datasetName, ME.message), logFile);
        
        % Fallback - wektor zerowy
        if isempty(features)
            % Ustal wymiar na podstawie parametrów
            featureDim = params.gridSize(1) * params.gridSize(2) + ... % mapa gęstości
                params.orientationBins + ...                    % histogram orientacji
                params.distanceBins + ...                       % rozkład odległości
                6;                                              % podstawowe statystyki
            features = zeros(1, featureDim);
        else
            features = [features; zeros(1, size(features, 2))];
        end
    end
end

% Normalizacja cech (jeśli wybrano)
if params.normalizeFeatures && ~isempty(features)
    features = normalizeFeatures(features);
end

fprintf('     ✅ %s: %d próbek x %d cech\n', datasetName, size(features, 1), size(features, 2));
end

function normalizedFeatures = normalizeFeatures(features)
% Normalizuje cechy do zakresu [0,1]

normalizedFeatures = features;

for i = 1:size(features, 2)
    column = features(:, i);
    minVal = min(column);
    maxVal = max(column);
    
    if maxVal > minVal
        normalizedFeatures(:, i) = (column - minVal) / (maxVal - minVal);
    end
end
end