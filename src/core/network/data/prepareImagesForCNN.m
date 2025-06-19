function imageArray = prepareImagesForCNN(imagesCellArray, targetSize, verbose)
% PREPAREIMAGESFORCNN Konwertuje cell array obrazów do 4D tensor dla CNN
%
% Funkcja przetwarza cell array z obrazami odcisków palców i konwertuje je
% do ustandaryzowanego 4D tensor wymaganego przez CNN w MATLAB. Wykonuje
% normalizację, konwersję do skali szarości, resize i kontrolę jakości danych.
%
% Parametry wejściowe:
%   imagesCellArray - cell array z obrazami (różne rozmiary/typy dozwolone)
%   targetSize - docelowy rozmiar [height, width] np. [128, 128]
%               domyślnie: [128, 128] (optymalny dla CNN na odciskach palców)
%   verbose - flaga debug output (boolean, domyślnie: false)
%
% Parametry wyjściowe:
%   imageArray - 4D tensor [height × width × channels × samples] typu single
%                gotowy do podania do trainNetwork() w MATLAB
%
% Algorytm przetwarzania każdego obrazu:
%   1. Konwersja do single precision
%   2. Normalizacja wartości do zakresu [0,1]
%   3. Konwersja do grayscale jeśli kolorowy
%   4. Resize do targetSize z interpolacją bilinear
%   5. Finalna kontrola zakresu i typu danych
%
% Przykład użycia:
%   tensor4D = prepareImagesForCNN(imagesCellArray, [64, 64], true);

if nargin < 2
    targetSize = [128, 128]; % Optymalny rozmiar dla CNN na odciskach palców
end

if nargin < 3
    verbose = false;
end

numImages = length(imagesCellArray);

% Obsługa pustego input
if numImages == 0
    imageArray = [];
    return;
end

if verbose
    fprintf('🔧 Preparing %d images for CNN...\n', numImages);
    fprintf('   Target size: [%d × %d × 1]\n', targetSize(1), targetSize(2));
end

% Inicjalizacja 4D tensor - [height, width, channels, samples]
% Typ single dla kompatybilności z GPU i redukcji zużycia pamięci
imageArray = zeros(targetSize(1), targetSize(2), 1, numImages, 'single');

% Przetwarzanie każdego obrazu osobno
for i = 1:numImages
    originalImage = imagesCellArray{i};
    
    if isempty(originalImage)
        % Fallback dla pustych obrazów - wypełnij zerami
        processedImage = zeros(targetSize, 'single');
        if verbose
            fprintf('   Image %d: Empty -> filled with zeros\n', i);
        end
    else
        try
            % ETAP 1: Konwersja do single precision floating point
            img = single(originalImage);
            
            % ETAP 2: Normalizacja do zakresu [0,1]
            % Obsługa różnych formatów wejściowych (uint8 vs double)
            if max(img(:)) > 1
                img = img / 255; % Zakłada format uint8 [0-255]
            end
            
            % ETAP 3: Konwersja do grayscale jeśli obraz kolorowy
            if size(img, 3) > 1
                img = rgb2gray(img);
            end
            
            % ETAP 4: Resize do jednolitego rozmiaru z interpolacją bilinear
            % Zachowuje gładkość linii papilarnych
            processedImage = imresize(img, targetSize, 'bilinear');
            
            % ETAP 5: Kontrola i normalizacja końcowa
            if max(processedImage(:)) > 1
                processedImage = processedImage / max(processedImage(:));
            end
            
            % ETAP 6: Zapewnienie typu single dla CNN
            processedImage = single(processedImage);
            
            % Debug output dla pierwszych kilku obrazów
            if verbose && i <= 3
                fprintf('   Image %d: [%dx%d] -> [%dx%d], range: [%.3f, %.3f]\n', ...
                    i, size(originalImage, 1), size(originalImage, 2), ...
                    targetSize(1), targetSize(2), min(processedImage(:)), max(processedImage(:)));
            end
            
        catch ME
            % Obsługa błędów przetwarzania - zastąp czarnym obrazem
            if verbose
                fprintf('   ⚠️ Error processing image %d: %s\n', i, ME.message);
            end
            processedImage = zeros(targetSize, 'single');
        end
    end
    
    % Zapisz przetworzony obraz do 4D tensor
    % Wymiar 3 (channels) = 1 dla grayscale
    imageArray(:, :, 1, i) = processedImage;
end

% Finalne raportowanie statystyk
if verbose
    fprintf('✅ Images prepared for CNN: [%d × %d × %d × %d]\n', size(imageArray));
    fprintf('   Data type: %s, Range: [%.3f, %.3f]\n', ...
        class(imageArray), min(imageArray(:)), max(imageArray(:)));
end
end