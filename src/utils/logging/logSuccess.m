function logSuccess(message, logFile)
% LOGSUCCESS Zapisuje komunikat o sukcesie
%   LOGSUCCESS(message, logFile) zapisuje komunikat o sukcesie
%   do pliku logu i wyświetla go w konsoli.

writeLog(message, 'SUCCESS', logFile);
end