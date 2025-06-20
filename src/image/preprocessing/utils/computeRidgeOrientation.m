function orientation = computeRidgeOrientation(image, blockSize)
% COMPUTERIDGEORIENTATION Obliczanie orientacji linii papilarnych metodą tensora struktury
%
% Funkcja analizuje lokalne kierunki linii papilarnych w obrazie odcisku palca
% wykorzystując tensor struktury (strukture tensor) oparty na gradientach obrazu.
% Metoda zapewnia dokładne wyznaczenie orientacji dla każdego fragmentu obrazu.
%
% Parametry wejściowe:
%   image - obraz w skali szarości (double, wartości 0-1)
%   blockSize - rozmiar bloku analizy w pikselach (typowo 16)
%
% Parametry wyjściowe:
%   orientation - mapa orientacji w radianach (-π/2, π/2)

[rows, cols] = size(image);
orientation = zeros(rows, cols);

% OPERATORY SOBELA: Wyznaczanie gradientów kierunkowych
sobelX = [-1 0 1; -2 0 2; -1 0 1];  % Gradient poziomy
sobelY = [-1 -2 -1; 0 0 0; 1 2 1];  % Gradient pionowy

% OBLICZANIE GRADIENTÓW obrazu
Gx = imfilter(image, sobelX, 'replicate');  % Pochodna cząstkowa ∂I/∂x
Gy = imfilter(image, sobelY, 'replicate');  % Pochodna cząstkowa ∂I/∂y

% ANALIZA BLOKOWA: Przetwarzanie w lokalnych fragmentach
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnienie gradientów dla bieżącego bloku
        blockGx = Gx(r1:r2, c1:c2);
        blockGy = Gy(r1:r2, c1:c2);
        
        % TENSOR STRUKTURY: Komponenty macierzy tensora
        Gxx = sum(blockGx(:).^2);        % ∑(∂I/∂x)²
        Gyy = sum(blockGy(:).^2);        % ∑(∂I/∂y)²
        Gxy = sum(blockGx(:).*blockGy(:)); % ∑(∂I/∂x)(∂I/∂y)
        
        % WYZNACZANIE ORIENTACJI z tensora struktury
        % Orientacja = 1/2 * arctan(2*Gxy / (Gxx - Gyy))
        if (Gxx + Gyy) > 0.01  % Próg na znaczące gradienty
            theta = 0.5 * atan2(2*Gxy, Gxx - Gyy);
        else
            theta = 0;  % Brak orientacji dla obszarów jednorodnych
        end
        
        % Przypisanie orientacji do całego bloku
        orientation(r1:r2, c1:c2) = theta;
    end
end

% WYGŁADZENIE MAPY ORIENTACJI
% Filtr medianowy usuwa artefakty i wygładza przejścia
orientation = medfilt2(orientation, [3 3]);
end