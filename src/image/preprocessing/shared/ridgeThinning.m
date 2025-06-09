% filepath: src/image/preprocessing/ridgeThinning.m
function skeletonImage = ridgeThinning(binaryImage)
% RIDGETHINNING Szkieletyzacja linii papilarnych

% Szkieletyzacja
skeletonImage = bwmorph(binaryImage, 'thin', inf);

% Usuń krótkie fragmenty
skeletonImage = bwareaopen(skeletonImage, 20);

% Wygładź szkielet
skeletonImage = bwmorph(skeletonImage, 'clean');
skeletonImage = bwmorph(skeletonImage, 'spur', 3);  % Usuń krótkie odnogi
end