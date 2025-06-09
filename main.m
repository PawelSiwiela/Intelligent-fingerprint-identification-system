%% FINGERPRINT IDENTIFICATION SYSTEM
% Main entry point for the fingerprint identification system
% Author: PS
% Date: June 2025

%% Initialize environment
clear all;
close all;
clc;

% Get the directory of this script
currentDir = fileparts(mfilename('fullpath'));

% Add src directory and all its subdirectories
addpath(genpath(fullfile(currentDir, 'src')));

fprintf('Added project directories to MATLAB path.\n');

%% Configuration
% Load configuration
config = loadConfig();

% Set random seed for reproducibility
rng(config.experiment.randomSeed);

% Create log file path
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
logFileName = sprintf('fingerprint_identification_%s.log', timestamp);
logFile = fullfile(config.logsPath, logFileName);

% Create logs directory if it doesn't exist
if ~exist(config.logsPath, 'dir')
    mkdir(config.logsPath);
end

% Write log header
fid = fopen(logFile, 'w');
fprintf(fid, '=============================================================\n');
fprintf(fid, '           FINGERPRINT IDENTIFICATION SYSTEM LOG              \n');
fprintf(fid, '=============================================================\n');
fprintf(fid, 'Started: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, 'MATLAB version: %s\n', version);
fprintf(fid, '=============================================================\n\n');
fclose(fid);

logInfo('Fingerprint Identification System started', logFile);

% Display banner
fprintf('\n');
fprintf('=============================================================\n');
fprintf('           FINGERPRINT IDENTIFICATION SYSTEM                 \n');
fprintf('=============================================================\n');
fprintf('\n');

%% Main execution workflow
try
    % Start timing the entire process
    totalTimer = tic;
    
    % 1. Load and prepare data
    logInfo('1. Loading and preprocessing data...', logFile);
    dataTimer = tic;
    [trainData, valData, testData, dataInfo] = prepareData(config, logFile);
    dataTime = toc(dataTimer);
    logSuccess(sprintf('Data preparation completed in %.2f seconds', dataTime), logFile);
    
    % 2. Create and optimize networks
    logInfo('\n2. Creating and optimizing neural networks...', logFile);
    optimizationTimer = tic;
    % TODO: Implement network creation and optimization
    optimizationTime = toc(optimizationTimer);
    logSuccess(sprintf('Network optimization completed in %.2f seconds', optimizationTime), logFile);
    
    % 3. Train networks
    logInfo('\n3. Training neural networks...', logFile);
    trainingTimer = tic;
    % TODO: Implement network training
    trainingTime = toc(trainingTimer);
    logSuccess(sprintf('Network training completed in %.2f seconds', trainingTime), logFile);
    
    % 4. Test networks and evaluate performance
    logInfo('\n4. Testing and evaluating networks...', logFile);
    testingTimer = tic;
    % TODO: Implement network testing and evaluation
    testingTime = toc(testingTimer);
    logSuccess(sprintf('Testing completed in %.2f seconds', testingTime), logFile);
    
    % 5. Compare results
    logInfo('\n5. Comparing network performance...', logFile);
    % TODO: Implement comparison visualization
    
    % Calculate total execution time
    totalTime = toc(totalTimer);
    logInfo(sprintf('\nTotal execution time: %.2f seconds (%.2f minutes)', totalTime, totalTime/60), logFile);
    
    % Summary
    logInfo('\n=============================================================', logFile);
    logInfo('                         SUMMARY                             ', logFile);
    logInfo('=============================================================', logFile);
    logInfo(sprintf('Data preparation time: %.2f seconds', dataTime), logFile);
    logInfo(sprintf('Network optimization time: %.2f seconds', optimizationTime), logFile);
    logInfo(sprintf('Network training time: %.2f seconds', trainingTime), logFile);
    logInfo(sprintf('Network testing time: %.2f seconds', testingTime), logFile);
    logInfo(sprintf('Total execution time: %.2f seconds', totalTime), logFile);
    logInfo('=============================================================', logFile);
    
    % Close log file
    closeLog(logFile, totalTime);
    
catch exception
    % Handle errors gracefully
    logError(sprintf('Error occurred: %s', exception.message), logFile);
    logError('Stack trace:', logFile);
    for i = 1:length(exception.stack)
        frame = exception.stack(i);
        logError(sprintf('  File: %s, Function: %s, Line: %d', ...
            frame.file, frame.name, frame.line), logFile);
    end
    
    % Close log file with error status
    closeLog(logFile);
    
    % Also display in console
    fprintf('\n❌ Error occurred: %s\n', exception.message);
    fprintf('Stack trace:\n');
    disp(exception.stack);
end
