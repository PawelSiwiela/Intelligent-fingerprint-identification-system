function frequency = computeRidgeFrequency(image, orientation, blockSize)
% COMPUTERIDGEFREQUENCY Oblicza częstotliwość linii papilarnych - UPROSZCZONA

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
        
        % Uproszczona analiza częstotliwości
        try
            % Obrót bloku
            rotatedBlock = imrotate(block, -orient*180/pi, 'bilinear', 'crop');
            
            % Projekcja na oś Y
            projection = sum(rotatedBlock, 2);
            projection = projection - mean(projection);
            
            % Znajdź częstotliwość przez FFT (uproszczone)
            if length(projection) > 10
                fftProj = abs(fft(projection));
                fftProj = fftProj(2:floor(length(fftProj)/2));
                
                % Rozsądny zakres częstotliwości
                minIdx = max(1, floor(length(projection)/25));
                maxIdx = min(length(fftProj), floor(length(projection)/3));
                
                if maxIdx > minIdx
                    [~, peakIdx] = max(fftProj(minIdx:maxIdx));
                    freq = (peakIdx + minIdx - 1) / length(projection);
                else
                    freq = 1/10;  % Domyślna
                end
            else
                freq = 1/10;
            end
        catch
            freq = 1/10;  % Fallback
        end
        
        % Przypisz częstotliwość
        frequency(r1:r2, c1:c2) = freq;
    end
end

% Wygładź
frequency = medfilt2(frequency, [3 3]);
end