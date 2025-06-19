function [segmentedImage, mask] = segmentFingerprint(image)
% SEGMENTFINGERPRINT Wydziela obszar odcisku palca od tła obrazu
%
% Funkcja segmentuje obraz odcisku palca, oddzielając obszar zawierający
% linie papilarne od tła. Wykorzystuje analizę lokalnej wariancji oraz
% operacje morfologiczne do utworzenia precyzyjnej maski segmentacji.
%
% Parametry wejściowe:
%   image - obraz po filtracji Gabora (macierz 2D, skala szarości)
%
% Parametry wyjściowe:
%   segmentedImage - obraz z wyzerowanym tłem (obszar poza odciskiem = 0)
%   mask - maska logiczna obszaru odcisku (true = odcisk, false = tło)
%
% Algorytm:
%   1. Analiza lokalnej wariancji w oknach 15x15 pikseli
%   2. Progowanie adaptacyjne oparte na graythresh
%   3. Operacje morfologiczne: opening, closing, wypełnianie dziur
%   4. Wybór największego komponentu spójnego
%
% Przykład użycia:
%   [segmentedImg, mask] = segmentFingerprint(gaborFilteredImage);

try
    % Konwersja do typu double jeśli potrzebna
    if ~isa(image, 'double')
        image = im2double(image);
    end
    
    [rows, cols] = size(image);
    
    % Obsługa małych obrazów - przyjmij pełną maskę
    if rows < 32 || cols < 32
        mask = true(size(image));
        segmentedImage = image;
        return;
    end
    
    % Segmentacja oparta na lokalnej wariancji tekstury
    % Użyj standardowego odchylenia w oknie 15x15 jako miary tekstury
    localVar = stdfilt(image, ones(15,15)).^2;
    threshold = graythresh(localVar) * 0.3;  % Zredukowany próg dla lepszej detekcji
    mask = localVar > threshold;
    
    % Mechanizm fallback jeśli segmentacja nie udała się
    if sum(mask(:)) < 0.05 * numel(mask)
        mask = image > graythresh(image) * 0.5;
    end
    
    % Operacje morfologiczne dla wygładzenia i oczyszczenia maski
    if sum(mask(:)) > 100
        % Opening - usuwa małe obiekty i wygładza kontury
        mask = imopen(mask, strel('disk', 2));
        % Closing - wypełnia małe dziury i łączy blisko siebie obiekty
        mask = imclose(mask, strel('disk', 3));
        % Wypełnianie dziur wewnątrz obiektów
        mask = imfill(mask, 'holes');
        
        % Wybierz największy komponent spójny (główny obszar odcisku)
        cc = bwconncomp(mask);
        if cc.NumObjects > 1
            areas = cellfun(@length, cc.PixelIdxList);
            [~, maxIdx] = max(areas);
            newMask = false(size(mask));
            newMask(cc.PixelIdxList{maxIdx}) = true;
            mask = newMask;
        end
    end
    
    % Zastosuj maskę - wyzeruj piksele poza obszarem odcisku
    segmentedImage = image;
    segmentedImage(~mask) = 0;
    
catch
    % Mechanizm awaryjny - zwróć pełną maskę i oryginalny obraz
    mask = true(size(image));
    segmentedImage = image;
end
end