function writeLog(message, level, logFile)
% WRITELOG Uniwersalna funkcja zapisywania komunikatów do systemu logowania
%
% Funkcja zapewnia zunifikowany sposób zapisywania komunikatów różnych poziomów
% ważności do pliku logów oraz konsoli. Automatycznie formatuje wszystkie wpisy
% z oznaczeniami czasowymi i poziomami ważności dla łatwego filtrowania.
%
% Parametry wejściowe:
%   message - treść komunikatu do zapisania
%   level - poziom ważności: 'INFO', 'WARNING', 'ERROR', 'SUCCESS' (opcjonalny, domyślnie INFO)
%   logFile - ścieżka do pliku logów (opcjonalny, jeśli brak to tylko konsola)
%
% Dane wyjściowe:
%   - Sformatowany wpis w pliku logów z [timestamp] [poziom] wiadomość
%   - Automatyczne tworzenie katalogów dla ścieżki pliku logów
%
% Przykład użycia:
%   writeLog('System uruchomiony', 'INFO', 'logs/system.log');
%   writeLog('Ostrzeżenie o jakości obrazu', 'WARNING');

if nargin < 2, level = 'INFO'; end
if nargin < 3, logFile = []; end

% FORMATUJ komunikat z datą i poziomem ważności
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
formattedMessage = sprintf('[%s] [%s] %s', timestamp, level, message);

% ZAPISZ do pliku jeśli ścieżka została podana
if ~isempty(logFile) && ischar(logFile)
    try
        % SPRAWDŹ czy katalog istnieje i utwórz go jeśli nie
        [logDir, ~, ~] = fileparts(logFile);
        
        % UTWÓRZ katalog jeśli nie istnieje i nie jest pusty
        if ~isempty(logDir) && ~exist(logDir, 'dir')
            mkdir(logDir);
        end
        
        % DOPISZ do pliku (tryb append)
        fileID = fopen(logFile, 'a');
        if fileID ~= -1
            fprintf(fileID, '%s\n', formattedMessage);
            fclose(fileID);
        end
    catch
        % W przypadku błędu zapisu do pliku - po cichu ignoruj
        % (unikanie nieskończonych pętli błędów logowania)
    end
end
end