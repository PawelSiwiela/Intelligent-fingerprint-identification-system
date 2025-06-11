function [trainMinutiae, valMinutiae, testMinutiae] = extractAllMinutiae(trainData, valData, testData, config, logFile)
% EXTRACTALLMINUTIAE Ekstraktuje minucje ze wszystkich zbiorów danych

logInfo('  Ekstrakcja minucji ze wszystkich obrazów...', logFile);

% Ekstraktuj z każdego zbioru
trainMinutiae = extractMinutiaeFromDataset(trainData, 'Training', config, logFile);
valMinutiae = extractMinutiaeFromDataset(valData, 'Validation', config, logFile);
testMinutiae = extractMinutiaeFromDataset(testData, 'Test', config, logFile);

logInfo('  Ekstrakcja minucji ukończona', logFile);
end