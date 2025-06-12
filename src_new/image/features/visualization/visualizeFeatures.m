function visualizeFeatures(allFeatures, labels, outputDir, logFile)
% VISUALIZEFEATURES Wizualizuje istotne cechy odcisków palców
% Skupia się TYLKO na cechach statystycznych

if nargin < 4, logFile = []; end

try
    logInfo('Generowanie wizualizacji cech...', logFile);
    
    [numSamples, numFeatures] = size(allFeatures);
    
    if numSamples == 0 || numFeatures == 0
        logWarning('Brak danych cech do wizualizacji', logFile);
        return;
    end
    
    fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};
    
    % Nazwy cech statystycznych
    statNames = {'Liczba minucji', 'Endpoints', 'Bifurcations', 'Centroid X', 'Centroid Y', ...
        'Śr. odległość', 'Odch. stand.', 'Szerokość', 'Wysokość', 'Pole'};
    
    % Wizualizacja 2x2 (bez odległościowych)
    figure('Visible', 'off', 'Position', [0, 0, 1600, 1200]);
    
    % 1. Analiza PCA
    subplot(2, 2, 1);
    plotPCA(allFeatures, labels, fingerNames);
    
    % 2. Macierz korelacji cech
    subplot(2, 2, 2);
    plotCorrelationMatrix(allFeatures, statNames);
    
    % 3. Cechy statystyczne wg typu palca
    subplot(2, 2, 3);
    plotStatistics(allFeatures, labels, fingerNames, statNames);
    
    % 4. Fisher Ratio dla rozdzielności cech
    subplot(2, 2, 4);
    plotFeatureSeparability(allFeatures, labels, statNames);
    
    % Tytuł ogólny
    sgtitle(sprintf('ANALIZA CECH STATYSTYCZNYCH ODCISKÓW PALCÓW (%d próbek, %d cech)', numSamples, numFeatures), 'FontSize', 16);
    
    % Zapisz wykres
    outputFile = fullfile(outputDir, 'features_analysis.png');
    saveas(gcf, outputFile);
    close(gcf);
    
    % Podsumowanie w konsoli
    fprintf('Analiza cech zakończona: %s\n', outputFile);
    
    logInfo(sprintf('Analiza cech zapisana: %s', outputFile), logFile);
    
catch ME
    logError(sprintf('Błąd wizualizacji cech: %s', ME.message), logFile);
end
end

function plotPCA(features, labels, fingerNames)
% Wyświetla rzut PCA danych

% Wykonaj PCA
[~, score, latent] = pca(features);
colors = lines(5);

hold on;

% Najpierw rysuj elipsy ufności
for finger = 1:5
    fingerMask = labels == finger;
    if sum(fingerMask) > 2  % Minimum 3 punkty
        fingerScores = score(fingerMask, 1:2);
        [ex, ey] = calculateConfidenceEllipse(fingerScores(:,1), fingerScores(:,2), 0.95);
        fill(ex, ey, colors(finger,:), 'FaceAlpha', 0.15, 'EdgeColor', colors(finger,:));
    end
end

% Teraz rysuj punkty
for finger = 1:5
    fingerMask = labels == finger;
    scatter(score(fingerMask, 1), score(fingerMask, 2), 60, colors(finger,:), 'filled', 'MarkerEdgeColor', 'k');
end

hold off;

% Dodaj opis osi
variance = latent / sum(latent) * 100;
xlabel(sprintf('PC1 (%.1f%% wariancji)', variance(1)), 'FontSize', 12);
ylabel(sprintf('PC2 (%.1f%% wariancji)', variance(2)), 'FontSize', 12);

% Legenda i tytuł
legend(fingerNames, 'Location', 'best');
title('ANALIZA PCA Z ELIPSAMI UFNOŚCI', 'FontWeight', 'bold');

% Pomocnicze linie przez początek układu
axisLimits = axis;
line([0 0], [axisLimits(3) axisLimits(4)], 'Color', [0.5 0.5 0.5], 'LineStyle', '--');
line([axisLimits(1) axisLimits(2)], [0 0], 'Color', [0.5 0.5 0.5], 'LineStyle', '--');

grid on;
end

function [ellipseX, ellipseY] = calculateConfidenceEllipse(x, y, confidence)
% Oblicza elipsę ufności dla danych 2D

% Sprawdź czy mamy wystarczającą ilość punktów
if length(x) <= 2
    ellipseX = [];
    ellipseY = [];
    return;
end

% Oblicz macierz kowariancji
covMatrix = cov(x, y);
[eigvec, eigval] = eig(covMatrix);
eigval = diag(eigval);

% Posortuj wartości własne
[~, idx] = sort(eigval, 'descend');
eigval = eigval(idx);
eigvec = eigvec(:, idx);

% Współczynnik dla poziomu ufności
scale = sqrt(chi2inv(confidence, 2));

% Generuj punkty elipsy
theta = linspace(0, 2*pi, 100);

% Półosie elipsy
a = scale * sqrt(eigval(1));
b = scale * sqrt(eigval(2));

% Punkty elipsy bez rotacji
ellipse = [a*cos(theta); b*sin(theta)];

% Rotacja
rotEllipse = eigvec * ellipse;

% Przesuń do średniej
meanX = mean(x);
meanY = mean(y);

ellipseX = rotEllipse(1,:) + meanX;
ellipseY = rotEllipse(2,:) + meanY;
end

function plotCorrelationMatrix(features, featureNames)
% Wyświetla macierz korelacji dla cech

% Oblicz macierz korelacji
corrMatrix = corr(features);

% Wyświetl macierz korelacji
imagesc(corrMatrix);
colormap(jet);
colorbar;
caxis([-1, 1]);

% Dodaj etykiety osi
set(gca, 'XTick', 1:length(featureNames), 'XTickLabel', featureNames);
set(gca, 'YTick', 1:length(featureNames), 'YTickLabel', featureNames);
xtickangle(45);

title('KORELACJA CECH STATYSTYCZNYCH', 'FontWeight', 'bold');
xlabel('Cecha');
ylabel('Cecha');

% Dodaj siatkę dla lepszej czytelności
grid on;
end

function plotStatistics(statFeatures, labels, fingerNames, statNames)
% Wyświetla cechy statystyczne jako mapę cieplną

% Oblicz średnie wartości dla każdego typu palca
statData = zeros(5, size(statFeatures, 2));

for finger = 1:5
    fingerMask = labels == finger;
    if sum(fingerMask) > 0
        statData(finger, :) = mean(statFeatures(fingerMask, :), 1);
    end
end

% Normalizacja do zakresu [0,1] dla lepszej wizualizacji
normalizedData = zeros(size(statData));
for i = 1:size(statData, 2)
    minVal = min(statData(:, i));
    maxVal = max(statData(:, i));
    if maxVal > minVal
        normalizedData(:, i) = (statData(:, i) - minVal) / (maxVal - minVal);
    end
end

% Tworzenie mapy cieplnej
h = heatmap(statNames, fingerNames, normalizedData);
h.Title = 'STATYSTYKI WEDŁUG TYPU PALCA';
h.XLabel = 'Cecha statystyczna';
h.YLabel = 'Typ palca';
h.Colormap = jet;
end

function plotFeatureSeparability(features, labels, featureNames)
% Wyświetla współczynniki Fisher Ratio dla każdej cechy

numFeatures = size(features, 2);

% Oblicz Fisher Ratio dla każdej cechy
fisherRatios = zeros(numFeatures, 1);
for i = 1:numFeatures
    fisherRatios(i) = calculateFisherRatio(features(:, i), labels);
end

% Usuń wartości inf/NaN
fisherRatios(isinf(fisherRatios) | isnan(fisherRatios)) = 0;

% Sortuj według wartości Fisher Ratio
[sortedRatios, sortedIdx] = sort(fisherRatios, 'descend');
sortedNames = featureNames(sortedIdx);

% Rysuj wykres słupkowy
b = barh(flipud(sortedRatios));
b.FaceColor = 'flat';

% Dodaj etykiety
yticks(1:numFeatures);
yticklabels(flipud(sortedNames));
xlabel('Fisher Ratio (wyższa = lepsza separowalność)');
title('SEPAROWALNOŚĆ CECH STATYSTYCZNYCH', 'FontWeight', 'bold');
grid on;

% Koloruj słupki według wartości
colormap(jet);
for i = 1:numFeatures
    b.CData(i,:) = [0.8, 0.4, 0.2]; % Jednolity kolor dla statystycznych
end

end

function fisherRatio = calculateFisherRatio(featureValues, labels)
% Oblicza Fisher Ratio dla pojedynczej cechy
% Fisher Ratio = (wariancja między klasami) / (wariancja wewnątrz klas)

classes = unique(labels);
numClasses = length(classes);
totalSamples = length(featureValues);

% Oblicz statystyki dla każdej klasy
classMeans = zeros(numClasses, 1);
classVars = zeros(numClasses, 1);
classCounts = zeros(numClasses, 1);

for i = 1:numClasses
    classIdx = (labels == classes(i));
    classValues = featureValues(classIdx);
    classCounts(i) = sum(classIdx);
    
    if classCounts(i) > 0
        classMeans(i) = mean(classValues);
        if classCounts(i) > 1
            classVars(i) = var(classValues, 0); % Nieobciążona wariancja
        end
    end
end

% Średnia ważona
globalMean = mean(featureValues);

% Wariancja między klasami
betweenClassVar = sum(classCounts .* (classMeans - globalMean).^2) / totalSamples;

% Wariancja wewnątrz klas
withinClassVar = sum((classCounts - 1) .* classVars) / (totalSamples - numClasses);

if withinClassVar > 1e-10
    fisherRatio = betweenClassVar / withinClassVar;
else
    fisherRatio = Inf; % Unikaj dzielenia przez zero
end
end