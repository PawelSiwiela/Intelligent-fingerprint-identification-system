function logWarning(message, logFile)
% LOGWARNING Komunikat ostrzegawczy
if nargin < 2, logFile = []; end
writeLog(message, 'WARNING', logFile);
end