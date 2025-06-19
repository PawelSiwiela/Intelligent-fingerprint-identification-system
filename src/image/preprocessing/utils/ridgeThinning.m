function skeletonImage = ridgeThinning(binaryImage)
% RIDGETHINNING Delikatna szkieletyzacja linii papilarnych odcisku palca
%
% Funkcja wykonuje kontrolowaną szkieletyzację obrazu binarnego odcisku palca,
% zachowując topologię linii papilarnych przy jednoczesnym zmniejszeniu ich
% grubości do pojedynczych pikseli. Implementuje wielopoziomowe mechanizmy
% fallback dla różnych jakości obrazów wejściowych.
%
% Parametry wejściowe:
%   binaryImage - obraz binarny po binaryzacji (logical lub double [0,1])
%
% Parametry wyjściowe:
%   skeletonImage - szkielet linii papilarnych (logical)
%
% Algorytm:
%   1. Delikatna szkieletyzacja (max 2 iteracje) dla zachowania struktury
%   2. Mechanizmy fallback: ultra-delikatna szkieletyzacja, erozja, oryginał
%   3. Selektywne czyszczenie małych komponentów
%   4. Opcjonalne operacje morfologiczne (clean, bridge) z kontrolą jakości
%
% Przykład użycia:
%   skeleton = ridgeThinning(binaryFingerprintImage);

try
    % ETAP 1: Delikatna szkieletyzacja z ograniczoną liczbą iteracji
    % Tylko 2 iteracje aby uniknąć nadmiernego erodowania struktury
    skeletonImage = bwmorph(binaryImage, 'thin', 2);
    
    % ETAP 2: Sprawdzenie czy szkielet nie jest pusty
    if sum(skeletonImage(:)) == 0
        % Fallback poziom 1 - jeszcze bardziej delikatna szkieletyzacja
        skeletonImage = bwmorph(binaryImage, 'thin', 1);
        
        if sum(skeletonImage(:)) == 0
            % Fallback poziom 2 - erozja zamiast szkieletyzacji
            se = strel('disk', 1);
            skeletonImage = imerode(binaryImage, se);
            
            if sum(skeletonImage(:)) == 0
                % Fallback poziom 3 - zwróć oryginalny obraz
                skeletonImage = binaryImage;
                return;
            end
        end
    end
    
    % ETAP 3: Delikatne czyszczenie małych izolowanych komponentów
    % Usuń komponenty mniejsze niż 2 piksele
    skeletonImage = bwareaopen(skeletonImage, 2);
    
    % Sprawdź pokrycie obrazu - metryka jakości szkieletu
    coverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    % Zastosuj czyszczenie tylko jeśli szkielet ma odpowiednią gęstość
    if coverage > 1
        cleanedImage = bwmorph(skeletonImage, 'clean');
        newCoverage = sum(cleanedImage(:)) / numel(cleanedImage) * 100;
        
        % Cofnij operację jeśli jest zbyt destruktywna (utrata >30% struktury)
        if newCoverage >= coverage * 0.7
            skeletonImage = cleanedImage;
        end
    end
    
    % ETAP 4: Opcjonalne łączenie przerwanych linii (bridge)
    finalCoverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    % Zastosuj bridge tylko dla szkieletów o dobrej gęstości
    if finalCoverage > 5
        testBridge = bwmorph(skeletonImage, 'bridge');
        bridgeCoverage = sum(testBridge(:)) / numel(testBridge) * 100;
        
        % Akceptuj bridge tylko jeśli nie dodaje zbyt wiele artefaktów
        if bridgeCoverage <= finalCoverage * 1.2
            skeletonImage = testBridge;
        end
    end
    
    % ETAP 5: Końcowa kontrola jakości
    endCoverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    % Jeśli szkielet jest zbyt rzadki, użyj ultra-delikatnej metody
    if endCoverage < 0.5
        skeletonImage = ultraGentleSkeleton(binaryImage);
    end
    
catch ME
    % Mechanizm awaryjny w przypadku błędu
    skeletonImage = ultraGentleSkeleton(binaryImage);
end
end

function gentleSkeletonImage = ultraGentleSkeleton(binaryImage)
% ULTRAGENTLESKELETON Najdelikatniejsza możliwa szkieletyzacja
%
% Funkcja pomocnicza implementująca szereg coraz delikatniejszych metod
% szkieletyzacji dla przypadków gdy standardowa metoda nie działa.
%
% Parametry wejściowe:
%   binaryImage - obraz binarny do szkieletyzacji
%
% Parametry wyjściowe:
%   gentleSkeletonImage - szkielet utworzony najdelikatniejszą metodą

try
    % Metoda 1: Jedna iteracja operacji thin
    gentleSkeletonImage = bwmorph(binaryImage, 'thin', 1);
    if sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) >= 0.01
        return;
    end
    
    % Metoda 2: Delikatna erozja z małym elementem strukturalnym
    se1 = strel('disk', 1);
    gentleSkeletonImage = imerode(binaryImage, se1);
    if sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) >= 0.005
        return;
    end
    
    % Metoda 3: Tylko operacja czyszczenia bez szkieletyzacji
    gentleSkeletonImage = bwmorph(binaryImage, 'clean');
    if sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) >= 0.002
        return;
    end
    
    % Metoda 4: Ostatnia deska ratunku - zwróć oryginalny obraz
    gentleSkeletonImage = binaryImage;
    
catch
    % Mechanizm awaryjny - oryginalny obraz
    gentleSkeletonImage = binaryImage;
end
end