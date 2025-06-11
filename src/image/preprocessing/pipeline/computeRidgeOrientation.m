function orientation = computeRidgeOrientation(image, blockSize)
% COMPUTERIDGEORIENTATION Oblicza orientację linii papilarnych - UPROSZCZONA

[rows, cols] = size(image);
orientation = zeros(rows, cols);

% Operatory gradientu Sobela
sobelX = [-1 0 1; -2 0 2; -1 0 1];
sobelY = [-1 -2 -1; 0 0 0; 1 2 1];

% Oblicz gradienty
Gx = imfilter(image, sobelX, 'replicate');
Gy = imfilter(image, sobelY, 'replicate');

% Przetwarzanie blokowe
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznacz granice bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnij blok
        blockGx = Gx(r1:r2, c1:c2);
        blockGy = Gy(r1:r2, c1:c2);
        
        % Oblicz składowe tensora struktury
        Gxx = sum(blockGx(:).^2);
        Gyy = sum(blockGy(:).^2);
        Gxy = sum(blockGx(:).*blockGy(:));
        
        % Oblicz orientację (uproszczone)
        if (Gxx + Gyy) > 0.01
            theta = 0.5 * atan2(2*Gxy, Gxx - Gyy);
        else
            theta = 0;
        end
        
        % Przypisz orientację do całego bloku
        orientation(r1:r2, c1:c2) = theta;
    end
end

% Podstawowe wygładzenie
orientation = medfilt2(orientation, [3 3]);
end