function visualizeMinutiaeFeatures(features, labels, metadata, outputDir)
% VISUALIZEMINUTIAEFEATURES Profesjonalne wizualizacje wzorowane na oryginałach

if nargin < 4
    outputDir = 'output/figures';
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fprintf('\n📊 Creating professional minutiae analysis...\n');

try
    %% 1. ANALIZA MINUCJI - ZAAWANSOWANE STATYSTYKI (jak oryginał)
    fprintf('  Creating advanced minutiae analysis...\n');
    createAdvancedMinutiaeAnalysis(features, labels, metadata, outputDir);
    
    %% 2. PROFIL PALCÓW - RADAR CHARTS (jak oryginał)
    fprintf('  Creating finger profiles analysis...\n');
    createFingerProfilesAnalysis(features, labels, metadata, outputDir);
    
    %% 3. ANALIZA ROZKŁADÓW I KORELACJI
    fprintf('  Creating distribution analysis...\n');
    createDistributionAnalysis(features, labels, metadata, outputDir);
    
    fprintf('✅ Professional minutiae analysis completed!\n');
    
catch ME
    fprintf('❌ Error creating visualizations: %s\n', ME.message);
    fprintf('Stack trace: %s\n', getReport(ME, 'extended'));
end
end

function createAdvancedMinutiaeAnalysis(features, labels, metadata, outputDir)
% CREATEADVANCEDMINUTIAEANALYSIS - Wzorowane na "ANALIZA MINUCJI - ZAAWANSOWANE STATYSTYKI"

figure('Position', [100, 100, 1400, 1000]);

uniqueLabels = unique(labels);
fingerNames = {};
for i = 1:length(uniqueLabels)
    if uniqueLabels(i) <= length(metadata.fingerNames)
        fingerNames{i} = metadata.fingerNames{uniqueLabels(i)};
    else
        fingerNames{i} = sprintf('Palec %d', uniqueLabels(i));
    end
end

%% SUBPLOT 1: ŚREDNIA LICZBA MINUCJI WG TYPU (jak oryginał)
subplot(2, 3, 1);

% Zbierz dane dla każdego palca
endpointMeans = [];
bifurcationMeans = [];

for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    endpointMeans(i) = mean(features(fingerMask, 28)); % Endpoints
    bifurcationMeans(i) = mean(features(fingerMask, 29)); % Bifurcations
end

% Wykres słupkowy jak w oryginale
x = 1:length(uniqueLabels);
width = 0.35;
b1 = bar(x - width/2, endpointMeans, width, 'FaceColor', [0.2, 0.4, 0.8]);
hold on;
b2 = bar(x + width/2, bifurcationMeans, width, 'FaceColor', [0.8, 0.2, 0.2]);

set(gca, 'XTick', x, 'XTickLabel', fingerNames);
xtickangle(45);
ylabel('Średnia liczba minucji');
title('ŚREDNIA LICZBA MINUCJI WG TYPU', 'FontWeight', 'bold');
legend([b1, b2], {'Endpoints', 'Bifurcations'}, 'Location', 'best');
grid on;
ylim([0, max([endpointMeans, bifurcationMeans]) * 1.1]);

%% SUBPLOT 2: ROZKŁAD STOSUNKU ENDPOINTS/BIFURCATIONS (jak oryginał)
subplot(2, 3, 2);

% Oblicz stosunek E/B dla każdego obrazu
ratios = features(:, 28) ./ max(features(:, 29), 1); % Unikaj dzielenia przez 0

% Histogram z czerwoną linią średniej
h = histogram(ratios, 20, 'FaceColor', [0.7, 0.9, 0.7], 'EdgeColor', 'black', 'FaceAlpha', 0.8);
hold on;

meanRatio = mean(ratios);
l = xline(meanRatio, 'r-', 'LineWidth', 3);

xlabel('Stosunek E/B');
ylabel('Liczba obrazów');
title('ROZKŁAD STOSUNKU ENDPOINTS/BIFURCATIONS', 'FontWeight', 'bold');
legend(l, sprintf('Średnia (%.2f)', meanRatio), 'Location', 'best');
grid on;

%% SUBPLOT 3: MAPA CIEPLNA E/B WG PALCA (jak oryginał)
subplot(2, 3, 3);

% Przygotuj dane dla mapy cieplnej
heatmapData = [endpointMeans; bifurcationMeans];

% Wykres cieplny
imagesc(heatmapData);
colormap('hot');
cb = colorbar;
cb.Label.String = 'Średnia liczba minucji';

% Dodaj wartości na mapie
for i = 1:2
    for j = 1:length(uniqueLabels)
        text(j, i, sprintf('%.0f', heatmapData(i, j)), ...
            'HorizontalAlignment', 'center', 'Color', 'white', 'FontWeight', 'bold', 'FontSize', 10);
    end
end

set(gca, 'YTick', 1:2, 'YTickLabel', {'Endpoints', 'Bifurcations'}, ...
    'XTick', 1:length(fingerNames), 'XTickLabel', fingerNames);
xtickangle(45);
title('MAPA CIEPLNA: E/B WG PALCA', 'FontWeight', 'bold');

%% SUBPLOT 4: HISTOGRAM JAKOŚCI MINUCJI
subplot(2, 3, 4);

qualityData = features(:, 30); % Średnia jakość
h2 = histogram(qualityData, 20, 'FaceColor', [0.9, 0.7, 0.2], 'EdgeColor', 'black');
hold on;
l2 = xline(mean(qualityData), 'r-', 'LineWidth', 2);

xlabel('Średnia jakość minucji');
ylabel('Liczba obrazów');
title('ROZKŁAD JAKOŚCI MINUCJI', 'FontWeight', 'bold');
legend(l2, sprintf('Średnia (%.3f)', mean(qualityData)), 'Location', 'best');
grid on;

%% SUBPLOT 5: LICZBA MINUCJI vs STOSUNEK E/B (ZMIENIONY!)
subplot(2, 3, 5);

totalMinutiae = features(:, 27); % Całkowita liczba minucji
ratiosForScatter = features(:, 28) ./ max(features(:, 29), 1); % Stosunek E/B
colors = lines(length(uniqueLabels));

% Scatter plots z legendą
scatterHandles = [];
for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    h_scatter = scatter(totalMinutiae(fingerMask), ratiosForScatter(fingerMask), 50, colors(i,:), ...
        'filled', 'MarkerEdgeColor', 'black', 'DisplayName', fingerNames{i});
    hold on;
    scatterHandles(i) = h_scatter;
end

% Trend line
if length(totalMinutiae) > 1
    p = polyfit(totalMinutiae, ratiosForScatter, 1);
    xfit = linspace(min(totalMinutiae), max(totalMinutiae), 100);
    yfit = polyval(p, xfit);
    plot(xfit, yfit, 'r--', 'LineWidth', 2, 'DisplayName', 'Trend');
end

xlabel('Całkowita liczba minucji');
ylabel('Stosunek E/B'); % ZMIENIONA ETYKIETA
title('LICZBA MINUCJI vs STOSUNEK E/B', 'FontSize', 10, 'FontWeight', 'bold'); % ZMNIEJSZONE z 12 na 10
legend(scatterHandles, fingerNames, 'Location', 'best', 'FontSize', 8);
grid on;

%% SUBPLOT 6: STATYSTYKI PRZESTRZENNE
subplot(2, 3, 6);

% Gęstość minucji vs rozprzestrzenienie
if size(features, 2) >= 42
    density = features(:, 42);  % Gęstość
    spread = sqrt(features(:, 33).^2 + features(:, 34).^2); % Spreadx + SpreadY
    
    % Scatter plots z legendą
    scatterHandles2 = [];
    for i = 1:length(uniqueLabels)
        fingerMask = labels == uniqueLabels(i);
        h_scatter2 = scatter(density(fingerMask), spread(fingerMask), 50, colors(i,:), ...
            'filled', 'MarkerEdgeColor', 'black', 'DisplayName', fingerNames{i});
        hold on;
        scatterHandles2(i) = h_scatter2;
    end
    
    xlabel('Gęstość minucji');
    ylabel('Rozprzestrzenienie');
    title('GĘSTOŚĆ vs ROZPRZESTRZENIENIE', 'FontSize', 10, 'FontWeight', 'bold'); % ZMNIEJSZONE z 12 na 10
    legend(scatterHandles2, fingerNames, 'Location', 'best', 'FontSize', 8);
    grid on;
else
    text(0.5, 0.5, 'Brak danych przestrzennych', 'HorizontalAlignment', 'center');
    title('Analiza przestrzenna - brak danych');
end

% POPRAWIONY TYTUŁ GŁÓWNY
sgtitle('ANALIZA MINUCJI - ZAAWANSOWANE STATYSTYKI', 'FontSize', 16, 'FontWeight', 'bold');

% Zapisz
saveas(gcf, fullfile(outputDir, 'minutiae_advanced_analysis.png'));
close(gcf);
end

function createFingerProfilesAnalysis(features, labels, metadata, outputDir)
% CREATEFINGERPROFILESANALYSIS - POPRAWIONY radar chart bez thetalabels

figure('Position', [100, 100, 1200, 1200]);

uniqueLabels = unique(labels);
fingerNames = {};
for i = 1:length(uniqueLabels)
    if uniqueLabels(i) <= length(metadata.fingerNames)
        fingerNames{i} = metadata.fingerNames{uniqueLabels(i)};
    else
        fingerNames{i} = sprintf('Palec %d', uniqueLabels(i));
    end
end

% Wybierz 6 kluczowych cech dla profilu (mniej = czytelniej)
selectedFeatures = [27, 28, 29, 30, 31, 32]; % Dostępne cechy
selectedNames = {'Liczba\nminucji', 'Endpoints', 'Bifurcations', 'Jakość', 'Centroid X', 'Centroid Y'};

% Ogranicz do dostępnych cech
availableFeatures = selectedFeatures(selectedFeatures <= size(features, 2));
availableNames = selectedNames(selectedFeatures <= size(features, 2));

if length(availableFeatures) < 3
    text(0.5, 0.5, 'Niewystarczająco cech dla profilu', 'HorizontalAlignment', 'center');
    saveas(gcf, fullfile(outputDir, 'minutiae_finger_profiles.png'));
    close(gcf);
    return;
end

%% Oblicz profile dla każdego palca
profiles = zeros(length(uniqueLabels), length(availableFeatures));
for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    fingerFeatures = features(fingerMask, availableFeatures);
    profiles(i, :) = mean(fingerFeatures, 1);
end

% Normalizuj do procentów maksimum (jak w oryginale)
for j = 1:size(profiles, 2)
    maxVal = max(profiles(:, j));
    if maxVal > 0
        profiles(:, j) = (profiles(:, j) / maxVal) * 100;
    end
end

%% RADAR CHART - POPRAWIONA WERSJA
% Kąty dla każdej cechy
angles = linspace(0, 2*pi, length(availableFeatures) + 1);

% Kolory dla każdego palca
colors = lines(length(uniqueLabels));

% Rysuj profile
plotHandles = [];
for i = 1:length(uniqueLabels)
    % Zamknij profil (dodaj pierwszy punkt na końcu)
    profileData = [profiles(i, :), profiles(i, 1)];
    
    h = polarplot(angles, profileData, 'o-', 'Color', colors(i, :), ...
        'LineWidth', 3, 'MarkerSize', 8, 'MarkerFaceColor', colors(i, :), ...
        'DisplayName', fingerNames{i});
    hold on;
    plotHandles(i) = h;
end

% RĘCZNE USTAWIENIE ETYKIET (zamiast thetalabels)
ax = gca;
ax.ThetaTick = rad2deg(angles(1:end-1)); % Konwersja na stopnie
ax.ThetaTickLabel = availableNames;

% Ustaw promień
rlim([0, 110]);
rticks([0, 20, 40, 60, 80, 100]);

% Tytuł i legenda
title('PROFIL PALCÓW (% max)', 'FontSize', 16, 'FontWeight', 'bold');
legend(plotHandles, fingerNames, 'Location', 'best', 'FontSize', 10);

% Zapisz
saveas(gcf, fullfile(outputDir, 'minutiae_finger_profiles.png'));
close(gcf);
end

function createDistributionAnalysis(features, labels, metadata, outputDir)
% CREATEDISTRIBUTIONANALYSIS - Z LEPSZYMI OPISAMI CECH I POPRAWKAMI NAKŁADANIA

figure('Position', [100, 100, 1400, 1000]);

uniqueLabels = unique(labels);
fingerNames = {};
for i = 1:length(uniqueLabels)
    if uniqueLabels(i) <= length(metadata.fingerNames)
        fingerNames{i} = metadata.fingerNames{uniqueLabels(i)};
    else
        fingerNames{i} = sprintf('Palec %d', uniqueLabels(i));
    end
end

colors = lines(length(uniqueLabels));

%% SUBPLOT 1: Rozkład liczby minucji per palec
subplot(2, 3, 1);

totalMinutiae = features(:, 27);
histHandles = [];

for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    fingerData = totalMinutiae(fingerMask);
    
    h = histogram(fingerData, 10, 'FaceColor', colors(i, :), 'FaceAlpha', 0.6, ...
        'EdgeColor', 'black', 'DisplayName', fingerNames{i});
    hold on;
    histHandles(i) = h;
end

xlabel('Liczba minucji');
ylabel('Częstość');
title('ROZKŁAD LICZBY MINUCJI PER PALEC', 'FontSize', 10, 'FontWeight', 'bold');
legend(histHandles, fingerNames, 'Location', 'best', 'FontSize', 8);
grid on;

%% SUBPLOT 2: Box plot STOSUNKU E/B per palec - POPRAWIONE ETYKIETY I YLIM
subplot(2, 3, 2);

ratioData = [];
groupLabels = [];
groupNames = {};

% Zbierz dane z zabezpieczeniami
for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    fingerEndpoints = features(fingerMask, 28);
    fingerBifurcations = features(fingerMask, 29);
    
    % ZABEZPIECZENIE: upewnij się że nie dzielimy przez zero
    fingerRatios = fingerEndpoints ./ max(fingerBifurcations, 0.1);
    
    % Usuń outliers (stosunki > 20 to prawdopodobnie błędy)
    validRatios = fingerRatios(fingerRatios <= 20 & fingerRatios >= 0.01);
    
    if ~isempty(validRatios)
        ratioData = [ratioData; validRatios(:)];
        groupLabels = [groupLabels; repmat(i, length(validRatios), 1)];
        groupNames{i} = fingerNames{i}; % Tylko nazwa palca
    else
        ratioData = [ratioData; NaN];
        groupLabels = [groupLabels; i];
        groupNames{i} = fingerNames{i}; % Tylko nazwa palca
    end
end

try
    % Usuń grupy z samymi NaN
    validGroups = ~isnan(ratioData);
    if sum(validGroups) > 0
        boxplot(ratioData(validGroups), groupLabels(validGroups), 'Labels', groupNames);
        
        % POPRAWKA: Ustaw xtickangle(45) jak żądasz
        xtickangle(45);
        
        ylim([0 9]);
        
        ylabel('Stosunek E/B');
        title('STOSUNEK E/B PER PALEC', 'FontSize', 9, 'FontWeight', 'bold');
        grid on;
    else
        text(0.5, 0.5, 'Brak danych do wyświetlenia', 'HorizontalAlignment', 'center');
        title('STOSUNEK E/B - Brak danych', 'FontSize', 9, 'FontWeight', 'bold');
    end
catch
    % Fallback - wykres słupkowy
    fprintf('⚠️  Boxplot failed, using bar chart fallback\n');
    
    barData = [];
    barNames = {};
    
    for i = 1:length(uniqueLabels)
        fingerMask = labels == uniqueLabels(i);
        
        if sum(fingerMask) > 0
            fingerEndpoints = features(fingerMask, 28);
            fingerBifurcations = features(fingerMask, 29);
            
            meanEndpoints = mean(fingerEndpoints);
            meanBifurcations = mean(fingerBifurcations);
            
            if meanBifurcations > 0.1
                meanRatio = meanEndpoints / meanBifurcations;
            else
                meanRatio = meanEndpoints;
            end
            
            barData(end+1) = meanRatio;
            barNames{end+1} = fingerNames{i}; % Tylko nazwa palca
        end
    end
    
    if ~isempty(barData)
        barHandles = bar(barData, 'FaceColor', 'flat');
        
        for i = 1:length(barData)
            barHandles.CData(i,:) = colors(i,:);
        end
        
        set(gca, 'XTick', 1:length(barNames), 'XTickLabel', barNames);
        
        % POPRAWKA: Zastosuj xtickangle(45) również w fallback
        xtickangle(45);
        
        % POPRAWKA: Zwiększ ylim dla miejsca na etykiety
        maxBarValue = max(barData);
        ylim([0, maxBarValue * 1.2]); % Zwiększ górną granicę o 20%
        
        ylabel('Średni stosunek E/B');
        title('ŚREDNI STOSUNEK E/B', 'FontSize', 9, 'FontWeight', 'bold');
        grid on;
        
        for i = 1:length(barData)
            text(i, barData(i) + maxBarValue * 0.05, sprintf('%.2f', barData(i)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 8);
        end
    else
        text(0.5, 0.5, 'Brak danych E/B', 'HorizontalAlignment', 'center');
        title('STOSUNEK E/B - Brak danych', 'FontSize', 9, 'FontWeight', 'bold');
    end
end

%% SUBPLOT 3: KORELACJA WYBRANYCH KLUCZOWYCH CECH - POWRÓT DO POPRZEDNIEJ WERSJI
subplot(2, 3, 3);

% POWRÓT: Wybierz tylko kluczowe cechy dla lepszej czytelności
if size(features, 2) >= 32
    % Wybierz reprezentatywne cechy
    selectedFeatures = [27, 28, 29, 30, 31]; % Liczba, Endpoints, Bifurcations, Jakość, CentroidX
    selectedNames = {'Liczba', 'Endpoints', 'Bifurcations', 'Jakość', 'Stor.E/B'};
    
    % DODAJ OBLICZONY STOSUNEK E/B jako 6. cecha
    ratioFeature = features(:, 28) ./ max(features(:, 29), 0.1);
    selectedData = [features(:, selectedFeatures), ratioFeature];
    selectedNames{end+1} = 'Stor.E/B';
    
    % Usuń próbki z NaN/Inf
    validRows = all(isfinite(selectedData), 2) & all(~isnan(selectedData), 2);
    selectedData = selectedData(validRows, :);
    
    if size(selectedData, 1) > 3
        % Oblicz korelację dla wybranych cech
        corrMatrix = corr(selectedData);
        
        % Wyświetl macierz korelacji
        imagesc(corrMatrix);
        
        % Użyj lepszej mapy kolorów
        cmap = redblue(64);
        colormap(cmap);
        
        cb = colorbar;
        cb.Label.String = 'Korelacja';
        caxis([-1, 1]);
        
        % LEPSZE ETYKIETY - wszystkie widoczne
        set(gca, 'XTick', 1:length(selectedNames), 'YTick', 1:length(selectedNames));
        set(gca, 'XTickLabel', selectedNames, 'YTickLabel', selectedNames);
        xtickangle(45);
        
        % Dodaj wartości korelacji w komórkach
        for i = 1:length(selectedNames)
            for j = 1:length(selectedNames)
                if corrMatrix(i,j) > 0.6
                    textColor = 'white';
                elseif corrMatrix(i,j) < -0.6
                    textColor = 'white';
                else
                    textColor = 'black';
                end
                
                text(j, i, sprintf('%.2f', corrMatrix(i,j)), ...
                    'HorizontalAlignment', 'center', 'Color', textColor, ...
                    'FontSize', 8, 'FontWeight', 'bold');
            end
        end
        
        title('KORELACJA KLUCZOWYCH CECH', 'FontSize', 10, 'FontWeight', 'bold');
        
    else
        text(0.5, 0.5, 'Za mało danych do korelacji', 'HorizontalAlignment', 'center');
        title('KORELACJA - Za mało danych', 'FontSize', 10, 'FontWeight', 'bold');
    end
else
    text(0.5, 0.5, 'Brak wystarczających cech', 'HorizontalAlignment', 'center');
    title('KORELACJA - Brak cech', 'FontSize', 10, 'FontWeight', 'bold');
end

%% SUBPLOT 4: Endpoints vs Bifurcations per palec
subplot(2, 3, 4);

endpoints = features(:, 28);
bifurcations = features(:, 29);
scatterHandles = [];

for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    h = scatter(endpoints(fingerMask), bifurcations(fingerMask), 80, colors(i, :), ...
        'filled', 'MarkerEdgeColor', 'black', 'DisplayName', fingerNames{i});
    hold on;
    scatterHandles(i) = h;
end

% Linia referencja y=x
maxVal = max([max(endpoints), max(bifurcations)]);
refLine = plot([0, maxVal], [0, maxVal], 'k:', 'LineWidth', 2, 'DisplayName', 'y=x');

xlabel('Endpoints');
ylabel('Bifurcations');
title('ENDPOINTS vs BIFURCATIONS', 'FontSize', 10, 'FontWeight', 'bold');
legend([scatterHandles, refLine], [fingerNames, {'y=x'}], 'Location', 'best', 'FontSize', 8);
grid on;

%% SUBPLOT 5: Rozmieszczenie centroidów
subplot(2, 3, 5);

if size(features, 2) >= 32
    centroidX = features(:, 31);
    centroidY = features(:, 32);
    scatterHandles2 = [];
    
    for i = 1:length(uniqueLabels)
        fingerMask = labels == uniqueLabels(i);
        h = scatter(centroidX(fingerMask), centroidY(fingerMask), 80, colors(i, :), ...
            'filled', 'MarkerEdgeColor', 'black', 'DisplayName', fingerNames{i});
        hold on;
        scatterHandles2(i) = h;
    end
    
    xlabel('Centroid X');
    ylabel('Centroid Y');
    title('ROZMIESZCZENIE CENTROIDÓW', 'FontSize', 10, 'FontWeight', 'bold');
    legend(scatterHandles2, fingerNames, 'Location', 'best', 'FontSize', 8);
    grid on;
else
    text(0.5, 0.5, 'Brak danych centroidów', 'HorizontalAlignment', 'center');
    title('Centroids - brak danych', 'FontSize', 10, 'FontWeight', 'bold');
end

%% SUBPLOT 6: Statystyki sumaryczne - POPRAWIONE ETYKIETY
subplot(2, 3, 6);

statsData = [];
statsNames = {};

for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    
    if sum(fingerMask) > 0
        meanTotal = mean(features(fingerMask, 27));
        meanQuality = mean(features(fingerMask, 30));
        
        fingerEndpoints = features(fingerMask, 28);
        fingerBifurcations = features(fingerMask, 29);
        meanRatio = mean(fingerEndpoints ./ max(fingerBifurcations, 0.1));
        
        statsData = [statsData; meanTotal, meanQuality, meanRatio];
        statsNames{end+1} = fingerNames{i}; % POPRAWKA: Tylko nazwa palca
    end
end

if ~isempty(statsData)
    barHandles = bar(statsData);
    set(gca, 'XTick', 1:length(statsNames), 'XTickLabel', statsNames);
    xtickangle(45);
    ylabel('Wartość');
    title('STATYSTYKI SUMARYCZNE', 'FontSize', 10, 'FontWeight', 'bold');
    legend(barHandles, {'Śr. liczba minucji', 'Śr. jakość', 'Śr. stosunek E/B'}, 'Location', 'best', 'FontSize', 8);
    grid on;
else
    text(0.5, 0.5, 'Brak danych do statystyk', 'HorizontalAlignment', 'center');
    title('STATYSTYKI - Brak danych', 'FontSize', 10, 'FontWeight', 'bold');
end

sgtitle('ANALIZA ROZKŁADÓW I ZALEŻNOŚCI CECH MINUCJI', 'FontSize', 16, 'FontWeight', 'bold');

% Zapisz
saveas(gcf, fullfile(outputDir, 'minutiae_distribution_analysis.png'));
close(gcf);
end

function cmap = redblue(n)
% REDBLUE Tworzy mapę kolorów od niebieskiego przez biały do czerwonego
%
% Args:
%   n - liczba kolorów (domyślnie 256)

if nargin < 1
    n = 256;
end

if n == 1
    cmap = [1 1 1]; % Biały dla jednego koloru
    return;
end

% Połowa kolorów: niebieski -> biały
% Połowa kolorów: biały -> czerwony
half = floor(n/2);

% Niebieski do białego
blue_to_white = [linspace(0, 1, half)', linspace(0, 1, half)', ones(half, 1)];

% Biały do czerwonego
white_to_red = [ones(n-half, 1), linspace(1, 0, n-half)', linspace(1, 0, n-half)'];

% Połącz
cmap = [blue_to_white; white_to_red];
end