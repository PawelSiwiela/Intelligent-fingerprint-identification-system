function logSuccess(message, logFile)
% LOGSUCCESS Zapisuje komunikat o powodzeniu operacji do systemu logowania
%
% Funkcja zapisuje komunikaty o udanych operacjach z oznaczeniem czasowym
% do pliku logów oraz wyświetla je na konsoli. Automatycznie formatuje
% wiadomości z prefiksem [SUCCESS] dla łatwej identyfikacji udanych działań.
%
% Parametry wejściowe:
%   message - treść komunikatu o sukcesie do zapisania
%   logFile - ścieżka do pliku logów (opcjonalny, jeśli brak to tylko konsola)
%
% Dane wyjściowe:
%   - Wpis w pliku logów z oznaczeniem czasowym
%   - Wyświetlenie komunikatu na konsoli z prefiksem [SUCCESS]
%
% Przykład użycia:
%   logSuccess('Model wytrenowany pomyślnie', 'logs/system.log');
%   logSuccess('Preprocessing zakończony');  % Tylko na konsoli

if nargin < 2 || isempty(logFile)
    % TYLKO wyświetl na konsoli gdy brak pliku logów
    fprintf('[SUCCESS] %s\n', message);
else
    % ZAPISZ do pliku i wyświetl z pełnym oznaczeniem czasowym
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    logEntry = sprintf('[%s] [SUCCESS] %s\n', timestamp, message);
    
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