%% FINGERPRINT IDENTIFICATION SYSTEM
% Main entry point for the fingerprint identification system

%% Initialize environment
clear all;
close all;
clc;

% Get the directory of this script
currentDir = fileparts(mfilename('fullpath'));

% Add src directory and all its subdirectories
addpath(genpath(fullfile(currentDir, 'src')));

% DODANE: Upewnij się że katalog utils jest dostępny
addpath(fullfile(currentDir, 'src', 'utils'));

fprintf('Added project directories to MATLAB path.\n');

%% Run the application
App();
