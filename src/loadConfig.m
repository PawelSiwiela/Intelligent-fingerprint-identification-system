function config = loadConfig()
% LOADCONFIG Ładuje konfigurację dla systemu identyfikacji odcisków palców
%
% Output:
%   config - struktura z parametrami konfiguracyjnymi

config = struct();

%% PREPROCESSING CONFIG
config.preprocessing.orientationBlockSize = 16;
config.preprocessing.frequencyBlockSize = 32;
config.preprocessing.gaborFilterSize = 39;

%% MINUTIAE CONFIG
% Parametry detekcji
config.minutiae.detection.minDistance = 10;        % Minimalna odległość między minucjami
config.minutiae.detection.borderMargin = 20;       % Margines od brzegu obrazu
config.minutiae.detection.angleThreshold = 15;     % Próg kąta dla bifurkacji (stopnie)

% Parametry filtracji
config.minutiae.filtering.qualityThreshold = 0.3;  % Próg jakości minucji
config.minutiae.filtering.maxMinutiae = 400;       % Maksymalna liczba minucji
config.minutiae.filtering.ridgeCountRadius = 20;   % Promień dla liczenia linii

% Parametry ekstrakcji cech
config.minutiae.features.neighborhoodRadius = 50;  % Promień sąsiedztwa
config.minutiae.features.maxNeighbors = 8;         % Maksymalna liczba sąsiadów
config.minutiae.features.orientationBins = 36;     % Liczba binów dla orientacji

%% LOGGING CONFIG
config.logging.enabled = true;
config.logging.level = 'INFO';                     % INFO, WARNING, ERROR, SUCCESS
config.logging.outputDir = 'output/logs';

%% VISUALIZATION CONFIG
config.visualization.enabled = true;
config.visualization.outputDir = 'output/figures';
config.visualization.saveFormat = 'png';
config.visualization.dpi = 300;

%% DATA LOADING CONFIG
config.dataLoading.format = 'PNG';                 % 'PNG' lub 'TIFF' - wybór formatu do wczytania
config.dataLoading.supportedFormats = {'.png', '.tiff'};
config.dataLoading.recursive = false;              % Czy szukać rekurencyjnie w podfolderach
config.dataLoading.shuffleData = true;             % Czy przetasować dane po wczytaniu

end