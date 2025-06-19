function visualizeProcessingSteps(originalImage, preprocessedImage, minutiae, imageIndex, outputDir)
% VISUALIZEPROCESSINGSTEPS Kompletny pipeline preprocessingu dla jednego obrazu
%
% Funkcja tworzy szczegółową wizualizację 8-etapowego procesu preprocessingu
% odcisku palca, pokazując transformacje od oryginalnego obrazu do finalnej
% detekcji minucji. Implementuje rzeczywiste kroki zgodne z preprocessing.m
% i PreprocessingPipeline.m.
%
% Parametry wejściowe:
%   originalImage - oryginalny obraz odcisku palca
%   preprocessedImage - finalny przetworzony obraz (szkielet)
%   minutiae - macierz wykrytych minucji [x, y, angle, type]
%   imageIndex - numer obrazu dla nazwy pliku
%   outputDir - katalog wyjściowy (opcjonalny, domyślnie 'output/figures')
%
% Dane wyjściowe:
%   - preprocessing_pipeline_sample_XXX.png - Wizualizacja 8 kroków
%
% Wizualizowane kroki (zgodne z preprocessing.m):
%   1. Original - obraz wejściowy
%   2. Orientation - analiza kierunków linii papilarnych
%   3. Frequency - mapa częstotliwości linii papilarnych
%   4. Gabor Filter - filtracja wzmacniająca linie papilarne
%   5. Segmented - wyodrębnienie obszaru odcisku
%   6. Binarized - konwersja do obrazu binarnego
%   7. Skeleton - szkieletyzacja linii papilarnych
%   8. Minutiae - detekcja i wizualizacja punktów charakterystycznych

if nargin < 5
    outputDir = 'output/figures';
end

% UPEWNIJ SIĘ że katalog istnieje
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

try
    % WIĘKSZA FIGURA dla szczegółowego pipeline (8 kroków)
    figure('Position', [50, 50, 2400, 600], 'Visible', 'off');
    
    %% WYKONAJ RZECZYSTE KROKI PREPROCESSINGU (z preprocessing.m)
    
    % PRZYGOTUJ obraz wejściowy
    workingImage = originalImage;
    if size(workingImage, 3) == 3
        workingImage = rgb2gray(workingImage);
    end
    workingImage = im2double(workingImage);
    
    %% KROK 1: ORYGINALNY OBRAZ
    subplot(2, 4, 1);
    imshow(originalImage);
    title('1. Original', 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Raw fingerprint');
    
    %% KROK 2: ORIENTACJA LINII PAPILARNYCH
    subplot(2, 4, 2);
    try
        % KROK 1 z preprocessing.m: Orientacja linii papilarnych
        orientation = computeRidgeOrientation(workingImage, 16);
        
        % WIZUALIZUJ orientację jako kierunki
        orientationVis = createOrientationVisualization(workingImage, orientation);
        imshow(orientationVis);
        title('2. Orientation', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge directions');
        
    catch
        % FALLBACK - gradient
        [Gx, Gy] = gradient(workingImage);
        gradMag = sqrt(Gx.^2 + Gy.^2);
        imshow(gradMag, []);
        title('2. Gradient', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Edge detection');
        orientation = zeros(size(workingImage));
    end
    
    %% KROK 3: CZĘSTOTLIWOŚĆ LINII PAPILARNYCH
    subplot(2, 4, 3);
    try
        % KROK 2 z preprocessing.m: Częstotliwość linii papilarnych
        frequency = computeRidgeFrequency(workingImage, orientation, 32);
        
        % WIZUALIZUJ częstotliwość
        freqVis = frequency / max(frequency(:)) * 255;
        imshow(freqVis, []);
        colormap(gca, 'jet');
        title('3. Frequency', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge frequency');
        
    catch
        % FALLBACK - pokaż orientację
        imshow(workingImage);
        title('3. Frequency', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Analysis failed');
        frequency = 0.1 * ones(size(workingImage));
    end
    
    %% KROK 4: FILTRACJA GABORA
    subplot(2, 4, 4);
    try
        % KROK 3 z preprocessing.m: Filtracja Gabora
        gaborFiltered = applyGaborFilter(workingImage, orientation, frequency);
        
        imshow(gaborFiltered);
        title('4. Gabor Filter', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge enhancement');
        
    catch
        % FALLBACK - enhancement przez kontrast
        gaborFiltered = imadjust(workingImage);
        imshow(gaborFiltered);
        title('4. Enhanced', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Contrast improved');
    end
    
    %% KROK 5: SEGMENTACJA
    subplot(2, 4, 5);
    try
        % KROK 4 z preprocessing.m: Segmentacja
        [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
        
        imshow(segmentedImage);
        title('5. Segmented', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('ROI extracted');
        
    catch
        % FALLBACK - thresholding
        segmentedImage = imbinarize(gaborFiltered, 'adaptive');
        imshow(segmentedImage);
        title('5. Thresholded', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Binary conversion');
        mask = ones(size(segmentedImage));
    end
    
    %% KROK 6: BINARYZACJA ZORIENTOWANA
    subplot(2, 4, 6);
    try
        % KROK 5 z preprocessing.m: Binaryzacja zorientowana na orientację
        if exist('orientation', 'var') && exist('mask', 'var')
            binaryImage = orientationAwareBinarization(segmentedImage, orientation, mask);
        else
            binaryImage = imbinarize(segmentedImage);
        end
        
        imshow(binaryImage);
        title('6. Binarized', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Orientation-aware');
        
    catch
        % FALLBACK - prosta binaryzacja
        binaryImage = imbinarize(segmentedImage);
        imshow(binaryImage);
        title('6. Binarized', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Binary image');
    end
    
    %% KROK 7: SZKIELETYZACJA (ridge thinning)
    subplot(2, 4, 7);
    try
        % KROK 6 z preprocessing.m: Szkieletyzacja
        skeletonImage = ridgeThinning(binaryImage);
        
        % FINALNE czyszczenie (jak w preprocessing.m)
        if exist('mask', 'var')
            finalSkeleton = skeletonImage & mask;
        else
            finalSkeleton = skeletonImage;
        end
        finalSkeleton = bwmorph(finalSkeleton, 'clean');
        
        imshow(finalSkeleton);
        title('7. Skeleton', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge thinning');
        
    catch
        % FALLBACK - użyj preprocessedImage
        finalSkeleton = preprocessedImage;
        imshow(finalSkeleton);
        title('7. Skeleton', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge skeleton');
    end
    
    %% KROK 8: DETEKCJA MINUCJI (zgodnie z PreprocessingPipeline)
    subplot(2, 4, 8);
    
    % UŻYJ finalnego szkieletu
    if exist('finalSkeleton', 'var')
        imshow(finalSkeleton);
    else
        imshow(preprocessedImage);
    end
    hold on;
    
    % ZGODNE Z PreprocessingPipeline.m - minutiae przekazane jako argument
    if ~isempty(minutiae) && size(minutiae, 2) >= 4
        % LICZNIKI dla legendy
        endingCount = 0;
        bifurcationCount = 0;
        
        % HANDLES dla legendy
        endingHandle = [];
        bifurcationHandle = [];
        
        % RYSUJ minucje zgodnie z formatem z detectMinutiae + filterMinutiae
        for i = 1:size(minutiae, 1)
            x = minutiae(i, 1);
            y = minutiae(i, 2);
            
            % SPRAWDŹ typ minucji
            if size(minutiae, 2) >= 4
                type = minutiae(i, 4);
            else
                type = 1; % Domyślnie ending
            end
            
            % RYSUJ minucje - MNIEJSZE markery, BEZ kierunków
            if type == 1 % Ending
                h = plot(x, y, 'ro', 'MarkerSize', 4, 'LineWidth', 1.5, ...
                    'MarkerFaceColor', 'red', 'MarkerEdgeColor', 'white');
                endingCount = endingCount + 1;
                
                % ZAPISZ HANDLE dla legendy (tylko pierwszy)
                if isempty(endingHandle)
                    endingHandle = h;
                end
                
            else % Bifurcation
                h = plot(x, y, 'bs', 'MarkerSize', 4, 'LineWidth', 1.5, ...
                    'MarkerFaceColor', 'blue', 'MarkerEdgeColor', 'white');
                bifurcationCount = bifurcationCount + 1;
                
                % ZAPISZ HANDLE dla legendy (tylko pierwszy)
                if isempty(bifurcationHandle)
                    bifurcationHandle = h;
                end
            end
        end
        
        % POPRAWIONA LEGENDA - używa rzeczywistych handles
        legendHandles = [];
        legendLabels = {};
        
        if ~isempty(endingHandle)
            legendHandles(end+1) = endingHandle;
            legendLabels{end+1} = 'Endings';
        end
        
        if ~isempty(bifurcationHandle)
            legendHandles(end+1) = bifurcationHandle;
            legendLabels{end+1} = 'Bifurcations';
        end
        
        % POKAŻ legendę tylko jeśli mamy oba typy
        if length(legendHandles) == 2
            legend(legendHandles, legendLabels, 'Location', 'best', 'FontSize', 8);
        end
        
        minutiaeInfo = sprintf('%d total (E:%d, B:%d)', size(minutiae, 1), endingCount, bifurcationCount);
    else
        minutiaeInfo = 'No minutiae';
    end
    
    hold off;
    title('8. Minutiae', 'FontSize', 10, 'FontWeight', 'bold');
    xlabel(minutiaeInfo);
    
    %% GŁÓWNY TYTUŁ
    sgtitle(sprintf('PREPROCESSING PIPELINE - Sample Image %d', imageIndex), ...
        'FontSize', 16, 'FontWeight', 'bold');
    
    %% ZAPISZ FIGURĘ
    filename = sprintf('preprocessing_pipeline_sample_%03d.png', imageIndex);
    filepath = fullfile(outputDir, filename);
    
    % USTAW jakość obrazu
    set(gcf, 'PaperPositionMode', 'auto');
    print(gcf, filepath, '-dpng', '-r300');
    
    % ZAMKNIJ figurę
    close(gcf);
    
    fprintf('  📊 Preprocessing pipeline visualization saved: %s\n', filename);
    
catch ME
    fprintf('  ⚠️  Preprocessing pipeline visualization failed for image %d: %s\n', imageIndex, ME.message);
    if exist('gcf', 'var')
        close(gcf);
    end
end
end

function orientationVis = createOrientationVisualization(image, orientation)
% CREATEORIENTATIONVISUALIZATION Tworzy wizualizację orientacji linii papilarnych
%
% Generuje kolorowy obraz pokazujący kierunki orientacji linii papilarnych
% poprzez nałożenie kolorowych linii na oryginalny obraz w regularnej siatce.
%
% Parametry wejściowe:
%   image - obraz wejściowy w odcieniach szarości [0,1]
%   orientation - macierz orientacji w radianach
%
% Dane wyjściowe:
%   orientationVis - obraz RGB z wizualizacją orientacji

% KONWERSJA do RGB
orientationVis = repmat(image, [1, 1, 3]);
[rows, cols] = size(image);

% PARAMETRY wizualizacji
step = 16;       % Odstęp między liniami orientacji
lineLength = 8;  % Długość linii

% RYSUJ linie orientacji w regularnej siatce
for i = step:step:rows-step
    for j = step:step:cols-step
        if i <= size(orientation, 1) && j <= size(orientation, 2)
            angle = orientation(i, j);
            
            % OBLICZ końce linii
            dx = lineLength * cos(angle);
            dy = lineLength * sin(angle);
            
            % WSPÓŁRZĘDNE końców linii
            x1 = max(1, min(cols, round(j - dx/2)));
            y1 = max(1, min(rows, round(i - dy/2)));
            x2 = max(1, min(cols, round(j + dx/2)));
            y2 = max(1, min(rows, round(i + dy/2)));
            
            % RYSUJ linię (czerwona)
            try
                orientationVis = insertShape(orientationVis, 'Line', [x1, y1, x2, y2], ...
                    'Color', 'red', 'LineWidth', 1);
            catch
                % FALLBACK - manualne rysowanie pikseli
                if x1 ~= x2 || y1 ~= y2
                    linePixels = bresenham(x1, y1, x2, y2);
                    for k = 1:size(linePixels, 1)
                        px = linePixels(k, 1);
                        py = linePixels(k, 2);
                        if px >= 1 && px <= cols && py >= 1 && py <= rows
                            orientationVis(py, px, 1) = 1; % Czerwony kanał
                            orientationVis(py, px, 2) = 0; % Zielony kanał
                            orientationVis(py, px, 3) = 0; % Niebieski kanał
                        end
                    end
                end
            end
        end
    end
end
end

function pixels = bresenham(x1, y1, x2, y2)
% BRESENHAM Algorytm Bresenhama dla rysowania linii
%
% Implementuje klasyczny algorytm rysowania linii poprzez zwrócenie
% wszystkich pikseli leżących na linii między dwoma punktami.
%
% Parametry wejściowe:
%   x1, y1 - współrzędne punktu początkowego
%   x2, y2 - współrzędne punktu końcowego
%
% Dane wyjściowe:
%   pixels - macierz [n×2] ze współrzędnymi pikseli linii

x1 = round(x1); y1 = round(y1);
x2 = round(x2); y2 = round(y2);

dx = abs(x2 - x1);
dy = abs(y2 - y1);

% KIERUNKI przyrostu
sx = sign(x2 - x1);
sy = sign(y2 - y1);

err = dx - dy;
pixels = [];

x = x1;
y = y1;

while true
    pixels(end+1, :) = [x, y];
    
    if x == x2 && y == y2
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
