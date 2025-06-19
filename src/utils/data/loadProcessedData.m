function [images, minutiae, features, labels, metadata] = loadProcessedData(matFilePath)
% LOADPROCESSEDDATA Wczytuje zapisane anonimowe dane
%
% Funkcja bezpiecznie wczytuje przetworzone dane odcisków palców z plików
% .mat utworzonych przez saveProcessedData. Automatycznie rozpoznaje typ
% pliku i ekstraktuje odpowiednie dane bez narażania oryginalnych danych
% biometrycznych.
%
% Parametry wejściowe:
%   matFilePath - ścieżka do pliku .mat z anonimowymi danymi
%
% Dane wyjściowe:
%   images - przeprocesowane obrazy (szkielety binarne)
%   minutiae - wykryte punkty charakterystyczne
%   features - cechy numeryczne do uczenia maszynowego
%   labels - etykiety klas (typy palców)
%   metadata - metadane bez wrażliwych informacji
%
% Obsługiwane typy plików:
%   - complete_anonymized_dataset_*.mat (kompletny dataset)
%   - preprocessed_images_*.mat (tylko obrazy)
%   - features_data_*.mat (tylko cechy)

try
    fprintf('📂 Loading anonymized data from: %s\n', matFilePath);
    
    loadedData = load(matFilePath);
    
    % SPRAWDŹ jaki typ pliku został wczytany
    if isfield(loadedData, 'completeDataset')
        % KOMPLETNY dataset - wszystkie dane w jednym pliku
        data = loadedData.completeDataset;
        images = data.preprocessedImages;
        minutiae = data.minutiae;
        features = data.features;
        labels = data.labels;
        metadata = data.metadata;
        
    elseif isfield(loadedData, 'processedData')
        % TYLKO przeprocesowane obrazy
        data = loadedData.processedData;
        images = data.images;
        minutiae = [];
        features = [];
        labels = data.labels;
        metadata = data.metadata;
        
    elseif isfield(loadedData, 'featuresData')
        % TYLKO cechy numeryczne
        data = loadedData.featuresData;
        images = [];
        minutiae = [];
        features = data.features;
        labels = data.labels;
        metadata = data.metadata;
        
    else
        error('Unknown file format - file may be corrupted or from different system');
    end
    
    fprintf('✅ Data loaded successfully!\n');
    fprintf('   Images: %d, Features: %d×%d, Labels: %d\n', ...
        length(images), size(features, 1), size(features, 2), length(labels));
    
catch ME
    fprintf('❌ Failed to load data: %s\n', ME.message);
    % ZWRÓĆ puste dane w przypadku błędu
    images = [];
    minutiae = [];
    features = [];
    labels = [];
    metadata = [];
end
end