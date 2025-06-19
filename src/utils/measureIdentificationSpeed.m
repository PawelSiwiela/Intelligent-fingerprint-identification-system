function identificationResults = measureIdentificationSpeed(model, testFeatures, testLabels, modelType)
% MEASUREIDENTIFICATIONSPEED Mierzy szybkość identyfikacji pojedynczych próbek
%
% Funkcja przeprowadza benchmarking wydajności wytrenowanych modeli biometrycznych
% poprzez pomiar czasu potrzebnego na klasyfikację pojedynczych próbek odcisków
% palców. Generuje szczegółowe statystyki czasowe dla różnych typów modeli ML.
%
% Parametry wejściowe:
%   model - wytrenowany model (PatternNet lub CNN)
%   testFeatures - macierz cech testowych [n_samples × n_features] dla PatternNet
%                  LUB tensor obrazów [H × W × C × n_samples] dla CNN
%   testLabels - wektor etykiet testowych [n_samples × 1] (nieużywany w pomiarach)
%   modelType - typ modelu: 'patternnet' lub 'cnn'
%
% Dane wyjściowe:
%   identificationResults - struktura ze statystykami wydajności:
%     .avgTimeMs - średni czas identyfikacji w milisekundach
%     .minTimeMs - minimalny czas identyfikacji
%     .maxTimeMs - maksymalny czas identyfikacji
%     .stdTimeMs - odchylenie standardowe czasów
%     .throughputSamplesPerSec - przepustowość w próbkach/sekundę
%
% Przykład użycia:
%   results = measureIdentificationSpeed(trainedNet, X_test, Y_test, 'patternnet');
%   results = measureIdentificationSpeed(trainedCNN, imagesTensor, Y_test, 'cnn');

fprintf('\n⚡ IDENTIFICATION SPEED ANALYSIS\n');
fprintf('===============================\n');

% INICJALIZACJA pomiarów - różne podejścia dla różnych typów modeli
if strcmp(modelType, 'cnn')
    % CNN: tensor 4D [H × W × C × n_samples]
    numSamples = size(testFeatures, 4);
    fprintf('🔄 Processing %d test samples for %s model...\n', numSamples, upper(modelType));
    fprintf('📐 Input tensor size: [%d × %d × %d × %d]\n', ...
        size(testFeatures, 1), size(testFeatures, 2), size(testFeatures, 3), size(testFeatures, 4));
else
    % PatternNet: macierz 2D [n_samples × n_features]
    numSamples = size(testFeatures, 1);
    fprintf('🔄 Processing %d test samples for %s model...\n', numSamples, upper(modelType));
    fprintf('📐 Feature matrix size: [%d × %d]\n', size(testFeatures, 1), size(testFeatures, 2));
end

identificationTimes = zeros(numSamples, 1);

% PĘTLA POMIARÓW - każda próbka mierzona indywidualnie
for i = 1:numSamples
    % PRZYGOTUJ pojedynczą próbkę zgodnie z typem modelu
    if strcmp(modelType, 'cnn')
        % CNN: wyizoluj pojedynczy obraz z tensora 4D
        singleSample = testFeatures(:, :, :, i);  % [H × W × C × 1]
        
    elseif strcmp(modelType, 'patternnet')
        % PatternNet: wyizoluj pojedynczy wiersz cech
        singleSample = testFeatures(i, :);  % [1 × n_features]
        
    else
        error('Unsupported model type: %s. Use "patternnet" or "cnn"', modelType);
    end
    
    % START TIMER dla pojedynczej predykcji
    tic;
    
    % WYKONAJ PREDYKCJĘ zgodnie z typem modelu
    if strcmp(modelType, 'patternnet')
        % PATTERNNET: wektor cech → wektor prawdopodobieństw → klasa
        prediction = model(singleSample');  % Transpozycja dla PatternNet
        [~, predictedClass] = max(prediction);  % Wybór klasy o max prawdopodobieństwie
        
    elseif strcmp(modelType, 'cnn')
        % CNN: tensor obrazu → categorical → klasa numeryczna
        % KRYTYCZNE: Zachowaj wymiary 4D dla classify()
        prediction = classify(model, singleSample);
        predictedClass = double(prediction);
    end
    
    % STOP TIMER i zapisz czas dla tej próbki
    identificationTimes(i) = toc;
    
    % PROGRESS INDICATOR dla długich testów (co 10% próbek)
    if mod(i, max(1, floor(numSamples/10))) == 0
        fprintf('    Progress: %d/%d (%.1f%%)\n', i, numSamples, (i/numSamples)*100);
    end
end

% OBLICZ STATYSTYKI CZASOWE z konwersją na milisekundy
avgTime = mean(identificationTimes) * 1000;  % Średni czas [ms]
minTime = min(identificationTimes) * 1000;   % Najszybsza identyfikacja [ms]
maxTime = max(identificationTimes) * 1000;   % Najwolniejsza identyfikacja [ms]
stdTime = std(identificationTimes) * 1000;   % Odchylenie standardowe [ms]

% OBLICZ PRZEPUSTOWOŚĆ (próbki per sekunda)
throughput = 1 / (avgTime / 1000);  % Konwersja ms → s dla przepustowości

% WYŚWIETL SZCZEGÓŁOWY RAPORT WYDAJNOŚCI
fprintf('\n📊 %s IDENTIFICATION PERFORMANCE:\n', upper(modelType));
fprintf('=====================================\n');
fprintf('  Average time per sample: %.2f ms\n', avgTime);
fprintf('  Minimum time:            %.2f ms\n', minTime);
fprintf('  Maximum time:            %.2f ms\n', maxTime);
fprintf('  Standard deviation:      %.2f ms\n', stdTime);
fprintf('  Throughput:              %.0f samples/second\n', throughput);

% DODATKOWE ANALIZY WYDAJNOŚCI
fprintf('\n📈 PERFORMANCE INSIGHTS:\n');
if avgTime < 5
    fprintf('  ✅ EXCELLENT: Very fast identification (< 5ms)\n');
elseif avgTime < 20
    fprintf('  ✅ GOOD: Fast identification (< 20ms)\n');
elseif avgTime < 100
    fprintf('  ⚠️  MODERATE: Acceptable speed (< 100ms)\n');
else
    fprintf('  ❌ SLOW: Consider optimization (> 100ms)\n');
end

% ANALIZA STABILNOŚCI (coefficient of variation)
cv = (stdTime / avgTime) * 100;  % Współczynnik zmienności [%]
fprintf('  Timing stability: %.1f%% CV ', cv);
if cv < 10
    fprintf('(Very stable)\n');
elseif cv < 25
    fprintf('(Stable)\n');
else
    fprintf('(Variable - investigate)\n');
end

% PORÓWNANIE Z BENCHMARKAMI BIOMETRYCZNYMI
fprintf('  Real-time capability: ');
if throughput > 100
    fprintf('✅ Suitable for real-time systems\n');
elseif throughput > 10
    fprintf('⚠️  Limited real-time capability\n');
else
    fprintf('❌ Not suitable for real-time\n');
end

% ANALIZA SPECYFICZNA DLA TYPU MODELU
if strcmp(modelType, 'cnn')
    fprintf('\n🧠 CNN SPECIFIC INSIGHTS:\n');
    if avgTime < 10
        fprintf('  ✅ Excellent CNN performance for image classification\n');
    elseif avgTime < 50
        fprintf('  ✅ Good CNN performance - acceptable for most applications\n');
    else
        fprintf('  ⚠️  CNN slower than expected - consider model optimization\n');
    end
elseif strcmp(modelType, 'patternnet')
    fprintf('\n🧮 PATTERNNET SPECIFIC INSIGHTS:\n');
    if avgTime < 5
        fprintf('  ✅ Excellent feature-based classification speed\n');
    elseif avgTime < 15
        fprintf('  ✅ Good PatternNet performance\n');
    else
        fprintf('  ⚠️  PatternNet slower than expected - check feature complexity\n');
    end
end

% ZWRÓĆ STRUKTURĘ Z WYNIKAMI dla dalszej analizy
identificationResults = struct();
identificationResults.avgTimeMs = avgTime;
identificationResults.minTimeMs = minTime;
identificationResults.maxTimeMs = maxTime;
identificationResults.stdTimeMs = stdTime;
identificationResults.throughputSamplesPerSec = throughput;
identificationResults.coefficientOfVariation = cv;
identificationResults.totalSamples = numSamples;
identificationResults.modelType = modelType;

% DODAJ informacje o wymiarach danych
if strcmp(modelType, 'cnn')
    identificationResults.inputDimensions = size(testFeatures);
    identificationResults.imageSize = [size(testFeatures, 1), size(testFeatures, 2), size(testFeatures, 3)];
else
    identificationResults.inputDimensions = size(testFeatures);
    identificationResults.featureCount = size(testFeatures, 2);
end

% DODAJ timestamp dla dokumentacji
identificationResults.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

fprintf('\n✅ Speed analysis completed for %d samples\n', numSamples);
end