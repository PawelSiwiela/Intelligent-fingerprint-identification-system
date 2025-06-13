function closeLog(logFile, executionTime)
% CLOSELOG Zamyka plik loga z podsumowaniem
%
% Argumenty:
%   logFile - ścieżka do pliku logów
%   executionTime - czas wykonania w sekundach

if nargin < 1 || isempty(logFile)
    return;
end

try
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    logEntry = sprintf('\n[%s] [INFO] =============================================================\n', timestamp);
    logEntry = [logEntry sprintf('[%s] [INFO]           SESSION COMPLETED                              \n', timestamp)];
    logEntry = [logEntry sprintf('[%s] [INFO] =============================================================\n', timestamp)];
    
    if nargin >= 2 && ~isempty(executionTime)
        logEntry = [logEntry sprintf('[%s] [INFO] Total execution time: %.2f seconds\n', timestamp, executionTime)];
    end
    
    logEntry = [logEntry sprintf('[%s] [INFO] Session ended: %s\n', timestamp, datestr(now))];
    logEntry = [logEntry sprintf('[%s] [INFO] =============================================================\n\n', timestamp)];
    
    % Zapisz do pliku
    fileID = fopen(logFile, 'a');
    if fileID ~= -1
        fprintf(fileID, '%s', logEntry);
        fclose(fileID);
    end
    
catch
    % Ignoruj błędy zamykania loga
end
end