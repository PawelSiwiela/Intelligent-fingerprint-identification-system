function writeLog(message, logLevel, logFile)
% WRITELOG Zapisuje komunikat do logu
%   WRITELOG(message, logLevel, logFile) zapisuje komunikat
%   do pliku logu i wyświetla go w konsoli.

% Utwórz folder logów, jeśli nie istnieje
[logDir, ~, ~] = fileparts(logFile);
if ~exist(logDir, 'dir')
    mkdir(logDir);
end

% Dodaj znacznik czasu
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% Formatuj komunikat
formattedMessage = sprintf('[%s] [%s] %s', timestamp, logLevel, message);

% Otwórz plik w trybie dopisywania
fid = fopen(logFile, 'a');
if fid == -1
    error('Nie można otworzyć pliku logu: %s', logFile);
end

fprintf(fid, '%s\n', formattedMessage);
fclose(fid);

% Wyświetl w konsoli z odpowiednim kolorem
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