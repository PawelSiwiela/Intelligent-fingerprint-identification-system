function skeletonImage = ridgeThinning(binaryImage)
% RIDGETHINNING Bardzo delikatna szkieletyzacja linii papilarnych
%
% Argumenty:
%   binaryImage - obraz binarny po binaryzacji
%
% Output:
%   skeletonImage - szkielet linii papilarnych

try
    % KROK 1: Delikatna szkieletyzacja (ograniczone iteracje)
    skeletonImage = bwmorph(binaryImage, 'thin', 2);  % Tylko 2 iteracje
    
    % KROK 2: Sprawdź czy szkielet nie jest pusty
    if sum(skeletonImage(:)) == 0
        % Fallback 1 - jeszcze delikatniejszy
        skeletonImage = bwmorph(binaryImage, 'thin', 1);
        
        if sum(skeletonImage(:)) == 0
            % Fallback 2 - erozja zamiast szkieletyzacji
            se = strel('disk', 1);
            skeletonImage = imerode(binaryImage, se);
            
            if sum(skeletonImage(:)) == 0
                % Fallback 3 - oryginalny obraz
                skeletonImage = binaryImage;
                return;
            end
        end
    end
    
    % KROK 3: Delikatne czyszczenie
    skeletonImage = bwareaopen(skeletonImage, 2);  % Usuń małe komponenty
    
    % Sprawdź pokrycie
    coverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    % Podstawowe czyszczenie tylko przy dobrej jakości
    if coverage > 1
        cleanedImage = bwmorph(skeletonImage, 'clean');
        newCoverage = sum(cleanedImage(:)) / numel(cleanedImage) * 100;
        
        % Cofnij jeśli zbyt destruktywne
        if newCoverage >= coverage * 0.7
            skeletonImage = cleanedImage;
        end
    end
    
    % KROK 4: Opcjonalne połączenia (bridge)
    finalCoverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    if finalCoverage > 5
        testBridge = bwmorph(skeletonImage, 'bridge');
        bridgeCoverage = sum(testBridge(:)) / numel(testBridge) * 100;
        
        if bridgeCoverage <= finalCoverage * 1.2
            skeletonImage = testBridge;
        end
    end
    
    % KROK 5: Końcowe sprawdzenie jakości
    endCoverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    if endCoverage < 0.5
        skeletonImage = ultraGentleSkeleton(binaryImage);
    end
    
catch ME
    % Ultimate fallback
    skeletonImage = ultraGentleSkeleton(binaryImage);
end
end

function gentleSkeletonImage = ultraGentleSkeleton(binaryImage)
% ULTRAGENTLESKELETON Najdelikatniejsza możliwa szkieletyzacja

try
    % Metoda 1: Jedna iteracja thin
    gentleSkeletonImage = bwmorph(binaryImage, 'thin', 1);
    if sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) >= 0.01
        return;
    end
    
    % Metoda 2: Delikatna erozja
    se1 = strel('disk', 1);
    gentleSkeletonImage = imerode(binaryImage, se1);
    if sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) >= 0.005
        return;
    end
    
    % Metoda 3: Tylko czyszczenie
    gentleSkeletonImage = bwmorph(binaryImage, 'clean');
    if sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) >= 0.002
        return;
    end
    
    % Metoda 4: Oryginalny obraz
    gentleSkeletonImage = binaryImage;
    
catch
    gentleSkeletonImage = binaryImage;
end
end