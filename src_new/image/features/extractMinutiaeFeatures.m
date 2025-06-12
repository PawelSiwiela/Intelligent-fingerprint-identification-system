function allFeatures = extractMinutiaeFeatures(allMinutiae, labels, config, logFile)
% EXTRACTMINUTIAEFEATURES Ekstraktuje cechy z minucji
% Ekstrahuje TYLKO cechy statystyczne (bez odległościowych)

if nargin < 4, logFile = []; end

try
    logInfo('=== EKSTRAKCJA CECH Z MINUCJI ===', logFile);
    
    logInfo('Parametry: 10 cech statystycznych (bez cech odległościowych)', logFile);
    
    numImages = length(allMinutiae);
    
    % Wymiar cech: tylko statystyki (10 cech)
    featureDim = 10; % Tylko 10 cech statystycznych
    
    fprintf('🧠 Ekstrakcja cech z %d obrazów...\n', numImages);
    fprintf('   📊 Wymiar cech: %d (tylko cechy statystyczne)\n', featureDim);
    
    allFeatures = zeros(numImages, featureDim);
    
    for i = 1:numImages
        try
            if ~isempty(allMinutiae{i}) && ~isempty(allMinutiae{i}.all)
                % Ekstrahuj tylko cechy statystyczne
                statFeatures = computeStatisticalFeatures(allMinutiae{i});
                
                if length(statFeatures) == featureDim
                    allFeatures(i, :) = statFeatures';
                else
                    allFeatures(i, :) = zeros(1, featureDim);
                end
            else
                allFeatures(i, :) = zeros(1, featureDim);
            end
            
            if mod(i, 10) == 0
                logInfo('   📊 Przetworzono %d/%d obrazów...\n', i, numImages);
            end
            
        catch ME
            logWarning(sprintf('Błąd ekstrakcji cech dla obrazu %d: %s', i, ME.message), logFile);
            allFeatures(i, :) = zeros(1, featureDim);
        end
    end
    
    fprintf('\n📋 EKSTRAKCJA CECH UKOŃCZONA:\n');
    fprintf('   📊 Macierz cech: %d x %d\n', size(allFeatures, 1), size(allFeatures, 2));
    fprintf('   📈 Zakres wartości: %.3f - %.3f\n', min(allFeatures(:)), max(allFeatures(:)));
    
    nonZeroFeatures = sum(allFeatures ~= 0, 2);
    fprintf('   ✅ Średnio %.1f niezerowych cech/obraz\n', mean(nonZeroFeatures));
    
    logInfo(sprintf('Ekstraktowano cechy: %dx%d, zakres %.3f-%.3f', ...
        size(allFeatures, 1), size(allFeatures, 2), min(allFeatures(:)), max(allFeatures(:))), logFile);
    
catch ME
    logError(sprintf('Błąd ekstrakcji cech: %s', ME.message), logFile);
    allFeatures = [];
end
end

function statFeatures = computeStatisticalFeatures(minutiae)
% Oblicza cechy statystyczne

statFeatures = zeros(10, 1);

if isempty(minutiae.all)
    return;
end

points = minutiae.all(:, 1:2);

% Podstawowe statystyki
statFeatures(1) = size(minutiae.all, 1); % liczba minucji
statFeatures(2) = size(minutiae.endpoints, 1); % liczba endpoints
statFeatures(3) = size(minutiae.bifurcations, 1); % liczba bifurcations

if size(points, 1) > 1
    % Statystyki przestrzenne
    centroid = mean(points);
    statFeatures(4) = centroid(1); % centroid X
    statFeatures(5) = centroid(2); % centroid Y
    
    distances = sqrt(sum((points - centroid).^2, 2));
    statFeatures(6) = mean(distances); % średnia odległość od centroidu
    statFeatures(7) = std(distances); % odchylenie standardowe odległości
    
    % Obszar pokrycia
    statFeatures(8) = max(points(:, 1)) - min(points(:, 1)); % szerokość
    statFeatures(9) = max(points(:, 2)) - min(points(:, 2)); % wysokość
    statFeatures(10) = statFeatures(8) * statFeatures(9); % pole
end
end