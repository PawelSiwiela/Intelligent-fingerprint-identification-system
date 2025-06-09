function [images, labels] = loadImages(config, logFile)
% LOADIMAGES Wczytuje obrazy odcisków palców
%   [images, labels] = LOADIMAGES(config, logFile) wczytuje obrazy odcisków palców
%   z katalogu określonego w konfiguracji, zwracając macierz obrazów oraz
%   etykiety identyfikujące palce.
%
%   Parametry:
%     config - struktura zawierająca konfigurację, w tym ścieżki do katalogów
%     logFile - opcjonalny plik dziennika do rejestrowania postępu
%
%   Wyjście:
%     images - komórka zawierająca obrazy odcisków palców
%     labels - wektor etykiet (1-5) odpowiadających poszczególnym palcom

% Czas rozpoczęcia
ticStart = tic;

% Katalog główny z danymi
dataDir = config.dataPath;

% Nazwy folderów palców
fingerFolders = {'kciuk', 'wskazujący', 'środkowy', 'serdeczny', 'mały'};

% Format obrazów do wczytania
if isfield(config, 'imageFormat')
    format = config.imageFormat;
else
    format = 'png';
end

% Przygotowanie kontenerów na dane
images = {};
labels = [];

% Liczniki obrazów
totalImages = 0;
loadedImages = 0;

% Logowanie rozpoczęcia
logInfo('  Rozpoczęto wczytywanie obrazów...', logFile);

% Wczytywanie obrazów z każdego folderu
for i = 1:length(fingerFolders)
    fingerName = fingerFolders{i};
    fprintf('  Wczytywanie obrazów palca: %s\n', fingerName);
    
    % Sprawdź kolejno wszystkie możliwe lokalizacje plików
    possibleLocations = {
        fullfile(dataDir, fingerName, upper(format)), % D:/.../data/kciuk/PNG/
        fullfile(dataDir, fingerName, lower(format)), % D:/.../data/kciuk/png/
        fullfile(dataDir, fingerName) % Bezpośrednio w katalogu palca
        };
    
    foundFiles = false;
    
    % Sprawdź każdą możliwą lokalizację
    for locIdx = 1:length(possibleLocations)
        currentDir = possibleLocations{locIdx};
        
        if ~exist(currentDir, 'dir')
            fprintf('  Katalog %s nie istnieje, sprawdzam kolejną lokalizację...\n', currentDir);
            continue;
        end
        
        filePattern = fullfile(currentDir, ['*.' format]);
        
        files = dir(filePattern);
        
        % Jeśli znaleziono pliki, wczytaj je
        if ~isempty(files)
            foundFiles = true;
            
            % Liczba znalezionych obrazów
            numImages = length(files);
            totalImages = totalImages + numImages;
            
            fprintf('    Znaleziono %d obrazów w %s\n', numImages, currentDir);
            
            % Wczytanie każdego obrazu
            for j = 1:numImages
                try
                    % Pełna ścieżka do pliku
                    imagePath = fullfile(currentDir, files(j).name);
                    
                    % Wczytanie obrazu
                    img = imread(imagePath);
                    
                    % Konwersja do skali szarości, jeśli obraz jest kolorowy
                    if size(img, 3) > 1
                        img = rgb2gray(img);
                    end
                    
                    % Dodanie obrazu do listy
                    images{end+1} = img;
                    
                    % Dodanie etykiety (numer palca)
                    labels(end+1) = i;
                    
                    loadedImages = loadedImages + 1;
                catch e
                    warning('Nie można wczytać obrazu %s: %s', files(j).name, e.message);
                end
            end
            
            break; % Przerwij po znalezieniu plików w jednej z lokalizacji
        end
    end
    
    if ~foundFiles
        warning('Nie znaleziono żadnych plików %s dla palca %s', format, fingerName);
    end
end

% Sprawdź czy wczytano jakiekolwiek obrazy
if loadedImages == 0
    error('Nie wczytano żadnych obrazów. Sprawdź ścieżki i format plików.');
end

% Wyświetlenie podsumowania
timeElapsed = toc(ticStart);
fprintf('  Wczytano %d/%d obrazów odcisków palców w %.2f sekund\n', ...
    loadedImages, totalImages, timeElapsed);

% Logowanie zakończenia
logInfo(sprintf('  Wczytano %d/%d obrazów odcisków palców', loadedImages, totalImages), logFile);
end

