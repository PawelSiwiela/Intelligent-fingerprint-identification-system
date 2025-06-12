function config = loadConfig()
% LOADCONFIG Czysta konfiguracja systemu

logInfo('⚙️ Ładowanie konfiguracji...');

% ŚCIEŻKI
config.dataPath = 'data';
config.outputPath = 'output';
config.logsPath = fullfile(config.outputPath, 'logs');
config.figuresPath = fullfile(config.outputPath, 'figures');

% DANE
config.imageFormat = 'png';
config.samplesPerFinger = 14;
config.trainSamples = 10;
config.valSamples = 2;
config.testSamples = 2;

% MINUTIAE
config.minutiae = struct();
config.minutiae.minDistance = 8;
config.minutiae.maxMinutiae = 200;

% OPCJE
config.saveFigures = false;
config.showProgress = true;

% TWORZENIE FOLDERÓW
folders = {config.outputPath, config.logsPath, config.figuresPath};
for i = 1:length(folders)
    if ~exist(folders{i}, 'dir')
        mkdir(folders{i});
    end
end

logSuccess('✅ Konfiguracja załadowana');
logInfo(sprintf('   📂 Dane: %s', config.dataPath));
logInfo(sprintf('   📊 Format: %s', config.imageFormat));
logInfo(sprintf('   📈 Próbki: %d/%d/%d (train/val/test)', ...
    config.trainSamples, config.valSamples, config.testSamples));
end