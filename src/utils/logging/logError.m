function logError(message, logFile)
% LOGERROR Zapisuje błąd do loga
%
% Argumenty:
%   message - wiadomość do zapisania
%   logFile - ścieżka do pliku logów (opcjonalne)

if nargin < 2 || isempty(logFile)
    % Tylko wyświetl na konsoli
    fprintf('[ERROR] %s\n', message);
else
    % Zapisz do pliku i wyświetl
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    logEntry = sprintf('[%s] [ERROR] %s\n', timestamp, message);
    
    % Wyświetl na konsoli
    fprintf('%s', logEntry);
    
    % Zapisz do pliku
    try
        fileID = fopen(logFile, 'a');
        if fileID ~= -1
            fprintf(fileID, '%s', logEntry);
            fclose(fileID);
        end
    catch
        % Ignoruj błędy zapisu do pliku
    end
end
end