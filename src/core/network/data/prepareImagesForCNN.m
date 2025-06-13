function imageArray = prepareImagesForCNN(imagesCellArray, targetSize, verbose)
% PREPAREIMAGESFORCNN Konwertuje cell array obrazów do 4D array dla CNN
%
% Args:
%   imagesCellArray - cell array z obrazami
%   targetSize - docelowy rozmiar [height, width] np. [128, 128]
%   verbose - czy wyświetlać debug info (default: false)
%
% Returns:
%   imageArray - 4D array [height × width × channels × samples] dla CNN

if nargin < 2
    targetSize = [128, 128];
end

if nargin < 3
    verbose = false;
end

numImages = length(imagesCellArray);

if numImages == 0
    imageArray = [];
    return;
end

if verbose
    fprintf('🔧 Preparing %d images for CNN...\n', numImages);
    fprintf('   Target size: [%d × %d × 1]\n', targetSize(1), targetSize(2));
end

% Inicjalizacja 4D array
imageArray = zeros(targetSize(1), targetSize(2), 1, numImages, 'single');

for i = 1:numImages
    originalImage = imagesCellArray{i};
    
    if isempty(originalImage)
        % Fallback - czarny obraz
        processedImage = zeros(targetSize, 'single');
        if verbose
            fprintf('   Image %d: Empty -> filled with zeros\n', i);
        end
    else
        try
            % 1. Konwertuj do single precision
            img = single(originalImage);
            
            % 2. Normalizuj do [0,1]
            if max(img(:)) > 1
                img = img / 255;
            end
            
            % 3. Jeśli obraz kolorowy, konwertuj do grayscale
            if size(img, 3) > 1
                img = rgb2gray(img);
            end
            
            % 4. Resize do target size
            processedImage = imresize(img, targetSize, 'bilinear');
            
            % 5. Upewnij się że to binary/grayscale
            if max(processedImage(:)) > 1
                processedImage = processedImage / max(processedImage(:));
            end
            
            % 6. Konwertuj do single
            processedImage = single(processedImage);
            
            if verbose && i <= 3
                fprintf('   Image %d: [%dx%d] -> [%dx%d], range: [%.3f, %.3f]\n', ...
                    i, size(originalImage, 1), size(originalImage, 2), ...
                    targetSize(1), targetSize(2), min(processedImage(:)), max(processedImage(:)));
            end
            
        catch ME
            if verbose
                fprintf('   ⚠️ Error processing image %d: %s\n', i, ME.message);
            end
            processedImage = zeros(targetSize, 'single');
        end
    end
    
    % Zapisz obraz do 4D array
    imageArray(:, :, 1, i) = processedImage;
end

if verbose
    fprintf('✅ Images prepared for CNN: [%d × %d × %d × %d]\n', size(imageArray));
    fprintf('   Data type: %s, Range: [%.3f, %.3f]\n', ...
        class(imageArray), min(imageArray(:)), max(imageArray(:)));
end
end