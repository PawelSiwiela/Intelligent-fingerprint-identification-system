% filepath: src/image/preprocessing/computeRidgeOrientation.m
function orientation = computeRidgeOrientation(image, blockSize)
% COMPUTERIDGEORIENTATION Oblicza orientację linii papilarnych
%   orientation = COMPUTERIDGEORIENTATION(image, blockSize) oblicza lokalną
%   orientację linii papilarnych w każdym bloku obrazu.

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
        
        % Oblicz orientację (kąt główny)
        if (Gxx + Gyy) > 0.01  % Sprawdź czy jest wystarczająca struktura
            theta = 0.5 * atan2(2*Gxy, Gxx - Gyy);
        else
            theta = 0;  % Brak wyraźnej orientacji
        end
        
        % Przypisz orientację do całego bloku
        orientation(r1:r2, c1:c2) = theta;
    end
end

% Wygładź orientację
orientation = smoothOrientation(orientation, 3);
end

function smoothedOrientation = smoothOrientation(orientation, windowSize)
% Wygładza pole orientacji używając filtru medianowego w przestrzeni kątowej
% Konwertuj na reprezentację zespoloną
complexOrient = exp(2i * orientation);

% Zastosuj filtr medianowy
realPart = medfilt2(real(complexOrient), [windowSize windowSize]);
imagPart = medfilt2(imag(complexOrient), [windowSize windowSize]);

% Konwertuj z powrotem na kąty
smoothedOrientation = 0.5 * angle(complex(realPart, imagPart));
end