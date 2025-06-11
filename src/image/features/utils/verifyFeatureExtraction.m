function verifyFeatureExtraction(trainFeatures, valFeatures, testFeatures, trainMinutiae, valMinutiae, testMinutiae)
% VERIFYFEATUREEXTRACTION Szczegółowa weryfikacja ekstrakcji cech

fprintf('\n🔬 SZCZEGÓŁOWA WERYFIKACJA EKSTRAKCJI CECH:\n');
fprintf('%s\n', repmat('=', 1, 60)); % POPRAWKA: zamiast fprintf('=' * 60)
fprintf('\n');

% ======================================================================
% 1. SPRAWDŹ STRUKTURĘ WEKTORÓW CECH
% ======================================================================
fprintf('📊 STRUKTURA WEKTORÓW CECH (122 wymiary):\n');
fprintf('   Cechy 1-6:   Podstawowe statystyki\n');
fprintf('   Cechy 7-70:  Mapa gęstości 8x8 (64 cechy)\n');
fprintf('   Cechy 71-106: Histogram orientacji (36 cech)\n');
fprintf('   Cechy 107-122: Rozkład odległości (16 cech)\n\n');

allFeatures = [trainFeatures; valFeatures; testFeatures];

% ======================================================================
% 2. ANALIZA PODSTAWOWYCH STATYSTYK (cechy 1-6)
% ======================================================================
fprintf('📈 PODSTAWOWE STATYSTYKI (cechy 1-6):\n');
basicStats = allFeatures(:, 1:6);
statNames = {'Endpoints', 'Bifurcations', 'Total', 'EndpointRatio', 'BifurcationRatio', 'Density'};

for i = 1:6
    values = basicStats(:, i);
    fprintf('   %s: śr=%.3f, std=%.3f, min=%.3f, max=%.3f\n', ...
        statNames{i}, mean(values), std(values), min(values), max(values));
end

% ======================================================================
% 3. ANALIZA MAPY GĘSTOŚCI (cechy 7-70)
% ======================================================================
fprintf('\n🗺️  MAPA GĘSTOŚCI (cechy 7-70):\n');
densityFeatures = allFeatures(:, 7:70);
nonZeroDensity = sum(densityFeatures ~= 0, 'all');
totalDensityElements = numel(densityFeatures);

fprintf('   Elementy niezerowe: %d/%d (%.1f%%)\n', ...
    nonZeroDensity, totalDensityElements, nonZeroDensity/totalDensityElements*100);
fprintf('   Średnia gęstość: %.4f\n', mean(densityFeatures(:)));

% ======================================================================
% 4. ANALIZA ORIENTACJI (cechy 71-106)
% ======================================================================
fprintf('\n🧭 HISTOGRAM ORIENTACJI (cechy 71-106):\n');
orientationFeatures = allFeatures(:, 71:106);
nonZeroOrientation = sum(orientationFeatures ~= 0, 'all');
totalOrientationElements = numel(orientationFeatures);

fprintf('   Elementy niezerowe: %d/%d (%.1f%%)\n', ...
    nonZeroOrientation, totalOrientationElements, nonZeroOrientation/totalOrientationElements*100);

% Sprawdź czy suma każdego wiersza = 1 (znormalizowany histogram)
rowSums = sum(orientationFeatures, 2);
normalizedRows = sum(abs(rowSums - 1) < 0.001);
fprintf('   Poprawnie znormalizowane wiersze: %d/%d\n', normalizedRows, size(orientationFeatures, 1));

% ======================================================================
% 5. ANALIZA ODLEGŁOŚCI (cechy 107-122)
% ======================================================================
fprintf('\n📏 ROZKŁAD ODLEGŁOŚCI (cechy 107-122):\n');
distanceFeatures = allFeatures(:, 107:122);
nonZeroDistance = sum(distanceFeatures ~= 0, 'all');
totalDistanceElements = numel(distanceFeatures);

fprintf('   Elementy niezerowe: %d/%d (%.1f%%)\n', ...
    nonZeroDistance, totalDistanceElements, nonZeroDistance/totalDistanceElements*100);

% ======================================================================
% 6. KORELACJA Z LICZBĄ MINUCJI
% ======================================================================
fprintf('\n🔗 KORELACJA Z MINUCJAMI:\n');

% Zbierz rzeczywiste liczby minucji
allMinutiae = [trainMinutiae; valMinutiae; testMinutiae];
minutiaeCounts = zeros(length(allMinutiae), 1);

for i = 1:length(allMinutiae)
    if ~isempty(allMinutiae{i}) && ~isempty(allMinutiae{i}.all)
        minutiaeCounts(i) = size(allMinutiae{i}.all, 1);
    end
end

% Korelacja z cechą "Total minutiae" (3. cecha)
totalMinutiaeFeature = allFeatures(:, 3);
correlation = corrcoef(minutiaeCounts, totalMinutiaeFeature);

fprintf('   Korelacja rzeczywiste vs cechy: %.3f\n', correlation(1,2));

if correlation(1,2) > 0.9
    fprintf('   ✅ Bardzo dobra korelacja!\n');
elseif correlation(1,2) > 0.7
    fprintf('   ✅ Dobra korelacja\n');
else
    fprintf('   ⚠️ Słaba korelacja - sprawdź implementację\n');
end

% ======================================================================
% 7. PRZYKŁAD POJEDYNCZEGO WEKTORA CECH
% ======================================================================
fprintf('\n🔍 PRZYKŁAD WEKTORA CECH (1. obraz treningowy):\n');
example = trainFeatures(1, :);

fprintf('   Podstawowe: [%.1f, %.1f, %.1f, %.3f, %.3f, %.6f]\n', example(1:6));
fprintf('   Gęstość (pierwsze 8): [%.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f]\n', example(7:14));
fprintf('   Orientacja (pierwsze 8): [%.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f]\n', example(71:78));
fprintf('   Odległości (wszystkie 16): [%.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f]\n', example(107:122));

% ======================================================================
% 8. OCENA OGÓLNA
% ======================================================================
fprintf('\n📋 OCENA OGÓLNA:\n');

issues = 0;

% Sprawdź wymiary
if size(allFeatures, 2) ~= 122
    fprintf('   ❌ Nieprawidłowe wymiary cech\n');
    issues = issues + 1;
else
    fprintf('   ✅ Wymiary cech: OK\n');
end

% Sprawdź czy są dane
if sum(allFeatures(:)) == 0
    fprintf('   ❌ Wszystkie cechy to zera!\n');
    issues = issues + 1;
else
    fprintf('   ✅ Cechy zawierają dane\n');
end

% Sprawdź normalizację
if all(allFeatures(:) >= 0) && all(allFeatures(:) <= 1)
    fprintf('   ✅ Cechy znormalizowane [0,1]\n');
else
    fprintf('   ⚠️ Cechy mogą nie być znormalizowane\n');
    issues = issues + 1;
end

% Sprawdź korelację
if correlation(1,2) > 0.7
    fprintf('   ✅ Dobra korelacja z minucjami\n');
else
    fprintf('   ⚠️ Słaba korelacja z minucjami\n');
    issues = issues + 1;
end

% Podsumowanie
if issues == 0
    fprintf('\n🎉 EKSTRAKCJA CECH DZIAŁA POPRAWNIE!\n');
else
    fprintf('\n⚠️ Znaleziono %d problemów do sprawdzenia\n', issues);
end

fprintf('%s\n', repmat('=', 1, 60)); % POPRAWKA: zamiast fprintf('=' * 60)
fprintf('\n');
end