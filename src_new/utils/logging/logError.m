function logError(message, logFile)
% LOGERROR Komunikat o błędzie
if nargin < 2, logFile = []; end
writeLog(message, 'ERROR', logFile);
end