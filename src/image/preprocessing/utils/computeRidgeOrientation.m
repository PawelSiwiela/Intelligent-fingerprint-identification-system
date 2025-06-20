function orientation = computeRidgeOrientation(image, blockSize)
% COMPUTERIDGEORIENTATION Oblicza orientację linii papilarnych metodą tensora struktury
%
% Argumenty:
%   image - obraz w skali szarości
%   blockSize - rozmiar bloku analizy (typowo 16)
%
% Output:
%   orientation - mapa orientacji w radianach

[rows, cols] = size(image);
orientation = zeros(rows, cols);

% Operatory Sobela
sobelX = [-1 0 1; -2 0 2; -1 0 1];
sobelY = [-1 -2 -1; 0 0 0; 1 2 1];

% Oblicz gradienty
Gx = imfilter(image, sobelX, 'replicate');
Gy = imfilter(image, sobelY, 'replicate');

% Analiza blokowa
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        blockGx = Gx(r1:r2, c1:c2);
        blockGy = Gy(r1:r2, c1:c2);
        
        % Tensor struktury
        Gxx = sum(blockGx(:).^2);
        Gyy = sum(blockGy(:).^2);
        Gxy = sum(blockGx(:).*blockGy(:));
        
        % Orientacja
        if (Gxx + Gyy) > 0.01
            theta = 0.5 * atan2(2*Gxy, Gxx - Gyy);
        else
            theta = 0;
        end
        
        orientation(r1:r2, c1:c2) = theta;
    end
end

% Wygładzenie
orientation = medfilt2(orientation, [3 3]);
end