function logWarning(message, logFile)
% LOGWARNING Zapisuje ostrzeżenie
%   LOGWARNING(message, logFile) zapisuje ostrzeżenie
%   do pliku logu i wyświetla je w konsoli.

writeLog(message, 'WARNING', logFile);
end