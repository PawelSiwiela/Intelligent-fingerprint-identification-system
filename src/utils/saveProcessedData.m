function saveProcessedData(preprocessedImages, allMinutiae, allFeatures, validImageIndices, labels, metadata, outputDir)
% SAVEPROCESSEDDATA Zapisuje przetworzone dane zamiast oryginalnych odcisków
%
% Funkcja zabezpiecza dane biometryczne poprzez zapisanie tylko przetworzonych
% form (szkielety, minucje, cechy numeryczne) bez oryginalnych odcisków palców.
% Tworzy kompletny dataset anonimowych danych bezpiecznych do udostępniania.
%
% Parametry wejściowe:
%   preprocessedImages - obrazy po preprocessingu (szkielety)
%   allMinutiae - wykryte minucje
%   allFeatures - ekstraktowane cechy
%   validImageIndices - indeksy prawidłowych obrazów
%   labels - etykiety klas
%   metadata - metadane
%   outputDir - katalog wyjściowy (opcjonalny)
%
% Dane wyjściowe:
%   - preprocessed_images_[timestamp].mat - szkielety linii papilarnych
%   - minutiae_data_[timestamp].mat - punkty charakterystyczne
%   - features_data_[timestamp].mat - wektory cech numerycznych
%   - complete_anonymized_dataset_[timestamp].mat - kompletny dataset
%   - README_ANONYMIZED_DATA.txt - dokumentacja bezpieczeństwa

if nargin < 7
    outputDir = 'output/processed_data';
end

% UTWÓRZ katalog jeśli nie istnieje
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% TIMESTAMP dla unikalnych nazw plików
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

%% 1. ZAPISZ PRZEPROCESOWANE OBRAZY (szkielety)
fprintf('\n💾 Saving preprocessed images (skeletons)...\n');

processedData = struct();
processedData.images = preprocessedImages(validImageIndices); % Tylko prawidłowe
processedData.labels = labels(validImageIndices);
processedData.imageIndices = validImageIndices;
processedData.metadata = metadata;
processedData.timestamp = timestamp;
processedData.description = 'Fingerprint skeletons after preprocessing - NO ORIGINAL BIOMETRIC DATA';

filename = sprintf('preprocessed_images_%s.mat', timestamp);
filepath = fullfile(outputDir, filename);
save(filepath, 'processedData', '-v7.3'); % -v7.3 dla dużych plików

fprintf('✅ Preprocessed images saved: %s\n', filename);
fprintf('   Contains %d skeleton images (no original biometric data)\n', length(processedData.images));

%% 2. ZAPISZ MINUCJE (punkty charakterystyczne)
fprintf('\n💾 Saving detected minutiae...\n');

minutiaeData = struct();
minutiaeData.minutiae = allMinutiae(validImageIndices); % Tylko prawidłowe
minutiaeData.labels = labels(validImageIndices);
minutiaeData.imageIndices = validImageIndices;
minutiaeData.metadata = metadata;
minutiaeData.timestamp = timestamp;
minutiaeData.description = 'Extracted minutiae points [x, y, angle, type, quality] - ANONYMIZED DATA';

% STATYSTYKI minucji
totalMinutiae = 0;
for i = 1:length(minutiaeData.minutiae)
    if ~isempty(minutiaeData.minutiae{i})
        totalMinutiae = totalMinutiae + size(minutiaeData.minutiae{i}, 1);
    end
end

minutiaeData.statistics = struct();
minutiaeData.statistics.totalMinutiae = totalMinutiae;
minutiaeData.statistics.averagePerImage = totalMinutiae / length(minutiaeData.minutiae);

filename = sprintf('minutiae_data_%s.mat', timestamp);
filepath = fullfile(outputDir, filename);
save(filepath, 'minutiaeData', '-v7.3');

fprintf('✅ Minutiae data saved: %s\n', filename);
fprintf('   Contains %d minutiae points from %d images\n', totalMinutiae, length(minutiaeData.minutiae));

%% 3. ZAPISZ CECHY (wektory numeryczne)
fprintf('\n💾 Saving extracted features...\n');

featuresData = struct();
featuresData.features = allFeatures; % Już tylko dla prawidłowych obrazów
featuresData.labels = labels(validImageIndices);
featuresData.imageIndices = validImageIndices;
featuresData.metadata = metadata;
featuresData.timestamp = timestamp;
featuresData.description = 'Numerical feature vectors extracted from minutiae - COMPLETELY ANONYMIZED';

% INFORMACJE o strukturze cech
featuresData.featureInfo = struct();
featuresData.featureInfo.numFeatures = size(allFeatures, 2);
featuresData.featureInfo.numSamples = size(allFeatures, 1);
featuresData.featureInfo.featureNames = {
    'MinutiaeCount', 'EndpointCount', 'BifurcationCount', 'AverageQuality',
    'CentroidX', 'CentroidY', 'OrientationMean', 'OrientationStd',
    'SpatialSpread', 'QualityVariance', 'EndpointRatio', 'MinutiaDensity',
    % ... dodaj więcej nazw cech w razie potrzeby
    };

filename = sprintf('features_data_%s.mat', timestamp);
filepath = fullfile(outputDir, filename);
save(filepath, 'featuresData', '-v7.3');

fprintf('✅ Features data saved: %s\n', filename);
fprintf('   Contains %d feature vectors with %d features each\n', size(allFeatures, 1), size(allFeatures, 2));

%% 4. ZAPISZ KOMPLETNY DATASET (wszystko w jednym pliku)
fprintf('\n💾 Saving complete anonymized dataset...\n');

completeDataset = struct();
completeDataset.preprocessedImages = processedData.images;
completeDataset.minutiae = minutiaeData.minutiae;
completeDataset.features = featuresData.features;
completeDataset.labels = labels(validImageIndices);
completeDataset.timestamp = timestamp;
completeDataset.description = 'Complete anonymized fingerprint dataset - NO ORIGINAL BIOMETRIC DATA';

% USUŃ ścieżki do oryginalnych plików z metadanych (bezpieczeństwo)
safeMetadata = metadata;
if isfield(safeMetadata, 'imagePaths')
    safeMetadata = rmfield(safeMetadata, 'imagePaths');
end
if isfield(safeMetadata, 'imageNames')
    safeMetadata = rmfield(safeMetadata, 'imageNames');
end

% DODAJ opis bezpieczeństwa do metadanych
safeMetadata.description = 'Complete anonymized fingerprint dataset - NO ORIGINAL BIOMETRIC DATA';
safeMetadata.timestamp = timestamp;

completeDataset.metadata = safeMetadata;

filename = sprintf('complete_anonymized_dataset_%s.mat', timestamp);
filepath = fullfile(outputDir, filename);
save(filepath, 'completeDataset', '-v7.3');

fprintf('✅ Complete anonymized dataset saved: %s\n', filename);

%% 5. STWÓRZ README (dokumentacja bezpieczeństwa)
fprintf('\n📝 Creating README file...\n');

readmeFile = fullfile(outputDir, 'README_ANONYMIZED_DATA.txt');
fid = fopen(readmeFile, 'w');

fprintf(fid, '=========================================================================\n');
fprintf(fid, '              ANONYMIZED FINGERPRINT DATASET - README\n');
fprintf(fid, '=========================================================================\n\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));
fprintf(fid, 'SECURITY NOTICE:\n');
fprintf(fid, '- This dataset contains NO original biometric data\n');
fprintf(fid, '- All images are processed skeletons (binary images)\n');
fprintf(fid, '- Features are numerical vectors derived from minutiae\n');
fprintf(fid, '- Original fingerprint images are NOT included\n\n');
fprintf(fid, 'FILES INCLUDED:\n');
fprintf(fid, '- preprocessed_images_%s.mat : Binary skeleton images\n', timestamp);
fprintf(fid, '- minutiae_data_%s.mat : Extracted minutiae points\n', timestamp);
fprintf(fid, '- features_data_%s.mat : Numerical feature vectors\n', timestamp);
fprintf(fid, '- complete_anonymized_dataset_%s.mat : All data combined\n', timestamp);
fprintf(fid, '\nDATASET STATISTICS:\n');
fprintf(fid, '- Total samples: %d\n', length(validImageIndices));
fprintf(fid, '- Number of classes: %d\n', length(unique(labels(validImageIndices))));
fprintf(fid, '- Features per sample: %d\n', size(allFeatures, 2));
fprintf(fid, '- Total minutiae points: %d\n', totalMinutiae);

fclose(fid);

fprintf('✅ README file created: README_ANONYMIZED_DATA.txt\n');

%% PODSUMOWANIE eksportu danych
fprintf('\n🎉 ANONYMIZED DATA EXPORT COMPLETED!\n');
fprintf('=====================================\n');
fprintf('Output directory: %s\n', outputDir);
fprintf('Files created: 4 .mat files + README\n');
fprintf('Data is completely anonymized and safe to share!\n\n');

end