function debugPreprocessing()
% DEBUGPREPROCESSING Prosty test preprocessing pipeline

close all;
clear all;
clc;

fprintf('🔍 TEST PREPROCESSING\n');
fprintf('%s\n', repmat('=', 1, 30));

% Setup ścieżek
currentDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(currentDir));
addpath(genpath(fullfile(projectRoot, 'src')));

% Setup logFile - POTRZEBNE!
systemConfig = loadConfig();
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
logFile = fullfile(systemConfig.logsPath, sprintf('debug_preprocessing_%s.log', timestamp));

% Wczytaj obraz
[images, ~] = loadImages(systemConfig, logFile);
testImage = images{1};
fprintf('✅ Obraz rzeczywisty: %dx%d\n', size(testImage, 1), size(testImage, 2));

% PREPROCESSING
fprintf('🔧 Preprocessing...\n');
tic;
processedImage = preprocessing(testImage, logFile, true);
elapsed = toc;

% Wynik
coverage = sum(processedImage(:)) / numel(processedImage) * 100;
fprintf('✅ Gotowe! Czas: %.3fs, Pokrycie: %.2f%%\n', elapsed, coverage);

% Prosta wizualizacja
figure('Position', [100, 100, 600, 300]);

subplot(1, 2, 1);
imshow(testImage);
title('Original');

subplot(1, 2, 2);
imshow(processedImage);
title(sprintf('Result: %.2f%%', coverage));

end