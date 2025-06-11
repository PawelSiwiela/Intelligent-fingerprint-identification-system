function [segmentedImage, mask] = segmentFingerprint(image)
% SEGMENTFINGERPRINT Segmentuje obszar odcisku - UPROSZCZONA

try
    % Konwersja typu
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
    
    % Analiza lokalnej wariancji (UPROSZCZONA)
    localVar = stdfilt(image, ones(15,15)).^2;
    
    % Próg segmentacji
    threshold = graythresh(localVar) * 0.3;
    mask = localVar > threshold;
    
    % Sprawdź czy maska nie jest za mała
    if sum(mask(:)) < 0.05 * numel(mask)
        % Fallback - prosta binaryzacja
        mask = image > graythresh(image) * 0.5;
    end
    
    % UPROSZCZONE operacje morfologiczne
    if sum(mask(:)) > 100
        % Podstawowe czyszczenie
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
    % Fallback - pełna maska
    mask = true(size(image));
    segmentedImage = image;
end
end