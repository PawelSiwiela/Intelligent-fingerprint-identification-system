function config = loadConfig()
% LOADCONFIG Tworzy i zwraca domyślną konfigurację projektu
%   config = LOADCONFIG() tworzy strukturę zawierającą wszystkie parametry
%   konfiguracyjne używane w projekcie.

% Pozyskanie katalogu projektu - usuwamy jeden poziom fileparts
% (już jesteśmy w src)
projectDir = fileparts(fileparts(mfilename('fullpath')));

% Ścieżki do katalogów
config.projectDir = projectDir;
config.dataPath = fullfile(projectDir, 'data');
config.outputPath = fullfile(projectDir, 'output');
config.modelsPath = fullfile(projectDir, 'output', 'models');
config.logsPath = fullfile(projectDir, 'output', 'logs');
config.figuresPath = fullfile(projectDir, 'output', 'figures');

% Parametry danych
config.imageFormat = 'png';  % Format obrazów do wczytania ('png' lub 'tiff')
config.imageSize = [400, 400];  % Docelowy rozmiar obrazów

% Ustawienie proporcji danych na dokładne liczby: 10 trening, 2 walidacja, 2 test
config.samplesPerFinger = 14;
config.trainSamples = 10;     % 10 próbek treningowych
config.valSamples = 2;        % 2 próbki walidacyjne
config.testSamples = 2;       % 2 próbki testowe

% Oblicz proporcje (na wszelki wypadek, gdyby były potrzebne)
config.trainRatio = config.trainSamples / config.samplesPerFinger;
config.valRatio = config.valSamples / config.samplesPerFinger;
config.testRatio = config.testSamples / config.samplesPerFinger;

% Parametry przetwarzania obrazu
config.preprocessing = struct();
config.preprocessing.normalize = true;         % Normalizacja intensywności
config.preprocessing.contrastEnhancement = true; % Poprawa kontrastu
config.preprocessing.denoise = true;           % Odszumianie

% Parametry ekstrakcji minucji
config.minutiae = struct();
config.minutiae.blockSize = 16;               % Rozmiar bloku dla filtracji Gabora
config.minutiae.orientationSmoothing = 5;     % Wygładzanie orientacji
config.minutiae.threshold = 0.1;              % Próg binaryzacji

% Parametry sieci Pattern Recognition Network
config.patternnet = struct();
config.patternnet.hiddenLayerSizes = [50, 25]; % Rozmiary warstw ukrytych
config.patternnet.trainFcn = 'trainscg';      % Funkcja trenująca
config.patternnet.performFcn = 'crossentropy'; % Funkcja kosztu
config.patternnet.maxEpochs = 100;            % Maksymalna liczba epok

% Parametry sieci konwolucyjnej (CNN)
config.cnn = struct();
config.cnn.imageInputSize = [128, 128, 1];    % Rozmiar wejściowy obrazu dla CNN

% Parametry optymalizacji genetycznej
config.genetic = struct();
config.genetic.populationSize = 20;           % Rozmiar populacji
config.genetic.maxGenerations = 10;           % Maksymalna liczba generacji
config.genetic.crossoverFraction = 0.8;       % Współczynnik krzyżowania
config.genetic.eliteCount = 2;                % Liczba elitarnych osobników

% Parametry eksperymentu
config.experiment = struct();
config.experiment.randomSeed = 42;            % Ziarno dla generatora liczb losowych
config.experiment.kFold = 5;                  % Liczba podziałów dla cross-validation

% Wyświetlenie podsumowania konfiguracji
fprintf('Konfiguracja załadowana:\n');
fprintf('- Katalog danych: %s\n', config.dataPath);
fprintf('- Format obrazów: %s\n', config.imageFormat);
fprintf('- Liczba próbek: %d treningowych, %d walidacyjnych, %d testowych\n', ...
    config.trainSamples, config.valSamples, config.testSamples);
end