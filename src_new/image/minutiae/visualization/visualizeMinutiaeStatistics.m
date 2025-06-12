function visualizeMinutiaeStatistics(allMinutiae, labels, outputDir, logFile)
% VISUALIZEMINUTIAESTATISTICS Wizualizuje statystyki minucji

if nargin < 4, logFile = []; end

try
    logInfo('Generowanie statystyk minucji...', logFile);
    
    % Zbierz statystyki
    stats = collectMinutiaeStats(allMinutiae, labels, logFile);
    
    % Wizualizacja 2x2
    figure('Visible', 'off', 'Position', [0, 0, 1400, 1000]);
    
    % 1. Średnia liczba minucji wg typu
    subplot(2, 2, 1);
    fingerNames = {'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'};
    bar_data = [stats.avgEndpoints, stats.avgBifurcations];
    bar(bar_data);
    title('ŚREDNIA LICZBA MINUCJI WG TYPU', 'FontWeight', 'bold');
    xlabel('Palec');
    ylabel('Średnia liczba');
    legend({'Endpoints', 'Bifurcations'}, 'Location', 'northeast');
    set(gca, 'XTickLabel', fingerNames);
    grid on;
    
    % 2. Rozkład stosunku E/B
    subplot(2, 2, 2);
    ratios = stats.endpointsPerImage ./ (stats.bifurcationsPerImage + 1);
    histogram(ratios, 15, 'FaceColor', [0.3, 0.7, 0.5]);
    title('ROZKŁAD STOSUNKU ENDPOINTS/BIFURCATIONS', 'FontWeight', 'bold');
    xlabel('Stosunek E/B');
    ylabel('Liczba obrazów');
    grid on;
    avgRatio = mean(ratios);
    xline(avgRatio, 'r--', sprintf('Średnia: %.2f', avgRatio), 'LineWidth', 2);
    
    % 3. Mapa cieplna E/B per palec
    subplot(2, 2, 3);
    heatmapData = [stats.avgEndpoints'; stats.avgBifurcations'];
    imagesc(heatmapData);
    colormap(hot);
    colorbar;
    title('MAPA CIEPLNA: E/B WG PALCA', 'FontWeight', 'bold');
    xlabel('Palec');
    ylabel('Typ minucji');
    set(gca, 'XTickLabel', fingerNames, 'YTickLabel', {'Endpoints', 'Bifurcations'});
    
    % Dodaj wartości na mapie
    for i = 1:5
        text(i, 1, sprintf('%.0f', stats.avgEndpoints(i)), 'HorizontalAlignment', 'center', 'Color', 'white', 'FontWeight', 'bold');
        text(i, 2, sprintf('%.0f', stats.avgBifurcations(i)), 'HorizontalAlignment', 'center', 'Color', 'white', 'FontWeight', 'bold');
    end
    
    % 4. Profil palców (radar chart)
    subplot(2, 2, 4);
    % Znormalizuj dane dla radar chart
    maxE = max(stats.avgEndpoints);
    maxB = max(stats.avgBifurcations);
    normE = stats.avgEndpoints / maxE * 100;
    normB = stats.avgBifurcations / maxB * 100;
    
    angles = linspace(0, 2*pi, 6); % 5 palców + zamknięcie
    normE_plot = [normE; normE(1)]; % Zamknij wykres
    normB_plot = [normB; normB(1)];
    
    polarplot(angles, normE_plot, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
    polarplot(angles, normB_plot, 'r-s', 'LineWidth', 2, 'MarkerSize', 8);
    hold off;
    
    title('PROFIL PALCÓW (% max)', 'FontWeight', 'bold');
    legend({'Endpoints', 'Bifurcations'}, 'Location', 'best');
    
    % Ustaw etykiety
    thetaticks([0, 72, 144, 216, 288]);
    thetaticklabels({'Kciuk', 'Wskazujący', 'Środkowy', 'Serdeczny', 'Mały'});
    
    sgtitle('ANALIZA MINUCJI - ZAAWANSOWANE STATYSTYKI', 'FontSize', 16, 'FontWeight', 'bold');
    
    % Zapisz wykres
    outputFile = fullfile(outputDir, 'minutiae_statistics.png');
    saveas(gcf, outputFile);
    close(gcf);
    
    fprintf('📊 Statystyki minucji zapisane w %s\n', outputFile);
    
    logInfo(sprintf('Statystyki minucji zapisane: %s', outputFile), logFile);
    
catch ME
    logError(sprintf('Błąd wizualizacji statystyk minucji: %s', ME.message), logFile);
end
end

function stats = collectMinutiaeStats(allMinutiae, labels, logFile)
% Zbierz statystyki z wszystkich minucji z ograniczonym wypisywaniem do konsoli

numImages = length(allMinutiae);
minutiaePerImage = zeros(numImages, 1);
endpointsPerImage = zeros(numImages, 1);
bifurcationsPerImage = zeros(numImages, 1);

logInfo('Zbieranie danych statystycznych minucji...', logFile);

for i = 1:numImages
    if ~isempty(allMinutiae{i}) && isfield(allMinutiae{i}, 'all')
        minutiaePerImage(i) = size(allMinutiae{i}.all, 1);
        endpointsPerImage(i) = size(allMinutiae{i}.endpoints, 1);
        bifurcationsPerImage(i) = size(allMinutiae{i}.bifurcations, 1);
        
        % Logowanie szczegółów do pliku zamiast konsoli
        if i <= 3
            logInfo(sprintf('Statystyki obrazu %d: E=%d, B=%d, Suma=%d', i, ...
                endpointsPerImage(i), bifurcationsPerImage(i), minutiaePerImage(i)), logFile);
        end
    end
end

% Totale zapisane do logu zamiast terminalu
totalE = sum(endpointsPerImage);
totalB = sum(bifurcationsPerImage);
logInfo(sprintf('SUMA statystyk: E=%d, B=%d, Suma=%d', totalE, totalB, totalE + totalB), logFile);

% Statystyki per palec
avgEndpoints = zeros(5, 1);
avgBifurcations = zeros(5, 1);

for finger = 1:5
    fingerMask = labels == finger;
    if sum(fingerMask) > 0
        avgEndpoints(finger) = mean(endpointsPerImage(fingerMask));
        avgBifurcations(finger) = mean(bifurcationsPerImage(fingerMask));
        
        logInfo(sprintf('Palec %d: średnio E=%.1f, B=%.1f', finger, ...
            avgEndpoints(finger), avgBifurcations(finger)), logFile);
    end
end

stats = struct();
stats.minutiaePerImage = minutiaePerImage;
stats.endpointsPerImage = endpointsPerImage;
stats.bifurcationsPerImage = bifurcationsPerImage;
stats.fingerLabels = labels;
stats.avgEndpoints = avgEndpoints;
stats.avgBifurcations = avgBifurcations;
end