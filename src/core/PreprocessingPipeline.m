function [normalizedFeatures, validLabels, metadata, preprocessedImages, validImageIndices] = PreprocessingPipeline(selectedFormat, config, logFile)
% PREPROCESSINGPIPELINE Kompletny 6-etapowy pipeline preprocessingu odcisków palców
%
% Funkcja implementuje zaawansowany workflow przetwarzania obrazów odcisków palców
% od surowych plików graficznych do znormalizowanych wektorów cech minucji gotowych
% do klasyfikacji ML. Pipeline składa się z następujących etapów:
%
% WORKFLOW PREPROCESSINGU:
%   1. ŁADOWANIE DANYCH - wczytanie obrazów z hierarchii katalogów
%   2. PREPROCESSING OBRAZÓW - 6-etapowa transformacja: orientacja → częstotliwość
%      → Gabor → segmentacja → binaryzacja → szkieletyzacja
%   3. DETEKCJA MINUCJI - wykrywanie punktów charakterystycznych (endpoints/bifurcations)
%   4. FILTRACJA MINUCJI - eliminacja fałszywych detekcji, ranking jakości
%   5. EKSTRAKCJA CECH - generowanie deskryptorów relacyjnych między minucjami
%   6. NORMALIZACJA - skalowanie cech do zakresu [0,1] metodą Min-Max
%   7. WIZUALIZACJE - generowanie wykresów diagnostycznych i analitycznych
%
% Parametry wejściowe:
%   selectedFormat - format obrazów do wczytania ('PNG' lub 'TIFF')
%   config - struktura konfiguracyjna (z loadConfig())
%   logFile - uchwyt pliku logów dla szczegółowego śledzenia
%
% Parametry wyjściowe:
%   normalizedFeatures - znormalizowane cechy [N × features] gotowe do ML
%   validLabels - etykiety klas dla udanych próbek [N × 1]
%   metadata - metadane procesu (nazwy palców, ścieżki, statystyki)
%   preprocessedImages - przetworzone obrazy (szkielety binarny) {N × 1}
%   validImageIndices - indeksy oryginalnych obrazów [N × 1]
%
% Mechanizmy odporności:
%   - Obsługa błędów per-obraz (single failure nie przerywa całości)
%   - Szczegółowe logowanie problemów dla post-analizy
%   - Automatyczne fallback dla nieudanych preprocessingów
%   - Progress tracking dla długotrwałych operacji
%   - Walidacja na każdym etapie z recovery options
%
% Statystyki generowane:
%   - Success rate preprocessingu (% udanych obrazów)
%   - Rozkład minucji per palec
%   - Wymiarowość przestrzeni cech
%   - Czasy wykonania poszczególnych etapów
%
% Przykład użycia:
%   [features, labels, meta, images, indices] = PreprocessingPipeline('PNG', config, logFile);

fprintf('\n');
fprintf('=================================================================\n');
fprintf('                    PREPROCESSING PIPELINE                       \n');
fprintf('=================================================================\n');

try
    %% KROK 1: ŁADOWANIE DANYCH WEJŚCIOWYCH
    % Systematyczne wczytanie obrazów z organizacji katalogowej
    
    fprintf('\n📥 STEP 1/7: Loading %s images from directory structure...\n', selectedFormat);
    loadingStartTime = tic;
    dataPath = 'data';
    
    % Delegacja do modułu loadImages z obsługą hierarchii katalogów
    [imageData, labels, metadata] = loadImages(dataPath, config, logFile);
    
    loadingTime = toc(loadingStartTime);
    fprintf('✅ Data loading completed in %.2f seconds\n', loadingTime);
    
    % Walidacja krytyczna - bez obrazów nie ma sensu kontynuować
    if isempty(imageData)
        error('CRITICAL: No images loaded from %s. Check directory structure and file formats.', dataPath);
    end
    
    fprintf('✅ Successfully loaded %d images from %d fingers\n', metadata.totalImages, metadata.actualFingers);
    logInfo(sprintf('Data loading completed: %d images from %d fingers', ...
        metadata.totalImages, metadata.actualFingers), logFile);
    
    %% KROK 2: PREPROCESSING OBRAZÓW (6-ETAPOWY)
    % Transformacja surowych obrazów w szkielety binarne linii papilarnych
    
    fprintf('\n🔄 STEP 2/7: Image preprocessing (6-stage pipeline)...\n');
    fprintf('      Stages: Orientation → Frequency → Gabor → Segmentation → Binarization → Skeletonization\n');
    
    % Inicjalizacja struktur wynikowych
    preprocessedImages = cell(size(imageData));
    numImages = length(imageData);
    
    fprintf('Processing %d images with progress tracking:\n', numImages);
    
    % PĘTLA PREPROCESSINGU Z OBSŁUGĄ BŁĘDÓW PER-OBRAZ
    processingStartTime = tic;
    successCount = 0;
    
    for i = 1:numImages
        % Progress indicator co 10% lub dla pierwszego obrazu
        if mod(i, max(1, floor(numImages/10))) == 0 || i == 1
            fprintf('  📊 Progress: %d/%d (%.1f%%) - ETA: %.1fs\n', i, numImages, ...
                (i/numImages)*100, (toc(processingStartTime)/i)*(numImages-i));
        end
        
        try
            % DELEGACJA DO GŁÓWNEJ FUNKCJI PREPROCESSING
            % Wykonuje pełny 6-etapowy pipeline dla pojedynczego obrazu
            preprocessedImages{i} = preprocessing(imageData{i}, logFile);
            
            % Walidacja wyniku - sprawdź czy szkielet nie jest pusty
            if ~isempty(preprocessedImages{i}) && sum(preprocessedImages{i}(:)) > 0
                successCount = successCount + 1;
            else
                logWarning(sprintf('Preprocessing for image %d resulted in empty skeleton', i), logFile);
                preprocessedImages{i} = []; % Explicit empty dla consistency
            end
            
        catch ME
            % IZOLACJA BŁĘDU - jeden obraz nie przerywa całego procesu
            logWarning(sprintf('Preprocessing failed for image %d (%s): %s', ...
                i, metadata.imagePaths{i}, ME.message), logFile);
            preprocessedImages{i} = []; % Fallback - pusty obraz
        end
    end
    
    processingTime = toc(processingStartTime);
    successRate = (successCount / numImages) * 100;
    
    fprintf('✅ Image preprocessing completed in %.1f seconds\n', processingTime);
    fprintf('📊 Success rate: %d/%d (%.1f%%)\n', successCount, numImages, successRate);
    
    %% KROK 3: DETEKCJA I FILTRACJA MINUCJI
    % Systematyczne wykrywanie i filtracja punktów charakterystycznych
    fprintf('\n🔍 STEP 3/7: Minutiae detection and filtering...\n');
    
    % INICJALIZACJA STRUKTUR WYNIKOWYCH
    allMinutiae = cell(numImages, 1);      % Przechowuje minucje dla każdego obrazu
    allFeatures = [];                      % Macierz cech [samples × features]
    validImageIndices = [];                % Indeksy udanych obrazów
    validMinutiaeCount = 0;                % Licznik udanych ekstrakcji
    minutiaeStartTime = tic;               % Timer dla tego etapu
    
    fprintf('Processing %d images for minutiae detection:\n', numImages);
    
    % PĘTLA DETEKCJI MINUCJI Z OBSŁUGĄ BŁĘDÓW PER-OBRAZ
    for i = 1:numImages
        % Progress indicator co 10% lub dla pierwszego obrazu
        if mod(i, max(1, floor(numImages/10))) == 0 || i == 1
            fprintf('  📊 Progress: %d/%d (%.1f%%) - Processing minutiae\n', i, numImages, (i/numImages)*100);
        end
        
        % Pomiń obrazy które nie przeszły preprocessingu
        if isempty(preprocessedImages{i})
            continue;
        end
        
        try
            %% SUB-ETAP 3A: DETEKCJA MINUCJI
            % Wykrywanie kandydatów na punkty charakterystyczne
            [minutiae, qualityMap] = detectMinutiae(preprocessedImages{i}, config, logFile);
            
            % Walidacja podstawowa - sprawdź czy wykryto jakieś minucje
            if isempty(minutiae) || size(minutiae, 1) == 0
                logWarning(sprintf('No minutiae detected for image %d', i), logFile);
                continue;
            end
            
            % Sprawdź minimalną liczbę minucji dla sensownej analizy
            if size(minutiae, 1) < 3
                logWarning(sprintf('Too few minutiae (%d) detected for image %d', size(minutiae, 1), i), logFile);
                continue;
            end
            
            %% SUB-ETAP 3B: FILTRACJA MINUCJI
            % Eliminacja fałszywych detekcji i ranking jakości
            filteredMinutiae = filterMinutiae(minutiae, config, logFile);
            
            % Walidacja po filtracji
            if isempty(filteredMinutiae) || size(filteredMinutiae, 1) == 0
                logWarning(sprintf('No minutiae remained after filtering for image %d', i), logFile);
                continue;
            end
            
            % Sprawdź czy zostały wystarczające minucje po filtracji
            if size(filteredMinutiae, 1) < 2
                logWarning(sprintf('Too few minutiae (%d) after filtering for image %d', size(filteredMinutiae, 1), i), logFile);
                continue;
            end
            
            %% SUB-ETAP 3C: EKSTRAKCJA CECH
            % Generowanie deskryptorów numerycznych z minucji
            features = extractMinutiaeFeatures(filteredMinutiae, config, logFile);
            
            % Walidacja cech
            if isempty(features) || length(features) == 0
                logWarning(sprintf('Feature extraction failed for image %d', i), logFile);
                continue;
            end
            
            % Sprawdź wymiarowość cech (powinno być ~55 cech)
            if length(features) < 10
                logWarning(sprintf('Feature vector too short (%d) for image %d', length(features), i), logFile);
                continue;
            end
            
            %% SUB-ETAP 3D: WIZUALIZACJA (tylko dla pierwszego udanego obrazu)
            if validMinutiaeCount == 0 && config.visualization.enabled
                try
                    fprintf('      🎨 Creating processing visualization for sample image...\n');
                    visualizeProcessingSteps(imageData{i}, preprocessedImages{i}, ...
                        filteredMinutiae, i, config.visualization.outputDir);
                catch vizME
                    logWarning(sprintf('Visualization failed: %s', vizME.message), logFile);
                end
            end
            
            %% SUB-ETAP 3E: ZAPISYWANIE WYNIKÓW
            % Przechowaj udane rezultaty
            allMinutiae{i} = filteredMinutiae;
            
            % Inicjalizuj macierz cech jeśli to pierwszy udany obraz
            if isempty(allFeatures)
                allFeatures = zeros(0, length(features));
            end
            
            % Dodaj cechy do macierzy wyników
            allFeatures(end+1, :) = features;
            validImageIndices(end+1) = i;
            validMinutiaeCount = validMinutiaeCount + 1;
            
        catch ME
            % IZOLACJA BŁĘDU - jeden obraz nie przerywa całego procesu
            logError(sprintf('Minutiae processing failed for image %d: %s', i, ME.message), logFile);
            continue;
        end
    end
    
    % PODSUMOWANIE ETAPU MINUCJI
    minutiaeTime = toc(minutiaeStartTime);
    
    fprintf('✅ Minutiae processing completed in %.1f seconds\n', minutiaeTime);
    fprintf('📊 Valid results: %d/%d images (%.1f%%)\n', ...
        validMinutiaeCount, numImages, (validMinutiaeCount/numImages)*100);
    
    % Szczegółowe statystyki minucji
    if validMinutiaeCount > 0
        totalMinutiae = 0;
        for i = 1:length(allMinutiae)
            if ~isempty(allMinutiae{i})
                totalMinutiae = totalMinutiae + size(allMinutiae{i}, 1);
            end
        end
        avgMinutiaePerImage = totalMinutiae / validMinutiaeCount;
        fprintf('🔍 Total minutiae detected: %d (avg %.1f per image)\n', totalMinutiae, avgMinutiaePerImage);
        
        logInfo(sprintf('Minutiae detection completed: %d valid images, %d total minutiae, %.1f avg per image', ...
            validMinutiaeCount, totalMinutiae, avgMinutiaePerImage), logFile);
    else
        logError('No valid minutiae extracted from any image', logFile);
    end
    
    %% KROK 4: WALIDACJA WYNIKÓW I KONTROLA JAKOŚCI
    % Sprawdzenie integralności danych przed normalizacją
    
    fprintf('\n📊 STEP 4/7: Quality control and validation...\n');
    
    % Walidacja krytyczna - musi być przynajmniej kilka udanych próbek
    if validMinutiaeCount == 0
        error('CRITICAL: No valid minutiae features extracted from any image. Check preprocessing parameters.');
    end
    
    if validMinutiaeCount < 5
        fprintf('⚠️  WARNING: Very few valid samples (%d). Results may be unreliable.\n', validMinutiaeCount);
        logWarning(sprintf('Low sample count: only %d valid images processed', validMinutiaeCount), logFile);
    end
    
    % Pobierz etykiety dla udanych obrazów
    validLabels = labels(validImageIndices);
    
    % SZCZEGÓŁOWE STATYSTYKI WYNIKÓW
    fprintf('Processing Results Summary:\n');
    fprintf('===========================\n');
    fprintf('📸 Total images loaded: %d\n', numImages);
    fprintf('✅ Successfully preprocessed: %d (%.1f%%)\n', successCount, successRate);
    fprintf('🔍 Valid minutiae extractions: %d (%.1f%%)\n', validMinutiaeCount, (validMinutiaeCount/numImages)*100);
    fprintf('❌ Failed to process: %d images\n', numImages - validMinutiaeCount);
    fprintf('🧬 Feature vector dimensionality: %d features per sample\n', size(allFeatures, 2));
    
    % STATYSTYKI PER PALEC (rozkład klas)
    fprintf('\n👆 Per-finger statistics:\n');
    uniqueLabels = unique(validLabels);
    for finger = uniqueLabels'
        fingerCount = sum(validLabels == finger);
        if finger <= length(metadata.fingerNames)
            fingerName = metadata.fingerNames{finger};
        else
            fingerName = sprintf('Finger %d', finger);
        end
        fprintf('  %s: %d samples\n', fingerName, fingerCount);
    end
    
    %% KROK 5: NORMALIZACJA CECH
    % Skalowanie wszystkich cech do jednolitego zakresu [0,1]
    
    fprintf('\n🔧 STEP 5/7: Feature normalization...\n');
    normalizationStartTime = tic;
    
    % Sprawdź czy cechy wymagają normalizacji
    minVal = min(allFeatures(:));
    maxVal = max(allFeatures(:));
    
    fprintf('Original feature range: [%.3f, %.3f]\n', minVal, maxVal);
    
    if maxVal > 1.01 || minVal < -0.01
        % AUTOMATYCZNA NORMALIZACJA MIN-MAX
        fprintf('Applying Min-Max normalization to range [0,1]...\n');
        normalizedFeatures = normalizeFeatures(allFeatures, 'minmax');
        
        % Weryfikacja normalizacji
        newMin = min(normalizedFeatures(:));
        newMax = max(normalizedFeatures(:));
        fprintf('Normalized feature range: [%.3f, %.3f]\n', newMin, newMax);
        
        logInfo('Features normalized using Min-Max method', logFile);
    else
        % Cechy już w odpowiednim zakresie
        normalizedFeatures = allFeatures;
        fprintf('Features already in [0,1] range - normalization skipped\n');
        logInfo('Feature normalization skipped - values already normalized', logFile);
    end
    
    normalizationTime = toc(normalizationStartTime);
    fprintf('✅ Normalization completed in %.2f seconds\n', normalizationTime);
    
    %% KROK 6: WIZUALIZACJE CECH MINUCJI
    % Generowanie wykresów analitycznych dla przestrzeni cech
    
    fprintf('\n📊 STEP 6/7: Creating feature analysis visualizations...\n');
    
    try
        % Minimum próbek dla sensownych wizualizacji
        if validMinutiaeCount >= 10
            fprintf('Generating minutiae feature analysis plots...\n');
            visualizeMinutiaeFeatures(normalizedFeatures, validLabels, metadata, config.visualization.outputDir);
            
            fprintf('✅ Feature visualizations saved to: %s\n', config.visualization.outputDir);
            logInfo('Minutiae feature visualizations generated successfully', logFile);
        else
            fprintf('⚠️  Skipping visualizations - need at least 10 samples (have %d)\n', validMinutiaeCount);
            logWarning(sprintf('Visualization skipped - insufficient samples: %d < 10', validMinutiaeCount), logFile);
        end
    catch vizME
        fprintf('⚠️  Visualization creation failed: %s\n', vizME.message);
        logWarning(sprintf('Feature visualization failed: %s', vizME.message), logFile);
        
        % Nie przerywaj procesu - wizualizacje są opcjonalne
        fprintf('💡 Continuing without visualizations - this does not affect ML training\n');
    end
    
    %% KROK 7: FINALIZACJA I RAPORT KOŃCOWY
    % Przygotowanie metadanych i podsumowania dla ML Pipeline
    
    fprintf('\n📋 STEP 7/7: Finalizing preprocessing results...\n');
    
    % Dodaj statystyki do metadata dla ML Pipeline
    metadata.successfulImages = validMinutiaeCount;
    metadata.successRate = (validMinutiaeCount / numImages) * 100;
    metadata.failedImages = numImages - validMinutiaeCount;
    metadata.featureVectorSize = size(normalizedFeatures, 2);
    metadata.preprocessingTime = processingTime + minutiaeTime;
    metadata.processingVersion = 'v1.0-advanced';
    metadata.timings = struct();
    metadata.timings.dataLoading = loadingTime;
    metadata.timings.imagePreprocessing = processingTime;
    metadata.timings.minutiaeExtraction = minutiaeTime;
    metadata.timings.normalization = normalizationTime;
    metadata.timings.totalPreprocessing = loadingTime + processingTime + minutiaeTime + normalizationTime;
    
    fprintf('✅ PREPROCESSING PIPELINE COMPLETED SUCCESSFULLY!\n');
    fprintf('================================================\n');
    fprintf('🎯 Ready for Machine Learning Pipeline\n');
    fprintf('⏱️  Total processing time: %.1f seconds\n', metadata.preprocessingTime);
    fprintf('📊 Success rate: %.1f%% (%d/%d images)\n', metadata.successRate, validMinutiaeCount, numImages);
    fprintf('🧬 Feature space: %d samples × %d features\n', validMinutiaeCount, size(normalizedFeatures, 2));
    
    % RAPORT CZASÓW
    fprintf('\n⏱️  DETAILED TIMING REPORT:\n');
    fprintf('================================\n');
    fprintf('📥 Data Loading:        %.2f seconds\n', loadingTime);
    fprintf('🔄 Image Preprocessing: %.2f seconds (%.1f sec/image)\n', processingTime, processingTime/numImages);
    fprintf('🔍 Minutiae Extraction: %.2f seconds\n', minutiaeTime);
    fprintf('🔧 Normalization:       %.2f seconds\n', normalizationTime);
    fprintf('📊 Total Preprocessing: %.2f seconds (%.1f minutes)\n', ...
        metadata.timings.totalPreprocessing, metadata.timings.totalPreprocessing/60);
    
    % KOŃCOWE LOGOWANIE
    logSuccess(sprintf('Preprocessing pipeline completed: %d samples processed, %d features per sample', ...
        validMinutiaeCount, size(normalizedFeatures, 2)), logFile);
    
catch ME
    %% OBSŁUGA BŁĘDÓW GLOBALNYCH PIPELINE
    % Mechanizm awaryjny dla krytycznych problemów
    
    fprintf('\n❌ PREPROCESSING PIPELINE FAILURE\n');
    fprintf('==================================\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Location: %s\n', ME.stack(1).name);
    
    % Szczegółowe logowanie błędu
    logError(sprintf('CRITICAL: Preprocessing pipeline crashed: %s', ME.message), logFile);
    logError(sprintf('Stack trace: %s', getReport(ME, 'extended')), logFile);
    
    fprintf('\n🛠️  TROUBLESHOOTING CHECKLIST:\n');
    fprintf('- Verify input image formats and quality\n');
    fprintf('- Check preprocessing configuration parameters\n');
    fprintf('- Ensure sufficient disk space for processing\n');
    fprintf('- Review log file for detailed error information\n');
    fprintf('- Try reducing image resolution or quantity\n');
    
    % Przekaż błąd dalej z kontekstem
    rethrow(ME);
end
end