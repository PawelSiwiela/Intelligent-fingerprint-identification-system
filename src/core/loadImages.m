function [imageData, labels, metadata] = loadImages(dataPath, config, logFile)
% LOADIMAGES Wczytuje pliki Sample z wybranego formatu (PNG lub TIFF)
%
% Argumenty:
%   dataPath - ścieżka do folderu z danymi (np. 'data')
%   config - struktura konfiguracyjna (config.dataLoading.format = 'PNG' lub 'TIFF')
%   logFile - plik logów (opcjonalny)
%
% Output:
%   imageData - cell array z obrazami
%   labels - wektor etykiet (ID palca)
%   metadata - struktura z metadanymi

if nargin < 3, logFile = []; end

try
    % Pobierz wybrany format z konfiguracji
    selectedFormat = upper(config.dataLoading.format);
    
    logInfo(sprintf('Starting image loading for format: %s', selectedFormat), logFile);
    
    % Inicjalizacja
    imageData = {};
    labels = [];
    metadata = struct();
    
    % Sprawdź czy ścieżka istnieje
    if ~exist(dataPath, 'dir')
        logError(sprintf('Data directory does not exist: %s', dataPath), logFile);
        return;
    end
    
    % Sprawdź czy format jest obsługiwany
    if ~ismember(selectedFormat, {'PNG', 'TIFF'})
        logError(sprintf('Unsupported format: %s. Use PNG or TIFF.', selectedFormat), logFile);
        return;
    end
    
    % Znajdź wszystkie podfoldery palców (kciuk, wskazujący, etc.)
    fingerFolders = dir(dataPath);
    fingerFolders = fingerFolders([fingerFolders.isdir] & ~startsWith({fingerFolders.name}, '.'));
    
    if isempty(fingerFolders)
        logWarning('No finger folders found in data directory', logFile);
        return;
    end
    
    logInfo(sprintf('Found %d finger folders', length(fingerFolders)), logFile);
    
    % Liczniki
    totalImages = 0;
    fingerID = 1;
    
    % Inicjalizacja metadanych
    metadata.fingerNames = {};
    metadata.imagePaths = {};
    metadata.imageNames = {};
    metadata.loadTimestamp = datestr(now);
    metadata.totalFingers = length(fingerFolders);
    metadata.selectedFormat = selectedFormat;
    
    % Przetwarzaj każdy folder palca
    for i = 1:length(fingerFolders)
        fingerName = fingerFolders(i).name;
        fingerPath = fullfile(dataPath, fingerName);
        
        logInfo(sprintf('Processing finger %d/%d: %s', i, length(fingerFolders), fingerName), logFile);
        
        % Znajdź Sample pliki w wybranym formacie
        sampleFiles = findSampleFiles(fingerPath, selectedFormat);
        
        if isempty(sampleFiles)
            logWarning(sprintf('No %s Sample files found for finger: %s', selectedFormat, fingerName), logFile);
            continue;
        end
        
        logInfo(sprintf('Found %d %s Sample files for %s', length(sampleFiles), selectedFormat, fingerName), logFile);
        
        % Wczytaj każdy Sample obraz
        fingerImageCount = 0;
        for j = 1:length(sampleFiles)
            imagePath = sampleFiles{j};
            [~, imageName, ~] = fileparts(imagePath);
            
            try
                % Wczytaj obraz
                img = imread(imagePath);
                
                % Dodaj do kolekcji
                totalImages = totalImages + 1;
                fingerImageCount = fingerImageCount + 1;
                
                imageData{end+1} = img;
                labels(end+1) = fingerID;
                
                % Metadane
                metadata.imagePaths{end+1} = imagePath;
                metadata.imageNames{end+1} = imageName;
                
            catch ME
                logWarning(sprintf('Failed to load image %s: %s', imagePath, ME.message), logFile);
            end
        end
        
        % Zapisz nazwę palca tylko jeśli ma przynajmniej jeden obraz
        if fingerImageCount > 0
            metadata.fingerNames{fingerID} = fingerName;
            fingerID = fingerID + 1;
        end
        
        logInfo(sprintf('Loaded %d %s Sample images for %s', fingerImageCount, selectedFormat, fingerName), logFile);
    end
    
    % Finalne statystyki
    metadata.totalImages = totalImages;
    metadata.actualFingers = length(metadata.fingerNames);
    
    % Konwertuj labels na wektor kolumnowy
    labels = labels(:);
    
    logSuccess(sprintf('Loading completed: %d %s Sample images from %d fingers', ...
        totalImages, selectedFormat, metadata.actualFingers), logFile);
    
catch ME
    logError(sprintf('Error loading images: %s', ME.message), logFile);
    imageData = {};
    labels = [];
    metadata = struct();
end
end

%% HELPER FUNCTIONS

function sampleFiles = findSampleFiles(fingerPath, selectedFormat)
% FINDSAMPLEFILES Znajduje pliki Sample w wybranym formacie
    sampleFiles = {};
    
    % Określ folder i rozszerzenie na podstawie wybranego formatu
    switch upper(selectedFormat)
        case 'PNG'
            formatPath = fullfile(fingerPath, 'PNG');
            extension = '.png';
        case 'TIFF'
            formatPath = fullfile(fingerPath, 'TIFF');
            extension = '.tiff';
        otherwise
            logWarning(sprintf('Unknown format: %s', selectedFormat));
            return;
    end
    
    % Sprawdź czy folder istnieje
    if exist(formatPath, 'dir')
        sampleFiles = findSampleFilesInFolder(formatPath, extension);
    end
end

function sampleFiles = findSampleFilesInFolder(folderPath, extension)
% FINDSAMPLEFILESINFOLDER Znajduje pliki Sample o określonym rozszerzeniu
    sampleFiles = {};
    
    % Przeszukaj folder
    files = dir(folderPath);
    files = files(~[files.isdir]); % Tylko pliki
    
    for i = 1:length(files)
        fileName = files(i).name;
        [~, ~, ext] = fileparts(fileName);
        
        % Sprawdź czy to plik Sample o odpowiednim rozszerzeniu
        if strcmpi(ext, extension) && startsWith(fileName, 'Sample', 'IgnoreCase', true)
            fullPath = fullfile(folderPath, fileName);
            sampleFiles{end+1} = fullPath;
        end
    end
end