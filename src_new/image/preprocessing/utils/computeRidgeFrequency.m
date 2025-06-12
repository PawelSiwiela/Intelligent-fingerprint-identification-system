function frequency = computeRidgeFrequency(image, orientation, blockSize)
% COMPUTERIDGEFREQUENCY Oblicza częstotliwość linii papilarnych metodą projekcji
%
% Argumenty:
%   image - obraz w skali szarości
%   orientation - mapa orientacji linii papilarnych
%   blockSize - rozmiar bloku analizy (typowo 32)
%
% Output:
%   frequency - mapa częstotliwości [cykle/piksel]

[rows, cols] = size(image);
frequency = zeros(rows, cols);

for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznacz granice bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnij blok i orientację
        block = image(r1:r2, c1:c2);
        orient = orientation(i, j);
        
        % Analiza częstotliwości przez FFT projekcji
        try
            % Obrót bloku zgodnie z orientacją
            rotatedBlock = imrotate(block, -orient*180/pi, 'bilinear', 'crop');
            
            % Projekcja na oś Y (prostopadła do linii)
            projection = sum(rotatedBlock, 2);
            projection = projection - mean(projection);
            
            % Znajdź częstotliwość przez FFT
            if length(projection) > 10
                fftProj = abs(fft(projection));
                fftProj = fftProj(2:floor(length(fftProj)/2));
                
                % Rozsądny zakres częstotliwości dla odcisków
                minIdx = max(1, floor(length(projection)/25));  % ~3-4 piksele/cykl
                maxIdx = min(length(fftProj), floor(length(projection)/3));  % ~10-15 pikseli/cykl
                
                if maxIdx > minIdx
                    [~, peakIdx] = max(fftProj(minIdx:maxIdx));
                    freq = (peakIdx + minIdx - 1) / length(projection);
                else
                    freq = 1/10;  % Domyślna częstotliwość
                end
            else
                freq = 1/10;
            end
        catch
            freq = 1/10;  % Fallback
        end
        
        % Przypisz częstotliwość do całego bloku
        frequency(r1:r2, c1:c2) = freq;
    end
end

% Wygładzenie mapy częstotliwości
frequency = medfilt2(frequency, [3 3]);
end