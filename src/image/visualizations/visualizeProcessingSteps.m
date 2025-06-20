function visualizeProcessingSteps(originalImage, preprocessedImage, minutiae, imageIndex, outputDir)
% VISUALIZEPROCESSINGSTEPS Wizualizacja kompletnego pipeline'u preprocessingu v3
%
% Funkcja tworzy szczegółową wizualizację wszystkich 8 etapów procesu
% preprocessingu odcisku palca. Każdy krok pipeline'u jest dokładnie
% odtwarzany i wizualizowany z dodatkowymi informacjami o jakości przetwarzania.
% Wykorzystuje rzeczywiste funkcje preprocessingu dla pełnej zgodności.
%
% Parametry wejściowe:
%   originalImage - oryginalny obraz odcisku palca (uint8 lub double)
%   preprocessedImage - finalny przetworzony obraz - szkielet (logical)
%   minutiae - macierz wykrytych minucji [x, y, angle, type, quality]
%   imageIndex - numer obrazu dla nazwy pliku wyjściowego
%   outputDir - katalog wyjściowy (opcjonalny, domyślnie 'output/figures')

if nargin < 5
    outputDir = 'output/figures';
end

% Sprawdzenie i utworzenie katalogu wyjściowego
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

try
    % UTWORZENIE FIGURY z układem 2x4 (8 kroków preprocessingu)
    figure('Position', [50, 50, 2400, 700], 'Visible', 'off');
    
    % PRZYGOTOWANIE OBRAZU ROBOCZEGO do przetwarzania
    workingImage = originalImage;
    if size(workingImage, 3) == 3
        workingImage = rgb2gray(workingImage);  % Konwersja RGB → grayscale
    end
    workingImage = im2double(workingImage);     % Konwersja do formatu double
    
    %% KROK 1: ORYGINALNY OBRAZ
    subplot(2, 4, 1);
    imshow(originalImage);
    title('1. Original Image', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0, 0.8]);
    xlabel('Raw fingerprint', 'FontSize', 10);
    addQualityBorder(gca, 'input');
    
    %% KROK 2: ORIENTACJA LINII PAPILARNYCH (computeRidgeOrientation.m)
    subplot(2, 4, 2);
    try
        % Obliczenie orientacji metodą tensora struktury
        orientation = computeRidgeOrientation(workingImage, 16);
        % Utworzenie kolorowej wizualizacji orientacji z wektorami
        orientationVis = createEnhancedOrientationVisualization(workingImage, orientation);
        imshow(orientationVis);
        title('2. Ridge Orientation', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0.6, 0]);
        xlabel('Tensor structure analysis', 'FontSize', 10);
        addQualityBorder(gca, 'good');
    catch
        % Fallback: proste gradienty w przypadku błędu
        [Gx, Gy] = gradient(workingImage);
        gradMag = sqrt(Gx.^2 + Gy.^2);
        imshow(gradMag, []);
        title('2. Gradient (Fallback)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Edge detection', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
        orientation = zeros(size(workingImage));
    end
    
    %% KROK 3: CZĘSTOTLIWOŚĆ LINII PAPILARNYCH (computeRidgeFrequency.m)
    subplot(2, 4, 3);
    try
        % Obliczenie częstotliwości metodą projekcji FFT
        frequency = computeRidgeFrequency(workingImage, orientation, 32);
        freqVis = frequency / max(frequency(:));  % Normalizacja dla wizualizacji
        imagesc(freqVis);
        colormap(gca, 'jet');
        colorbar('FontSize', 8);
        title('3. Ridge Frequency', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'magenta');
        xlabel('FFT projection analysis', 'FontSize', 10);
        addQualityBorder(gca, 'good');
        axis image; axis off;
    catch
        % Fallback: wyświetlenie oryginalnego obrazu
        imshow(workingImage);
        title('3. Frequency (Failed)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'red');
        xlabel('Analysis failed', 'FontSize', 10);
        addQualityBorder(gca, 'error');
        frequency = 0.1 * ones(size(workingImage));  % Wartość domyślna
    end
    
    %% KROK 4: FILTRACJA GABORA (applyGaborFilter.m)
    subplot(2, 4, 4);
    try
        % Adaptacyjna filtracja Gabora z lokalnym dostrojeniem
        gaborFiltered = applyGaborFilter(workingImage, orientation, frequency);
        % Dodatkowe wzmocnienie kontrastu dla wizualizacji
        enhancedGabor = adapthisteq(gaborFiltered, 'ClipLimit', 0.02);
        imshow(enhancedGabor);
        title('4. Gabor Enhanced', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.6, 0, 0]);
        xlabel('Adaptive ridge enhancement', 'FontSize', 10);
        addQualityBorder(gca, 'excellent');
    catch
        % Fallback: proste dostrojenie kontrastu
        gaborFiltered = imadjust(workingImage);
        imshow(gaborFiltered);
        title('4. Enhanced (Simple)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Basic enhancement', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
    end
    
    %% KROK 5: SEGMENTACJA OBSZARU ODCISKU (segmentFingerprint.m)
    subplot(2, 4, 5);
    try
        % Segmentacja oparta na analizie lokalnej wariancji
        [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
        % Wizualizacja z podkreśleniem granic segmentacji
        segVis = createSegmentationOverlay(segmentedImage, mask);
        imshow(segVis);
        title('5. Segmented ROI', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'blue');
        xlabel('Variance-based ROI', 'FontSize', 10);
        addQualityBorder(gca, 'good');
    catch
        % Fallback: prosta binaryzacja adaptacyjna
        segmentedImage = imbinarize(gaborFiltered, 'adaptive');
        imshow(segmentedImage);
        title('5. Thresholded', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Binary fallback', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
        mask = ones(size(segmentedImage));
    end
    
    %% KROK 6: BINARYZACJA ADAPTACYJNA (orientationAwareBinarization.m)
    subplot(2, 4, 6);
    try
        % Binaryzacja blokowa z uwzględnieniem orientacji
        if exist('orientation', 'var') && exist('mask', 'var')
            binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
        else
            binaryImage = imbinarize(segmentedImage);
        end
        
        % Kolorowa wizualizacja obrazu binarnego
        binaryVis = createColoredBinary(binaryImage);
        imshow(binaryVis);
        title('6. Orientation-Aware Binary', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0.6, 0]);
        xlabel('Adaptive block thresholding', 'FontSize', 10);
        addQualityBorder(gca, 'good');
    catch
        % Fallback: prosta binaryzacja
        binaryImage = imbinarize(segmentedImage);
        imshow(binaryImage);
        title('6. Simple Binary', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [1, 0.6, 0]);
        xlabel('Standard binarization', 'FontSize', 10);
        addQualityBorder(gca, 'warning');
    end
    
    %% KROK 7: SZKIELETYZACJA LINII PAPILARNYCH (ridgeThinning.m)
    subplot(2, 4, 7);
    try
        % Zaawansowana szkieletyzacja z kontrolą jakości
        skeletonImage = ridgeThinning(binaryImage);
        
        % Zastosowanie maski obszaru odcisku
        if exist('mask', 'var')
            finalSkeleton = skeletonImage & mask;
        else
            finalSkeleton = skeletonImage;
        end
        % Końcowe czyszczenie szkieletu
        finalSkeleton = bwmorph(finalSkeleton, 'clean');
        
        % Kolorowa wizualizacja szkieletu
        skelVis = createEnhancedSkeleton(finalSkeleton);
        imshow(skelVis);
        title('7. Ridge Skeleton', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'magenta');
        
        % Analiza pokrycia szkieletu
        coverage = sum(finalSkeleton(:)) / numel(finalSkeleton) * 100;
        xlabel(sprintf('Coverage: %.2f%% | Gentle thinning', coverage), 'FontSize', 10);
        
        % Ocena jakości na podstawie pokrycia
        if coverage > 3
            addQualityBorder(gca, 'excellent');
        elseif coverage > 1
            addQualityBorder(gca, 'good');
        else
            addQualityBorder(gca, 'warning');
        end
    catch
        % Fallback: użycie obrazu z preprocessingu
        finalSkeleton = preprocessedImage;
        imshow(finalSkeleton);
        title('7. Skeleton (Fallback)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'red');
        xlabel('Processing fallback', 'FontSize', 10);
        addQualityBorder(gca, 'error');
    end
    
    %% KROK 8: WIZUALIZACJA MINUCJI - bez nakładek na obraz
    subplot(2, 4, 8);
    
    % Wyświetlenie szkieletu jako tła
    if exist('finalSkeleton', 'var')
        imshow(finalSkeleton);
    else
        imshow(preprocessedImage);
    end
    hold on;
    
    % Inicjalizacja liczników i tekstu legendy
    endingCount = 0;
    bifurcationCount = 0;
    legendText = '';
    
    if ~isempty(minutiae) && size(minutiae, 2) >= 4
        % FILTRACJA KRAWĘDZI - pomiń minucje blisko brzegów obrazu
        [rows, cols] = size(preprocessedImage);
        borderMargin = 10;  % Margines bezpieczeństwa w pikselach
        
        % RYSOWANIE MINUCJI z filtrowaniem krawędzi
        for i = 1:size(minutiae, 1)
            x = minutiae(i, 1);
            y = minutiae(i, 2);
            type = minutiae(i, 4);
            
            % Pomiń minucje zbyt blisko krawędzi
            if x <= borderMargin || y <= borderMargin || x >= cols-borderMargin || y >= rows-borderMargin
                continue;
            end
            
            % Wybór koloru i stylu według typu minucji
            if type == 1 % Ending (punkt końcowy linii)
                markerColor = 'red';
                markerShape = 'o';
                markerSize = 1;
                endingCount = endingCount + 1;
            else % Bifurcation (rozwidlenie linii)
                markerColor = 'blue';
                markerShape = 'o';
                markerSize = 1;
                bifurcationCount = bifurcationCount + 1;
            end
            
            % Rysowanie punktu minucji z wysoką widocznością
            scatter(x, y, markerSize^2*4, markerColor, markerShape, 'filled', ...
                'MarkerEdgeColor', 'white', 'LineWidth', 0.8, 'MarkerFaceAlpha', 0.9);
        end
        
        % Przygotowanie tekstu legendy (wyświetlany pod obrazem)
        if endingCount > 0 && bifurcationCount > 0
            legendText = sprintf('● Endings: %d   ● Bifurcations: %d', endingCount, bifurcationCount);
        elseif endingCount > 0
            legendText = sprintf('● Endings: %d', endingCount);
        elseif bifurcationCount > 0
            legendText = sprintf('● Bifurcations: %d', bifurcationCount);
        end
        
        % ANALIZA JAKOŚCI minucji
        if size(minutiae, 2) >= 5
            totalQuality = mean(minutiae(:, 5));
            minutiaeInfo = sprintf('Total: %d (E:%d, B:%d) | Q:%.2f', ...
                endingCount + bifurcationCount, endingCount, bifurcationCount, totalQuality);
            
            % Klasyfikacja jakości
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
        % Brak wykrytych minucji
        minutiaeInfo = 'No minutiae detected';
        qualityColor = 'red';
        addQualityBorder(gca, 'error');
        legendText = 'No minutiae found';
    end
    
    hold off;
    title('8. Enhanced Minutiae', 'FontSize', 12, 'FontWeight', 'bold', 'Color', qualityColor);
    
    % LEGENDA POD OBRAZEM (dwuliniowy tekst w xlabel)
    if ~isempty(legendText)
        xlabel(sprintf('%s\n%s', legendText, minutiaeInfo), 'FontSize', 10);
    else
        xlabel(minutiaeInfo, 'FontSize', 10);
    end
    
    %% GŁÓWNY TYTUŁ CAŁEJ WIZUALIZACJI
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    sgtitle(sprintf('ENHANCED PREPROCESSING PIPELINE v3 - Sample %d | %s', imageIndex, timestamp), ...
        'FontSize', 18, 'FontWeight', 'bold', 'Color', [0, 0, 0.8]);
    
    %% ZAPISYWANIE WIZUALIZACJI
    filename = sprintf('enhanced_pipeline_v3_sample_%03d.png', imageIndex);
    filepath = fullfile(outputDir, filename);
    
    set(gcf, 'PaperPositionMode', 'auto');
    print(gcf, filepath, '-dpng', '-r350');  % Wysoka rozdzielczość
    
    close(gcf);
    
    fprintf('  📊 Enhanced pipeline v3 visualization saved: %s\n', filename);
    
catch ME
    fprintf('  ⚠️  Enhanced pipeline visualization failed for image %d: %s\n', imageIndex, ME.message);
    if exist('gcf', 'var')
        close(gcf);
    end
end
end

%% FUNKCJE POMOCNICZE WIZUALIZACJI

function orientationVis = createEnhancedOrientationVisualization(image, orientation)
% CREATEENHANCEDORIENTATIONVISUALIZATION Kolorowa wizualizacja orientacji z wektorami
%
% Tworzy zaawansowaną wizualizację mapy orientacji linii papilarnych
% z użyciem przestrzeni barw HSV i nałożonych wektorów kierunkowych.

[rows, cols] = size(image);
orientationVis = zeros(rows, cols, 3);

% KONWERSJA ORIENTACJI DO PRZESTRZENI HSV
hue = (orientation + pi/2) / pi;        % Normalizacja do [0,1] dla odcienia
saturation = ones(size(orientation)) * 0.8;  % Wysokie nasycenie
value = image;                          % Jasność z oryginalnego obrazu

% Przekształcenie HSV → RGB
orientationVis(:,:,1) = hue;
orientationVis(:,:,2) = saturation;
orientationVis(:,:,3) = value;
orientationVis = hsv2rgb(orientationVis);

% NAKŁADANIE WEKTORÓW ORIENTACJI jako białe linie
step = 16;      % Odstęp między wektorami
lineLength = 8; % Długość linii wektora

for i = step:step:rows-step
    for j = step:step:cols-step
        if i <= size(orientation, 1) && j <= size(orientation, 2)
            angle = orientation(i, j);
            % Obliczenie końców wektora
            dx = lineLength * cos(angle);
            dy = lineLength * sin(angle);
            
            x1 = max(1, min(cols, round(j - dx/2)));
            y1 = max(1, min(rows, round(i - dy/2)));
            x2 = max(1, min(cols, round(j + dx/2)));
            y2 = max(1, min(rows, round(i + dy/2)));
            
            % Rasteryzacja linii algorytmem Bresenhama
            linePixels = bresenham(x1, y1, x2, y2);
            for k = 1:size(linePixels, 1)
                px = linePixels(k, 1);
                py = linePixels(k, 2);
                if px >= 1 && px <= cols && py >= 1 && py <= rows
                    orientationVis(py, px, :) = [1, 1, 1]; % Białe linie
                end
            end
        end
    end
end
end

%% POZOSTAŁE FUNKCJE POMOCNICZE WIZUALIZACJI

function segVis = createSegmentationOverlay(image, mask)
% CREATESEGMENTATIONOVERLAY Wizualizacja segmentacji z podkreśleniem granic
segVis = repmat(image, [1, 1, 3]);  % Konwersja do RGB
boundary = bwperim(mask);           % Granice maski segmentacji
% Dodanie czerwonej linii granicy
segVis(:,:,1) = segVis(:,:,1) + 0.3 * double(boundary);
segVis(:,:,2) = segVis(:,:,2) - 0.2 * double(boundary);
segVis(:,:,3) = segVis(:,:,3) - 0.2 * double(boundary);
segVis = max(0, min(1, segVis));    % Ograniczenie do [0,1]
end

function binaryVis = createColoredBinary(binaryImage)
% CREATECOLOREDBINARY Kolorowa wizualizacja obrazu binarnego
binaryVis = zeros([size(binaryImage), 3]);
% Ciemne tło
binaryVis(:,:,1) = 0.2; binaryVis(:,:,2) = 0.1; binaryVis(:,:,3) = 0.1;
% Białe linie papilarne
binaryVis(:,:,1) = binaryVis(:,:,1) + 0.8 * double(binaryImage);
binaryVis(:,:,2) = binaryVis(:,:,2) + 0.8 * double(binaryImage);
binaryVis(:,:,3) = binaryVis(:,:,3) + 0.8 * double(binaryImage);
end

function skelVis = createEnhancedSkeleton(skeleton)
% CREATEENHANCEDSKELETON Kolorowa wizualizacja szkieletu (zielono-niebieska)
skelVis = zeros([size(skeleton), 3]);
skelVis(:,:,3) = 0.2;  % Niebieskie tło
% Zielono-niebieskie linie szkieletu
skelVis(:,:,2) = skelVis(:,:,2) + 0.9 * double(skeleton);
skelVis(:,:,3) = skelVis(:,:,3) + 0.9 * double(skeleton);
end

function addQualityBorder(ax, qualityLevel)
% ADDQUALITYBORDER Dodanie kolorowego obramowania według jakości
colors = containers.Map({'input', 'excellent', 'good', 'warning', 'error'}, ...
    {[0.5, 0.5, 0.5], [0, 0.8, 0], [0, 0.6, 0.8], [1, 0.6, 0], [0.8, 0, 0]});

if isKey(colors, qualityLevel)
    color = colors(qualityLevel);
    set(ax, 'XColor', color, 'YColor', color, 'LineWidth', 2);
end
end

function linePixels = bresenham(x0, y0, x1, y1)
% BRESENHAM Algorytm rasteryzacji linii Bresenhama
% Generuje piksele składające się na linię między dwoma punktami
dx = abs(x1 - x0); dy = abs(y1 - y0);
sx = sign(x1 - x0); sy = sign(y1 - y0);
err = dx - dy;

x = x0; y = y0;
linePixels = [];

while true
    linePixels = [linePixels; x, y];
    
    if x == x1 && y == y1
        break;
    end
    
    e2 = 2 * err;
    if e2 > -dy
        err = err - dy; x = x + sx;
    end
    if e2 < dx
        err = err + dx; y = y + sy;
    end
end
end
