function logError(message, logFile)
% LOGERROR Zapisuje komunikat o błędzie
%   LOGERROR(message, logFile) zapisuje komunikat o błędzie
%   do pliku logu i wyświetla go w konsoli.

writeLog(message, 'ERROR', logFile);
end