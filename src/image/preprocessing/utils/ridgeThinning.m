function skeletonImage = ridgeThinning(binaryImage)
% RIDGETHINNING Szkieletyzacja linii papilarnych
%
% Argumenty:
%   binaryImage - obraz binarny po binaryzacji
%
% Output:
%   skeletonImage - szkielet linii papilarnych

try
    % Przygotowanie obrazu przed szkieletyzacją
    binaryImage = bwareaopen(binaryImage, 10);  % Usunięcie małych artefaktów
    binaryImage = imclose(binaryImage, strel('disk', 1));  % Zamknięcie małych przerw
    binaryImage = imfill(binaryImage, 'holes');  % Wypełnienie dziur
    
    % KROK 1: PEŁNA SZKIELETYZACJA dla linii 1-pikselowych
    skeletonImage = bwmorph(binaryImage, 'thin', Inf);  % Pełna szkieletyzacja
    
    % KROK 2: Podstawowe czyszczenie szkieletu
    skeletonImage = bwareaopen(skeletonImage, 5);  % Usuń bardzo małe fragmenty
    
    % KROK 3: Sprawdź czy szkielet nie jest pusty lub zbyt rzadki
    coverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    if coverage < 0.1
        % Próbujemy delikatniejszą szkieletyzację
        skeletonImage = bwskel(binaryImage, 'MinBranchLength', 3);
        
        if sum(skeletonImage(:)) / numel(skeletonImage) * 100 < 0.05
            % Ostatnia szansa - szkieletyzacja z limitem iteracji
            skeletonImage = bwmorph(binaryImage, 'thin', 5);
        end
    end
    
catch ME
    % Fallback
    try
        skeletonImage = bwskel(binaryImage);
    catch
        skeletonImage = bwmorph(binaryImage, 'thin', 3);
    end
end

% Końcowe czyszczenie (tylko usunięcie izolowanych punktów)
skeletonImage = bwmorph(skeletonImage, 'clean');
end