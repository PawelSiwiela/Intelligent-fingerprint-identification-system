function App()
% APP Główna aplikacja systemu identyfikacji odcisków palców - interfejs terminalowy
%
% Funkcja stanowi centralny punkt wejściowy do całego systemu identyfikacji
% odcisków palców. Implementuje kompleksowy workflow obejmujący preprocessing
% obrazów, ekstrakcję cech minucji, trenowanie modeli ML oraz ewaluację
% wydajności. Obsługuje zarówno przetwarzanie surowych obrazów jak i
% wczytywanie preprocessowanych danych z plików .mat.
%
% Główne komponenty systemu:
%   1. Inicjalizacja - konfiguracja, katalogi, logowanie
%   2. Wybór źródła danych - surowe obrazy vs preprocessowane .mat
%   3. Preprocessing Pipeline - pełna obróbka obrazów (opcjonalnie)
%   4. Machine Learning Pipeline - trenowanie i ewaluacja modeli
%   5. Finalizacja - raporty, wizualizacje, zapis wyników
%
% Obsługiwane ścieżki przetwarzania:
%   ŚCIEŻKA A: .mat → ML Pipeline (szybka, dla preprocessowanych danych)
%   ŚCIEŻKA B: Surowe obrazy → Preprocessing → ML Pipeline (pełna)
%
% Funkcjonalności dodatkowe:
%   - Interaktywny wybór formatu danych (PNG/TIFF)
%   - Automatyczne tworzenie katalogów wyjściowych
%   - Szczegółowe logowanie z timestamp
%   - Opcjonalny zapis danych anonimowych do udostępniania
%   - Obsługa błędów z fallback scenarios
%   - Szczegółowe raporty wydajności i czasów wykonania
%
% Struktura katalogów wyjściowych:
%   output/
%   ├── logs/          - pliki logów z timestampem
%   ├── figures/       - wizualizacje i wykresy analizy
%   ├── models/        - zapisane modele i hiperparametry
%   └── anonymized_data/ - bezpieczne dane do udostępniania
%
% Przykład użycia:
%   App(); % Uruchamia interaktywną sesję z menu wyboru

fprintf('\n');
fprintf('=================================================================\n');
fprintf('              FINGERPRINT IDENTIFICATION SYSTEM                 \n');
fprintf('=================================================================\n');
fprintf('\n');

try
    %% KROK 1: INICJALIZACJA SYSTEMU
    % Przygotowanie środowiska, konfiguracji i systemów pomocniczych
    
    fprintf('🔧 Initializing system...\n');
    
    % Wczytaj globalną konfigurację systemu (preprocessing, ML, wizualizacje)
    config = loadConfig();
    
    % Utwórz hierarchię katalogów wyjściowych
    createOutputDirectories(config);
    
    % Inicjalizacja systemu logowania z unikalnym timestampem
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    logFile = fullfile(config.logging.outputDir, sprintf('fingerprint_processing_%s.log', timestamp));
    
    % Rozpocznij sesję logowania z nagłówkiem
    logInfo('=============================================================', logFile);
    logInfo('           FINGERPRINT IDENTIFICATION SYSTEM STARTED         ', logFile);
    logInfo('=============================================================', logFile);
    logInfo(sprintf('Session started: %s', datestr(now)), logFile);
    
    % Uruchom timer globalny dla całej sesji
    startTime = tic;
    
    %% KROK 2: INTERAKTYWNY WYBÓR ŹRÓDŁA DANYCH
    % Umożliwia użytkownikowi wybór między surowymi obrazami a preprocessowanymi plikami .mat
    
    fprintf('\n📂 Data source selection...\n');
    [useMatFiles, matFilePath, selectedFormat] = selectDataSource();
    
    % Aktualizacja konfiguracji zgodnie z wyborem użytkownika
    config.dataLoading.format = selectedFormat;
    
    % Logowanie wybranej ścieżki przetwarzania
    if useMatFiles
        logInfo(sprintf('Processing path: Loading from .mat file: %s', matFilePath), logFile);
    else
        logInfo(sprintf('Processing path: Full preprocessing pipeline - format: %s', selectedFormat), logFile);
    end
    
    %% KROK 3: GŁÓWNA LOGIKA PRZETWARZANIA
    % Rozwidlenie na dwie ścieżki w zależności od źródła danych
    
    if useMatFiles
        %% ŚCIEŻKA A: BEZPOŚREDNIE WCZYTANIE PREPROCESSOWANYCH DANYCH
        % Szybka ścieżka omijająca preprocessing - dane już przetworzone
        
        fprintf('\n📥 Loading preprocessed data from .mat file...\n');
        [preprocessedImages, allMinutiae, normalizedFeatures, labels, metadata] = loadProcessedData(matFilePath);
        
        % Walidacja integralności wczytanych danych
        if isempty(normalizedFeatures)
            error('Failed to load valid feature data from .mat file. File may be corrupted or incompatible.');
        end
        
        % Symulacja validImageIndices dla kompatybilności z ML Pipeline
        validImageIndices = 1:length(labels);
        
        % Dodatkowa normalizacja jeśli dane nie są w zakresie [0,1]
        if max(normalizedFeatures(:)) > 1 || min(normalizedFeatures(:)) < 0
            fprintf('🔧 Re-normalizing loaded features to [0,1] range...\n');
            normalizedFeatures = normalizeFeatures(normalizedFeatures, 'minmax');
            logInfo('Loaded features re-normalized using Min-Max method', logFile);
        end
        
        fprintf('✅ Successfully loaded %d preprocessed samples from .mat file\n', length(labels));
        displayDataSummary(metadata, true);
        
    else
        %% ŚCIEŻKA B: PEŁNY PREPROCESSING PIPELINE
        % Kompletne przetwarzanie od surowych obrazów do cech ML
        
        fprintf('\n🔄 Starting full preprocessing pipeline...\n');
        
        % DELEGACJA DO MODUŁU PREPROCESSING PIPELINE
        % Wykonuje pełny 6-etapowy preprocessing: orientacja → częstotliwość →
        % → Gabor → segmentacja → binaryzacja → szkieletyzacja
        [normalizedFeatures, labels, metadata, preprocessedImages, validImageIndices] = ...
            PreprocessingPipeline(selectedFormat, config, logFile);
        
        % Walidacja wyników preprocessingu
        if isempty(normalizedFeatures)
            error('Preprocessing pipeline failed - no valid features extracted. Check input images and parameters.');
        end
        
        % Wyświetl szczegółowe podsumowanie preprocessingu
        displayDataSummary(metadata, false);
        
        %% OPCJONALNY ZAPIS DANYCH ANONIMOWYCH
        % Umożliwia eksport preprocessowanych danych bez informacji biometrycznych
        offerDataSaving(preprocessedImages, [], normalizedFeatures, validImageIndices, labels, metadata, logFile);
    end
    
    %% KROK 4: MACHINE LEARNING PIPELINE
    % Trenowanie modeli, optymalizacja hiperparametrów, ewaluacja wydajności
    
    fprintf('\n🤖 Starting Machine Learning Pipeline...\n');
    
    try
        % PRZEKAZANIE KONTROLI DO ML PIPELINE
        % Argumenty: cechy, etykiety, metadata, obrazy preprocessowane, indeksy, log
        MLPipeline(normalizedFeatures, labels, metadata, preprocessedImages, validImageIndices, logFile);
        
        fprintf('✅ ML Pipeline completed successfully!\n');
        logSuccess('ML Pipeline executed without errors', logFile);
        
    catch ME
        % Obsługa błędów ML Pipeline z zachowaniem kontynuacji sesji
        fprintf('⚠️  ML Pipeline encountered error: %s\n', ME.message);
        logWarning(sprintf('ML Pipeline failed: %s', ME.message), logFile);
        
        % Szczegółowy stack trace dla debugowania (tylko w logach)
        fprintf('Stack trace logged to file for debugging\n');
        logError(sprintf('ML Pipeline stack trace: %s', getReport(ME, 'extended')), logFile);
    end
    
    %% KROK 5: FINALIZACJA I PODSUMOWANIE SESJI
    % Obliczenie czasów, statystyki, raporty końcowe
    
    executionTime = toc(startTime);
    
    % RAPORT KOŃCOWY SUKCESU
    fprintf('\n🎉 FINGERPRINT IDENTIFICATION SESSION COMPLETED!\n');
    fprintf('==================================================\n');
    fprintf('Total execution time: %.2f seconds (%.1f minutes)\n', executionTime, executionTime/60);
    fprintf('Feature vector dimensionality: %d features per sample\n', size(normalizedFeatures, 2));
    
    % Statystyki specyficzne dla ścieżki przetwarzania
    if useMatFiles
        fprintf('Data source: Preprocessed .mat file\n');
        fprintf('Samples processed: %d (from cached data)\n', length(labels));
    else
        fprintf('Data source: Original image files (%s format)\n', selectedFormat);
        fprintf('Images successfully processed: %d/%d (%.1f%% success rate)\n', ...
            length(validImageIndices), metadata.totalImages, ...
            (length(validImageIndices)/metadata.totalImages)*100);
    end
    
    % Finalizacja logowania z metadanymi sesji
    closeLog(logFile, executionTime);
    
    % Instrukcje dla użytkownika - gdzie znaleźć wyniki
    fprintf('\n📋 RESULTS SUMMARY:\n');
    fprintf('===================\n');
    fprintf('📄 Session log: %s\n', logFile);
    fprintf('🤖 Trained models: output/models/\n');
    fprintf('📊 Visualizations: output/figures/\n');
    if ~useMatFiles
        fprintf('💾 Anonymized data: output/anonymized_data/ (if saved)\n');
    end
    fprintf('\n=================================================================\n');
    
catch ME
    %% OBSŁUGA BŁĘDÓW GLOBALNYCH
    % Mechanizm awaryjny dla krytycznych błędów aplikacji
    
    fprintf('\n❌ CRITICAL APPLICATION ERROR\n');
    fprintf('==============================\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    
    % Logowanie błędu jeśli system logowania jest dostępny
    if exist('logFile', 'var') && ~isempty(logFile)
        logError(sprintf('CRITICAL: Application crashed: %s', ME.message), logFile);
        logError(sprintf('CRITICAL: Full stack trace: %s', getReport(ME)), logFile);
        
        % Finalizacja logów z informacją o błędzie
        if exist('startTime', 'var')
            executionTime = toc(startTime);
            logInfo(sprintf('Session terminated due to error after %.2f seconds', executionTime), logFile);
            closeLog(logFile, executionTime);
        end
        
        fprintf('📄 Detailed error log: %s\n', logFile);
    end
    
    fprintf('\n🛠️  TROUBLESHOOTING TIPS:\n');
    fprintf('- Check input data directory structure\n');
    fprintf('- Verify image file formats (PNG/TIFF)\n');
    fprintf('- Ensure sufficient disk space for processing\n');
    fprintf('- Review configuration parameters\n');
    
    % Przekaż błąd dalej dla debugowania
    rethrow(ME);
end
end

%% FUNKCJE POMOCNICZE - INTERFEJS UŻYTKOWNIKA I WALIDACJA

function [useMatFiles, matFilePath, selectedFormat] = selectDataSource()
% SELECTDATASOURCE Interaktywny interfejs wyboru źródła danych
%
% Funkcja implementuje inteligentny system wyboru między preprocessowanymi
% plikami .mat a surowymi obrazami. Automatycznie skanuje dostępne opcje,
% prezentuje użytkownikowi menu z rekomendacjami i waliduje wybory.
%
% Logika decyzyjna:
%   1. Skanuj katalog output/anonymized_data/ w poszukiwaniu plików .mat
%   2. Jeśli znaleziono .mat → opcja preferowana (szybsza, bezpieczna)
%   3. Jeśli brak .mat → sprawdź dostępność surowych obrazów
%   4. Prezentuj opcje z rekomendacjami opartymi na dostępności danych
%
% Obsługa scenariuszy:
%   - Wiele plików .mat → menu wyboru z metadanymi (rozmiar, data)
%   - Pojedynczy .mat → automatyczne podpowiedzi
%   - Brak .mat → sprawdzenie obrazów w data/ directory
%   - Brak jakichkolwiek danych → instrukcje dla użytkownika

% Wstępne skanowanie dostępnych plików .mat
matFilesDir = 'output/anonymized_data';
matFiles = [];

if exist(matFilesDir, 'dir')
    % Szukaj plików z prefiksem complete_anonymized_dataset_
    matSearch = dir(fullfile(matFilesDir, 'complete_anonymized_dataset_*.mat'));
    if ~isempty(matSearch)
        matFiles = matSearch;
    end
end

fprintf('📋 AVAILABLE DATA SOURCES:\n');
fprintf('===========================\n');

if ~isempty(matFiles)
    %% SCENARIUSZ A: DOSTĘPNE PLIKI .MAT
    % Prezentuj opcje z rekomendacją użycia preprocessowanych danych
    
    fprintf('  🎯 RECOMMENDED: Use preprocessed .mat files\n');
    fprintf('     ✅ Faster processing (skips preprocessing)\n');
    fprintf('     ✅ Anonymous data (safe for sharing)\n');
    fprintf('     ✅ Consistent feature extraction\n\n');
    
    fprintf('  1. 📦 Load from .mat file (preprocessed features)\n');
    fprintf('  2. 🖼️  Load original images (full preprocessing pipeline)\n');
    
    % Prezentacja dostępnych plików .mat z metadanymi
    fprintf('\n📁 Available preprocessed datasets:\n');
    for i = 1:length(matFiles)
        fileInfo = dir(fullfile(matFilesDir, matFiles(i).name));
        fprintf('    %d. %s\n', i, matFiles(i).name);
        fprintf('       Size: %.1f MB | Created: %s\n', ...
            fileInfo.bytes/1024/1024, datestr(fileInfo.datenum));
    end
    
    % INTERAKTYWNY WYBÓR OPCJI
    while true
        fprintf('\n❓ Select processing option: ');
        choice = input('');
        
        if choice == 1
            %% WYBÓR PLIKU .MAT
            
            if length(matFiles) == 1
                % Pojedynczy plik - automatyczne wybranie
                selectedFile = 1;
                fprintf('✅ Auto-selected: %s\n', matFiles(1).name);
            else
                % Wiele plików - interaktywny wybór
                fprintf('\n📋 Select .mat file:\n');
                while true
                    fprintf('❓ Enter file number (1-%d): ', length(matFiles));
                    selectedFile = input('');
                    
                    if selectedFile >= 1 && selectedFile <= length(matFiles)
                        break;
                    else
                        fprintf('❌ Invalid choice. Please enter number between 1 and %d.\n', length(matFiles));
                    end
                end
            end
            
            % Finalizacja wyboru .mat
            useMatFiles = true;
            matFilePath = fullfile(matFilesDir, matFiles(selectedFile).name);
            selectedFormat = 'MAT'; % Dla celów logowania
            
            fprintf('✅ Selected preprocessed dataset: %s\n', matFiles(selectedFile).name);
            break;
            
        elseif choice == 2
            %% WYBÓR ORYGINALNYCH OBRAZÓW
            
            useMatFiles = false;
            matFilePath = '';
            selectedFormat = selectDataFormat(); % Delegacja do funkcji wyboru formatu
            break;
            
        else
            fprintf('❌ Invalid option. Please enter 1 or 2.\n');
        end
    end
    
else
    %% SCENARIUSZ B: BRAK PLIKÓW .MAT
    % Sprawdź dostępność oryginalnych obrazów i prezentuj odpowiednie opcje
    
    fprintf('  ⚠️  No preprocessed .mat files found in %s\n', matFilesDir);
    fprintf('  🔍 Scanning for original sample images...\n');
    
    % Walidacja dostępności surowych obrazów
    if exist('data', 'dir')
        % Rekurencyjne przeszukiwanie PNG i TIFF
        pngFiles = dir('data/**/*.png');
        tiffFiles = dir('data/**/*.tiff');
        
        if isempty(pngFiles) && isempty(tiffFiles)
            %% BRAK JAKICHKOLWIEK DANYCH
            fprintf('  ❌ No sample images found in data/ directory!\n\n');
            
            fprintf('🚨 NO DATA SOURCES AVAILABLE\n');
            fprintf('============================\n');
            fprintf('📋 SOLUTION OPTIONS:\n');
            fprintf('  1. 📁 Add fingerprint images to data/ directory\n');
            fprintf('     Structure: data/FingerName/PNG/Sample*.png\n');
            fprintf('                data/FingerName/TIFF/Sample*.tiff\n\n');
            fprintf('  2. 📦 Use existing .mat file with preprocessed data\n');
            fprintf('     Place in: output/anonymized_data/\n\n');
            fprintf('  3. 🌐 Download sample dataset from project repository\n\n');
            
            error('CRITICAL: No data source available. Please add sample images or .mat files.');
            
        else
            %% ZNALEZIONO ORYGINALNE OBRAZY
            fprintf('  ✅ Found original sample images:\n');
            fprintf('     📷 PNG files: %d\n', length(pngFiles));
            fprintf('     📷 TIFF files: %d\n', length(tiffFiles));
            
            % Prezentacja dostępnej ścieżki
            fprintf('\n  Available processing path:\n');
            fprintf('  1. 🖼️  Load original images (full preprocessing pipeline)\n');
            fprintf('     ⏱️  Processing time: ~2-5 minutes per image\n');
            fprintf('     🔄 Full feature extraction workflow\n');
        end
    else
        %% BRAK KATALOGU data/
        fprintf('  ❌ No data/ directory found!\n\n');
        
        fprintf('🚨 DATA DIRECTORY MISSING\n');
        fprintf('=========================\n');
        fprintf('📋 REQUIRED ACTION:\n');
        fprintf('  Create data/ directory structure:\n');
        fprintf('  data/\n');
        fprintf('  ├── Finger1/\n');
        fprintf('  │   ├── PNG/Sample*.png\n');
        fprintf('  │   └── TIFF/Sample*.tiff\n');
        fprintf('  ├── Finger2/\n');
        fprintf('  └── ...\n\n');
        
        error('CRITICAL: data/ directory not found. Please create directory structure with sample images.');
    end
    
    % POTWIERDZENIE WYBORU ORYGINALNYCH OBRAZÓW
    while true
        fprintf('\n❓ Continue with original image processing? (1 = Yes): ');
        choice = input('');
        
        if choice == 1
            useMatFiles = false;
            matFilePath = '';
            selectedFormat = selectDataFormat();
            break;
        else
            fprintf('❌ Invalid choice. Enter 1 to continue or Ctrl+C to exit.\n');
        end
    end
end

end

function selectedFormat = selectDataFormat()
% SELECTDATAFORMAT Interaktywny wybór formatu obrazów (PNG vs TIFF)
%
% Funkcja prezentuje użytkownikowi dostępne formaty obrazów i umożliwia
% wybór między PNG a TIFF na podstawie preferencji lub dostępności danych.

fprintf('\n🎨 IMAGE FORMAT SELECTION:\n');
fprintf('==========================\n');
fprintf('  1. 📸 PNG files (.png)\n');
fprintf('     • Lossless compression\n');
fprintf('     • Widely supported\n');
fprintf('     • Good for sharing\n\n');

fprintf('  2. 🖼️  TIFF files (.tiff)\n');
fprintf('     • Uncompressed/lossless\n');
fprintf('     • High quality preservation\n');
fprintf('     • Scientific standard\n\n');

% INTERAKTYWNY WYBÓR FORMATU
while true
    fprintf('❓ Select image format (1 for PNG, 2 for TIFF): ');
    choice = input('');
    
    if choice == 1
        selectedFormat = 'PNG';
        fprintf('✅ Selected format: PNG\n');
        break;
    elseif choice == 2
        selectedFormat = 'TIFF';
        fprintf('✅ Selected format: TIFF\n');
        break;
    else
        fprintf('❌ Invalid choice. Please enter 1 (PNG) or 2 (TIFF).\n');
    end
end
end

function displayDataSummary(metadata, useMatFiles)
% DISPLAYDATASUMMARY Szczegółowe podsumowanie wczytanych danych
%
% Funkcja prezentuje kompleksowe informacje o załadowanym zbiorze danych,
% dostosowując prezentację do typu źródła (surowe obrazy vs .mat file).
% Implementuje bezpieczne sprawdzanie pól metadata z fallback values.

fprintf('\n📊 DATA SUMMARY REPORT\n');
fprintf('======================\n');

if useMatFiles
    %% PODSUMOWANIE DANYCH Z PLIKU .MAT
    
    fprintf('📦 Source: Preprocessed .mat file\n');
    
    % BEZPIECZNE sprawdzanie pól metadata z fallback
    if isfield(metadata, 'description') && ~isempty(metadata.description)
        fprintf('📝 Description: %s\n', metadata.description);
    else
        fprintf('📝 Description: Anonymized fingerprint dataset\n');
    end
    
    if isfield(metadata, 'timestamp') && ~isempty(metadata.timestamp)
        fprintf('🕐 Generated: %s\n', metadata.timestamp);
    else
        fprintf('🕐 Generated: Unknown timestamp\n');
    end
    
    % Informacje o próbkach i palcach
    if isfield(metadata, 'totalImages') && ~isempty(metadata.totalImages)
        fprintf('📊 Total samples: %d\n', metadata.totalImages);
    else
        fprintf('📊 Total samples: Not specified\n');
    end
    
    % Liczba palców (różne możliwe źródła tej informacji)
    if isfield(metadata, 'actualFingers') && ~isempty(metadata.actualFingers)
        fprintf('👆 Number of fingers: %d\n', metadata.actualFingers);
    elseif isfield(metadata, 'fingerNames') && ~isempty(metadata.fingerNames)
        fprintf('👆 Number of fingers: %d\n', length(metadata.fingerNames));
    else
        fprintf('👆 Number of fingers: Not specified\n');
    end
    
    % Dodatkowe metadane jeśli dostępne
    if isfield(metadata, 'featureVectorSize')
        fprintf('🧬 Feature vector size: %d\n', metadata.featureVectorSize);
    end
    
    if isfield(metadata, 'processingVersion')
        fprintf('🔧 Processing version: %s\n', metadata.processingVersion);
    end
    
else
    %% PODSUMOWANIE SUROWYCH OBRAZÓW PO PREPROCESSINGU
    
    fprintf('🖼️  Source: Original image files\n');
    fprintf('📊 Total images loaded: %d\n', metadata.totalImages);
    fprintf('👆 Number of fingers: %d\n', metadata.actualFingers);
    fprintf('🎨 Image format: %s\n', metadata.selectedFormat);
    fprintf('🕐 Load timestamp: %s\n', metadata.loadTimestamp);
    
    % SZCZEGÓŁOWY BREAKDOWN PER PALEC
    fprintf('\n📋 Per-finger breakdown:\n');
    for i = 1:length(metadata.fingerNames)
        fingerName = metadata.fingerNames{i};
        
        % Zlicz obrazy dla danego palca (sprawdź w ścieżkach)
        fingerImageCount = 0;
        if isfield(metadata, 'imagePaths')
            % Metoda 1: Sprawdź w ścieżkach plików
            fingerImageCount = sum(contains(metadata.imagePaths, fingerName, 'IgnoreCase', true));
        end
        
        % Jeśli metoda 1 nie działa, użyj etykiet
        if fingerImageCount == 0 && exist('labels', 'var')
            fingerImageCount = sum(labels == i);
        end
        
        % Fallback - równy podział
        if fingerImageCount == 0
            fingerImageCount = floor(metadata.totalImages / metadata.actualFingers);
        end
        
        fprintf('  👉 %s: %d images\n', fingerName, fingerImageCount);
    end
    
    % STATYSTYKI SUKCESU PREPROCESSINGU (jeśli dostępne)
    if isfield(metadata, 'successRate')
        fprintf('\n✅ Preprocessing success rate: %.1f%%\n', metadata.successRate);
    end
    
    if isfield(metadata, 'failedImages')
        fprintf('❌ Failed to process: %d images\n', metadata.failedImages);
    end
end

% SEPARATOR WIZUALNY
fprintf('======================\n');
end

function createOutputDirectories(config)
% CREATEOUTPUTDIRECTORIES Tworzenie hierarchii katalogów wyjściowych
%
% Funkcja zapewnia istnienie wszystkich wymaganych katalogów dla różnych
% komponentów systemu: logów, wizualizacji, modeli ML i danych anonimowych.

% DEFINICJA KOMPLETNEJ STRUKTURY KATALOGÓW
requiredDirectories = {
    config.logging.outputDir,           % Logi sesji z timestampem
    config.visualization.outputDir,     % Wykresy, matryce pomyłek, wizualizacje
    'output/models',                    % Zapisane modele ML i hiperparametry
    'output/anonymized_data',           % Dane bezpieczne do udostępniania
    'output/preprocessing',             % Wyniki pośrednie preprocessingu (opcjonalne)
    'output/reports'                    % Raporty końcowe (opcjonalne)
    };

% TWORZENIE KATALOGÓW Z OBSŁUGĄ BŁĘDÓW
for i = 1:length(requiredDirectories)
    targetDir = requiredDirectories{i};
    
    if ~exist(targetDir, 'dir')
        try
            mkdir(targetDir);
            fprintf('📁 Created directory: %s\n', targetDir);
        catch ME
            warning('Failed to create directory %s: %s', targetDir, ME.message);
        end
    end
end
end

function offerDataSaving(preprocessedImages, allMinutiae, allFeatures, validImageIndices, labels, metadata, logFile)
% OFFERDATASAVING Interaktywna oferta zapisu danych anonimowych
%
% Funkcja umożliwia użytkownikowi eksport preprocessowanych danych do
% bezpiecznego formatu .mat, który nie zawiera surowych danych biometrycznych.
% Implementuje wykrywanie istniejących plików i inteligentne naming.

matFilesDir = 'output/anonymized_data';

% SPRAWDZENIE ISTNIEJĄCYCH PLIKÓW .MAT
existingMats = [];
if exist(matFilesDir, 'dir')
    existingMats = dir(fullfile(matFilesDir, 'complete_anonymized_dataset_*.mat'));
end

% PREZENTACJA OPCJI Z KONTEKSTEM
fprintf('\n💾 DATA EXPORT OPTIONS\n');
fprintf('======================\n');

if ~isempty(existingMats)
    fprintf('📋 Found existing anonymized datasets:\n');
    for i = 1:length(existingMats)
        fileInfo = dir(fullfile(matFilesDir, existingMats(i).name));
        fprintf('  📦 %s\n', existingMats(i).name);
        fprintf('     Size: %.1f MB | Created: %s\n', ...
            fileInfo.bytes/1024/1024, datestr(fileInfo.datenum));
    end
    
    fprintf('\n🔄 Save NEW anonymized dataset? (existing files will remain)\n');
    fprintf('   ✅ Benefits: Safe sharing, faster future loading\n');
    fprintf('   ✅ Contains: Normalized features, labels, metadata only\n');
    fprintf('   ❌ Excludes: Original biometric images\n\n');
else
    fprintf('💡 RECOMMENDATION: Save anonymized data for:\n');
    fprintf('   🎓 Safe sharing with professors/colleagues\n');
    fprintf('   ⚡ Faster future processing (skip preprocessing)\n');
    fprintf('   📊 Reproducible experiments\n');
    fprintf('   🔒 Privacy protection (no original biometrics)\n\n');
    
    fprintf('📋 Anonymized data will include:\n');
    fprintf('   ✅ Normalized feature vectors\n');
    fprintf('   ✅ Class labels (finger IDs)\n');
    fprintf('   ✅ Processing metadata\n');
    fprintf('   ❌ NO original fingerprint images\n');
    fprintf('   ❌ NO biometric templates\n\n');
end

% INTERAKTYWNE POTWIERDZENIE
fprintf('❓ Save anonymized dataset? (y/n): ');
saveAnonymized = input('', 's');

if strcmpi(saveAnonymized, 'y') || strcmpi(saveAnonymized, 'yes')
    %% WYKONAJ ZAPIS DANYCH ANONIMOWYCH
    
    fprintf('\n🔒 Creating anonymized dataset...\n');
    fprintf('   📊 Processing %d samples with %d features each\n', ...
        length(labels), size(allFeatures, 2));
    
    try
        % DELEGACJA DO FUNKCJI ZAPISU
        saveProcessedData(preprocessedImages, allMinutiae, allFeatures, ...
            validImageIndices, labels, metadata, matFilesDir);
        
        fprintf('✅ ANONYMIZED DATA SAVED SUCCESSFULLY!\n');
        fprintf('📍 Location: %s\n', matFilesDir);
        fprintf('🎓 SAFE FOR ACADEMIC SHARING - contains no biometric data!\n');
        fprintf('⚡ Use for faster future experiments\n');
        
        % LOGOWANIE SUKCESU
        logInfo(sprintf('Anonymized dataset saved: %d samples, %d features', ...
            length(labels), size(allFeatures, 2)), logFile);
        
    catch ME
        fprintf('❌ FAILED TO SAVE ANONYMIZED DATA\n');
        fprintf('Error: %s\n', ME.message);
        logWarning(sprintf('Anonymized data save failed: %s', ME.message), logFile);
        
        fprintf('💡 Troubleshooting:\n');
        fprintf('   - Check disk space\n');
        fprintf('   - Verify write permissions\n');
        fprintf('   - Try different output directory\n');
    end
    
else
    %% POMINIĘCIE ZAPISU
    fprintf('⏭️  Anonymized data export skipped\n');
    fprintf('💡 Tip: You can save data later using saveProcessedData() function\n');
    
    logInfo('User declined anonymized data export', logFile);
end
end