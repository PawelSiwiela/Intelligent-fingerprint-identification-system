function [normalizedFeatures, validLabels, metadata, preprocessedImages, validImageIndices] = PreprocessingPipeline(selectedFormat, config, logFile)
% PREPROCESSINGPIPELINE Kompletny pipeline preprocessingu obrazów odcisków palców
%
% Wyjście:
%   normalizedFeatures - znormalizowane cechy [N x features]
%   validLabels - etykiety dla prawidłowych próbek [N x 1]
%   metadata - metadane z informacjami o danych
%   preprocessedImages - przetworzone obrazy (szkielety)
%   validImageIndices - indeksy prawidłowych obrazów

fprintf('\n');
fprintf('=================================================================\n');
fprintf('                    PREPROCESSING PIPELINE                       \n');
fprintf('=================================================================\n');

try
    %% KROK 1: Wczytaj dane
    fprintf('\n📥 Loading %s images...\n', selectedFormat);
    dataPath = 'data';
    
    [imageData, labels, metadata] = loadImages(dataPath, config, logFile);
    
    if isempty(imageData)
        error('No images loaded. Please check data path and format.');
    end
    
    fprintf('✅ Loaded %d images from %d fingers\n', metadata.totalImages, metadata.actualFingers);
    
    %% KROK 2: Preprocessing obrazów
    fprintf('\n🔄 Image preprocessing...\n');
    
    % Inicjalizacja wyników preprocessing
    preprocessedImages = cell(size(imageData));
    numImages = length(imageData);
    
    fprintf('Processing %d images:\n', numImages);
    
    for i = 1:numImages
        % Progress indicator
        if mod(i, max(1, floor(numImages/10))) == 0 || i == 1
            fprintf('  Progress: %d/%d (%.1f%%)\n', i, numImages, (i/numImages)*100);
        end
        
        try
            % Preprocessing dla każdego obrazu
            preprocessedImages{i} = preprocessing(imageData{i}, logFile);
            
        catch ME
            logWarning(sprintf('Preprocessing failed for image %d: %s', i, ME.message), logFile);
            % Fallback - pusty obraz
            preprocessedImages{i} = [];
        end
    end
    
    fprintf('✅ Preprocessing completed\n');
    
    %% KROK 3: Detekcja i ekstrakcja minucji
    fprintf('\n🔍 Minutiae detection and feature extraction...\n');
    
    % Inicjalizacja wyników
    allMinutiae = cell(size(preprocessedImages));
    allFeatures = [];
    validImageIndices = [];
    
    fprintf('Detecting minutiae and extracting features:\n');
    
    for i = 1:numImages
        % Progress indicator
        if mod(i, max(1, floor(numImages/10))) == 0 || i == 1
            fprintf('  Progress: %d/%d (%.1f%%)\n', i, numImages, (i/numImages)*100);
        end
        
        if isempty(preprocessedImages{i})
            continue; % Pomiń obrazy które nie zostały przetworzone
        end
        
        try
            % 1. Detekcja minucji
            [minutiae, ~] = detectMinutiae(preprocessedImages{i}, config, logFile);
            
            if isempty(minutiae)
                logWarning(sprintf('No minutiae detected for image %d', i), logFile);
                continue;
            end
            
            % 2. Filtracja minucji
            filteredMinutiae = filterMinutiae(minutiae, config, logFile);
            
            if isempty(filteredMinutiae)
                logWarning(sprintf('No minutiae remained after filtering for image %d', i), logFile);
                continue;
            end
            
            % 3. Ekstrakcja cech
            features = extractMinutiaeFeatures(filteredMinutiae, config, logFile);
            
            if isempty(features)
                logWarning(sprintf('Feature extraction failed for image %d', i), logFile);
                continue;
            end
            
            % 4. WIZUALIZACJA (dla pierwszych 5 obrazów)
            if i <= 5 && config.visualization.enabled
                visualizeProcessingSteps(imageData{i}, preprocessedImages{i}, ...
                    filteredMinutiae, i, config.visualization.outputDir);
            end
            
            % Zapisz wyniki
            allMinutiae{i} = filteredMinutiae;
            allFeatures(end+1, :) = features;
            validImageIndices(end+1) = i;
            
        catch ME
            logError(sprintf('Minutiae processing failed for image %d: %s', i, ME.message), logFile);
        end
    end
    
    fprintf('✅ Minutiae detection and feature extraction completed\n');
    
    %% KROK 4: Podsumowanie wyników
    fprintf('\n📊 Processing Results Summary:\n');
    fprintf('=================================\n');
    
    numValidImages = length(validImageIndices);
    validLabels = labels(validImageIndices);
    
    fprintf('Total images processed: %d\n', numImages);
    fprintf('Successfully processed: %d (%.1f%%)\n', numValidImages, (numValidImages/numImages)*100);
    fprintf('Failed to process: %d\n', numImages - numValidImages);
    fprintf('Feature vector size: %d features per image\n', size(allFeatures, 2));
    
    % Statystyki per palec
    fprintf('\nPer-finger statistics:\n');
    uniqueLabels = unique(validLabels);
    for finger = uniqueLabels'
        fingerCount = sum(validLabels == finger);
        fingerName = metadata.fingerNames{finger};
        fprintf('  %s: %d images\n', fingerName, fingerCount);
    end
    
    %% KROK 5: Normalizacja cech
    fprintf('\n🔧 Normalizing features...\n');
    
    % Automatyczna normalizacja cech (Min-Max)
    fprintf('Normalizing features using Min-Max method...\n');
    normalizedFeatures = normalizeFeatures(allFeatures, 'minmax');
    
    logInfo('Features automatically normalized using Min-Max method', logFile);
    
    %% KROK 6: WIZUALIZACJE CECH MINUCJI
    fprintf('\n📊 Creating minutiae features visualizations...\n');
    
    try
        if numValidImages >= 10 % Minimum próbek dla sensownych wizualizacji
            visualizeMinutiaeFeatures(normalizedFeatures, validLabels, metadata, config.visualization.outputDir);
            
            fprintf('✅ Minutiae features visualizations completed\n');
        else
            fprintf('⚠️  Skipping visualizations - need at least 10 samples (have %d)\n', numValidImages);
        end
    catch ME
        fprintf('⚠️  Visualization creation failed: %s\n', ME.message);
        logWarning(sprintf('Visualization creation failed: %s', ME.message), logFile);
    end
    
    %% SUKCES
    fprintf('\n✅ PREPROCESSING PIPELINE COMPLETED SUCCESSFULLY!\n');
    fprintf('Ready for Machine Learning Pipeline.\n');
    
catch ME
    fprintf('\n❌ Preprocessing Pipeline error: %s\n', ME.message);
    logError(sprintf('Preprocessing Pipeline error: %s', ME.message), logFile);
    rethrow(ME);
end
end