function visualizeNetworkStructure(net, title_text, save_path)
% VISUALIZENETWORKSTRUCTURE Wizualizuje strukturę sieci neuronowej
%
% Składnia:
%   visualizeNetworkStructure(net, title_text, save_path)
%
% Argumenty:
%   net - sieć neuronowa
%   title_text - opcjonalny tytuł wykresu
%   save_path - opcjonalna ścieżka do zapisania wykresu

% Domyślny tytuł
if nargin < 2
    title_text = 'Struktura sieci neuronowej';
end

% Domyślna ścieżka zapisu
if nargin < 3
    save_path = '';
end

try
    % Utworzenie nowej figury
    h = figure('Name', title_text, 'Position', [200, 200, 800, 600]);
    
    % Pobranie informacji o warstwach sieci
    input_size = net.inputs{1}.size;
    output_size = net.outputs{end}.size;
    
    % Określenie liczby i rozmiaru warstw ukrytych
    hidden_layers = {};
    activation_functions = {};
    
    % Sprawdzenie typu sieci (patternnet lub feedforwardnet)
    if isa(net, 'network')
        % Dla standardowych sieci z Neural Network Toolbox
        for i = 1:length(net.layers)-1
            hidden_layers{i} = net.layers{i}.size;
            activation_functions{i} = net.layers{i}.transferFcn;
        end
        % Funkcja aktywacji warstwy wyjściowej
        output_activation = net.layers{end}.transferFcn;
    else
        % Fallback dla innych typów sieci
        hidden_layers = {16}; % Domyślnie jedna warstwa ukryta z 16 neuronami
        activation_functions = {'unknown'};
        output_activation = 'unknown';
    end
    
    % Przygotuj dane do wizualizacji
    num_layers = 2 + length(hidden_layers); % wejściowa + ukryte + wyjściowa
    layer_sizes = [input_size, cell2mat(hidden_layers), output_size];
    
    % Rysowanie warstw i neuronów
    cla; % Wyczyść osie
    hold on;
    
    % Definicja kolorów
    input_color = [0.2, 0.7, 1.0];   % Niebieski
    hidden_color = [0.8, 0.5, 0.9];  % Fioletowy
    output_color = [1.0, 0.5, 0.5];  % Czerwony
    
    % Margines na górze i dole
    total_height = 8;
    
    % Szerokość wykresu
    total_width = num_layers * 2;
    
    % Pozycje warstw na osi X
    x_positions = linspace(1, total_width-1, num_layers);
    
    % Przechowaj pozycje neuronów dla połączeń
    all_y_positions = cell(1, num_layers);
    
    % Rysuj każdą warstwę
    for i = 1:num_layers
        % Wybierz kolor i nazwę warstwy
        if i == 1
            layer_color = input_color;
            layer_name = 'Warstwa wejściowa';
        elseif i == num_layers
            layer_color = output_color;
            layer_name = 'Warstwa wyjściowa';
            activation = output_activation;
        else
            layer_color = hidden_color;
            layer_name = sprintf('Warstwa ukryta %d', i-1);
            activation = activation_functions{i-1};
        end
        
        % Pozycja warstwy
        x_pos = x_positions(i);
        
        % Liczba neuronów w warstwie
        num_neurons = layer_sizes(i);
        
        % Właściwa liczba neuronów do narysowania (max 10, żeby było czytelnie)
        display_neurons = min(10, num_neurons);
        
        % Rysuj neurony jako kółka
        y_positions = linspace(1, total_height-1, display_neurons);
        all_y_positions{i} = y_positions;
        
        for j = 1:display_neurons
            circle(x_pos, y_positions(j), 0.3, layer_color);
        end
        
        % Dodaj etykietę warstwy na dole
        text(x_pos, 0.2, layer_name, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        
        % Dodaj liczbę neuronów na górze
        text(x_pos, total_height+0.5, sprintf('%d neuronów', num_neurons), 'HorizontalAlignment', 'center');
        
        % Dodaj informację o funkcji aktywacji dla warstw ukrytych i wyjściowej
        if i > 1
            text(x_pos, total_height+1.2, sprintf('Aktywacja: %s', activation), ...
                'HorizontalAlignment', 'center', 'FontSize', 9);
        else
            text(x_pos, total_height+1.2, 'Brak funkcji aktywacji', ...
                'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5, 0.5, 0.5]);
        end
        
        % Dla dużej liczby neuronów pokazujemy "..." w środku
        if num_neurons > 10
            text(x_pos, (y_positions(5) + y_positions(6))/2, '...', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 14);
        end
    end
    
    % Rysuj połączenia między warstwami - WSZYSTKIE połączenia będą widoczne
    for i = 2:num_layers
        prev_x = x_positions(i-1);
        curr_x = x_positions(i);
        
        prev_y_positions = all_y_positions{i-1};
        curr_y_positions = all_y_positions{i};
        
        % Rysujemy wszystkie połączenia
        for j = 1:length(curr_y_positions)
            for k = 1:length(prev_y_positions)
                % Użyj przezroczystości dla lepszego efektu wizualnego
                alpha = 0.05;  % Bardzo niska przezroczystość dla czytelności
                plot([prev_x, curr_x], [prev_y_positions(k), curr_y_positions(j)], ...
                    'Color', [0.4, 0.4, 0.4, alpha], 'LineWidth', 0.2);
            end
        end
        
        % Dodatkowo dla lepszej widoczności, podkreśl kilka połączeń
        for j = [1, 3, 5, 8, 10]
            if j <= length(curr_y_positions)
                for k = [1, 4, 7, 10]
                    if k <= length(prev_y_positions)
                        plot([prev_x, curr_x], [prev_y_positions(k), curr_y_positions(j)], ...
                            'Color', [0.2, 0.2, 0.2, 0.3], 'LineWidth', 0.6);
                    end
                end
            end
        end
    end
    
    % Dodanie informacji o biasie
    for i = 2:num_layers
        % Dodaj informację o biasie (małe kółko z "+" wewnątrz)
        bias_x = x_positions(i);
        bias_y = 0.7;
        
        % Narysuj małe kółko dla biasu
        circle(bias_x, bias_y, 0.15, [0.95, 0.95, 0.95]);
        
        % Dodaj "+" w środku kółka biasu
        plot([bias_x-0.1, bias_x+0.1], [bias_y, bias_y], 'k', 'LineWidth', 1);
        plot([bias_x, bias_x], [bias_y-0.1, bias_y+0.1], 'k', 'LineWidth', 1);
        
        % Dodaj strzałkę od biasu do warstwy
        arrow([bias_x, bias_y+0.2], [bias_x, all_y_positions{i}(end)-0.4]);
    end
    
    % Informacje o sieci
    box_text = {
        sprintf('Typ sieci: %s', class(net)),
        sprintf('Algorytm uczenia: %s', net.trainFcn)
        };
    
    % Dodaj ramkę z informacjami na dole
    annotation('textbox', [0.15, 0.02, 0.7, 0.08], ...
        'String', box_text, ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.95, 0.95, 0.95], ...
        'FitBoxToText', 'on', ...
        'EdgeColor', [0.7, 0.7, 0.7]);
    
    % Dostosuj osie
    axis([0, total_width, 0, total_height+2]);
    axis off;
    title(title_text, 'FontSize', 14);
    hold off;
    
    % Zapisanie wizualizacji jeśli podano ścieżkę
    if ~isempty(save_path)
        % Sprawdzenie czy folder istnieje, jeśli nie - utworzenie
        viz_dir = fileparts(save_path);
        if ~exist(viz_dir, 'dir')
            mkdir(viz_dir);
            fprintf('📁 Utworzono katalog dla wizualizacji: %s\n', viz_dir);
        end
        
        % Zapisanie figury
        saveas(h, save_path);
        fprintf('💾 Zapisano wizualizację struktury sieci: %s\n', save_path);
    end
    
catch e
    fprintf('❌ Błąd podczas generowania wizualizacji struktury sieci: %s\n', e.message);
end

end

% Funkcja pomocnicza do rysowania kółek
function circle(x, y, r, color)
theta = linspace(0, 2*pi, 30);
x_circle = r * cos(theta) + x;
y_circle = r * sin(theta) + y;
fill(x_circle, y_circle, color, 'EdgeColor', 'k', 'LineWidth', 1);
end

% Funkcja pomocnicza do rysowania strzałek
function arrow(start_point, end_point)
% Rysowanie linii
line([start_point(1), end_point(1)], [start_point(2), end_point(2)], 'Color', 'k', 'LineWidth', 1);

% Parametry grotu strzałki
arrow_size = 0.1;
angle = atan2(end_point(2) - start_point(2), end_point(1) - start_point(1));

% Obliczenie punktów grotu
x1 = end_point(1) - arrow_size * cos(angle - pi/6);
y1 = end_point(2) - arrow_size * sin(angle - pi/6);
x2 = end_point(1) - arrow_size * cos(angle + pi/6);
y2 = end_point(2) - arrow_size * sin(angle + pi/6);

% Narysowanie grotu strzałki
fill([end_point(1), x1, x2], [end_point(2), y1, y2], 'k');
end