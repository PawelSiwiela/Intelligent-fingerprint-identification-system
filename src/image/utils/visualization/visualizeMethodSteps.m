function visualizeMethodSteps(image, method, logFile)
% VISUALIZEMETHODSTEPS Wizualizuje kroki jednej metody preprocessingu
%
% Input:
%   image - oryginalny obraz
%   method - nazwa metody ('basic', 'hybrid', 'advanced')
%   logFile - plik logu (opcjonalny)

if nargin < 3, logFile = []; end

switch lower(method)
    case 'basic'
        visualizeBasicSteps(image, logFile);
    case 'hybrid'
        visualizeHybridSteps(image, logFile);
    case 'advanced'
        visualizeAdvancedSteps(image, logFile);
    otherwise
        error('Unknown method: %s', method);
end
end

function visualizeBasicSteps(image, logFile)
% Wizualizacja kroków metody BASIC

% Wykonaj kroki i zachowaj pośrednie rezultaty
if size(image, 3) == 3, image = rgb2gray(image); end
if ~isa(image, 'double'), image = im2double(image); end

% Krok po kroku
enhanced = adapthisteq(image, 'ClipLimit', 0.02, 'TileGridSize', [8 8]);
enhanced = imadjust(enhanced);

denoised = medfilt2(enhanced, [3 3]);
gaussFilter = fspecial('gaussian', [5 5], 1.0);
denoised = imfilter(denoised, gaussFilter, 'same', 'replicate');

edges = edge(denoised, 'canny', [0.1 0.25], 1.0);
binary = imbinarize(denoised, 'adaptive', 'Sensitivity', 0.5);
combined = binary | edges;

se = strel('disk', 2);
opened = imopen(combined, se);
closed = imclose(opened, se);
filled = imfill(closed, 'holes');

final = bwareaopen(filled, 30);
final = bwmorph(final, 'clean');

% Wizualizacja
figure('Position', [50, 50, 1400, 800], 'Name', 'BASIC Preprocessing Steps');

steps = {image, enhanced, denoised, edges, binary, combined, opened, final};
titles = {'Original', 'Enhanced', 'Denoised', 'Edges', 'Binary', 'Combined', 'Morphology', 'Final'};

for i = 1:length(steps)
    subplot(2, 4, i);
    imshow(steps{i});
    title(titles{i}, 'FontSize', 12, 'FontWeight', 'bold');
end

sgtitle('BASIC Preprocessing Pipeline', 'FontSize', 16, 'FontWeight', 'bold');
end

function visualizeHybridSteps(image, logFile)
% Wizualizacja kroków metody HYBRID

if size(image, 3) == 3, image = rgb2gray(image); end
if ~isa(image, 'double'), image = im2double(image); end

% Wykonaj oba pipeline'y
basicResult = basicPreprocessing(image, []);

try
    orientation = computeRidgeOrientation(image, 16);
    frequency = computeRidgeFrequency(image, orientation, 32);
    gaborFiltered = applyGaborFilter(image, orientation, frequency);
    gaborResult = imbinarize(gaborFiltered, 'adaptive', 'Sensitivity', 0.4);
    combined = basicResult | gaborResult;
    final = bwareaopen(combined, 25);
    final = bwmorph(final, 'clean');
    
    gaborSuccess = true;
catch
    final = basicResult;
    gaborSuccess = false;
end

% Wizualizacja
figure('Position', [50, 50, 1200, 600], 'Name', 'HYBRID Preprocessing Steps');

if gaborSuccess
    steps = {image, basicResult, gaborFiltered, gaborResult, combined, final};
    titles = {'Original', 'BASIC Result', 'Gabor Filtered', 'Gabor Binary', 'Combined', 'Final'};
else
    steps = {image, basicResult, final};
    titles = {'Original', 'BASIC Result', 'Final (Gabor Failed)'};
end

numSteps = length(steps);
for i = 1:numSteps
    subplot(2, ceil(numSteps/2), i);
    imshow(steps{i});
    title(titles{i}, 'FontSize', 12, 'FontWeight', 'bold');
end

sgtitle('HYBRID Preprocessing Pipeline', 'FontSize', 16, 'FontWeight', 'bold');
end

function visualizeAdvancedSteps(image, logFile)
% Wizualizacja kroków metody ADVANCED

if size(image, 3) == 3, image = rgb2gray(image); end
if ~isa(image, 'double'), image = im2double(image); end

try
    % Wykonaj kroki
    orientation = computeRidgeOrientation(image, 16);
    frequency = computeRidgeFrequency(image, orientation, 32);
    gaborFiltered = applyGaborFilter(image, orientation, frequency);
    [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
    binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
    skeletonImage = ridgeThinning(binaryImage);
    final = removeArtifacts(skeletonImage, mask);
    
    % Wizualizacja
    figure('Position', [50, 50, 1400, 800], 'Name', 'ADVANCED Preprocessing Steps');
    
    steps = {image, orientation, gaborFiltered, mask, binaryImage, skeletonImage, final};
    titles = {'Original', 'Orientation', 'Gabor Filtered', 'Mask', 'Binary', 'Skeleton', 'Final'};
    
    for i = 1:length(steps)
        subplot(2, 4, i);
        if i == 2 % Orientation map
            imagesc(steps{i}); colormap(gca, hsv); colorbar;
            title(titles{i}, 'FontSize', 12, 'FontWeight', 'bold');
        else
            imshow(steps{i});
            title(titles{i}, 'FontSize', 12, 'FontWeight', 'bold');
        end
    end
    
    sgtitle('ADVANCED Preprocessing Pipeline', 'FontSize', 16, 'FontWeight', 'bold');
    
catch ME
    % Fallback visualization
    figure('Position', [50, 50, 600, 400], 'Name', 'ADVANCED Preprocessing (Failed)');
    
    subplot(1, 2, 1);
    imshow(image);
    title('Original', 'FontSize', 12, 'FontWeight', 'bold');
    
    subplot(1, 2, 2);
    fallbackResult = imbinarize(image);
    imshow(fallbackResult);
    title('Fallback Result', 'FontSize', 12, 'FontWeight', 'bold');
    
    sgtitle(sprintf('ADVANCED Failed: %s', ME.message), 'FontSize', 14, 'Color', 'red');
end
end