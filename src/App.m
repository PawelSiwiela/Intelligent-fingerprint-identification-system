function App()
% APP Prosta aplikacja konsolowa do rozpoznawania odcisków palców
%
% Aplikacja umożliwiająca wybór różnych scenariuszy rozpoznawania odcisków palców
% oraz obserwowanie wyników działania systemu przez interfejs konsolowy.

% Czyszczenie konsoli
clc;

% Tytuł aplikacji
printHeader('SYSTEM ROZPOZNAWANIA ODCISKÓW PALCÓW');

% Inicjalizacja konfiguracji
config = struct();

% ===== WYBÓR METODY PREPROCESSING =====
fprintf('KROK 1: Wybór metody preprocessing\n');
fprintf('1 - Basic (szybka, podstawowa)\n');
fprintf('2 - Hybrid (basic + gabor)\n');
fprintf('3 - Advanced (zaawansowana, wolna)\n');
fprintf('4 - Porównanie wszystkich metod\n');
fprintf('Wybierz opcję [1-4]: ');
preprocessChoice = input('');

switch preprocessChoice
    case 1
        config.preprocessing_method = 'basic';
        fprintf('✓ Wybrano: Basic preprocessing\n');
    case 2
        config.preprocessing_method = 'hybrid';
        fprintf('✓ Wybrano: Hybrid preprocessing\n');
    case 3
        config.preprocessing_method = 'advanced';
        fprintf('✓ Wybrano: Advanced preprocessing\n');
    case 4
        config.preprocessing_method = 'all';
        fprintf('✓ Wybrano: Porównanie wszystkich metod\n');
    otherwise
        config.preprocessing_method = 'basic';
        fprintf('⚠ Nieprawidłowy wybór. Ustawiam domyślnie: Basic preprocessing\n');
end

fprintf('\n');

% ===== METODA EKSTRAKTOWANIA CECH =====
fprintf('KROK 2: Metoda ekstraktowania cech\n');
fprintf('1 - Simple (9 cech - szybka)\n');
fprintf('2 - Normalized (17 cech - zalecana)\n');
fprintf('3 - Statistical (25+ cech - dokładna)\n');
fprintf('Wybierz metodę [1-3]: ');
featureChoice = input('');

switch featureChoice
    case 1
        config.feature_method = 'simple';
        fprintf('✓ Wybrano: Simple features (9 cech)\n');
    case 2
        config.feature_method = 'normalized';
        fprintf('✓ Wybrano: Normalized features (17 cech)\n');
    case 3
        config.feature_method = 'statistical';
        fprintf('✓ Wybrano: Statistical features (25+ cech)\n');
    otherwise
        config.feature_method = 'normalized';
        fprintf('⚠ Nieprawidłowy wybór. Ustawiam domyślnie: Normalized features\n');
end

fprintf('\n');

% ===== TRYB DZIAŁANIA =====
fprintf('KROK 3: Tryb działania\n');
fprintf('1 - Test szybki (syntetyczne dane)\n');
fprintf('2 - Test na pojedynczym obrazie\n');
fprintf('3 - Test na małym dataset (10 obrazów)\n');
fprintf('4 - Pełny dataset\n');
fprintf('Wybierz tryb [1-4]: ');
modeChoice = input('');

switch modeChoice
    case 1
        config.mode = 'quick';
        fprintf('✓ Wybrano: Test szybki\n');
    case 2
        config.mode = 'single';
        fprintf('✓ Wybrano: Test pojedynczego obrazu\n');
    case 3
        config.mode = 'small';
        fprintf('✓ Wybrano: Mały dataset\n');
    case 4
        config.mode = 'full';
        fprintf('✓ Wybrano: Pełny dataset\n');
    otherwise
        config.mode = 'quick';
        fprintf('⚠ Nieprawidłowy wybór. Ustawiam domyślnie: Test szybki\n');
end

fprintf('\n');

% ===== WIZUALIZACJE =====
fprintf('KROK 4: Wizualizacje\n');
fprintf('1 - Tak (pokaż wyniki)\n');
fprintf('2 - Nie (tylko konsola)\n');
fprintf('Czy generować wizualizacje? [1-2]: ');
vizChoice = input('');

switch vizChoice
    case 1
        config.show_visualizations = true;
        fprintf('✓ Wybrano: Wizualizacje włączone\n');
    case 2
        config.show_visualizations = false;
        fprintf('✓ Wybrano: Tylko wyniki w konsoli\n');
    otherwise
        config.show_visualizations = false;
        fprintf('⚠ Nieprawidłowy wybór. Ustawiam domyślnie: Bez wizualizacji\n');
end

fprintf('\n');

% ===== ZAPIS WYNIKÓW =====
fprintf('KROK 5: Zapis wyników\n');
fprintf('1 - Tak (zapisz do plików)\n');
fprintf('2 - Nie\n');
fprintf('Czy zapisać wyniki? [1-2]: ');
saveChoice = input('');

switch saveChoice
    case 1
        config.save_results = true;
        fprintf('✓ Wybrano: Zapis wyników włączony\n');
    case 2
        config.save_results = false;
        fprintf('✓ Wybrano: Bez zapisu wyników\n');
    otherwise
        config.save_results = false;
        fprintf('⚠ Nieprawidłowy wybór. Ustawiam domyślnie: Bez zapisu\n');
end

fprintf('\n');

% ===== PODSUMOWANIE KONFIGURACJI =====
printHeader('PODSUMOWANIE KONFIGURACJI');
fprintf('Metoda preprocessing: %s\n', getPreprocessingName(config.preprocessing_method));
fprintf('Ekstraktowanie cech: %s\n', getFeatureName(config.feature_method));
fprintf('Tryb działania: %s\n', getModeName(config.mode));
fprintf('Wizualizacje: %s\n', getYesNo(config.show_visualizations));
fprintf('Zapis wyników: %s\n', getYesNo(config.save_results));
fprintf('\n');

% ===== URUCHOMIENIE SYSTEMU =====
fprintf('Czy uruchomić system z powyższymi ustawieniami? (t/n): ');
startChoice = input('', 's');

if strcmpi(startChoice, 't') || strcmpi(startChoice, 'tak') || strcmpi(startChoice, 'y') || strcmpi(startChoice, 'yes')
    printHeader('ROZPOCZYNAM PRZETWARZANIE ODCISKÓW PALCÓW');
    
    % Uruchomienie głównej funkcji
    try
        tic;
        results = fingerprintProcessing(config);
        elapsed_time = toc;
        
        % Wyświetlenie podsumowania
        printHeader('WYNIKI');
        fprintf('Czas wykonania: %.2f sekund\n', elapsed_time);
        
        if isfield(results, 'preprocessing_method')
            fprintf('Użyta metoda preprocessing: %s\n', results.preprocessing_method);
        end
        
        if isfield(results, 'total_minutiae')
            fprintf('Łączna liczba wykrytych minucji: %d\n', results.total_minutiae);
        end
        
        if isfield(results, 'feature_count')
            fprintf('Liczba ekstraktowanych cech: %d\n', results.feature_count);
        end
        
        if isfield(results, 'processed_images')
            fprintf('Liczba przetworzonych obrazów: %d\n', results.processed_images);
        end
        
        if config.save_results && isfield(results, 'output_path')
            fprintf('Wyniki zapisane w: %s\n', results.output_path);
        end
        
    catch e
        % Obsługa błędów
        fprintf('\n❌ BŁĄD: %s\n', e.message);
        if ~isempty(e.stack)
            fprintf('Ścieżka: %s\n', e.stack(1).name);
            fprintf('Linia: %d\n', e.stack(1).line);
        end
        
        % Pokaż sugestie rozwiązania
        fprintf('\n💡 SUGESTIE:\n');
        fprintf('- Sprawdź czy dane wejściowe są dostępne\n');
        fprintf('- Upewnij się że wszystkie funkcje są w ścieżce MATLAB\n');
        fprintf('- Spróbuj trybu "Test szybki" dla debugowania\n');
    end
else
    fprintf('Anulowano uruchomienie.\n');
end

end

% ===== FUNKCJE POMOCNICZE =====

function printHeader(text)
% Wyświetla nagłówek z ramką
fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('%s\n', text);
fprintf('%s\n\n', repmat('=', 1, 60));
end

function name = getPreprocessingName(method)
% Zwraca czytelną nazwę metody preprocessing
switch method
    case 'basic'
        name = 'Basic (szybka, podstawowa)';
    case 'hybrid'
        name = 'Hybrid (basic + gabor)';
    case 'advanced'
        name = 'Advanced (zaawansowana)';
    case 'all'
        name = 'Porównanie wszystkich metod';
    otherwise
        name = method;
end
end

function name = getFeatureName(method)
% Zwraca czytelną nazwę metody cech
switch method
    case 'simple'
        name = 'Simple (9 cech)';
    case 'normalized'
        name = 'Normalized (17 cech)';
    case 'statistical'
        name = 'Statistical (25+ cech)';
    otherwise
        name = method;
end
end

function name = getModeName(mode)
% Zwraca czytelną nazwę trybu
switch mode
    case 'quick'
        name = 'Test szybki (syntetyczne dane)';
    case 'single'
        name = 'Test pojedynczego obrazu';
    case 'small'
        name = 'Mały dataset (10 obrazów)';
    case 'full'
        name = 'Pełny dataset';
    otherwise
        name = mode;
end
end

function result = getYesNo(value)
% Zwraca 'Tak' lub 'Nie'
if value
    result = 'Tak';
else
    result = 'Nie';
end
end