%% FINGERPRINT IDENTIFICATION SYSTEM - GŁÓWNY PUNKT WEJŚCIOWY
% System identyfikacji odcisków palców - uruchamianie aplikacji głównej
%
% Ten skrypt jest punktem startowym całego systemu identyfikacji odcisków palców.
% Konfiguruje środowisko MATLAB poprzez dodanie wszystkich niezbędnych ścieżek
% do katalogów projektu i uruchamia główną aplikację GUI.
%
% Struktura projektu:
%   - src/ - kod źródłowy systemu
%   - src/utils/ - funkcje pomocnicze i narzędziowe
%   - src/image/ - przetwarzanie obrazów i preprocessing
%   - src/models/ - modele uczenia maszynowego
%
% Sposób użycia:
%   Uruchom ten skrypt w MATLAB aby rozpocząć pracę z systemem

%% INICJALIZACJA ŚRODOWISKA
% Wyczyść workspace i zamknij wszystkie figury
clear all;
close all;
clc;

% POBIERZ ścieżkę do katalogu głównego projektu
currentDir = fileparts(mfilename('fullpath'));

% DODAJ katalog src i wszystkie jego podkatalogi do ścieżki MATLAB
addpath(genpath(fullfile(currentDir, 'src')));

% DODATKOWO: Upewnij się że katalog utils jest dostępny (funkcje pomocnicze)
addpath(fullfile(currentDir, 'src', 'utils'));

fprintf('✅ Dodano katalogi projektu do ścieżki MATLAB.\n');
fprintf('📁 Katalog główny: %s\n', currentDir);

%% URUCHOMIENIE APLIKACJI GŁÓWNEJ
% Startuj główną aplikację GUI systemu identyfikacji odcisków palców
fprintf('🚀 Uruchamianie systemu identyfikacji odcisków palców...\n');
App();
