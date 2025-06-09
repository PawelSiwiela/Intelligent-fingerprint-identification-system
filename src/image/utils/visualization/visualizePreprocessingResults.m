function visualizePreprocessingResults(originalImage, results, methods, config, sampleInfo)
% VISUALIZEPREPROCESSINGRESULTS Wizualizuje wyniki preprocessingu z metrykami
%
% Input:
%   originalImage - oryginalny obraz
%   results - cell array wyników dla każdej metody
%   methods - nazwy metod
%   config - konfiguracja
%   sampleInfo - informacje o próbce

figure('Position', [100, 100, 1200, 800], 'Name', 'Preprocessing Results Analysis');

numMethods = length(methods);
rows = 2; cols = numMethods + 1;

% Oryginalny obraz
subplot(rows, cols, 1);
imshow(originalImage);
title('Original Image', 'FontSize', 12, 'FontWeight', 'bold');
if nargin > 4
    xlabel(sprintf('Sample: %s', sampleInfo), 'FontSize', 10);
end

% Wyniki każdej metody
for i = 1:numMethods
    subplot(rows, cols, i+1);
    imshow(results{i});
    
    % Oblicz metryki
    coverage = sum(results{i}(:)) / numel(results{i}) * 100;
    connectivity = analyzeConnectivity(results{i});
    
    title(sprintf('%s\nCoverage: %.1f%%', upper(methods{i}), coverage), ...
        'FontSize', 12, 'FontWeight', 'bold');
    xlabel(sprintf('Connectivity: %.2f', connectivity), 'FontSize', 10);
end

% Histogramy pokrycia
subplot(rows, cols, cols+1:2*cols);
coverages = zeros(1, numMethods);
for i = 1:numMethods
    coverages(i) = sum(results{i}(:)) / numel(results{i}) * 100;
end

bar(coverages);
set(gca, 'XTickLabel', upper(methods));
ylabel('Coverage (%)');
title('Coverage Comparison', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

sgtitle('Preprocessing Results Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end

function connectivity = analyzeConnectivity(binaryImage)
% Prosta analiza połączalności linii

skeleton = bwmorph(binaryImage, 'thin', inf);
endpoints = bwmorph(skeleton, 'endpoints');
branchpoints = bwmorph(skeleton, 'branchpoints');

totalPoints = sum(skeleton(:));
endCount = sum(endpoints(:));
branchCount = sum(branchpoints(:));

if totalPoints > 0
    connectivity = 1 - (endCount / totalPoints);
else
    connectivity = 0;
end
end