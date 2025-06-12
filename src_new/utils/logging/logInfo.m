function logInfo(message, logFile)
% LOGINFO Komunikat informacyjny
if nargin < 2, logFile = []; end
writeLog(message, 'INFO', logFile);
end