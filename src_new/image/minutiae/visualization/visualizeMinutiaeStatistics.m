function visualizeMinutiaeStatistics(allMinutiae, labels, outputDir, logFile)
% VISUALIZEMINUTIAESTATISTICS Wizualizuje statystyki minucji

if nargin < 4, logFile = []; end

try
    logInfo('Generowanie statystyk minucji...', logFile);
    
    % Zbierz statystyki
    stats = collectMinutiaeStats(allMinutiae, labels);
    
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
    
    % 🆕 ULEPSZONE PODSUMOWANIE W KONSOLI
    fprintf('📊 STATYSTYKI MINUCJI:\n');
    fprintf('   📈 Łączne minucje: %d (E:%d, B:%d)\n', ...
        sum(stats.minutiaePerImage), sum(stats.endpointsPerImage), sum(stats.bifurcationsPerImage));
    
    for i = 1:5
        fingerData_E = stats.endpointsPerImage(stats.fingerLabels == i);
        fingerData_B = stats.bifurcationsPerImage(stats.fingerLabels == i);
        ratio = mean(fingerData_E) / mean(fingerData_B);
        
        fprintf('   👆 %s: E=%.1f, B=%.1f (stosunek %.2f)\n', ...
            fingerNames{i}, mean(fingerData_E), mean(fingerData_B), ratio);
    end
    
    % Analiza charakterystyk palców
    [~, maxE_finger] = max(stats.avgEndpoints);
    [~, maxB_finger] = max(stats.avgBifurcations);
    fprintf('   🏆 Najwięcej endpoints: %s\n', fingerNames{maxE_finger});
    fprintf('   🏆 Najwięcej bifurcations: %s\n', fingerNames{maxB_finger});
    
    logInfo(sprintf('Statystyki minucji zapisane: %s', outputFile), logFile);
    
catch ME
    logError(sprintf('Błąd wizualizacji statystyk minucji: %s', ME.message), logFile);
end
end

function stats = collectMinutiaeStats(allMinutiae, labels)
% Zbiera statystyki z wszystkich minucji - ORYGINALNA DZIAŁAJĄCA WERSJA

numImages = length(allMinutiae);
minutiaePerImage = zeros(numImages, 1);
endpointsPerImage = zeros(numImages, 1);
bifurcationsPerImage = zeros(numImages, 1);

fprintf('🔍 DEBUG collectMinutiaeStats:\n');

for i = 1:numImages
    if ~isempty(allMinutiae{i}) && isfield(allMinutiae{i}, 'all')
        minutiaePerImage(i) = size(allMinutiae{i}.all, 1);
        endpointsPerImage(i) = size(allMinutiae{i}.endpoints, 1);
        bifurcationsPerImage(i) = size(allMinutiae{i}.bifurcations, 1);
        
        % DEBUG dla pierwszych 3
        if i <= 3
            fprintf('   Obraz %d: E=%d, B=%d, Total=%d\n', i, ...
                endpointsPerImage(i), bifurcationsPerImage(i), minutiaePerImage(i));
        end
    end
end

% Sprawdź totale
totalE = sum(endpointsPerImage);
totalB = sum(bifurcationsPerImage);
fprintf('📊 SUMA: E=%d, B=%d, Total=%d\n', totalE, totalB, totalE + totalB);

% Statystyki per palec
avgEndpoints = zeros(5, 1);
avgBifurcations = zeros(5, 1);

for finger = 1:5
    fingerMask = labels == finger;
    if sum(fingerMask) > 0  % Sprawdź czy są obrazy dla tego palca
        avgEndpoints(finger) = mean(endpointsPerImage(fingerMask));
        avgBifurcations(finger) = mean(bifurcationsPerImage(fingerMask));
        
        fprintf('   Palec %d: średnio E=%.1f, B=%.1f\n', finger, ...
            avgEndpoints(finger), avgBifurcations(finger));
    end
end

% 🎯 Dane dla wykresu
fprintf('🎯 Dane dla wykresu:\n');
fprintf('   Endpoints: %s\n', mat2str(avgEndpoints'));
fprintf('   Bifurcations: %s\n', mat2str(avgBifurcations'));

stats = struct();
stats.minutiaePerImage = minutiaePerImage;
stats.endpointsPerImage = endpointsPerImage;
stats.bifurcationsPerImage = bifurcationsPerImage;
stats.fingerLabels = labels;
stats.avgEndpoints = avgEndpoints;
stats.avgBifurcations = avgBifurcations;
end