function gaborFiltered = applyGaborFilter(image, orientation, frequency)
% APPLYGABORFILTER Stosuje filtrację Gabora dostosowaną do orientacji i częstotliwości
%
% Argumenty:
%   image - obraz po obliczeniu orientacji
%   orientation - mapa orientacji linii papilarnych
%   frequency - mapa częstotliwości linii papilarnych
%
% Output:
%   gaborFiltered - obraz po filtracji Gabora

[rows, cols] = size(image);
gaborFiltered = zeros(rows, cols);
blockSize = 16;

% Zmodyfikowane parametry Gabora dla lepszej separacji linii
sigma_x = 4.0;
sigma_y = 2.5;  % Zmniejszone dla lepszej separacji między liniami

% Wstępne wzmocnienie kontrastu
enhancedImage = adapthisteq(image, 'ClipLimit', 0.01);

for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Granice bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnij parametry
        block = enhancedImage(r1:r2, c1:c2);  % Używamy wzmocnionego obrazu
        orient = orientation(i, j);
        freq = frequency(i, j);
        
        % Korekta niepoprawnej częstotliwości
        if freq < 0.05 || freq > 0.15
            freq = 0.1;  % Bezpieczna wartość
        end
        
        % Utwórz i zastosuj filtr Gabora
        try
            gaborKernel = createSimpleGaborKernel(size(block), orient, freq, sigma_x, sigma_y);
            filteredBlock = imfilter(block, gaborKernel, 'replicate');
            
            % Nie wzmacniamy kontrastu po filtracji - zostawiamy naturalną strukturę
            
            gaborFiltered(r1:r2, c1:c2) = filteredBlock;
        catch
            % Fallback - przepisz oryginalny blok
            gaborFiltered(r1:r2, c1:c2) = block;
        end
    end
end

% Delikatne wygładzenie zamiast wzmocnienia kontrastu
gaborFiltered = imgaussfilt(gaborFiltered, 0.5);
end

function kernel = createSimpleGaborKernel(blockSize, theta, frequency, sigma_x, sigma_y)
% CREATESIMPLEGABORKERNEL Tworzy jądro filtra Gabora
%
% Argumenty:
%   blockSize - rozmiar bloku [h, w]
%   theta - orientacja w radianach
%   frequency - częstotliwość fali nośnej
%   sigma_x, sigma_y - parametry Gaussowskiej obwiedni

[h, w] = deal(blockSize(1), blockSize(2));
[x, y] = meshgrid(1:w, 1:h);

% Środek układu współrzędnych
x = x - (w+1)/2;
y = y - (h+1)/2;

% Obrót układu współrzędnych
x_rot = x * cos(theta) + y * sin(theta);
y_rot = -x * sin(theta) + y * cos(theta);

% Filtr Gabora = Gaussian * sinusoid
gaussian = exp(-(x_rot.^2/(2*sigma_x^2) + y_rot.^2/(2*sigma_y^2)));
sinusoid = cos(2*pi*frequency*x_rot);
kernel = gaussian .* sinusoid;

% Normalizacja - zero mean
kernel = kernel - mean(kernel(:));
if sum(kernel(:).^2) > 0
    kernel = kernel / sqrt(sum(kernel(:).^2));
end
end