function [segmentedImage, mask] = segmentFingerprint(image)
% SEGMENTFINGERPRINT Segmentuje obszar odcisku palca od tła
%
% Funkcja automatycznie wykrywa i oddziela obszar rzeczywistego odcisku palca
% od tła obrazu wykorzystując analizę lokalnej wariancji i operacje morfologiczne.
%
% Parametry wejściowe:
%   image - obraz po filtracji Gabora (double, skala szarości)
%
% Parametry wyjściowe:
%   segmentedImage - obraz z wyzerowanym tłem (tylko obszar odcisku)
%   mask - maska binarna obszaru odcisku (logical)

try
    % Konwersja do formatu double jeśli potrzeba
    if ~isa(image, 'double')
        image = im2double(image);
    end
    
    [rows, cols] = size(image);
    
    % Dla małych obrazów - zwróć pełną maskę (brak segmentacji)
    if rows < 32 || cols < 32
        mask = true(size(image));
        segmentedImage = image;
        return;
    end
    
    % GŁÓWNA SEGMENTACJA: Analiza lokalnej wariancji
    % Obszary odcisku mają wysoką wariancję (struktury linii papilarnych)
    % Tło ma niską wariancję (jednorodne obszary)
    localVar = stdfilt(image, ones(15,15)).^2;
    threshold = graythresh(localVar) * 0.3;  % Konserwatywny próg
    mask = localVar > threshold;
    
    % FALLBACK: Jeśli segmentacja wariancją nie powiodła się
    if sum(mask(:)) < 0.05 * numel(mask)
        mask = image > graythresh(image) * 0.5;
    end
    
    % OPERACJE MORFOLOGICZNE: Wygładzenie i czyszczenie maski
    if sum(mask(:)) > 100
        % Usunięcie małych artefaktów (opening)
        mask = imopen(mask, strel('disk', 2));
        % Zamknięcie małych dziur (closing)
        mask = imclose(mask, strel('disk', 3));
        % Wypełnienie pozostałych dziur
        mask = imfill(mask, 'holes');
        
        % WYBÓR NAJWIĘKSZEGO KOMPONENTU: Jeden spójny obszar odcisku
        cc = bwconncomp(mask);
        if cc.NumObjects > 1
            areas = cellfun(@length, cc.PixelIdxList);
            [~, maxIdx] = max(areas);
            newMask = false(size(mask));
            newMask(cc.PixelIdxList{maxIdx}) = true;
            mask = newMask;
        end
    end
    
    % ZASTOSOWANIE MASKI: Wyzerowanie tła
    segmentedImage = image;
    segmentedImage(~mask) = 0;
    
catch
    % FALLBACK W PRZYPADKU BŁĘDU: Pełna maska
    mask = true(size(image));
    segmentedImage = image;
end
end