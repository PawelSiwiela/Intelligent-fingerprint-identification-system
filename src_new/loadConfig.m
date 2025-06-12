function config = loadConfig()
% LOADCONFIG Czysta konfiguracja systemu

fprintf('⚙️ Ładowanie konfiguracji...\n');

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

fprintf('✅ Konfiguracja załadowana\n');
fprintf('   📂 Dane: %s\n', config.dataPath);
fprintf('   📊 Format: %s\n', config.imageFormat);
fprintf('   📈 Próbki: %d/%d/%d (train/val/test)\n', ...
    config.trainSamples, config.valSamples, config.testSamples);
end