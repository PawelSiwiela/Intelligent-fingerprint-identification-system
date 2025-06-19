function frequency = computeRidgeFrequency(image, orientation, blockSize)
% COMPUTERIDGEFREQUENCY Oblicza częstotliwość linii papilarnych metodą projekcji
%
% Funkcja analizuje lokalną częstotliwość (gęstość) linii papilarnych w odcisku
% palca poprzez analizę spektralną projekcji obrazu w kierunku prostopadłym
% do orientacji linii. Wykorzystuje transformację Fouriera do detekcji
% dominującej częstotliwości przestrzennej.
%
% Parametry wejściowe:
%   image - obraz w skali szarości (macierz 2D typu double)
%   orientation - mapa orientacji linii papilarnych (macierz 2D w radianach)
%   blockSize - rozmiar bloku analizy w pikselach (typowo 32)
%
% Parametry wyjściowe:
%   frequency - mapa częstotliwości w cyklach/piksel (macierz 2D)
%               typowe wartości: 0.05-0.25 cykli/piksel
%
% Algorytm:
%   1. Dla każdego bloku: obrót zgodny z lokalną orientacją
%   2. Projekcja na oś Y (prostopadła do linii papilarnych)
%   3. Analiza FFT projekcji w rozsądnym zakresie częstotliwości
%   4. Wybór częstotliwości z maksymalną amplitudą
%   5. Wygładzenie mapy częstotliwości filtrem medianowym
%
% Przykład użycia:
%   freqMap = computeRidgeFrequency(image, orientMap, 32);

[rows, cols] = size(image);
frequency = zeros(rows, cols);

% Przetwarzanie blokowe - analiza każdego bloku osobno
for i = blockSize:blockSize:rows-blockSize+1
    for j = blockSize:blockSize:cols-blockSize+1
        % Wyznaczenie granic aktualnego bloku
        r1 = max(1, i-blockSize+1);
        r2 = min(rows, i);
        c1 = max(1, j-blockSize+1);
        c2 = min(cols, j);
        
        % Wyodrębnienie bloku obrazu i odpowiadającej mu orientacji
        block = image(r1:r2, c1:c2);
        orient = orientation(i, j);
        
        % Analiza częstotliwości poprzez FFT projekcji
        try
            % Obrót bloku zgodnie z orientacją linii papilarnych
            % Linie stają się poziome, co ułatwia analizę częstotliwości
            rotatedBlock = imrotate(block, -orient*180/pi, 'bilinear', 'crop');
            
            % Projekcja na oś Y (sumowanie w kierunku poziomym)
            % Otrzymujemy 1D sygnał reprezentujący zmiany intensywności
            % w kierunku prostopadłym do linii papilarnych
            projection = sum(rotatedBlock, 2);
            projection = projection - mean(projection);  % Usunięcie składowej stałej
            
            % Analiza spektralna dla znalezienia dominującej częstotliwości
            if length(projection) > 10
                fftProj = abs(fft(projection));
                fftProj = fftProj(2:floor(length(fftProj)/2));  % Tylko dodatnie częstotliwości
                
                % Rozsądny zakres częstotliwości dla odcisków palców
                % Minimalna częstotliwość: ~3-4 piksele na cykl linii papilarnej
                minIdx = max(1, floor(length(projection)/25));
                % Maksymalna częstotliwość: ~10-15 pikseli na cykl
                maxIdx = min(length(fftProj), floor(length(projection)/3));
                
                % Znajdź szczyt w widmie FFT w rozsądnym zakresie
                if maxIdx > minIdx
                    [~, peakIdx] = max(fftProj(minIdx:maxIdx));
                    freq = (peakIdx + minIdx - 1) / length(projection);
                else
                    freq = 1/10;  % Domyślna częstotliwość (10 pikseli/cykl)
                end
            else
                freq = 1/10;  % Fallback dla zbyt małych bloków
            end
        catch
            % Mechanizm awaryjny w przypadku błędu
            freq = 1/10;  % Domyślna częstotliwość
        end
        
        % Przypisanie obliczonej częstotliwości do całego bloku
        frequency(r1:r2, c1:c2) = freq;
    end
end

% Wygładzenie mapy częstotliwości filtrem medianowym
% Redukuje szum zachowując lokalne zmiany częstotliwości
frequency = medfilt2(frequency, [3 3]);
end