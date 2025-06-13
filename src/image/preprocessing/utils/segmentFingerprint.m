function [segmentedImage, mask] = segmentFingerprint(image)
% SEGMENTFINGERPRINT Segmentuje obszar odcisku od tła
%
% Argumenty:
%   image - obraz po filtracji Gabora
%
% Output:
%   segmentedImage - obraz z wyzerowanym tłem
%   mask - maska obszaru odcisku

try
    if ~isa(image, 'double')
        image = im2double(image);
    end
    
    [rows, cols] = size(image);
    
    % Dla małych obrazów - pełna maska
    if rows < 32 || cols < 32
        mask = true(size(image));
        segmentedImage = image;
        return;
    end
    
    % Segmentacja na podstawie lokalnej wariancji
    localVar = stdfilt(image, ones(15,15)).^2;
    threshold = graythresh(localVar) * 0.3;
    mask = localVar > threshold;
    
    % Fallback jeśli maska za mała
    if sum(mask(:)) < 0.05 * numel(mask)
        mask = image > graythresh(image) * 0.5;
    end
    
    % Operacje morfologiczne
    if sum(mask(:)) > 100
        mask = imopen(mask, strel('disk', 2));
        mask = imclose(mask, strel('disk', 3));
        mask = imfill(mask, 'holes');
        
        % Wybierz największy komponent
        cc = bwconncomp(mask);
        if cc.NumObjects > 1
            areas = cellfun(@length, cc.PixelIdxList);
            [~, maxIdx] = max(areas);
            newMask = false(size(mask));
            newMask(cc.PixelIdxList{maxIdx}) = true;
            mask = newMask;
        end
    end
    
    % Zastosuj maskę
    segmentedImage = image;
    segmentedImage(~mask) = 0;
    
catch
    % Fallback
    mask = true(size(image));
    segmentedImage = image;
end
end