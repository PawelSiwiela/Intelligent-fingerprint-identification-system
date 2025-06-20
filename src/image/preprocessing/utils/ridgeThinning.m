function skeletonImage = ridgeThinning(binaryImage)
% RIDGETHINNING Szkieletyzacja linii papilarnych z zachowaniem struktury
%
% Funkcja przeprowadza zaawansowaną szkieletyzację linii papilarnych
% z automatyczną kontrolą jakości i systemem fallback dla trudnych przypadków.
% Celem jest uzyskanie linii o grubości 1 piksela przy zachowaniu
% topologii i ciągłości struktur.
%
% Parametry wejściowe:
%   binaryImage - obraz binarny po binaryzacji (logical)
%
% Parametry wyjściowe:
%   skeletonImage - szkielet linii papilarnych (logical)

try
    % PREPROCESSING: Przygotowanie obrazu przed szkieletyzacją
    binaryImage = bwareaopen(binaryImage, 10);      % Usunięcie małych artefaktów
    binaryImage = imclose(binaryImage, strel('disk', 1));  % Zamknięcie małych przerw
    binaryImage = imfill(binaryImage, 'holes');      % Wypełnienie dziur w liniach
    
    % KROK 1: PEŁNA SZKIELETYZACJA - algorytm iteracyjny Zhang-Suen
    % Redukuje wszystkie linie do grubości 1 piksela
    skeletonImage = bwmorph(binaryImage, 'thin', Inf);
    
    % KROK 2: PODSTAWOWE CZYSZCZENIE szkieletu
    % Usunięcie bardzo małych, izolowanych fragmentów
    skeletonImage = bwareaopen(skeletonImage, 5);
    
    % KROK 3: KONTROLA JAKOŚCI SZKIELETYZACJI
    % Sprawdzenie czy szkielet nie jest zbyt rzadki (błąd przetwarzania)
    coverage = sum(skeletonImage(:)) / numel(skeletonImage) * 100;
    
    if coverage < 0.1
        % FALLBACK 1: Szkieletyzacja z ograniczeniem długości gałęzi
        % Bardziej konserwatywne podejście
        skeletonImage = bwskel(binaryImage, 'MinBranchLength', 3);
        
        if sum(skeletonImage(:)) / numel(skeletonImage) * 100 < 0.05
            % FALLBACK 2: Szkieletyzacja z limitem iteracji
            % Najłagodniejsze podejście - ograniczona liczba iteracji
            skeletonImage = bwmorph(binaryImage, 'thin', 5);
        end
    end
    
catch ME
    % FALLBACK W PRZYPADKU BŁĘDU: Hierarchia metod zapasowych
    try
        % Próba 1: Standardowa szkieletyzacja MATLAB
        skeletonImage = bwskel(binaryImage);
    catch
        % Próba 2: Podstawowa morfologiczna szkieletyzacja
        skeletonImage = bwmorph(binaryImage, 'thin', 3);
    end
end

% KOŃCOWE CZYSZCZENIE: Usunięcie izolowanych punktów
% Operacja 'clean' usuwa pojedyncze piksele bez sąsiadów
skeletonImage = bwmorph(skeletonImage, 'clean');
end