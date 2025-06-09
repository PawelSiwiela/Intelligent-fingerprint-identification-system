% filepath: src/image/preprocessing/computeRidgeFrequency.m
function frequency = computeRidgeFrequency(image, orientation, blockSize)
% COMPUTERIDGEFREQUENCY Oblicza lokalną częstotliwość linii papilarnych

[rows, cols] = size(image);
frequency = zeros(rows, cols);

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
        
        % Obrót bloku do poziomej orientacji linii
        rotatedBlock = imrotate(block, -orient*180/pi, 'bilinear', 'crop');
        
        % Projekcja na oś Y (prostopadła do linii)
        projection = sum(rotatedBlock, 2);
        projection = projection - mean(projection);  % Usuń składową DC
        
        % Analiza FFT aby znaleźć dominującą częstotliwość
        if length(projection) > 10
            fftProj = abs(fft(projection));
            fftProj = fftProj(2:floor(length(fftProj)/2));  % Usuń DC i część ujemną
            
            % Znajdź dominującą częstotliwość w rozsądnym zakresie (3-25 pikseli na grzbiet)
            minFreqIdx = max(1, floor(length(projection)/25));
            maxFreqIdx = min(length(fftProj), floor(length(projection)/3));
            
            if maxFreqIdx > minFreqIdx
                [~, maxIdx] = max(fftProj(minFreqIdx:maxFreqIdx));
                freq = (maxIdx + minFreqIdx - 1) / length(projection);
            else
                freq = 1/10;  % Domyślna częstotliwość
            end
        else
            freq = 1/10;  % Domyślna częstotliwość dla małych bloków
        end
        
        % Przypisz częstotliwość do bloku
        frequency(r1:r2, c1:c2) = freq;
    end
end

% Wygładź mapę częstotliwości
frequency = medfilt2(frequency, [3 3]);
end