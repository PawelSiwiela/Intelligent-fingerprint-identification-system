function closeLog(logFile, executionTime)
% CLOSELOG Zamyka sesję logowania z podsumowaniem wykonania
%
% Funkcja kończy sesję logowania poprzez zapisanie podsumowania z czasem
% wykonania oraz ozdobnym separatorem. Służy do dokumentowania zakończenia
% procesów i czasu ich trwania w celach analizy wydajności.
%
% Parametry wejściowe:
%   logFile - ścieżka do pliku logów do zamknięcia
%   executionTime - całkowity czas wykonania w sekundach (opcjonalny)
%
% Dane wyjściowe:
%   - Sformatowane podsumowanie sesji w pliku logów
%   - Informacja o czasie wykonania (jeśli podano)
%   - Ozdobny separator dla wyraźnego oznaczenia końca sesji
%
% Przykład użycia:
%   closeLog('logs/system.log', 45.67);  % Z czasem wykonania
%   closeLog('logs/system.log');         % Bez czasu wykonania

if nargin < 1 || isempty(logFile)
    return;
end

try
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    % NAGŁÓWEK zakończenia sesji z ozdobnymi separatorami
    logEntry = sprintf('\n[%s] [INFO] =============================================================\n', timestamp);
    logEntry = [logEntry sprintf('[%s] [INFO]           SESSION COMPLETED                              \n', timestamp)];
    logEntry = [logEntry sprintf('[%s] [INFO] =============================================================\n', timestamp)];
    
    % DODAJ czas wykonania jeśli został podany
    if nargin >= 2 && ~isempty(executionTime)
        logEntry = [logEntry sprintf('[%s] [INFO] Total execution time: %.2f seconds\n', timestamp, executionTime)];
    end
    
    % INFORMACJA o zakończeniu sesji
    logEntry = [logEntry sprintf('[%s] [INFO] Session ended: %s\n', timestamp, datestr(now))];
    logEntry = [logEntry sprintf('[%s] [INFO] =============================================================\n\n', timestamp)];
    
    % ZAPISZ podsumowanie do pliku
    fileID = fopen(logFile, 'a');
    if fileID ~= -1
        fprintf(fileID, '%s', logEntry);
        fclose(fileID);
    end
    
catch
    % IGNORUJ błędy zamykania loga (końcowa operacja)
end
end