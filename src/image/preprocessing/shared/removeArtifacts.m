% filepath: src/image/preprocessing/removeArtifacts.m
function cleanImage = removeArtifacts(skeletonImage, mask)
% REMOVEARTIFACTS Usuwa artefakty ze szkieletu

cleanImage = skeletonImage;

% Usuń piksele poza maską
cleanImage = cleanImage & mask;

% Usuń izolowane piksele
cleanImage = bwmorph(cleanImage, 'clean');

% Usuń małe komponenty
cleanImage = bwareaopen(cleanImage, 10);

% Wypełnij małe dziury w liniach
cleanImage = bwmorph(cleanImage, 'bridge');
cleanImage = bwmorph(cleanImage, 'fill');
end