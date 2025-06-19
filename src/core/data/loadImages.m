function [imageData, labels, metadata] = loadImages(dataPath, config, logFile)
% LOADIMAGES Wczytuje i organizuje pliki Sample odcisków palców z hierarchii katalogów
%
% Funkcja wykonuje systematyczne wczytywanie obrazów odcisków palców z struktury
% katalogów, organizując je według klas (palców) i obsługując różne formaty
% plików (PNG/TIFF). Implementuje elastyczne mechanizmy obsługi błędów oraz
% szczegółowe logowanie procesu ładowania danych.
%
% Parametry wejściowe:
%   dataPath - ścieżka do głównego katalogu danych (np. 'data/fingerprints')
%   config - struktura konfiguracyjna:
%           .dataLoading.format - wybrany format plików ('PNG' lub 'TIFF')
%   logFile - uchwyt do pliku logów (opcjonalny, może być [])
%
% Parametry wyjściowe:
%   imageData - cell array z wczytanymi obrazami {[H×W×C], ...}
%   labels - wektor kolumnowy etykiet klas palców [samples × 1]
%   metadata - struktura metadanych:
%             .fingerNames - nazwy katalogów palców
%             .imagePaths - pełne ścieżki do plików obrazów
%             .imageNames - nazwy plików bez rozszerzeń
%             .loadTimestamp - znacznik czasu wczytywania
%             .totalFingers - liczba katalogów palców
%             .actualFingers - liczba palców z przynajmniej jednym obrazem
%             .totalImages - całkowita liczba wczytanych obrazów
%             .selectedFormat - użyty format plików
%
% Oczekiwana struktura katalogów:
%   dataPath/
%   ├── PalecNazwa1/              ← Katalog pierwszego palca
%   │   ├── PNG/
%   │   │   ├── Sample1.png       ← Pliki Sample w formacie PNG
%   │   │   ├── Sample2.png
%   │   │   └── Sample*.png
%   │   └── TIFF/
%   │       ├── Sample1.tiff      ← Pliki Sample w formacie TIFF
%   │       ├── Sample2.tiff
%   │       └── Sample*.tiff
%   ├── PalecNazwa2/              ← Katalog drugiego palca
%   │   ├── PNG/...
%   │   └── TIFF/...
%   └── ...
%
% Algorytm ładowania:
%   1. Walidacja ścieżki danych i formatu plików
%   2. Skanowanie katalogów palców (subdirectories)
%   3. Dla każdego palca: znajdowanie plików Sample w wybranym formacie
%   4. Wczytywanie obrazów z obsługą błędów indywidualnych plików
%   5. Organizacja danych: imageData{i} ↔ labels(i) ↔ fingerID
%   6. Tworzenie szczegółowych metadanych procesu
%
% Przykład użycia:
%   config.dataLoading.format = 'PNG';
%   [images, labels, meta] = loadImages('data/fingerprints', config, logFile);

if nargin < 3, logFile = []; end

try
    % Pobranie wybranego formatu z konfiguracji (konwersja na wielkie litery)
    selectedFormat = upper(config.dataLoading.format);
    
    logInfo(sprintf('🚀 Starting image loading process for format: %s', selectedFormat), logFile);
    
    % Inicjalizacja struktur wyjściowych
    imageData = {};
    labels = [];
    metadata = struct();
    
    % WALIDACJA PARAMETRÓW WEJŚCIOWYCH
    
    % Sprawdzenie istnienia ścieżki danych
    if ~exist(dataPath, 'dir')
        logError(sprintf('Data directory does not exist: %s', dataPath), logFile);
        return;
    end
    
    % Walidacja obsługiwanego formatu plików
    if ~ismember(selectedFormat, {'PNG', 'TIFF'})
        logError(sprintf('Unsupported format: %s. Supported: PNG, TIFF.', selectedFormat), logFile);
        return;
    end
    
    % SKANOWANIE STRUKTURY KATALOGÓW
    
    % Znajdź wszystkie podkatalogi (katalogi palców)
    fingerFolders = dir(dataPath);
    fingerFolders = fingerFolders([fingerFolders.isdir] & ~startsWith({fingerFolders.name}, '.'));
    
    if isempty(fingerFolders)
        logWarning('No finger subdirectories found in data directory', logFile);
        return;
    end
    
    logInfo(sprintf('📁 Found %d finger folders to process', length(fingerFolders)), logFile);
    
    % INICJALIZACJA METADANYCH I LICZNIKÓW
    
    totalImages = 0;
    fingerID = 1;  % Identyfikator numeryczny palca (klasy)
    
    metadata.fingerNames = {};
    metadata.imagePaths = {};
    metadata.imageNames = {};
    metadata.loadTimestamp = datestr(now);
    metadata.totalFingers = length(fingerFolders);
    metadata.selectedFormat = selectedFormat;
    
    % PRZETWARZANIE KAŻDEGO KATALOGU PALCA
    
    for i = 1:length(fingerFolders)
        fingerName = fingerFolders(i).name;
        fingerPath = fullfile(dataPath, fingerName);
        
        logInfo(sprintf('🔍 Processing finger %d/%d: %s', i, length(fingerFolders), fingerName), logFile);
        
        % Znajdź wszystkie pliki Sample w wybranym formacie dla tego palca
        sampleFiles = findSampleFiles(fingerPath, selectedFormat);
        
        if isempty(sampleFiles)
            logWarning(sprintf('No %s Sample files found for finger: %s', selectedFormat, fingerName), logFile);
            continue;  % Przejdź do następnego palca
        end
        
        logInfo(sprintf('📸 Found %d %s Sample files for %s', length(sampleFiles), selectedFormat, fingerName), logFile);
        
        % WCZYTYWANIE OBRAZÓW DLA AKTUALNEGO PALCA
        
        fingerImageCount = 0;
        for j = 1:length(sampleFiles)
            imagePath = sampleFiles{j};
            [~, imageName, ~] = fileparts(imagePath);
            
            try
                % Wczytaj obraz z pliku
                img = imread(imagePath);
                
                % Dodaj do kolekcji danych
                totalImages = totalImages + 1;
                fingerImageCount = fingerImageCount + 1;
                
                imageData{end+1} = img;          % Dodaj obraz do cell array
                labels(end+1) = fingerID;        % Przypisz etykietę klasy
                
                % Zapisz metadane dla tego obrazu
                metadata.imagePaths{end+1} = imagePath;
                metadata.imageNames{end+1} = imageName;
                
            catch ME
                % Loguj błąd ale kontynuuj przetwarzanie innych plików
                logWarning(sprintf('Failed to load image %s: %s', imagePath, ME.message), logFile);
            end
        end
        
        % Zapisz nazwę palca tylko jeśli udało się wczytać przynajmniej jeden obraz
        if fingerImageCount > 0
            metadata.fingerNames{fingerID} = fingerName;
            fingerID = fingerID + 1;  % Przejdź do następnego ID klasy
        end
        
        logInfo(sprintf('✅ Loaded %d %s Sample images for %s', fingerImageCount, selectedFormat, fingerName), logFile);
    end
    
    % FINALIZACJA METADANYCH
    
    metadata.totalImages = totalImages;
    metadata.actualFingers = length(metadata.fingerNames);
    
    % Konwertuj labels na wektor kolumnowy dla spójności
    labels = labels(:);
    
    logSuccess(sprintf('🎉 Loading completed successfully: %d %s Sample images from %d fingers', ...
        totalImages, selectedFormat, metadata.actualFingers), logFile);
    
catch ME
    % Obsługa globalnych błędów
    logError(sprintf('Critical error during image loading: %s', ME.message), logFile);
    imageData = {};
    labels = [];
    metadata = struct();
end
end

%% FUNKCJE POMOCNICZE

function sampleFiles = findSampleFiles(fingerPath, selectedFormat)
% FINDSAMPLEFILES Lokalizuje pliki Sample w wybranym formacie dla danego palca
%
% Funkcja przeszukuje odpowiedni podfolder (PNG lub TIFF) w katalogu palca
% w poszukiwaniu plików Sample o właściwym rozszerzeniu.

sampleFiles = {};

% Określ ścieżkę do podfolderu i rozszerzenie pliku na podstawie formatu
switch upper(selectedFormat)
    case 'PNG'
        formatPath = fullfile(fingerPath, 'PNG');
        extension = '.png';
    case 'TIFF'
        formatPath = fullfile(fingerPath, 'TIFF');
        extension = '.tiff';
    otherwise
        logWarning(sprintf('Unknown format in findSampleFiles: %s', selectedFormat));
        return;
end

% Sprawdź czy podfolder z formatem istnieje
if exist(formatPath, 'dir')
    sampleFiles = findSampleFilesInFolder(formatPath, extension);
end
end

function sampleFiles = findSampleFilesInFolder(folderPath, extension)
% FINDSAMPLEFILESINFOLDER Wyszukuje pliki Sample o określonym rozszerzeniu w folderze
%
% Funkcja skanuje dany folder w poszukiwaniu plików, których nazwa zaczyna się
% od "Sample" (case-insensitive) i mają określone rozszerzenie.

sampleFiles = {};

% Pobierz listę wszystkich plików w folderze (bez podkatalogów)
files = dir(folderPath);
files = files(~[files.isdir]); % Filtruj tylko pliki

% Przeszukaj każdy plik
for i = 1:length(files)
    fileName = files(i).name;
    [~, ~, ext] = fileparts(fileName);
    
    % Sprawdź czy plik spełnia kryteria:
    % 1. Nazwa zaczyna się od "Sample" (ignorując wielkość liter)
    % 2. Rozszerzenie pasuje do wybranego formatu
    if strcmpi(ext, extension) && startsWith(fileName, 'Sample', 'IgnoreCase', true)
        fullPath = fullfile(folderPath, fileName);
        sampleFiles{end+1} = fullPath;
    end
end
end