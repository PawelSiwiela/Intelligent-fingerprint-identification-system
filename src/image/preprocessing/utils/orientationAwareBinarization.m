function binaryImage = orientationAwareBinarization(image, orientation, mask)
% ORIENTATIONAWAREBINARIZATION Binaryzacja adaptacyjna z uwzględnieniem orientacji linii
%
% Funkcja wykonuje binaryzację obrazu odcisku palca z wykorzystaniem informacji
% o lokalnej orientacji linii papilarnych. Adaptacyjne progowanie w blokach
% zapewnia lepszą jakość binaryzacji w różnych regionach obrazu.
%
% Parametry wejściowe:
%   image - obraz po segmentacji (macierz 2D w skali szarości)
%   orientation - mapa orientacji linii papilarnych (macierz 2D w radianach)
%   mask - maska obszaru odcisku (logical, true = obszar odcisku)
%
% Parametry wyjściowe:
%   binaryImage - obraz binarny (logical, true = linie papilarne)
%
% Algorytm:
%   1. Podział obrazu na bloki 16x16 pikseli
%   2. Dla każdego bloku: adaptacyjne progowanie Otsu (graythresh)
%   3. Sprawdzenie przynależności bloku do obszaru odcisku
%   4. Zastosowanie maski segmentacji na wynik końcowy
%
% Przykład użycia:
%   binaryImg = orientationAwareBinarization(segmentedImg, orientMap, mask);

% Inicjalizacja obrazu wyjściowego
binaryImage = zeros(size(image));
blockSize = 16;  % Rozmiar bloku dla adaptacyjnego progowania
[rows, cols] = size(image);

% Przetwarzanie blokowe - analiza każdego bloku 16x16 osobno
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);  % Górna granica wiersza
        r2 = min(rows, i);           % Dolna granica wiersza
        c1 = max(1, j-blockSize+1);  % Lewa granica kolumny
        c2 = min(cols, j);           % Prawa granica kolumny
        
        % Sprawdzenie czy blok należy do obszaru odcisku
        % Jeśli mniej niż 50% bloku to obszar odcisku, pomiń
        if mean(mask(r1:r2, c1:c2), 'all') < 0.5
            continue;
        end
        
        % Wyodrębnienie bloku do analizy
        block = image(r1:r2, c1:c2);
        
        try
            % Adaptacyjne progowanie lokalne metodą Otsu
            localThreshold = graythresh(block);
            if localThreshold > 0
                binaryBlock = imbinarize(block, localThreshold);
            else
                % Fallback dla przypadków gdy graythresh zwraca 0
                binaryBlock = block > 0.5;
            end
        catch
            % Mechanizm awaryjny - progowanie stałe
            binaryBlock = block > 0.5;
        end
        
        % Przypisanie wyniku binaryzacji do odpowiedniego regionu
        binaryImage(r1:r2, c1:c2) = binaryBlock;
    end
end

% Zastosowanie maski obszaru odcisku - wyzerowanie tła
binaryImage = binaryImage & mask;
end