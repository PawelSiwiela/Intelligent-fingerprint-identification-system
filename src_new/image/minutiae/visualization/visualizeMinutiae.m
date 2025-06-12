function visualizeMinutiae(originalImage, skeletonImage, minutiae, outputDir, imageName, logFile)
% VISUALIZEMINUTIAE Wizualizuje wykryte minucje na obrazie
%
% Argumenty:
%   originalImage - obraz oryginalny
%   skeletonImage - obraz szkieletowy
%   minutiae - struktura z minucjami
%   outputDir - katalog wyjściowy
%   imageName - nazwa obrazu
%   logFile - plik logów

if nargin < 5, imageName = 'sample'; end
if nargin < 6, logFile = []; end

try
    % Przygotuj obrazy
    if size(originalImage, 3) == 3
        grayImage = rgb2gray(originalImage);
    else
        grayImage = originalImage;
    end
    
    grayImage = im2double(grayImage);
    skeletonImage = im2double(skeletonImage);
    
    if isempty(minutiae) || isempty(minutiae.all)
        logWarning('Brak minucji do wizualizacji', logFile);
        return;
    end
    
    % Wizualizacja 2x2
    figure('Visible', 'off', 'Position', [0, 0, 1200, 900]);
    
    % 1. Obraz oryginalny
    subplot(2, 2, 1);
    imshow(grayImage);  % Bez zmian - obraz oryginalny
    title(sprintf('ORYGINALNY - %s', upper(imageName)), 'FontWeight', 'bold');
    
    % 2. Szkielet
    subplot(2, 2, 2);
    imshow(skeletonImage);
    title('SZKIELET', 'FontWeight', 'bold');
    
    % 3. Minucje na oryginalnym
    subplot(2, 2, 3);
    imshow(grayImage);
    hold on;
    plotMinutiae(minutiae);
    hold off;
    title(sprintf('MINUCJE NA ORYGINALNYM\n(%d punktów)', size(minutiae.all, 1)), 'FontWeight', 'bold');
    
    % 4. Minucje na szkielecie
    subplot(2, 2, 4);
    imshow(skeletonImage);
    hold on;
    plotMinutiae(minutiae);
    hold off;
    title(sprintf('MINUCJE NA SZKIELECIE\nE:%d, B:%d', ...
        size(minutiae.endpoints, 1), size(minutiae.bifurcations, 1)), 'FontWeight', 'bold');
    
    sgtitle(sprintf('ANALIZA MINUCJI - %s', upper(imageName)), 'FontSize', 16, 'FontWeight', 'bold');
    
    % Zapisz wykres
    outputFile = fullfile(outputDir, sprintf('minutiae_%s.png', imageName));
    saveas(gcf, outputFile);
    close(gcf);
    
    logInfo(sprintf('Wizualizacja minucji zapisana: %s', outputFile), logFile);
    
catch ME
    logError(sprintf('Błąd wizualizacji minucji: %s', ME.message), logFile);
end
end

function plotMinutiae(minutiae)
% Rysuje minucje na aktualnym wykresie

% Endpoints - czerwone kółka
if ~isempty(minutiae.endpoints)
    scatter(minutiae.endpoints(:, 1), minutiae.endpoints(:, 2), 50, 'r', 'o', 'filled', 'MarkerEdgeColor', 'k');
end

% Bifurcations - niebieskie kwadraty
if ~isempty(minutiae.bifurcations)
    scatter(minutiae.bifurcations(:, 1), minutiae.bifurcations(:, 2), 50, 'b', 's', 'filled', 'MarkerEdgeColor', 'k');
end

% Legenda tylko jeśli są dane
if ~isempty(minutiae.endpoints) || ~isempty(minutiae.bifurcations)
    legend({'Endpoints', 'Bifurcations'}, 'Location', 'best');
end
end