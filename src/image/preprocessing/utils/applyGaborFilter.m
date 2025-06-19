function gaborFiltered = applyGaborFilter(image, orientation, frequency)
% APPLYGABORFILTER Stosuje filtrację Gabora dostosowaną do orientacji i częstotliwości
%
% Funkcja wykonuje filtrację Gabora na obrazie odcisku palca, wykorzystując
% lokalnie estymowane parametry orientacji i częstotliwości linii papilarnych.
% Filtry Gabora są szczególnie skuteczne w wzmacnianiu struktur liniowych
% o znanej orientacji i częstotliwości.
%
% Parametry wejściowe:
%   image - obraz po obliczeniu orientacji (macierz 2D w skali szarości)
%   orientation - mapa orientacji linii papilarnych (macierz 2D w radianach)
%   frequency - mapa częstotliwości linii papilarnych (macierz 2D w cyklach/piksel)
%
% Parametry wyjściowe:
%   gaborFiltered - obraz po filtracji Gabora (macierz 2D)
%
% Algorytm:
%   1. Przetwarzanie blokowe (16x16 pikseli)
%   2. Dla każdego bloku: utworzenie spersonalizowanego jądra Gabora
%   3. Parametry jądra: orientacja i częstotliwość lokalne, σx=σy=4
%   4. Konwolucja bloku z odpowiednim jądrem Gabora
%
% Przykład użycia:
%   filteredImg = applyGaborFilter(image, orientMap, freqMap);

[rows, cols] = size(image);
gaborFiltered = zeros(rows, cols);
blockSize = 16;  % Rozmiar bloku dla lokalnej filtracji

% Stałe parametry obwiedni Gaussowskiej filtra Gabora
sigma_x = 4;  % Szerokość obwiedni w kierunku X
sigma_y = 4;  % Szerokość obwiedni w kierunku Y

% Przetwarzanie blokowe - każdy blok ma własny filtr Gabora
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnienie bloku obrazu oraz lokalnych parametrów
        block = image(r1:r2, c1:c2);
        orient = orientation(i, j);    % Lokalna orientacja linii
        freq = frequency(i, j);        % Lokalna częstotliwość linii
        
        % Utworzenie i zastosowanie filtra Gabora dla aktualnego bloku
        try
            % Generowanie jądra Gabora dostosowanego do lokalnych parametrów
            gaborKernel = createSimpleGaborKernel(size(block), orient, freq, sigma_x, sigma_y);
            
            % Konwolucja bloku z jądrem Gabora
            filteredBlock = imfilter(block, gaborKernel, 'replicate');
            gaborFiltered(r1:r2, c1:c2) = filteredBlock;
        catch
            % Mechanizm awaryjny - przepisz oryginalny blok bez filtracji
            gaborFiltered(r1:r2, c1:c2) = block;
        end
    end
end
end

function kernel = createSimpleGaborKernel(blockSize, theta, frequency, sigma_x, sigma_y)
% CREATESIMPLEGABORKERNEL Tworzy jądro filtra Gabora o zadanych parametrach
%
% Funkcja pomocnicza generująca 2D jądro filtra Gabora jako iloczyn
% obwiedni Gaussowskiej i fali sinusoidalnej o określonej orientacji
% i częstotliwości.
%
% Parametry wejściowe:
%   blockSize - rozmiar jądra [wysokość, szerokość] w pikselach
%   theta - orientacja fali sinusoidalnej w radianach
%   frequency - częstotliwość fali nośnej w cyklach/piksel
%   sigma_x, sigma_y - parametry obwiedni Gaussowskiej (szerokość)
%
% Parametry wyjściowe:
%   kernel - znormalizowane jądro filtra Gabora (macierz 2D)

[h, w] = deal(blockSize(1), blockSize(2));
[x, y] = meshgrid(1:w, 1:h);

% Przesunięcie układu współrzędnych do środka jądra
x = x - (w+1)/2;
y = y - (h+1)/2;

% Obrót układu współrzędnych zgodnie z orientacją linii papilarnych
x_rot = x * cos(theta) + y * sin(theta);
y_rot = -x * sin(theta) + y * cos(theta);

% Utworzenie filtra Gabora jako iloczyn dwóch składników:
% 1. Obwiednia Gaussowska - zapewnia lokalizację przestrzenną
gaussian = exp(-(x_rot.^2/(2*sigma_x^2) + y_rot.^2/(2*sigma_y^2)));

% 2. Fala sinusoidalna - selektuje określoną częstotliwość
sinusoid = cos(2*pi*frequency*x_rot);

% Końcowe jądro Gabora
kernel = gaussian .* sinusoid;

% Normalizacja jądra - zero mean i jednostkowa energia
kernel = kernel - mean(kernel(:));  % Usunięcie składowej stałej
if sum(kernel(:).^2) > 0
    kernel = kernel / sqrt(sum(kernel(:).^2));  % Normalizacja energii
end
end