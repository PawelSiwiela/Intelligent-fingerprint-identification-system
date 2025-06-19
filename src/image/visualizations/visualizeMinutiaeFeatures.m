function visualizeMinutiaeFeatures(features, labels, metadata, outputDir)
% VISUALIZEMINUTIAEFEATURES Profesjonalne wizualizacje cech minucji odcisków palców
%
% Funkcja generuje kompleksową analizę wizualną cech minucji obejmującą:
% 1. Zaawansowane statystyki minucji (rozkłady, typy, jakość)
% 2. Profile palców w formie radar charts
% 3. Analizę rozkładów i korelacji między cechami
%
% Parametry wejściowe:
%   features - macierz cech [n_samples × n_features] z ekstraktowanymi cechami minucji
%   labels - wektor etykiet klas [1×n] odpowiadający próbkom
%   metadata - struktura z nazwami palców i informacjami o klasach
%   outputDir - katalog wyjściowy dla wizualizacji (opcjonalny, domyślnie 'output/figures')
%
% Dane wyjściowe:
%   - minutiae_advanced_analysis.png - Zaawansowane statystyki minucji
%   - minutiae_finger_profiles.png - Profile palców (radar charts)
%   - minutiae_distribution_analysis.png - Analiza rozkładów i korelacji
%
% Wizualizowane cechy:
%   - Całkowita liczba minucji (cecha 27)
%   - Liczba endpoints (cecha 28) i bifurcations (cecha 29)
%   - Średnia jakość minucji (cecha 30)
%   - Pozycje centroidów (cechy 31-32)
%   - Rozkłady przestrzenne i korelacje międzycechowe

if nargin < 4
    outputDir = 'output/figures';
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fprintf('\n📊 Creating professional minutiae analysis...\n');

try
    %% KROK 1: ANALIZA MINUCJI - ZAAWANSOWANE STATYSTYKI (wzorowane na oryginałach)
    fprintf('  Creating advanced minutiae analysis...\n');
    createAdvancedMinutiaeAnalysis(features, labels, metadata, outputDir);
    
    %% KROK 2: PROFIL PALCÓW - RADAR CHARTS (wzorowane na oryginałach)
    fprintf('  Creating finger profiles analysis...\n');
    createFingerProfilesAnalysis(features, labels, metadata, outputDir);
    
    %% KROK 3: ANALIZA ROZKŁADÓW I KORELACJI
    fprintf('  Creating distribution analysis...\n');
    createDistributionAnalysis(features, labels, metadata, outputDir);
    
    fprintf('✅ Professional minutiae analysis completed!\n');
    
catch ME
    fprintf('❌ Error creating visualizations: %s\n', ME.message);
    fprintf('Stack trace: %s\n', getReport(ME, 'extended'));
end
end

function createAdvancedMinutiaeAnalysis(features, labels, metadata, outputDir)
% CREATEADVANCEDMINUTIAEANALYSIS Zaawansowane statystyki minucji
%
% Generuje kompleksową analizę składającą się z 6 wykresów:
% 1. Średnia liczba minucji według typu (endpoints vs bifurcations)
% 2. Rozkład stosunku endpoints/bifurcations w całym zbiorze
% 3. Mapa cieplna E/B według palca
% 4. Histogram jakości minucji
% 5. Liczba minucji vs stosunek E/B (scatter plot)
% 6. Statystyki przestrzenne (gęstość vs rozprzestrzenienie)

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

%% SUBPLOT 1: ŚREDNIA LICZBA MINUCJI WG TYPU (wzorowane na oryginałach)
subplot(2, 3, 1);

% AGREGACJA danych dla każdego palca
endpointMeans = [];
bifurcationMeans = [];

for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    endpointMeans(i) = mean(features(fingerMask, 28)); % Endpoints
    bifurcationMeans(i) = mean(features(fingerMask, 29)); % Bifurcations
end

% WYKRES słupkowy porównawczy (styl oryginalny)
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

%% SUBPLOT 2: ROZKŁAD STOSUNKU ENDPOINTS/BIFURCATIONS (histogram globalny)
subplot(2, 3, 2);

% OBLICZ stosunek E/B dla każdego obrazu z zabezpieczeniem dzielenia przez zero
ratios = features(:, 28) ./ max(features(:, 29), 1); % Unikaj dzielenia przez 0

% HISTOGRAM z czerwoną linią średniej
h = histogram(ratios, 20, 'FaceColor', [0.7, 0.9, 0.7], 'EdgeColor', 'black', 'FaceAlpha', 0.8);
hold on;

meanRatio = mean(ratios);
l = xline(meanRatio, 'r-', 'LineWidth', 3);

xlabel('Stosunek E/B');
ylabel('Liczba obrazów');
title('ROZKŁAD STOSUNKU ENDPOINTS/BIFURCATIONS', 'FontWeight', 'bold');
legend(l, sprintf('Średnia (%.2f)', meanRatio), 'Location', 'best');
grid on;

%% SUBPLOT 3: MAPA CIEPLNA E/B WG PALCA (wzorowane na oryginałach)
subplot(2, 3, 3);

% PRZYGOTOWANIE danych dla mapy cieplnej
heatmapData = [endpointMeans; bifurcationMeans];

% WYKRES cieplny z hot colormap
imagesc(heatmapData);
colormap('hot');
cb = colorbar;
cb.Label.String = 'Średnia liczba minucji';

% DODANIE wartości tekstowych na mapie
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

qualityData = features(:, 30); % Średnia jakość minucji
h2 = histogram(qualityData, 20, 'FaceColor', [0.9, 0.7, 0.2], 'EdgeColor', 'black');
hold on;
l2 = xline(mean(qualityData), 'r-', 'LineWidth', 2);

xlabel('Średnia jakość minucji');
ylabel('Liczba obrazów');
title('ROZKŁAD JAKOŚCI MINUCJI', 'FontWeight', 'bold');
legend(l2, sprintf('Średnia (%.3f)', mean(qualityData)), 'Location', 'best');
grid on;

%% SUBPLOT 5: LICZBA MINUCJI vs STOSUNEK E/B (scatter plot z trendami)
subplot(2, 3, 5);

totalMinutiae = features(:, 27); % Całkowita liczba minucji
ratiosForScatter = features(:, 28) ./ max(features(:, 29), 1); % Stosunek E/B
colors = lines(length(uniqueLabels));

% SCATTER PLOTS z legendą dla każdego palca
scatterHandles = [];
for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    h_scatter = scatter(totalMinutiae(fingerMask), ratiosForScatter(fingerMask), 50, colors(i,:), ...
        'filled', 'MarkerEdgeColor', 'black', 'DisplayName', fingerNames{i});
    hold on;
    scatterHandles(i) = h_scatter;
end

% LINIA trendu globalnego
if length(totalMinutiae) > 1
    p = polyfit(totalMinutiae, ratiosForScatter, 1);
    xfit = linspace(min(totalMinutiae), max(totalMinutiae), 100);
    yfit = polyval(p, xfit);
    plot(xfit, yfit, 'r--', 'LineWidth', 2, 'DisplayName', 'Trend');
end

xlabel('Całkowita liczba minucji');
ylabel('Stosunek E/B');
title('LICZBA MINUCJI vs STOSUNEK E/B', 'FontSize', 10, 'FontWeight', 'bold');
legend(scatterHandles, fingerNames, 'Location', 'best', 'FontSize', 8);
grid on;

%% SUBPLOT 6: STATYSTYKI PRZESTRZENNE
subplot(2, 3, 6);

% GĘSTOŚĆ minucji vs rozprzestrzenienie przestrzenne
if size(features, 2) >= 42
    density = features(:, 42);  % Gęstość minucji
    spread = sqrt(features(:, 33).^2 + features(:, 34).^2); % Spreadx + SpreadY
    
    % SCATTER PLOTS z legendą dla każdego palca
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
    title('GĘSTOŚĆ vs ROZPRZESTRZENIENIE', 'FontSize', 10, 'FontWeight', 'bold');
    legend(scatterHandles2, fingerNames, 'Location', 'best', 'FontSize', 8);
    grid on;
else
    % FALLBACK gdy brak danych przestrzennych
    text(0.5, 0.5, 'Brak danych przestrzennych', 'HorizontalAlignment', 'center');
    title('Analiza przestrzenna - brak danych');
end

% TYTUŁ GŁÓWNY FIGURY
sgtitle('ANALIZA MINUCJI - ZAAWANSOWANE STATYSTYKI', 'FontSize', 16, 'FontWeight', 'bold');

% ZAPIS FIGURY
saveas(gcf, fullfile(outputDir, 'minutiae_advanced_analysis.png'));
close(gcf);
end

function createFingerProfilesAnalysis(features, labels, metadata, outputDir)
% CREATEFINGERPROFILESANALYSIS Profile palców w formie radar charts
%
% Tworzy radar chart pokazujący charakterystyczne profile każdego palca
% na podstawie 6 kluczowych cech minucji. Każdy palec ma unikalny profil
% znormalizowany do skali procentowej dla łatwego porównania.

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

% WYBÓR 6 kluczowych cech dla profilu (mniej = czytelniej)
selectedFeatures = [27, 28, 29, 30, 31, 32]; % Dostępne cechy
selectedNames = {'Liczba\nminucji', 'Endpoints', 'Bifurcations', 'Jakość', 'Centroid X', 'Centroid Y'};

% OGRANICZENIE do dostępnych cech w zbiorze danych
availableFeatures = selectedFeatures(selectedFeatures <= size(features, 2));
availableNames = selectedNames(selectedFeatures <= size(features, 2));

if length(availableFeatures) < 3
    text(0.5, 0.5, 'Niewystarczająco cech dla profilu', 'HorizontalAlignment', 'center');
    saveas(gcf, fullfile(outputDir, 'minutiae_finger_profiles.png'));
    close(gcf);
    return;
end

%% OBLICZENIE profili dla każdego palca (średnie wartości)
profiles = zeros(length(uniqueLabels), length(availableFeatures));
for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    fingerFeatures = features(fingerMask, availableFeatures);
    profiles(i, :) = mean(fingerFeatures, 1);
end

% NORMALIZACJA do procentów maksimum (wzorowane na oryginałach)
for j = 1:size(profiles, 2)
    maxVal = max(profiles(:, j));
    if maxVal > 0
        profiles(:, j) = (profiles(:, j) / maxVal) * 100;
    end
end

%% RADAR CHART - poprawiona implementacja
% KĄTY dla każdej cechy (równomiernie rozłożone)
angles = linspace(0, 2*pi, length(availableFeatures) + 1);

% KOLORY dla każdego palca
colors = lines(length(uniqueLabels));

% RYSOWANIE profili dla każdego palca
plotHandles = [];
for i = 1:length(uniqueLabels)
    % ZAMKNIĘCIE profilu (dodaj pierwszy punkt na końcu)
    profileData = [profiles(i, :), profiles(i, 1)];
    
    h = polarplot(angles, profileData, 'o-', 'Color', colors(i, :), ...
        'LineWidth', 3, 'MarkerSize', 8, 'MarkerFaceColor', colors(i, :), ...
        'DisplayName', fingerNames{i});
    hold on;
    plotHandles(i) = h;
end

% RĘCZNE USTAWIENIE etykiet (zamiast thetalabels dla kompatybilności)
ax = gca;
ax.ThetaTick = rad2deg(angles(1:end-1)); % Konwersja na stopnie
ax.ThetaTickLabel = availableNames;

% USTAWIENIA promienia i podziałki
rlim([0, 110]);
rticks([0, 20, 40, 60, 80, 100]);

% TYTUŁ i legenda
title('PROFIL PALCÓW (% max)', 'FontSize', 16, 'FontWeight', 'bold');
legend(plotHandles, fingerNames, 'Location', 'best', 'FontSize', 10);

% ZAPIS FIGURY
saveas(gcf, fullfile(outputDir, 'minutiae_finger_profiles.png'));
close(gcf);
end

function createDistributionAnalysis(features, labels, metadata, outputDir)
% CREATEDISTRIBUTIONANALYSIS Analiza rozkładów i korelacji cech minucji
%
% Generuje kompleksową analizę rozkładów statystycznych składającą się z:
% 1. Histogramy liczby minucji per palec
% 2. Box ploty stosunku E/B per palec
% 3. Macierz korelacji kluczowych cech
% 4. Scatter plot endpoints vs bifurcations
% 5. Rozmieszczenie centroidów w przestrzeni
% 6. Statystyki sumaryczne dla każdego palca

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

%% SUBPLOT 1: ROZKŁAD LICZBY MINUCJI PER PALEC
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

%% SUBPLOT 2: BOX PLOT STOSUNKU E/B PER PALEC
subplot(2, 3, 2);

ratioData = [];
groupLabels = [];
groupNames = {};

% ZBIERANIE danych z zabezpieczeniami przeciw dzieleniu przez zero
for i = 1:length(uniqueLabels)
    fingerMask = labels == uniqueLabels(i);
    fingerEndpoints = features(fingerMask, 28);
    fingerBifurcations = features(fingerMask, 29);
    
    % ZABEZPIECZENIE: upewnij się że nie dzielimy przez zero
    fingerRatios = fingerEndpoints ./ max(fingerBifurcations, 0.1);
    
    % USUŃ outliers (stosunki > 20 to prawdopodobnie błędy)
    validRatios = fingerRatios(fingerRatios <= 20 & fingerRatios >= 0.01);
    
    if ~isempty(validRatios)
        ratioData = [ratioData; validRatios(:)];
        groupLabels = [groupLabels; repmat(i, length(validRatios), 1)];
        groupNames{i} = fingerNames{i};
    else
        ratioData = [ratioData; NaN];
        groupLabels = [groupLabels; i];
        groupNames{i} = fingerNames{i};
    end
end

try
    % USUŃ grupy z samymi NaN
    validGroups = ~isnan(ratioData);
    if sum(validGroups) > 0
        boxplot(ratioData(validGroups), groupLabels(validGroups), 'Labels', groupNames);
        
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
    % FALLBACK - wykres słupkowy gdy boxplot nie działa
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
            barNames{end+1} = fingerNames{i};
        end
    end
    
    if ~isempty(barData)
        barHandles = bar(barData, 'FaceColor', 'flat');
        
        for i = 1:length(barData)
            barHandles.CData(i,:) = colors(i,:);
        end
        
        set(gca, 'XTick', 1:length(barNames), 'XTickLabel', barNames);
        xtickangle(45);
        
        % ZWIĘKSZENIE ylim dla miejsca na etykiety
        maxBarValue = max(barData);
        ylim([0, maxBarValue * 1.2]);
        
        ylabel('Średni stosunek E/B');
        title('ŚREDNI STOSUNEK E/B', 'FontSize', 9, 'FontWeight', 'bold');
        grid on;
        
        % WARTOŚCI na słupkach
        for i = 1:length(barData)
            text(i, barData(i) + maxBarValue * 0.05, sprintf('%.2f', barData(i)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 8);
        end
    else
        text(0.5, 0.5, 'Brak danych E/B', 'HorizontalAlignment', 'center');
        title('STOSUNEK E/B - Brak danych', 'FontSize', 9, 'FontWeight', 'bold');
    end
end

%% SUBPLOT 3: KORELACJA WYBRANYCH KLUCZOWYCH CECH
subplot(2, 3, 3);

% WYBÓR tylko kluczowych cech dla lepszej czytelności
if size(features, 2) >= 32
    % REPREZENTATYWNE cechy
    selectedFeatures = [27, 28, 29, 30, 31]; % Liczba, Endpoints, Bifurcations, Jakość, CentroidX
    selectedNames = {'Liczba', 'Endpoints', 'Bifurcations', 'Jakość', 'Stor.E/B'};
    
    % DODANIE obliczonego stosunku E/B jako 6. cecha
    ratioFeature = features(:, 28) ./ max(features(:, 29), 0.1);
    selectedData = [features(:, selectedFeatures), ratioFeature];
    selectedNames{end+1} = 'Stor.E/B';
    
    % USUŃ próbki z NaN/Inf
    validRows = all(isfinite(selectedData), 2) & all(~isnan(selectedData), 2);
    selectedData = selectedData(validRows, :);
    
    if size(selectedData, 1) > 3
        % OBLICZ korelację dla wybranych cech
        corrMatrix = corr(selectedData);
        
        % WYŚWIETL macierz korelacji
        imagesc(corrMatrix);
        
        % LEPSZA mapa kolorów
        cmap = redblue(64);
        colormap(cmap);
        
        cb = colorbar;
        cb.Label.String = 'Korelacja';
        caxis([-1, 1]);
        
        % ETYKIETY - wszystkie widoczne
        set(gca, 'XTick', 1:length(selectedNames), 'YTick', 1:length(selectedNames));
        set(gca, 'XTickLabel', selectedNames, 'YTickLabel', selectedNames);
        xtickangle(45);
        
        % WARTOŚCI korelacji w komórkach
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

%% SUBPLOT 4: ENDPOINTS vs BIFURCATIONS PER PALEC
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

% LINIA referencyjna y=x
maxVal = max([max(endpoints), max(bifurcations)]);
refLine = plot([0, maxVal], [0, maxVal], 'k:', 'LineWidth', 2, 'DisplayName', 'y=x');

xlabel('Endpoints');
ylabel('Bifurcations');
title('ENDPOINTS vs BIFURCATIONS', 'FontSize', 10, 'FontWeight', 'bold');
legend([scatterHandles, refLine], [fingerNames, {'y=x'}], 'Location', 'best', 'FontSize', 8);
grid on;

%% SUBPLOT 5: ROZMIESZCZENIE CENTROIDÓW
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

%% SUBPLOT 6: STATYSTYKI SUMARYCZNE
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
        statsNames{end+1} = fingerNames{i};
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

% TYTUŁ GŁÓWNY FIGURY
sgtitle('ANALIZA ROZKŁADÓW I ZALEŻNOŚCI CECH MINUCJI', 'FontSize', 16, 'FontWeight', 'bold');

% ZAPIS FIGURY
saveas(gcf, fullfile(outputDir, 'minutiae_distribution_analysis.png'));
close(gcf);
end

function cmap = redblue(n)
% REDBLUE Tworzy mapę kolorów red-blue dla macierzy korelacji
%
% Generuje mapę kolorów przechodzącą od niebieskiego przez biały do czerwonego.
% Idealna dla wizualizacji korelacji gdzie:
% - Niebieski = korelacja ujemna
% - Biały = brak korelacji
% - Czerwony = korelacja dodatnia
%
% Parametry wejściowe:
%   n - liczba kolorów (opcjonalny, domyślnie 256)
%
% Dane wyjściowe:
%   cmap - macierz kolorów [n×3] w formacie RGB

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