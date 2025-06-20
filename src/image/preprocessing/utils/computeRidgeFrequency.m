function frequency = computeRidgeFrequency(image, orientation, blockSize)
% COMPUTERIDGEFREQUENCY Obliczanie częstotliwości linii papilarnych metodą FFT projekcji
%
% Funkcja wyznacza lokalną częstotliwość (gęstość) linii papilarnych w obrazie
% odcisku palca. Wykorzystuje analizę FFT projekcji obrazu w kierunku prostopadłym
% do orientacji linii. Typowa częstotliwość linii papilarnych wynosi 3-15 pikseli/cykl.
%
% Parametry wejściowe:
%   image - obraz w skali szarości (double, wartości 0-1)
%   orientation - mapa orientacji linii papilarnych w radianach
%   blockSize - rozmiar bloku analizy w pikselach (typowo 32)
%
% Parametry wyjściowe:
%   frequency - mapa częstotliwości w cyklach/piksel

[rows, cols] = size(image);
frequency = zeros(rows, cols);

% PRZETWARZANIE BLOKOWE: Analiza częstotliwości w lokalnych fragmentach
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnienie bloku i jego orientacji
        block = image(r1:r2, c1:c2);
        orient = orientation(i, j);  % Orientacja dla środka bloku
        
        % ANALIZA CZĘSTOTLIWOŚCI przez projekcję FFT
        try
            % KROK 1: OBRÓT BLOKU zgodnie z orientacją linii
            % Linie stają się poziome po obrocie
            rotatedBlock = imrotate(block, -orient*180/pi, 'bilinear', 'crop');
            
            % KROK 2: PROJEKCJA na oś pionową (prostopadła do linii)
            % Sumowanie w kierunku poziomym daje profil intensywności
            projection = sum(rotatedBlock, 2);
            projection = projection - mean(projection);  % Usunięcie składowej stałej
            
            % KROK 3: ANALIZA FFT dla znajdowania dominującej częstotliwości
            if length(projection) > 10
                fftProj = abs(fft(projection));
                fftProj = fftProj(2:floor(length(fftProj)/2));  % Tylko częstotliwości dodatnie
                
                % OGRANICZENIE DO REALISTYCZNEGO ZAKRESU częstotliwości odcisków
                minIdx = max(1, floor(length(projection)/25));      % ~3-4 piksele/cykl (gęste linie)
                maxIdx = min(length(fftProj), floor(length(projection)/3)); % ~10-15 pikseli/cykl (rzadkie linie)
                
                if maxIdx > minIdx
                    % Znajdź pik w spektrum FFT
                    [~, peakIdx] = max(fftProj(minIdx:maxIdx));
                    freq = (peakIdx + minIdx - 1) / length(projection);
                else
                    freq = 1/10;  % Domyślna częstotliwość (10 pikseli/cykl)
                end
            else
                freq = 1/10;  % Fallback dla zbyt małych bloków
            end
        catch
            freq = 1/10;  % Fallback w przypadku błędu
        end
        
        % Przypisanie częstotliwości do całego bloku
        frequency(r1:r2, c1:c2) = freq;
    end
end

% WYGŁADZENIE MAPY CZĘSTOTLIWOŚCI
% Filtr medianowy usuwa skokowe zmiany i wygładza przejścia
frequency = medfilt2(frequency, [3 3]);
end