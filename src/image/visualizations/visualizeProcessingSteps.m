function visualizeProcessingSteps(originalImage, preprocessedImage, minutiae, imageIndex, outputDir)
% VISUALIZEPROCESSINGSTEPS Kompletny pipeline preprocessingu dla jednego obrazu
% ZGODNY Z preprocessing.m i PreprocessingPipeline.m

if nargin < 5
    outputDir = 'output/figures';
end

% Upewnij się że katalog istnieje
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

try
    % WIĘKSZA FIGURA dla szczegółowego pipeline (8 kroków)
    figure('Position', [50, 50, 2400, 600], 'Visible', 'off');
    
    %% WYKONAJ RZECZYISTE KROKI PREPROCESSINGU (z preprocessing.m)
    
    % Przygotuj obraz wejściowy
    workingImage = originalImage;
    if size(workingImage, 3) == 3
        workingImage = rgb2gray(workingImage);
    end
    workingImage = im2double(workingImage);
    
    %% KROK 1: Oryginalny obraz
    subplot(2, 4, 1);
    imshow(originalImage);
    title('1. Original', 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Raw fingerprint');
    
    %% KROK 2: Orientacja linii papilarnych
    subplot(2, 4, 2);
    try
        % KROK 1 z preprocessing.m: Orientacja linii papilarnych
        orientation = computeRidgeOrientation(workingImage, 16);
        
        % Wizualizuj orientację jako kierunki
        orientationVis = createOrientationVisualization(workingImage, orientation);
        imshow(orientationVis);
        title('2. Orientation', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge directions');
        
    catch
        % Fallback - gradient
        [Gx, Gy] = gradient(workingImage);
        gradMag = sqrt(Gx.^2 + Gy.^2);
        imshow(gradMag, []);
        title('2. Gradient', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Edge detection');
        orientation = zeros(size(workingImage));
    end
    
    %% KROK 3: Częstotliwość linii papilarnych
    subplot(2, 4, 3);
    try
        % KROK 2 z preprocessing.m: Częstotliwość linii papilarnych
        frequency = computeRidgeFrequency(workingImage, orientation, 32);
        
        % Wizualizuj częstotliwość
        freqVis = frequency / max(frequency(:)) * 255;
        imshow(freqVis, []);
        colormap(gca, 'jet');
        title('3. Frequency', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge frequency');
        
    catch
        % Fallback - pokaż orientację
        imshow(workingImage);
        title('3. Frequency', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Analysis failed');
        frequency = 0.1 * ones(size(workingImage));
    end
    
    %% KROK 4: Filtracja Gabora
    subplot(2, 4, 4);
    try
        % KROK 3 z preprocessing.m: Filtracja Gabora
        gaborFiltered = applyGaborFilter(workingImage, orientation, frequency);
        
        imshow(gaborFiltered);
        title('4. Gabor Filter', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge enhancement');
        
    catch
        % Fallback - enhancement przez kontrast
        gaborFiltered = imadjust(workingImage);
        imshow(gaborFiltered);
        title('4. Enhanced', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Contrast improved');
    end
    
    %% KROK 5: Segmentacja
    subplot(2, 4, 5);
    try
        % KROK 4 z preprocessing.m: Segmentacja
        [segmentedImage, mask] = segmentFingerprint(gaborFiltered);
        
        imshow(segmentedImage);
        title('5. Segmented', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('ROI extracted');
        
    catch
        % Fallback - thresholding
        segmentedImage = imbinarize(gaborFiltered, 'adaptive');
        imshow(segmentedImage);
        title('5. Thresholded', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Binary conversion');
        mask = ones(size(segmentedImage));
    end
    
    %% KROK 6: Binaryzacja zorientowana
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
        % Fallback - prosta binaryzacja
        binaryImage = imbinarize(segmentedImage);
        imshow(binaryImage);
        title('6. Binarized', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Binary image');
    end
    
    %% KROK 7: Szkieletyzacja (ridge thinning)
    subplot(2, 4, 7);
    try
        % KROK 6 z preprocessing.m: Szkieletyzacja
        skeletonImage = ridgeThinning(binaryImage);
        
        % Finalne czyszczenie (jak w preprocessing.m)
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
        % Fallback - użyj preprocessedImage
        finalSkeleton = preprocessedImage;
        imshow(finalSkeleton);
        title('7. Skeleton', 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Ridge skeleton');
    end
    
    %% KROK 8: DETEKCJA MINUCJI (zgodnie z PreprocessingPipeline)
    subplot(2, 4, 8);
    
    % Użyj finalnego szkieletu
    if exist('finalSkeleton', 'var')
        imshow(finalSkeleton);
    else
        imshow(preprocessedImage);
    end
    hold on;
    
    % ZGODNE Z PreprocessingPipeline.m - minutiae przekazane jako argument
    if ~isempty(minutiae) && size(minutiae, 2) >= 4
        % Liczniki dla legendy
        endingCount = 0;
        bifurcationCount = 0;
        
        % HANDLES dla legendy
        endingHandle = [];
        bifurcationHandle = [];
        
        % Rysuj minucje zgodnie z formatem z detectMinutiae + filterMinutiae
        for i = 1:size(minutiae, 1)
            x = minutiae(i, 1);
            y = minutiae(i, 2);
            
            % Sprawdź typ minucji
            if size(minutiae, 2) >= 4
                type = minutiae(i, 4);
            else
                type = 1; % Domyślnie ending
            end
            
            % Rysuj minucje - MNIEJSZE markery, BEZ kierunków
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
        
        % Pokaż legendę tylko jeśli mamy oba typy
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
    
    %% Zapisz figurę
    filename = sprintf('preprocessing_pipeline_sample_%03d.png', imageIndex);
    filepath = fullfile(outputDir, filename);
    
    % Ustaw jakość obrazu
    set(gcf, 'PaperPositionMode', 'auto');
    print(gcf, filepath, '-dpng', '-r300');
    
    % Zamknij figurę
    close(gcf);
    
    fprintf('  📊 Preprocessing pipeline visualization saved: %s\n', filename);
    
catch ME
    fprintf('  ⚠️  Preprocessing pipeline visualization failed for image %d: %s\n', imageIndex, ME.message);
    if exist('gcf', 'var')
        close(gcf);
    end
end
end
