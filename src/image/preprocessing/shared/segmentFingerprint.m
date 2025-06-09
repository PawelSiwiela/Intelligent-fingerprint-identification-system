% filepath: src/image/preprocessing/segmentFingerprint.m
function [segmentedImage, mask] = segmentFingerprint(image)
% SEGMENTFINGERPRINT Segmentuje obszar odcisku palca od tła

try
    % Sprawdź czy obraz jest odpowiedniego typu
    if ~isa(image, 'double')
        image = im2double(image);
    end
    
    % Sprawdź rozmiar obrazu
    [rows, cols] = size(image);
    if rows < 32 || cols < 32
        % Dla małych obrazów, użyj prostej maski
        mask = true(size(image));
        segmentedImage = image;
        return;
    end
    
    % NAPRAWKA: Użyj nieparzystego rozmiaru dla stdfilt
    localVar = stdfilt(image, ones(15,15)).^2;  % ✅ 15x15 to nieparzyste!
    
    % Próg dla segmentacji (dostosuj według potrzeb)
    threshold = graythresh(localVar) * 0.3;
    
    % Utwórz maskę
    mask = localVar > threshold;
    
    % Sprawdź czy maska nie jest pusta
    if sum(mask(:)) < 0.05 * numel(mask)
        % Jeśli maska zbyt mała, użyj prostszej metody
        mask = image > graythresh(image) * 0.5;
    end
    
    % Operacje morfologiczne na masce
    if sum(mask(:)) > 100  % Tylko jeśli maska ma wystarczającą wielkość
        mask = imopen(mask, strel('disk', 3));
        mask = imclose(mask, strel('disk', 5));
        mask = imfill(mask, 'holes');
        
        % Wybierz największy połączony komponent
        cc = bwconncomp(mask);
        if cc.NumObjects > 0
            areas = cellfun(@length, cc.PixelIdxList);
            [~, maxIdx] = max(areas);
            newMask = false(size(mask));
            newMask(cc.PixelIdxList{maxIdx}) = true;
            mask = newMask;
        end
    end
    
    % Zastosuj maskę do obrazu
    segmentedImage = image;
    segmentedImage(~mask) = 0;
    
catch segmentError
    % Fallback - zwróć oryginalny obraz z pełną maską
    warning('Błąd segmentacji: %s. Używam pełnej maski.', '%s', segmentError.message);
    mask = true(size(image));
    segmentedImage = image;
end
end