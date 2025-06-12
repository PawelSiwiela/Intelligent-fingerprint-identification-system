function logInfo(message, logFile, varargin)
% LOGINFO Komunikat informacyjny
if nargin < 2, logFile = []; end

% Obsługa formatowania (jeśli podano dodatkowe argumenty)
if ~isempty(varargin)
    try
        message = sprintf(message, varargin{:});
    catch
        % Ignoruj błędy formatowania
    end
end

writeLog(message, 'INFO', logFile);
end