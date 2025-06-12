function logSuccess(message, logFile)
% LOGSUCCESS Komunikat o sukcesie
if nargin < 2, logFile = []; end
writeLog(message, 'SUCCESS', logFile);
end