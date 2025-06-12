function writeLog(message, logLevel, logFile)
% WRITELOG Podstawowa funkcja zapisu do logu
%
% Input:
%   message - tekst do zapisania
%   logLevel - poziom: INFO, SUCCESS, WARNING, ERROR
%   logFile - ścieżka do pliku logu

if isempty(logFile)
    return; % Nie zapisuj jeśli brak pliku
end

% Utwórz folder logów jeśli nie istnieje
[logDir, ~, ~] = fileparts(logFile);
if ~exist(logDir, 'dir')
    mkdir(logDir);
end

% Znacznik czasu
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% Formatuj komunikat
formattedMessage = sprintf('[%s] [%s] %s', timestamp, logLevel, message);

% Zapisz do pliku
fid = fopen(logFile, 'a');
if fid ~= -1
    fprintf(fid, '%s\n', formattedMessage);
    fclose(fid);
end

% Wyświetl w konsoli z kolorami
switch upper(logLevel)
    case 'INFO'
        fprintf('%s\n', formattedMessage);
    case 'SUCCESS'
        fprintf('\033[32m%s\033[0m\n', formattedMessage);  % zielony
    case 'WARNING'
        fprintf('\033[33m%s\033[0m\n', formattedMessage);  % żółty
    case 'ERROR'
        fprintf('\033[31m%s\033[0m\n', formattedMessage);  % czerwony
    otherwise
        fprintf('%s\n', formattedMessage);
end
end