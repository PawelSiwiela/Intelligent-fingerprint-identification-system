% filepath: src/image/preprocessing/orientationAwareBinarization.m
function binaryImage = orientationAwareBinarization(image, orientation, mask)
% ORIENTATIONAWAREBINARIZATION Binaryzacja adaptacyjna z uwzględnieniem orientacji

binaryImage = zeros(size(image));
blockSize = 16;
[rows, cols] = size(image);

for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznacz granice bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Sprawdź czy blok jest w masce
        if mean(mask(r1:r2, c1:c2), 'all') < 0.5
            continue;  % Pomiń bloki poza odciskiem
        end
        
        % Wyodrębnij blok
        block = image(r1:r2, c1:c2);
        
        % Oblicz lokalny próg
        localThreshold = graythresh(block);
        
        % Binaryzacja
        binaryBlock = imbinarize(block, localThreshold);
        
        % Przypisz wynik
        binaryImage(r1:r2, c1:c2) = binaryBlock;
    end
end

% Zastosuj maskę
binaryImage = binaryImage & mask;
end