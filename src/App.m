function App()
% APP Prosta aplikacja konsolowa do rozpoznawania odcisków palców

clc;

fprintf('🔬 SYSTEM ROZPOZNAWANIA ODCISKÓW PALCÓW\n');
fprintf('%s\n', repmat('=', 1, 50));

% Wczytaj konfigurację
config = loadConfig();

% ===== WYBÓR FORMATU OBRAZÓW =====
fprintf('\nFormat obrazów:\n');
fprintf('1 - PNG (aktualny: %s)\n', config.imageFormat);
fprintf('2 - TIFF\n');
fprintf('Wybierz [1-2]: ');
formatChoice = input('');

if formatChoice == 2
    config.imageFormat = 'tiff';
    fprintf('✓ Format: TIFF\n');
else
    config.imageFormat = 'png';
    fprintf('✓ Format: PNG\n');
end

% ===== ZAPISYWANIE FIGUR =====
fprintf('\nZapisywanie figur:\n');
fprintf('1 - Tak\n');
fprintf('2 - Nie\n');
fprintf('Wybierz [1-2]: ');
saveChoice = input('');

saveFigures = (saveChoice == 1);
fprintf('✓ Zapisywanie figur: %s\n', getYesNo(saveFigures));

% DODAJ TO DO CONFIG!
config.saveFigures = saveFigures;

% ===== URUCHOM SYSTEM OD RAZU =====
fprintf('\n🚀 URUCHAMIAM SYSTEM...\n');
fprintf('%s\n', repmat('=', 1, 50));

try
    % Przygotuj log
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    logFile = fullfile(config.logsPath, sprintf('app_system_%s.log', timestamp));
    
    % Uruchom system
    tic;
    results = fingerprintRecognition(config, logFile);
    elapsed = toc;
    
    % Wyświetl wyniki
    if results.success
        fprintf('\n✅ SYSTEM UKOŃCZONY w %.2f sekund!\n', elapsed);
        fprintf('📊 Przygotowane dane:\n');
        fprintf('  🎯 Trening: %d obrazów\n', results.stats.trainSamples);
        fprintf('  🔍 Walidacja: %d obrazów\n', results.stats.valSamples);
        fprintf('  📋 Test: %d obrazów\n', results.stats.testSamples);
        fprintf('  📈 ŁĄCZNIE: %d obrazów\n', results.stats.totalSamples);
        fprintf('📁 Logi: %s\n', logFile);
    else
        fprintf('\n❌ SYSTEM ZAKOŃCZONY BŁĘDEM!\n');
        fprintf('Błąd: %s\n', results.error);
    end
    
catch e
    fprintf('\n❌ KRYTYCZNY BŁĄD: %s\n', e.message);
    if ~isempty(e.stack)
        fprintf('Plik: %s, Linia: %d\n', e.stack(1).name, e.stack(1).line);
    end
end

fprintf('\n👋 Koniec pracy systemu.\n');

% Zamknij log
closeLog(logFile, results.totalTime);
end

% Funkcja zwracająca 'Tak' lub 'Nie'
function result = getYesNo(value)
if value
    result = 'TAK';
else
    result = 'NIE';
end
end