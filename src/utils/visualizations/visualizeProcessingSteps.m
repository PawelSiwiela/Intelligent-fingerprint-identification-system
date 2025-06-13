function visualizeProcessingSteps(originalImage, preprocessedImage, minutiae, imageIndex, outputDir)
% VISUALIZEPROCESSINGSTEPS Tworzy wizualizację trzech etapów przetwarzania
%
% Argumenty:
%   originalImage - oryginalny obraz odcisku palca
%   preprocessedImage - obraz po preprocessingu (szkielet)
%   minutiae - wykryte minucje [x, y, angle, type, quality]
%   imageIndex - numer obrazu (dla nazwy pliku)
%   outputDir - katalog wyjściowy (opcjonalny)

if nargin < 5
    outputDir = 'output/figures';
end

% Upewnij się że katalog istnieje
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

try
    % Stwórz subplot z trzema obrazami
    figure('Position', [100, 100, 1200, 400], 'Visible', 'off');
    
    %% SUBPLOT 1: Oryginalny obraz
    subplot(1, 3, 1);
    imshow(originalImage);
    title('Original Image', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('X [pixels]');
    ylabel('Y [pixels]');
    
    %% SUBPLOT 2: Po preprocessingu (szkielet)
    subplot(1, 3, 2);
    imshow(preprocessedImage);
    title('After Preprocessing (Skeleton)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('X [pixels]');
    ylabel('Y [pixels]');
    
    %% SUBPLOT 3: Z wykrytymi minucjami
    subplot(1, 3, 3);
    imshow(preprocessedImage);
    hold on;
    
    if ~isempty(minutiae)
        % Liczniki dla legendy
        endingCount = 0;
        bifurcationCount = 0;
        
        % Rysuj minucje
        for i = 1:size(minutiae, 1)
            x = minutiae(i, 1);
            y = minutiae(i, 2);
            angle = minutiae(i, 3);
            type = minutiae(i, 4);
            quality = minutiae(i, 5);
            
            % Kolor i kształt według typu minucji
            if type == 1 % Ending (punkt końcowy)
                markerColor = 'red';
                markerShape = 'o';
                markerSize = 4;
                endingCount = endingCount + 1;
            else % Bifurcation (bifurkacja)
                markerColor = 'blue';
                markerShape = 's';
                markerSize = 4;
                bifurcationCount = bifurcationCount + 1;
            end
            
            % Rysuj TYLKO punkt minucji (bez strzałek)
            plot(x, y, markerShape, 'Color', markerColor, 'MarkerSize', markerSize, ...
                'LineWidth', 1.5, 'MarkerFaceColor', markerColor, 'MarkerEdgeColor', 'white');
        end
        
        % Legenda z rzeczywistymi liczbami
        if endingCount > 0 && bifurcationCount > 0
            legend({sprintf('Endings (%d)', endingCount), sprintf('Bifurcations (%d)', bifurcationCount)}, ...
                'Location', 'best', 'FontSize', 10);
        elseif endingCount > 0
            legend({sprintf('Endings (%d)', endingCount)}, 'Location', 'best', 'FontSize', 10);
        elseif bifurcationCount > 0
            legend({sprintf('Bifurcations (%d)', bifurcationCount)}, 'Location', 'best', 'FontSize', 10);
        end
    end
    
    hold off;
    title(sprintf('Detected Minutiae (%d found)', size(minutiae, 1)), ...
        'FontSize', 12, 'FontWeight', 'bold');
    xlabel('X [pixels]');
    ylabel('Y [pixels]');
    
    %% Zapisz figurę
    filename = sprintf('processing_steps_image_%03d.png', imageIndex);
    filepath = fullfile(outputDir, filename);
    
    % Ustaw jakość obrazu
    set(gcf, 'PaperPositionMode', 'auto');
    print(gcf, filepath, '-dpng', '-r300');
    
    % Zamknij figurę
    close(gcf);
    
    fprintf('  📊 Visualization saved: %s\n', filename);
    
catch ME
    fprintf('  ⚠️  Visualization failed for image %d: %s\n', imageIndex, ME.message);
    if exist('gcf', 'var')
        close(gcf);
    end
end
end