function logError(message, logFile, varargin)
% LOGERROR Komunikat o błędzie
if nargin < 2, logFile = []; end

% Obsługa formatowania (jeśli podano dodatkowe argumenty)
if ~isempty(varargin)
    try
        message = sprintf(message, varargin{:});
    catch
        % Ignoruj błędy formatowania
    end
end

writeLog(message, 'ERROR', logFile);
end