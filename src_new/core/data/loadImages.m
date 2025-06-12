function [images, labels] = loadImages(config, logFile)
% LOADIMAGES Wczytuje obrazy odcisków palców z katalogu danych
%
% Argumenty:
%   config - konfiguracja systemu
%   logFile - plik logów (opcjonalny)
%
% Output:
%   images - cell array obrazów w skali szarości
%   labels - wektor etykiet (1-5)

if nargin < 2, logFile = []; end

ticStart = tic;
logInfo('=== WCZYTYWANIE OBRAZÓW ===', logFile);

% Katalog główny z danymi
dataDir = config.dataPath;
fingerFolders = {'kciuk', 'wskazujący', 'środkowy', 'serdeczny', 'mały'};
format = config.imageFormat;

% Kontejnery na dane
images = {};
labels = [];
totalImages = 0;
loadedImages = 0;

logInfo(sprintf('📂 Wczytywanie obrazów z katalogu: %s', dataDir), logFile);

% Wczytywanie z każdego folderu palca
for i = 1:length(fingerFolders)
    fingerName = fingerFolders{i};
    logInfo(sprintf('   📁 Palec %d - %s...', i, fingerName), logFile);
    
    % Możliwe lokalizacje plików
    possiblePaths = {
        fullfile(dataDir, fingerName, upper(format)),
        fullfile(dataDir, fingerName, lower(format)),
        fullfile(dataDir, fingerName)
        };
    
    foundFiles = false;
    
    % Sprawdź każdą lokalizację
    for pathIdx = 1:length(possiblePaths)
        currentDir = possiblePaths{pathIdx};
        
        if ~exist(currentDir, 'dir')
            continue;
        end
        
        filePattern = fullfile(currentDir, ['*.' format]);
        files = dir(filePattern);
        
        if ~isempty(files)
            foundFiles = true;
            numImages = length(files);
            totalImages = totalImages + numImages;
            
            logInfo(sprintf('      Znaleziono %d obrazów w %s', numImages, currentDir), logFile);
            
            % Wczytaj każdy obraz
            for j = 1:numImages
                try
                    imagePath = fullfile(currentDir, files(j).name);
                    img = imread(imagePath);
                    
                    % Konwersja do skali szarości
                    if size(img, 3) > 1
                        img = rgb2gray(img);
                    end
                    
                    % Dodaj do kolekcji
                    images{end+1} = img;
                    labels(end+1) = i;
                    loadedImages = loadedImages + 1;
                    
                catch ME
                    logWarning(sprintf('Błąd wczytywania %s: %s', files(j).name, ME.message), logFile);
                end
            end
            
            break; % Przerwij po znalezieniu plików
        end
    end
    
    if ~foundFiles
        logWarning(sprintf('Brak plików %s dla palca %s', format, fingerName), logFile);
    end
end

% Sprawdź czy coś wczytano
if loadedImages == 0
    error('Nie wczytano żadnych obrazów. Sprawdź ścieżki i format plików.');
end

% Podsumowanie
timeElapsed = toc(ticStart);
logSuccess(sprintf('Wczytano %d/%d obrazów w %.2f sekund', loadedImages, totalImages, timeElapsed), logFile);

fprintf('✅ WCZYTYWANIE UKOŃCZONE:\n');
fprintf('   📊 Załadowano: %d obrazów\n', loadedImages);
fprintf('   ⏱️ Czas: %.2f sekund\n', timeElapsed);

% Wyświetl rozkład palców
for finger = 1:5
    count = sum(labels == finger);
    fprintf('   👆 Palec %d (%s): %d obrazów\n', finger, fingerFolders{finger}, count);
end
end