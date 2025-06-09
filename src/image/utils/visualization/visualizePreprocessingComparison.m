function visualizePreprocessingComparison(originalImage, methods, results, savePath)
% VISUALIZEPREPROCESSINGCOMPARISON Porównuje wyniki różnych metod preprocessingu
%
% Input:
%   originalImage - oryginalny obraz
%   methods - cell array nazw metod {'basic', 'hybrid', 'advanced'}
%   results - cell array wyników preprocessingu
%   savePath - ścieżka zapisu (opcjonalna)

numMethods = length(methods);
numSubplots = numMethods + 1; % +1 dla oryginału

% Oblicz układ subplot
if numSubplots <= 2
    rows = 1; cols = numSubplots;
elseif numSubplots <= 4
    rows = 2; cols = 2;
else
    rows = 2; cols = ceil(numSubplots/2);
end

% Utwórz figurę
figure('Position', [100, 100, 300*cols, 300*rows], 'Name', 'Preprocessing Methods Comparison');

% Oryginalny obraz
subplot(rows, cols, 1);
imshow(originalImage);
title('Original Image', 'FontSize', 14, 'FontWeight', 'bold');

% Wyniki każdej metody
for i = 1:numMethods
    subplot(rows, cols, i+1);
    imshow(results{i});
    
    % Oblicz podstawowe statystyki
    whitePixels = sum(results{i}(:));
    totalPixels = numel(results{i});
    coverage = (whitePixels / totalPixels) * 100;
    
    title(sprintf('%s\nCoverage: %.1f%%', upper(methods{i}), coverage), ...
        'FontSize', 14, 'FontWeight', 'bold');
end

% Dodaj główny tytuł
sgtitle('Fingerprint Preprocessing Methods Comparison', ...
    'FontSize', 16, 'FontWeight', 'bold');

% Zapisz jeśli podano ścieżkę
if nargin > 3 && ~isempty(savePath)
    % Utwórz folder jeśli nie istnieje
    [folder, ~, ~] = fileparts(savePath);
    if ~exist(folder, 'dir')
        mkdir(folder);
    end
    
    % Zapisz w wysokiej rozdzielczości
    print(gcf, savePath, '-dpng', '-r300');
    fprintf('💾 Visualization saved: %s\n', savePath);
end
end