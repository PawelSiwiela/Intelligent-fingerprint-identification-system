function writeLog(message, level, logFile)
% WRITELOG Zapisuje komunikat do logu
%
% Argumenty:
%   message - treść komunikatu
%   level - poziom komunikatu (INFO, WARNING, ERROR, SUCCESS)
%   logFile - ścieżka do pliku logu (opcjonalnie)

if nargin < 2, level = 'INFO'; end
if nargin < 3, logFile = []; end

% Formatuj komunikat z datą i poziomem
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
formattedMessage = sprintf('[%s] [%s] %s', timestamp, level, message);

% Zapisz do pliku jeśli podano
if ~isempty(logFile) && ischar(logFile)
    try
        % Sprawdź czy katalog istnieje i utwórz go jeśli nie
        [logDir, ~, ~] = fileparts(logFile);
        
        % Utwórz katalog jeśli nie istnieje i nie jest pusty
        if ~isempty(logDir) && ~exist(logDir, 'dir')
            mkdir(logDir);
        end
        
        % Dopisz do pliku
        fileID = fopen(logFile, 'a');
        if fileID ~= -1
            fprintf(fileID, '%s\n', formattedMessage);
            fclose(fileID);
        end
    catch
        % W przypadku błędu zapisu do logu, po cichu ignoruj
    end
end
end