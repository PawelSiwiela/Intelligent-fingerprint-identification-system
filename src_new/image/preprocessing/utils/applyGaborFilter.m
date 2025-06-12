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

% Stałe parametry Gabora
sigma_x = 4;
sigma_y = 4;

for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Granice bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnij parametry
        block = image(r1:r2, c1:c2);
        orient = orientation(i, j);
        freq = frequency(i, j);
        
        % Utwórz i zastosuj filtr Gabora
        try
            gaborKernel = createSimpleGaborKernel(size(block), orient, freq, sigma_x, sigma_y);
            filteredBlock = imfilter(block, gaborKernel, 'replicate');
            gaborFiltered(r1:r2, c1:c2) = filteredBlock;
        catch
            % Fallback - przepisz oryginalny blok
            gaborFiltered(r1:r2, c1:c2) = block;
        end
    end
end
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