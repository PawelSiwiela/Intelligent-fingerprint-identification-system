function config = loadConfig()
% LOADCONFIG Wczytuje globalną konfigurację systemu identyfikacji odcisków palców
%
% Funkcja centralizuje wszystkie parametry konfiguracyjne systemu w jednej strukturze,
% umożliwiając łatwe zarządzanie ustawieniami preprocessingu, detekcji minucji,
% ekstrakcji cech, logowania oraz wizualizacji. Wszystkie parametry są udokumentowane
% z wartościami domyślnymi dostrojonymi na podstawie eksperymentów.
%
% Parametry wyjściowe:
%   config - struktura konfiguracyjna zawierająca:
%           .preprocessing - parametry przetwarzania obrazów
%           .minutiae - ustawienia detekcji i analizy minucji
%           .logging - konfiguracja systemu logowania
%           .visualization - opcje generowania wizualizacji
%           .dataLoading - ustawienia wczytywania danych
%
% Struktura konfiguracji:
%   ├── preprocessing: orientacja, częstotliwość, filtry Gabora
%   ├── minutiae: detekcja → filtracja → ekstrakcja cech
%   ├── logging: poziomy logów, ścieżki wyjściowe
%   ├── visualization: formaty, rozdzielczość, katalogi
%   └── dataLoading: formaty plików, strategie wczytywania
%
% Przykład użycia:
%   config = loadConfig();
%   orientBlockSize = config.preprocessing.orientationBlockSize;

config = struct();

%% KONFIGURACJA PREPROCESSINGU OBRAZÓW
% Parametry analizy struktur papilarnych i filtracji obrazów

config.preprocessing = struct();
% Rozmiar bloku dla analizy orientacji linii papilarnych (piksele)
% Wartość 16: kompromis między rozdzielczością orientacji a stabilnością numeryczną
config.preprocessing.orientationBlockSize = 16;

% Rozmiar bloku dla analizy częstotliwości linii papilarnych (piksele)
% Wartość 32: większy blok zapewnia stabilniejszą estymację częstotliwości FFT
config.preprocessing.frequencyBlockSize = 32;

% Rozmiar jądra filtra Gabora (piksele)
% Wartość 39: nieparzysty rozmiar zapewniający symetrię, ~2-3 okresy fali nośnej
config.preprocessing.gaborFilterSize = 39;

%% KONFIGURACJA DETEKCJI I ANALIZY MINUCJI
% Parametry dla całego pipeline'u minucji: detekcja → filtracja → cechy

config.minutiae = struct();

% === PARAMETRY DETEKCJI MINUCJI ===
config.minutiae.detection = struct();
% Minimalna odległość między wykrytymi minucjami (piksele)
% Eliminuje duplikaty i fałszywe detekcje w bliskim sąsiedztwie
config.minutiae.detection.minDistance = 10;

% Margines wykluczenia minucji od brzegów obrazu (piksele)
% Minucje na brzegach są często artefaktami segmentacji
config.minutiae.detection.borderMargin = 20;

% Próg kąta dla klasyfikacji bifurkacji (stopnie)
% Minimalny kąt między ramionami rozwidlenia dla akceptacji jako bifurkacja
config.minutiae.detection.angleThreshold = 15;

% === PARAMETRY FILTRACJI JAKOŚCIOWEJ ===
config.minutiae.filtering = struct();
% Minimalny próg jakości minucji w skali [0-1]
% Wartość 0.3: eliminuje ~30% najgorszych detekcji zachowując użyteczne minucje
config.minutiae.filtering.qualityThreshold = 0.3;

% Maksymalna liczba najlepszych minucji do zachowania po rankingu
% Ogranicza rozmiar wektora cech i redukuje szum obliczeniowy
config.minutiae.filtering.maxMinutiae = 400;

% Promień dla algorytmu liczenia linii papilarnych (piksele)
% Używany w analizie lokalnej gęstości i jakości struktury
config.minutiae.filtering.ridgeCountRadius = 20;

% === PARAMETRY EKSTRAKCJI CECH MINUCJI ===
config.minutiae.features = struct();
% Promień sąsiedztwa dla analizy relacji międzyminucyjnych (piksele)
% Definiuje zasięg wyszukiwania sąsiednich minucji dla deskryptorów
config.minutiae.features.neighborhoodRadius = 50;

% Maksymalna liczba sąsiadów uwzględniana w deskryptorze każdej minucji
% Ogranicza złożoność obliczeniową i wymiarowość wektora cech
config.minutiae.features.maxNeighbors = 8;

% Liczba binów w histogramie orientacji dla deskryptora (stopnie)
% Wartość 36: rozdzielczość 10 stopni, kompromis precyzja/odporność na szum
config.minutiae.features.orientationBins = 36;

%% KONFIGURACJA SYSTEMU LOGOWANIA
% Ustawienia monitorowania przebiegu algorytmów i debugowania

config.logging = struct();
% Włącz/wyłącz system logowania (true/false)
config.logging.enabled = true;

% Poziom szczegółowości logów: 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS'
% INFO: standardowy poziom z kluczowymi informacjami o przebiegu
config.logging.level = 'INFO';

% Katalog wyjściowy dla plików logów
config.logging.outputDir = 'output/logs';

%% KONFIGURACJA SYSTEMU WIZUALIZACJI
% Parametry generowania wykresów, diagramów i obrazów diagnostycznych

config.visualization = struct();
% Włącz/wyłącz generowanie wizualizacji (true/false)
config.visualization.enabled = true;

% Katalog wyjściowy dla plików graficznych
config.visualization.outputDir = 'output/figures';

% Format zapisu plików graficznych ('png', 'pdf', 'eps', 'svg')
% PNG: dobra jakość, uniwersalna kompatybilność, rozsądny rozmiar pliku
config.visualization.saveFormat = 'png';

% Rozdzielczość obrazów w punktach na cal (DPI)
% 300 DPI: jakość publikacyjna, odpowiednia do dokumentacji i prezentacji
config.visualization.dpi = 300;

%% KONFIGURACJA WCZYTYWANIA DANYCH
% Parametry organizacji i ładowania zbiorów danych odcisków palców

config.dataLoading = struct();
% Preferowany format plików do wczytania ('PNG' lub 'TIFF')
% System automatycznie wyszuka pliki Sample* w odpowiednim podkatalogu
config.dataLoading.format = 'PNG';

% Lista obsługiwanych rozszerzeń plików obrazów
% Rozszerzenie jest sprawdzane case-insensitive przy wczytywaniu
config.dataLoading.supportedFormats = {'.png', '.tiff'};

% Włącz rekurencyjne przeszukiwanie podkatalogów (true/false)
% false: tylko bezpośrednie podkatalogi zgodnie ze standardową strukturą
config.dataLoading.recursive = false;

% Tasowanie kolejności obrazów po wczytaniu (true/false)
% true: randomizacja kolejności poprawia statystyki walidacji krzyżowej
config.dataLoading.shuffleData = true;

end