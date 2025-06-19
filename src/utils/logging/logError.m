function logError(message, logFile)
% LOGERROR Zapisuje komunikat o błędzie do systemu logowania
%
% Funkcja zapisuje komunikaty o błędach z oznaczeniem czasowym do pliku
% logów oraz wyświetla je na konsoli. Automatycznie formatuje wiadomości
% z prefiksem [ERROR] dla łatwej identyfikacji poziomu ważności.
%
% Parametry wejściowe:
%   message - treść komunikatu o błędzie do zapisania
%   logFile - ścieżka do pliku logów (opcjonalny, jeśli brak to tylko konsola)
%
% Dane wyjściowe:
%   - Wpis w pliku logów z oznaczeniem czasowym
%   - Wyświetlenie komunikatu na konsoli z prefiksem [ERROR]
%
% Przykład użycia:
%   logError('Nie udało się wczytać obrazu', 'logs/system.log');
%   logError('Błąd preprocessingu');  % Tylko na konsoli

if nargin < 2 || isempty(logFile)
    % TYLKO wyświetl na konsoli gdy brak pliku logów
    fprintf('[ERROR] %s\n', message);
else
    % ZAPISZ do pliku i wyświetl z pełnym oznaczeniem czasowym
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    logEntry = sprintf('[%s] [ERROR] %s\n', timestamp, message);
    
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