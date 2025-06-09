% filepath: src/image/preprocessing/applyGaborFilter.m
function gaborFiltered = applyGaborFilter(image, orientation, frequency)
% APPLYGABORFILTER Stosuje filtrację Gabora dostosowaną do orientacji i częstotliwości

[rows, cols] = size(image);
gaborFiltered = zeros(rows, cols);
blockSize = 16;

% Parametry filtru Gabora
sigma_x = 4;  % odchylenie standardowe w kierunku x
sigma_y = 4;  % odchylenie standardowe w kierunku y

for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznacz granice bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnij blok
        block = image(r1:r2, c1:c2);
        orient = orientation(i, j);
        freq = frequency(i, j);
        
        % Utwórz filtr Gabora
        gaborKernel = createGaborKernel(size(block), orient, freq, sigma_x, sigma_y);
        
        % Zastosuj filtr
        filteredBlock = imfilter(block, gaborKernel, 'replicate');
        
        % Przypisz wynik
        gaborFiltered(r1:r2, c1:c2) = filteredBlock;
    end
end
end

function kernel = createGaborKernel(blockSize, theta, frequency, sigma_x, sigma_y)
% Tworzy jądro filtru Gabora
[h, w] = deal(blockSize(1), blockSize(2));
[x, y] = meshgrid(1:w, 1:h);

% Przesuń do środka
x = x - (w+1)/2;
y = y - (h+1)/2;

% Obrót współrzędnych
x_rot = x * cos(theta) + y * sin(theta);
y_rot = -x * sin(theta) + y * cos(theta);

% Funkcja Gabora
gaussian = exp(-(x_rot.^2/(2*sigma_x^2) + y_rot.^2/(2*sigma_y^2)));
sinusoid = cos(2*pi*frequency*x_rot);

kernel = gaussian .* sinusoid;

% Normalizacja
kernel = kernel - mean(kernel(:));
if sum(kernel(:).^2) > 0
    kernel = kernel / sqrt(sum(kernel(:).^2));
end
end