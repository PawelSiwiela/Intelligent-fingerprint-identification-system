function logInfo(message, logFile)
% LOGINFO Zapisuje komunikat informacyjny
%   LOGINFO(message, logFile) zapisuje komunikat informacyjny
%   do pliku logu i wyświetla go w konsoli.

writeLog(message, 'INFO', logFile);
end