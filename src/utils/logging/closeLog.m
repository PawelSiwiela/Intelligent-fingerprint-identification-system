function closeLog(logFile, executionTime)
% CLOSELOG Finalizuje plik logu
%   CLOSELOG(logFile, executionTime) zapisuje podsumowanie do pliku logu.
%   Parametr executionTime to całkowity czas wykonywania programu w sekundach.

if nargin < 2
    executionTime = 0;
end

% Oblicz formatowany czas wykonania
hours = floor(executionTime / 3600);
minutes = floor((executionTime - hours * 3600) / 60);
seconds = executionTime - hours * 3600 - minutes * 60;

timeStr = sprintf('%02d:%02d:%02.2f', hours, minutes, seconds);

% Zapisz podsumowanie do logu
logInfo('', logFile);
logInfo('=============================================================', logFile);
logInfo('                    EXECUTION COMPLETED                      ', logFile);
logInfo('=============================================================', logFile);
logInfo(sprintf('Finished: %s', datestr(now, 'yyyy-mm-dd HH:MM:SS')), logFile);
logInfo(sprintf('Total execution time: %s', timeStr), logFile);
logInfo('=============================================================', logFile);
end