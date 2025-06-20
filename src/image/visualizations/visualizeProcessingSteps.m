function visualizeProcessingSteps(originalImage, preprocessedImage, minutiae, imageIndex, outputDir)
% VISUALIZEPROCESSINGSTEPS Enhanced preprocessing pipeline visualization v3
%
% Funkcja tworzy szczegółową wizualizację 8-etapowego procesu preprocessingu
% odcisku palca zgodną z rzeczywistym pipelinemm z preprocessing.m
%
% Parametry wejściowe:
%   originalImage - oryginalny obraz odcisku palca
%   preprocessedImage - finalny przetworzony obraz (szkielet)
%   minutiae - macierz wykrytych minucji [x, y, angle, type, quality]
%   imageIndex - numer obrazu dla nazwy pliku
%   outputDir - katalog wyjściowy (opcjonalny, domyślnie 'output/figures')

if nargin < 5
    outputDir = 'output/figures';
end

% UPEWNIJ SIĘ że katalog istnieje
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

try
    % FIGURA z prostszym layoutem (2x4 zamiast 2x5)
    figure('Position', [50, 50, 2400, 700], 'Visible', 'off');
    
    % WYKONAJ RZECZYSTE KROKI PREPROCESSINGU
    workingImage = originalImage;
    if size(workingImage, 3) == 3
        workingImage = rgb2gray(workingImage);
    end
    workingImage = im2double(workingImage);
    
    %% KROK 1: ORYGINALNY OBRAZ
    subplot(2, 4, 1);
    imshow(originalImage);
    title('1. Original Image', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0, 0.8]);
    xlabel('Raw fingerprint', 'FontSize', 10);
    addQualityBorder(gca, 'input');
    
    %% KROK 2: ORIENTACJA (zgodnie z computeRidgeOrientation.m)
    subplot(2, 4, 2);
    try
        orientation = computeRidgeOrientation(workingImage, 16);
        orientationVis = createEnhancedOrientationVisualization(workingImage, orientation);
        imshow(orientationVis);
        title('2. Ridge Orientation', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0.6, 0]);
        xlabel('Tensor structure analysis', 'FontSize', 10);
        addQualityBorder(gca, 'good');
    catch
        [Gx, Gy] = gradient(workingImage);
        gradMag = sqrt(Gx.^2 + Gy.^2);
        imshow(gradMag, []);
        title('2. Gradient (Fallback)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Edge detection', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
        orientation = zeros(size(workingImage));
    end
    
    %% KROK 3: CZĘSTOTLIWOŚĆ (zgodnie z computeRidgeFrequency.m)
    subplot(2, 4, 3);
    try
        frequency = computeRidgeFrequency(workingImage, orientation, 32);
        freqVis = frequency / max(frequency(:));
        imagesc(freqVis);
        colormap(gca, 'jet');
        colorbar('FontSize', 8);
        title('3. Ridge Frequency', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'magenta');
        xlabel('FFT projection analysis', 'FontSize', 10);
        addQualityBorder(gca, 'good');
        axis image; axis off;
    catch
        imshow(workingImage);
        title('3. Frequency (Failed)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'red');
        xlabel('Analysis failed', 'FontSize', 10);
        addQualityBorder(gca, 'error');
        frequency = 0.1 * ones(size(workingImage));
    end
    
    %% KROK 4: FILTRACJA GABORA (zgodnie z applyGaborFilter.m)
    subplot(2, 4, 4);
    try
        gaborFiltered = applyGaborFilter(workingImage, orientation, frequency);
        enhancedGabor = adapthisteq(gaborFiltered, 'ClipLimit', 0.02);
        imshow(enhancedGabor);
        title('4. Gabor Enhanced', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.6, 0, 0]);
        xlabel('Adaptive ridge enhancement', 'FontSize', 10);
        addQualityBorder(gca, 'excellent');
    catch
        gaborFiltered = imadjust(workingImage);
        imshow(gaborFiltered);
        title('4. Enhanced (Simple)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Basic enhancement', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
    end
    
    %% KROK 5: SEGMENTACJA (zgodnie z segmentFingerprint.m)
    subplot(2, 4, 5);
    try
        [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
        segVis = createSegmentationOverlay(segmentedImage, mask);
        imshow(segVis);
        title('5. Segmented ROI', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'blue');
        xlabel('Variance-based ROI', 'FontSize', 10);
        addQualityBorder(gca, 'good');
    catch
        segmentedImage = imbinarize(gaborFiltered, 'adaptive');
        imshow(segmentedImage);
        title('5. Thresholded', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Binary fallback', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
        mask = ones(size(segmentedImage));
    end
    
    %% KROK 6: BINARYZACJA (zgodnie z orientationAwareBinarization.m)
    subplot(2, 4, 6);
    try
        if exist('orientation', 'var') && exist('mask', 'var')
            binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
        else
            binaryImage = imbinarize(segmentedImage);
        end
        
        binaryVis = createColoredBinary(binaryImage);
        imshow(binaryVis);
        title('6. Orientation-Aware Binary', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0.6, 0]);
        xlabel('Adaptive block thresholding', 'FontSize', 10);
        addQualityBorder(gca, 'good');
    catch
        binaryImage = imbinarize(segmentedImage);
        imshow(binaryImage);
        title('6. Simple Binary', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Standard binarization', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
    end
    
    %% KROK 7: SZKIELET (zgodnie z ridgeThinning.m)
    subplot(2, 4, 7);
    try
        skeletonImage = ridgeThinning(binaryImage);
        
        if exist('mask', 'var')
            finalSkeleton = skeletonImage & mask;
        else
            finalSkeleton = skeletonImage;
        end
        finalSkeleton = bwmorph(finalSkeleton, 'clean');
        
        skelVis = createEnhancedSkeleton(finalSkeleton);
        imshow(skelVis);
        title('7. Ridge Skeleton', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'magenta');
        
        coverage = sum(finalSkeleton(:)) / numel(finalSkeleton) * 100;
        xlabel(sprintf('Coverage: %.2f%% | Gentle thinning', coverage), 'FontSize', 10);
        
        if coverage > 3
            addQualityBorder(gca, 'excellent');
        elseif coverage > 1
            addQualityBorder(gca, 'good');
        else
            addQualityBorder(gca, 'warning');
        end
    catch
        finalSkeleton = preprocessedImage;
        imshow(finalSkeleton);
        title('7. Skeleton (Fallback)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'red');
        xlabel('Processing fallback', 'FontSize', 10);
        addQualityBorder(gca, 'error');
    end
    
    %% KROK 8: MINUCJE - BEZ LEGENDY NA OBRAZIE
    subplot(2, 4, 8);
    
    % Wyświetl szkielet jako tło
    if exist('finalSkeleton', 'var')
        imshow(finalSkeleton);
    else
        imshow(preprocessedImage);
    end
    hold on;
    
    % Przygotuj dane do legendy
    endingCount = 0;
    bifurcationCount = 0;
    legendText = '';
    
    if ~isempty(minutiae) && size(minutiae, 2) >= 4
        % DODAJ FILTRY KRAWĘDZI - ignoruj minucje blisko krawędzi
        [rows, cols] = size(preprocessedImage);
        borderMargin = 10;
        
        % Rysuj minucje bez legendy na obrazie
        for i = 1:size(minutiae, 1)
            x = minutiae(i, 1);
            y = minutiae(i, 2);
            type = minutiae(i, 4);
            
            % IGNORUJ minucje blisko krawędzi
            if x <= borderMargin || y <= borderMargin || x >= cols-borderMargin || y >= rows-borderMargin
                continue;
            end
            
            % Kolor i kształt według typu minucji
            if type == 1 % Ending (punkt końcowy)
                markerColor = 'red';
                markerShape = 'o';
                markerSize = 2;
                endingCount = endingCount + 1;
            else % Bifurcation (bifurkacja)
                markerColor = 'blue';
                markerShape = 'o';
                markerSize = 2;
                bifurcationCount = bifurcationCount + 1;
            end
            
            % Rysuj punkt minucji z lepszą widocznością
            scatter(x, y, markerSize^2*4, markerColor, markerShape, 'filled', ...
                'MarkerEdgeColor', 'white', 'LineWidth', 0.8, 'MarkerFaceAlpha', 0.9);
        end
        
        % Przygotuj tekst legendy (będzie wyświetlony pod obrazem)
        if endingCount > 0 && bifurcationCount > 0
            legendText = sprintf('● Endings: %d   ● Bifurcations: %d', endingCount, bifurcationCount);
        elseif endingCount > 0
            legendText = sprintf('● Endings: %d', endingCount);
        elseif bifurcationCount > 0
            legendText = sprintf('● Bifurcations: %d', bifurcationCount);
        end
        
        % JAKOŚĆ i informacje o minucjach
        if size(minutiae, 2) >= 5
            totalQuality = mean(minutiae(:, 5));
            minutiaeInfo = sprintf('Total: %d (E:%d, B:%d) | Q:%.2f', ...
                endingCount + bifurcationCount, endingCount, bifurcationCount, totalQuality);
            
            if totalQuality > 0.7
                qualityColor = [0, 0.6, 0];
                qualityLevel = 'excellent';
            elseif totalQuality > 0.5
                qualityColor = 'blue';
                qualityLevel = 'good';
            else
                qualityColor = [1, 0.6, 0];
                qualityLevel = 'warning';
            end
        else
            minutiaeInfo = sprintf('Total: %d (E:%d, B:%d)', ...
                endingCount + bifurcationCount, endingCount, bifurcationCount);
            qualityColor = 'blue';
            qualityLevel = 'good';
        end
        
        addQualityBorder(gca, qualityLevel);
    else
        minutiaeInfo = 'No minutiae detected';
        qualityColor = 'red';
        addQualityBorder(gca, 'error');
        legendText = 'No minutiae found';
    end
    
    hold off;
    title('8. Enhanced Minutiae', 'FontSize', 12, 'FontWeight', 'bold', 'Color', qualityColor);
    
    % LEGENDA POD OBRAZEM zamiast w xlabel
    if ~isempty(legendText)
        xlabel(sprintf('%s\n%s', legendText, minutiaeInfo), 'FontSize', 10);
    else
        xlabel(minutiaeInfo, 'FontSize', 10);
    end
    
    %% GŁÓWNY TYTUŁ
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    sgtitle(sprintf('ENHANCED PREPROCESSING PIPELINE v3 - Sample %d | %s', imageIndex, timestamp), ...
        'FontSize', 18, 'FontWeight', 'bold', 'Color', [0, 0, 0.8]);
    
    %% ZAPISZ
    filename = sprintf('enhanced_pipeline_v3_sample_%03d.png', imageIndex);
    filepath = fullfile(outputDir, filename);
    
    set(gcf, 'PaperPositionMode', 'auto');
    print(gcf, filepath, '-dpng', '-r350');
    
    close(gcf);
    
    fprintf('  📊 Enhanced pipeline v3 visualization saved: %s\n', filename);
    
catch ME
    fprintf('  ⚠️  Enhanced pipeline visualization failed for image %d: %s\n', imageIndex, ME.message);
    if exist('gcf', 'var')
        close(gcf);
    end
end
end

%% ENHANCED HELPER FUNCTIONS

function orientationVis = createEnhancedOrientationVisualization(image, orientation)
% Enhanced orientation visualization with HSV colormap

[rows, cols] = size(image);
orientationVis = zeros(rows, cols, 3);

% Convert orientation to HSV
hue = (orientation + pi/2) / pi; % Normalize to [0,1]
saturation = ones(size(orientation)) * 0.8;
value = image;

% Convert HSV to RGB
orientationVis(:,:,1) = hue;
orientationVis(:,:,2) = saturation;
orientationVis(:,:,3) = value;
orientationVis = hsv2rgb(orientationVis);

% Overlay orientation vectors
step = 16;
lineLength = 8;

for i = step:step:rows-step
    for j = step:step:cols-step
        if i <= size(orientation, 1) && j <= size(orientation, 2)
            angle = orientation(i, j);
            dx = lineLength * cos(angle);
            dy = lineLength * sin(angle);
            
            x1 = max(1, min(cols, round(j - dx/2)));
            y1 = max(1, min(rows, round(i - dy/2)));
            x2 = max(1, min(cols, round(j + dx/2)));
            y2 = max(1, min(rows, round(i + dy/2)));
            
            linePixels = bresenham(x1, y1, x2, y2);
            for k = 1:size(linePixels, 1)
                px = linePixels(k, 1);
                py = linePixels(k, 2);
                if px >= 1 && px <= cols && py >= 1 && py <= rows
                    orientationVis(py, px, :) = [1, 1, 1]; % White lines
                end
            end
        end
    end
end
end

%% POZOSTAŁE FUNKCJE POMOCNICZE

function segVis = createSegmentationOverlay(image, mask)
segVis = repmat(image, [1, 1, 3]);
boundary = bwperim(mask);
segVis(:,:,1) = segVis(:,:,1) + 0.3 * double(boundary);
segVis(:,:,2) = segVis(:,:,2) - 0.2 * double(boundary);
segVis(:,:,3) = segVis(:,:,3) - 0.2 * double(boundary);
segVis = max(0, min(1, segVis));
end

function binaryVis = createColoredBinary(binaryImage)
binaryVis = zeros([size(binaryImage), 3]);
binaryVis(:,:,1) = 0.2;
binaryVis(:,:,2) = 0.1;
binaryVis(:,:,3) = 0.1;
binaryVis(:,:,1) = binaryVis(:,:,1) + 0.8 * double(binaryImage);
binaryVis(:,:,2) = binaryVis(:,:,2) + 0.8 * double(binaryImage);
binaryVis(:,:,3) = binaryVis(:,:,3) + 0.8 * double(binaryImage);
end

function skelVis = createEnhancedSkeleton(skeleton)
skelVis = zeros([size(skeleton), 3]);
skelVis(:,:,3) = 0.2;
skelVis(:,:,2) = skelVis(:,:,2) + 0.9 * double(skeleton);
skelVis(:,:,3) = skelVis(:,:,3) + 0.9 * double(skeleton);
end

function addQualityBorder(ax, qualityLevel)
% Add colored border based on quality
colors = containers.Map({'input', 'excellent', 'good', 'warning', 'error'}, ...
    {[0.5, 0.5, 0.5], [0, 0.8, 0], [0, 0.6, 0.8], [1, 0.6, 0], [0.8, 0, 0]});

if isKey(colors, qualityLevel)
    color = colors(qualityLevel);
    set(ax, 'XColor', color, 'YColor', color, 'LineWidth', 2);
end
end

function linePixels = bresenham(x0, y0, x1, y1)
% Simple Bresenham line algorithm
dx = abs(x1 - x0);
dy = abs(y1 - y0);
sx = sign(x1 - x0);
sy = sign(y1 - y0);
err = dx - dy;

x = x0;
y = y0;
linePixels = [];

while true
    linePixels = [linePixels; x, y];
    
    if x == x1 && y == y1
        break;
    end
    
    e2 = 2 * err;
    if e2 > -dy
        err = err - dy;
        x = x + sx;
    end
    if e2 < dx
        err = err + dx;
        y = y + sy;
    end
end
end
