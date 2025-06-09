% filepath: src/image/minutiae/extraction/createFeatureDataset.m
function [featureMatrix, labels] = createFeatureDataset(trainData, method, logFile)
% CREATEFEATUREDATASET Tworzy macierz cech z danych treningowych
%
% Input:
%   trainData - dane treningowe z preprocessing
%   method - metoda ekstraktowania cech
%   logFile - plik logu
%
% Output:
%   featureMatrix - macierz cech [N x F]
%   labels - wektor etykiet [N x 1]

try
    if nargin < 2, method = 'normalized'; end
    if nargin < 3, logFile = []; end
    
    logInfo('  Creating feature dataset...', logFile);
    
    numSamples = length(trainData.images);
    featureMatrix = [];
    labels = trainData.labels;
    
    for i = 1:numSamples
        % Preprocessing obrazu
        processedImage = basicPreprocessing(trainData.images{i});
        
        % Wykrywanie minucji
        minutiae = detectMinutiae(processedImage);
        
        % Ekstraktowanie cech
        imageSize = size(trainData.images{i});
        features = extractMinutiaeFeatures(minutiae, imageSize, method);
        
        % Dodaj do macierzy
        if isempty(featureMatrix)
            featureMatrix = features;
        else
            % Upewnij się że wszystkie wektory mają tę samą długość
            minLen = min(length(features), size(featureMatrix, 2));
            featureMatrix = featureMatrix(:, 1:minLen);
            features = features(1:minLen);
            
            featureMatrix = [featureMatrix; features];
        end
        
        if mod(i, 10) == 0
            logInfo(sprintf('    Processed %d/%d samples', i, numSamples), logFile);
        end
    end
    
    logInfo(sprintf('  Created feature matrix: %dx%d', size(featureMatrix, 1), size(featureMatrix, 2)), logFile);
    
catch ME
    logError(sprintf('Error creating feature dataset: %s', ME.message), logFile);
    % Fallback
    featureMatrix = [];
    labels = [];
end
end