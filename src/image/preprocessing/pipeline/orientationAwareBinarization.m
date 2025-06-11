function binaryImage = orientationAwareBinarization(image, orientation, mask)
% ORIENTATIONAWAREBINARIZATION Binaryzacja z orientacją - UPROSZCZONA

binaryImage = zeros(size(image));
blockSize = 16;
[rows, cols] = size(image);

for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Granice bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Sprawdź maskę
        if mean(mask(r1:r2, c1:c2), 'all') < 0.5
            continue;
        end
        
        % Binaryzacja lokalna (UPROSZCZONA)
        block = image(r1:r2, c1:c2);
        
        try
            % Próg lokalny
            localThreshold = graythresh(block);
            if localThreshold > 0
                binaryBlock = imbinarize(block, localThreshold);
            else
                binaryBlock = block > 0.5;  % Fallback
            end
        catch
            binaryBlock = block > 0.5;  % Fallback
        end
        
        % Przypisz wynik
        binaryImage(r1:r2, c1:c2) = binaryBlock;
    end
end

% Zastosuj maskę
binaryImage = binaryImage & mask;
end