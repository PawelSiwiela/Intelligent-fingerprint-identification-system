% filepath: src/image/minutiae/utils/visualizeMinutiae.m
function visualizeMinutiae(binaryImage, minutiae, title_text, savePath)
% VISUALIZEMINUTIAE Wizualizuje wszystkie typy minucji
%
% Input:
%   binaryImage - obraz binarny
%   minutiae - struktura z minucjami
%   title_text - tytuł (opcjonalny)
%   savePath - ścieżka do zapisu PNG (opcjonalna)

if nargin < 3, title_text = 'Detected Minutiae'; end
if nargin < 4, savePath = []; end

figure('Position', [100, 100, 800, 600]);
imshow(binaryImage); hold on;

% Rysuj ZAKOŃCZENIA (czerwone kółka)
if ~isempty(minutiae.endpoints)
    plot(minutiae.endpoints(:,1), minutiae.endpoints(:,2), ...
        'ro', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', 'Endpoints');
end

% Rysuj BIFURKACJE (niebieskie kwadraty)
if ~isempty(minutiae.bifurcations)
    plot(minutiae.bifurcations(:,1), minutiae.bifurcations(:,2), ...
        'bs', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', 'Bifurcations');
end

% Rysuj OCZKA (zielone elipsy)
if ~isempty(minutiae.lakes)
    for i = 1:size(minutiae.lakes, 1)
        x = minutiae.lakes(i, 1);
        y = minutiae.lakes(i, 2);
        w = minutiae.lakes(i, 3);
        h = minutiae.lakes(i, 4);
        
        % Rysuj elipsę wokół oczka
        theta = 0:0.1:2*pi;
        ellipse_x = x + (w/2) * cos(theta);
        ellipse_y = y + (h/2) * sin(theta);
        plot(ellipse_x, ellipse_y, 'g-', 'LineWidth', 2);
    end
    % Dodaj do legendy (placeholder)
    plot(NaN, NaN, 'g-', 'LineWidth', 2, 'DisplayName', 'Lakes');
end

% Rysuj KROPKI (żółte gwiazdki)
if ~isempty(minutiae.dots)
    plot(minutiae.dots(:,1), minutiae.dots(:,2), ...
        'y*', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Dots');
end

title(sprintf('%s\nEndpoints: %d, Bifurcations: %d, Lakes: %d, Dots: %d (Total: %d)', ...
    title_text, size(minutiae.endpoints, 1), size(minutiae.bifurcations, 1), ...
    size(minutiae.lakes, 1), size(minutiae.dots, 1), minutiae.count));

legend('Location', 'best');
hold off;

% ZAPISZ PNG jeśli podano ścieżkę
if ~isempty(savePath)
    % Upewnij się że katalog istnieje
    saveDir = fileparts(savePath);
    if ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end
    
    % Zapisz w wysokiej rozdzielczości
    print(gcf, savePath, '-dpng', '-r300');
    fprintf('   💾 Zapisano wizualizację: %s\n', savePath);
end
end