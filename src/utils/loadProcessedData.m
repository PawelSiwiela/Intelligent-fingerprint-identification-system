function [images, minutiae, features, labels, metadata] = loadProcessedData(matFilePath)
% LOADPROCESSEDDATA Wczytuje zapisane anonimowe dane
%
% Argumenty:
%   matFilePath - ścieżka do pliku .mat
%
% Output:
%   images - przeprocesowane obrazy (szkielety)
%   minutiae - wykryte minucje
%   features - cechy numeryczne
%   labels - etykiety klas
%   metadata - metadane

try
    fprintf('📂 Loading anonymized data from: %s\n', matFilePath);
    
    loadedData = load(matFilePath);
    
    % Sprawdź jaki typ pliku to jest
    if isfield(loadedData, 'completeDataset')
        data = loadedData.completeDataset;
        images = data.preprocessedImages;
        minutiae = data.minutiae;
        features = data.features;
        labels = data.labels;
        metadata = data.metadata;
        
    elseif isfield(loadedData, 'processedData')
        data = loadedData.processedData;
        images = data.images;
        minutiae = [];
        features = [];
        labels = data.labels;
        metadata = data.metadata;
        
    elseif isfield(loadedData, 'featuresData')
        data = loadedData.featuresData;
        images = [];
        minutiae = [];
        features = data.features;
        labels = data.labels;
        metadata = data.metadata;
        
    else
        error('Unknown file format');
    end
    
    fprintf('✅ Data loaded successfully!\n');
    fprintf('   Images: %d, Features: %d×%d, Labels: %d\n', ...
        length(images), size(features, 1), size(features, 2), length(labels));
    
catch ME
    fprintf('❌ Failed to load data: %s\n', ME.message);
    images = []; minutiae = []; features = []; labels = []; metadata = [];
end
end