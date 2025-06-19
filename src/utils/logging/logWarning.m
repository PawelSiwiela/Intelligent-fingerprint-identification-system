function logWarning(message, logFile)
% LOGWARNING Zapisuje komunikat ostrzegawczy do systemu logowania
%
% Funkcja zapisuje ostrzeżenia z oznaczeniem czasowym do pliku logów
% oraz wyświetla je na konsoli. Automatycznie formatuje wiadomości
% z prefiksem [WARNING] dla łatwej identyfikacji potencjalnych problemów.
%
% Parametry wejściowe:
%   message - treść ostrzeżenia do zapisania
%   logFile - ścieżka do pliku logów (opcjonalny, jeśli brak to tylko konsola)
%
% Dane wyjściowe:
%   - Wpis w pliku logów z oznaczeniem czasowym
%   - Wyświetlenie komunikatu na konsoli z prefiksem [WARNING]
%
% Przykład użycia:
%   logWarning('Niska jakość obrazu', 'logs/system.log');
%   logWarning('Wykryto mało minucji');  % Tylko na konsoli

if nargin < 2 || isempty(logFile)
    % TYLKO wyświetl na konsoli gdy brak pliku logów
    fprintf('[WARNING] %s\n', message);
else
    % ZAPISZ do pliku i wyświetl z pełnym oznaczeniem czasowym
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    logEntry = sprintf('[%s] [WARNING] %s\n', timestamp, message);
    
    % WYŚWIETL na konsoli
    fprintf('%s', logEntry);
    
    % ZAPISZ do pliku z obsługą błędów
    try
        fileID = fopen(logFile, 'a');
        if fileID ~= -1
            fprintf(fileID, '%s', logEntry);
            fclose(fileID);
        end
    catch
        % IGNORUJ błędy zapisu do pliku (unikaj nieskończonych pętli logowania)
    end
end
end