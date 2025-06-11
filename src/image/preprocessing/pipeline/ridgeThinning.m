function skeletonImage = ridgeThinning(binaryImage)
% RIDGETHINNING Bardzo delikatna szkieletyzacja linii papilarnych

try
    % KROK 1: JESZCZE BARDZIEJ delikatna szkieletyzacja
    % Zamiast 'thin', inf używamy ograniczonej liczby iteracji
    skeletonImage = bwmorph(binaryImage, 'thin', 2);  % ZMNIEJSZONE z inf na 2!
    
    % KROK 2: Sprawdź czy szkielet nie jest pusty
    if sum(skeletonImage(:)) == 0
        % Fallback 1 - jeszcze delikatniejszy
        skeletonImage = bwmorph(binaryImage, 'thin', 1);  % Tylko 1 iteracja
        
        if sum(skeletonImage(:)) == 0
            % Fallback 2 - użyj erozji zamiast szkieletyzacji
            se = strel('disk', 1);
            skeletonImage = imerode(binaryImage, se);
            
            if sum(skeletonImage(:)) == 0
                % Fallback 3 - zwróć oryginalny obraz binarny
                fprintf('   ⚠️ Szkieletyzacja niemożliwa, używam oryginalny obraz binarny\n');
                skeletonImage = binaryImage;
                return;
            end
        end
    end
    
    % KROK 3: BARDZO delikatne czyszczenie (jeszcze bardziej zmniejszone)
    
    % Usuń tylko najdrobniejsze komponenty (zmniejszone z 5 na 2)
    skeletonImage = bwareaopen(skeletonImage, 2);  % Było 5, teraz 2
    
    % Sprawdź pokrycie przed dalszym przetwarzaniem
    coverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    % Tylko podstawowe czyszczenie jeśli pokrycie > 1%
    if coverage > 1
        % Podstawowe czyszczenie izolowanych pikseli
        skeletonImage = bwmorph(skeletonImage, 'clean');
        
        % Sprawdź pokrycie po czyszczeniu
        newCoverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
        
        % Jeśli czyszczenie zrujnowało wynik, cofnij
        if newCoverage < coverage * 0.7  % Jeśli straciliśmy >30% danych
            fprintf('   ⚠️ Cofam agresywne czyszczenie (strata %.1f%%)\n', (coverage-newCoverage));
            skeletonImage = bwareaopen(binaryImage, 2);  % Przywróć stan przed czyszczeniem
        end
    end
    
    % KROK 4: OPCJONALNE dodatkowe operacje (tylko przy bardzo wysokim pokryciu)
    finalCoverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    if finalCoverage > 5  % Tylko jeśli pokrycie > 5% (zwiększone z 2%)
        % Bardzo delikatne usuwanie odgałęzień (zmniejszone z 1 na 0)
        % skeletonImage = bwmorph(skeletonImage, 'spur', 0);  % WYŁĄCZONE!
        
        % Tylko bridge jeśli naprawdę potrzebne
        testBridge = bwmorph(skeletonImage, 'bridge');
        bridgeCoverage = sum(testBridge(:)) / numel(testBridge) * 100;
        
        if bridgeCoverage <= finalCoverage * 1.2  % Jeśli bridge nie dodał >20% danych
            skeletonImage = testBridge;
        end
    end
    
    % KROK 5: Końcowe sprawdzenie jakości
    endCoverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    if endCoverage < 0.5  % Jeśli pokrycie < 0.5%
        fprintf('   ⚠️ Szkieletyzacja zbyt destruktywna (%.2f%% pokrycia), używam gentle fallback\n', endCoverage);
        skeletonImage = ultraGentleSkeleton(binaryImage);
    elseif endCoverage > 0.5 && endCoverage < 2
        fprintf('   ✅ Delikatna szkieletyzacja (pokrycie: %.2f%%)\n', endCoverage);
    elseif endCoverage >= 2
        fprintf('   ✅ Zachowano dużo danych (pokrycie: %.2f%%)\n', endCoverage);
    end
    
catch ME
    % Ultimate fallback
    fprintf('   ❌ Błąd szkieletyzacji: %s\n', ME.message);
    skeletonImage = ultraGentleSkeleton(binaryImage);
end
end

function gentleSkeletonImage = ultraGentleSkeleton(binaryImage)
% ULTRAGENTLESKELETON Najdelikatniejsza możliwa szkieletyzacja

try
    % Metoda 1: Tylko jedna iteracja thin
    gentleSkeletonImage = bwmorph(binaryImage, 'thin', 1);
    coverage1 = sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) * 100;
    
    if coverage1 >= 1
        fprintf('   ✅ Ultra-gentle: 1-iteracja thin (pokrycie: %.2f%%)\n', coverage1);
        return;
    end
    
    % Metoda 2: Delikatna erozja z disk(1)
    se1 = strel('disk', 1);
    gentleSkeletonImage = imerode(binaryImage, se1);
    coverage2 = sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) * 100;
    
    if coverage2 >= 0.5
        fprintf('   ✅ Ultra-gentle: erozja disk(1) (pokrycie: %.2f%%)\n', coverage2);
        return;
    end
    
    % Metoda 3: Najdelikatniejsza erozja z krzyżykiem
    se_cross = strel('arbitrary', [0 1 0; 1 1 1; 0 1 0]);
    gentleSkeletonImage = imerode(binaryImage, se_cross);
    coverage3 = sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) * 100;
    
    if coverage3 >= 0.3
        fprintf('   ✅ Ultra-gentle: erozja cross (pokrycie: %.2f%%)\n', coverage3);
        return;
    end
    
    % Metoda 4: Oryginalny obraz z tylko podstawowym czyszczeniem
    gentleSkeletonImage = bwmorph(binaryImage, 'clean');
    coverage4 = sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) * 100;
    
    if coverage4 >= 0.2
        fprintf('   ✅ Ultra-gentle: tylko clean (pokrycie: %.2f%%)\n', coverage4);
        return;
    end
    
    % Metoda 5: Oryginalny obraz bez żadnych zmian
    gentleSkeletonImage = binaryImage;
    coverage5 = sum(gentleSkeletonImage(:)) / numel(gentleSkeletonImage) * 100;
    fprintf('   ⚠️ Ultra-gentle: oryginalny obraz binarny (pokrycie: %.2f%%)\n', coverage5);
    
catch
    % Absolutny fallback
    gentleSkeletonImage = binaryImage;
    fprintf('   ❌ Ultra-gentle fallback: oryginalny obraz\n');
end
end