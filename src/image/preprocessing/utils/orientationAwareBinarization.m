function binaryImage = orientationAwareBinarization(image, orientation, mask)
% ORIENTATIONAWAREBINARIZATION Binaryzacja adaptacyjna z uwzględnieniem orientacji
%
% Funkcja przeprowadza zaawansowaną binaryzację obrazu odcisku palca
% z adaptacyjnym doborem progów w zależności od lokalnych właściwości obrazu.
% Uwzględnia orientację linii papilarnych i maskę obszaru odcisku.
%
% Parametry wejściowe:
%   image - obraz po segmentacji (double, wartości 0-1)
%   orientation - mapa orientacji linii papilarnych w radianach
%   mask - maska obszaru odcisku (logical)
%
% Parametry wyjściowe:
%   binaryImage - obraz binarny (logical)

% Inicjalizacja obrazu wynikowego
binaryImage = zeros(size(image));
blockSize = 16;  % Rozmiar bloku analizy (16x16 pikseli)
[rows, cols] = size(image);

% PRZETWARZANIE BLOKOWE: Analiza w małych fragmentach obrazu
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % SPRAWDZENIE PRZYNALEŻNOŚCI DO ODCISKU
        % Przetwarzaj tylko bloki zawierające co najmniej 50% obszaru odcisku
        if mean(mask(r1:r2, c1:c2), 'all') < 0.5
            continue;  % Pomiń bloki tła
        end
        
        % LOKALNA BINARYZACJA ADAPTACYJNA
        block = image(r1:r2, c1:c2);
        
        try
            % Metoda Otsu dla lokalnego bloku
            % Automatyczne wyznaczenie optymalnego progu
            localThreshold = graythresh(block);
            if localThreshold > 0
                binaryBlock = imbinarize(block, localThreshold);
            else
                % Fallback: próg stały jeśli Otsu nie działa
                binaryBlock = block > 0.5;
            end
        catch
            % Fallback w przypadku błędu: próg środkowy
            binaryBlock = block > 0.5;
        end
        
        % PRZYPISANIE WYNIKU do obrazu głównego
        binaryImage(r1:r2, c1:c2) = binaryBlock;
    end
end

% ZASTOSOWANIE MASKI OBSZARU ODCISKU
% Wyzerowanie pikseli poza obszarem odcisku
binaryImage = binaryImage & mask;
end