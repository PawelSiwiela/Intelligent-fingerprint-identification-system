function datasetMinutiae = extractMinutiaeFromDataset(data, datasetName, config, logFile)
% EXTRACTMINUTIAEFROMDATASET Ekstraktuje minucje z jednego zbioru danych

images = data.images;
labels = data.labels;
numImages = length(images);

datasetMinutiae = cell(numImages, 1);

fprintf('   📊 %s: ekstrakcja minucji z %d obrazów...\n', datasetName, numImages);

for i = 1:numImages
    try
        % Dla każdego obrazu szkieletowego, wyekstraktuj minucje
        skeletonImage = images{i};
        
        % Utworz prostą maskę (cały obraz)
        mask = skeletonImage > 0;
        
        % Wykryj minucje
        minutiae = detectMinutiae(skeletonImage, mask);
        datasetMinutiae{i} = minutiae;
        
    catch ME
        logWarning(sprintf('Błąd minucji dla obrazu %d w %s: %s', i, datasetName, ME.message), logFile);
        datasetMinutiae{i} = struct('endpoints', [], 'bifurcations', [], 'all', []);
    end
end

% Podsumowanie
totalMinutiae = 0;
for i = 1:numImages
    if ~isempty(datasetMinutiae{i}) && isfield(datasetMinutiae{i}, 'all')
        totalMinutiae = totalMinutiae + size(datasetMinutiae{i}.all, 1);
    end
end

fprintf('   ✅ %s: wykryto łącznie %d minucji\n', datasetName, totalMinutiae);
logInfo(sprintf('%s: wykryto łącznie %d minucji z %d obrazów', datasetName, totalMinutiae, numImages), logFile);
end