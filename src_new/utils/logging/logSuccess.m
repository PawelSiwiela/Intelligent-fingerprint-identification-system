function logSuccess(message, logFile, varargin)
% LOGSUCCESS Komunikat o sukcesie
if nargin < 2, logFile = []; end

% Obsługa formatowania (jeśli podano dodatkowe argumenty)
if ~isempty(varargin)
    try
        message = sprintf(message, varargin{:});
    catch
        % Ignoruj błędy formatowania
    end
end

writeLog(message, 'SUCCESS', logFile);
end