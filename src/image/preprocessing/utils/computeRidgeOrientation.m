function orientation = computeRidgeOrientation(image, blockSize)
% COMPUTERIDGEORIENTATION Oblicza orientację linii papilarnych metodą tensora struktury
%
% Funkcja analizuje lokalną orientację linii papilarnych w odcisku palca
% wykorzystując tensor struktury oparty na gradientach obrazu. Analiza
% jest wykonywana w blokach dla uzyskania lokalnych estymacji orientacji.
%
% Parametry wejściowe:
%   image - obraz w skali szarości (macierz 2D typu double)
%   blockSize - rozmiar bloku analizy w pikselach (typowo 16)
%
% Parametry wyjściowe:
%   orientation - mapa orientacji w radianach (macierz 2D)
%                 wartości w zakresie [-π/2, π/2]
%
% Algorytm:
%   1. Obliczenie gradientów Gx, Gy operatorami Sobela
%   2. Dla każdego bloku: tensor struktury [Gxx, Gxy; Gxy, Gyy]
%   3. Orientacja θ = 0.5 * arctan(2*Gxy / (Gxx - Gyy))
%   4. Wygładzenie wyników filtrem medianowym 3x3
%
% Przykład użycia:
%   orientMap = computeRidgeOrientation(fingerprintImage, 16);

[rows, cols] = size(image);
orientation = zeros(rows, cols);

% Definicja operatorów Sobela dla obliczenia gradientów
sobelX = [-1 0 1; -2 0 2; -1 0 1];  % Gradient w kierunku X
sobelY = [-1 -2 -1; 0 0 0; 1 2 1];  % Gradient w kierunku Y

% Obliczenie gradientów obrazu w obu kierunkach
Gx = imfilter(image, sobelX, 'replicate');
Gy = imfilter(image, sobelY, 'replicate');

% Analiza blokowa - przetwarzanie bloków o rozmiarze blockSize x blockSize
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnienie gradientów dla aktualnego bloku
        blockGx = Gx(r1:r2, c1:c2);
        blockGy = Gy(r1:r2, c1:c2);
        
        % Obliczenie komponentów tensora struktury
        Gxx = sum(blockGx(:).^2);      % Suma kwadratów gradientów X
        Gyy = sum(blockGy(:).^2);      % Suma kwadratów gradientów Y
        Gxy = sum(blockGx(:).*blockGy(:)); % Suma iloczynów gradientów X i Y
        
        % Obliczenie orientacji linii papilarnych
        if (Gxx + Gyy) > 0.01  % Sprawdzenie czy gradients są wystarczająco silne
            % Wzór na orientację z tensora struktury
            theta = 0.5 * atan2(2*Gxy, Gxx - Gyy);
        else
            % Dla obszarów o niskim gradiencie przypisz orientację zerową
            theta = 0;
        end
        
        % Przypisanie obliczonej orientacji do całego bloku
        orientation(r1:r2, c1:c2) = theta;
    end
end

% Wygładzenie mapy orientacji filtrem medianowym
% Redukuje szum zachowując ostre przejścia orientacji
orientation = medfilt2(orientation, [3 3]);
end