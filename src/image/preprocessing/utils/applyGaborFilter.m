function gaborFiltered = applyGaborFilter(image, orientation, frequency)
% APPLYGABORFILTER Adaptacyjna filtracja Gabora dla wzmocnienia linii papilarnych
%
% Funkcja stosuje bank filtrów Gabora dostosowanych lokalnie do orientacji
% i częstotliwości linii papilarnych. Filtry Gabora są idealne do analizy
% struktur o znanej orientacji i częstotliwości, skutecznie wzmacniając
% linie papilarne i tłumiąc szum.
%
% Parametry wejściowe:
%   image - obraz po obliczeniu orientacji (double, wartości 0-1)
%   orientation - mapa orientacji linii papilarnych w radianach
%   frequency - mapa częstotliwości linii papilarnych w cyklach/piksel
%
% Parametry wyjściowe:
%   gaborFiltered - obraz po filtracji Gabora (double)

[rows, cols] = size(image);
gaborFiltered = zeros(rows, cols);
blockSize = 16;  % Rozmiar bloku przetwarzania

% PARAMETRY FILTRA GABORA - zoptymalizowane dla odcisków palców
sigma_x = 4.0;   % Rozciągnięcie wzdłuż kierunku linii (większa wartość = łagodniejszy filtr)
sigma_y = 2.5;   % Rozciągnięcie w poprzek linii (mniejsza wartość = lepsza separacja)

% PREPROCESSING: Wzmocnienie kontrastu dla lepszej filtracji
enhancedImage = adapthisteq(image, 'ClipLimit', 0.01);

% PRZETWARZANIE BLOKOWE: Adaptacyjna filtracja każdego fragmentu
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnienie danych dla bieżącego bloku
        block = enhancedImage(r1:r2, c1:c2);  % Blok obrazu
        orient = orientation(i, j);           % Lokalna orientacja
        freq = frequency(i, j);               % Lokalna częstotliwość
        
        % KOREKJA NIEPOPRAWNEJ CZĘSTOTLIWOŚCI
        % Ograniczenie do realistycznego zakresu dla odcisków palców
        if freq < 0.05 || freq > 0.15
            freq = 0.1;  % Bezpieczna wartość domyślna (10 pikseli/cykl)
        end
        
        % TWORZENIE I ZASTOSOWANIE FILTRU GABORA
        try
            % Utworzenie jądra Gabora dostosowanego do lokalnych parametrów
            gaborKernel = createSimpleGaborKernel(size(block), orient, freq, sigma_x, sigma_y);
            
            % Filtracja bloku
            filteredBlock = imfilter(block, gaborKernel, 'replicate');
            
            % Przypisanie wyniku (bez dodatkowego wzmocnienia kontrastu)
            gaborFiltered(r1:r2, c1:c2) = filteredBlock;
        catch
            % Fallback: przepisanie oryginalnego bloku w przypadku błędu
            gaborFiltered(r1:r2, c1:c2) = block;
        end
    end
end

% POSTPROCESSING: Delikatne wygładzenie wyników filtracji
gaborFiltered = imgaussfilt(gaborFiltered, 0.5);
end

function kernel = createSimpleGaborKernel(blockSize, theta, frequency, sigma_x, sigma_y)
% CREATESIMPLEGABORKERNEL Tworzenie jądra filtra Gabora
%
% Funkcja tworzy 2D jądro filtra Gabora - iloczyn funkcji Gaussa
% i sinusoidy. Filtr jest dostosowany do zadanej orientacji i częstotliwości.
%
% Parametry wejściowe:
%   blockSize - rozmiar jądra [wysokość, szerokość]
%   theta - orientacja filtra w radianach
%   frequency - częstotliwość fali nośnej w cyklach/piksel
%   sigma_x, sigma_y - parametry rozciągnięcia obwiedni Gaussa
%
% Parametry wyjściowe:
%   kernel - jądro filtra Gabora (znormalizowane)

[h, w] = deal(blockSize(1), blockSize(2));
[x, y] = meshgrid(1:w, 1:h);

% CENTROWANIE układu współrzędnych
x = x - (w+1)/2;
y = y - (h+1)/2;

% OBRÓT układu współrzędnych zgodnie z orientacją filtra
x_rot = x * cos(theta) + y * sin(theta);
y_rot = -x * sin(theta) + y * cos(theta);

% KONSTRUKCJA FILTRU GABORA = Gaussowska obwiednia × sinusoida
gaussian = exp(-(x_rot.^2/(2*sigma_x^2) + y_rot.^2/(2*sigma_y^2)));
sinusoid = cos(2*pi*frequency*x_rot);
kernel = gaussian .* sinusoid;

% NORMALIZACJA jądra
kernel = kernel - mean(kernel(:));  % Średnia = 0 (filtr pasmowy)
if sum(kernel(:).^2) > 0
    kernel = kernel / sqrt(sum(kernel(:).^2));  % Normalizacja energii
end
end