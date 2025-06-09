function saveVisualization(figureHandle, savePath, format, resolution)
% SAVEVISUALIZATION Zapisuje wizualizację do pliku
%
% Input:
%   figureHandle - uchwyt do figury
%   savePath - ścieżka zapisu
%   format - format pliku ('png', 'pdf', 'eps') [default: 'png']
%   resolution - rozdzielczość DPI [default: 300]

if nargin < 3, format = 'png'; end
if nargin < 4, resolution = 300; end

% Utwórz folder jeśli nie istnieje
[folder, ~, ~] = fileparts(savePath);
if ~exist(folder, 'dir')
    mkdir(folder);
end

% Dodaj rozszerzenie jeśli brakuje
[~, ~, ext] = fileparts(savePath);
if isempty(ext)
    savePath = [savePath '.' format];
end

% Zapisz z odpowiednimi parametrami
switch lower(format)
    case 'png'
        print(figureHandle, savePath, '-dpng', sprintf('-r%d', resolution));
    case 'pdf'
        print(figureHandle, savePath, '-dpdf', '-r300');
    case 'eps'
        print(figureHandle, savePath, '-depsc', '-r300');
    otherwise
        print(figureHandle, savePath, ['-d' format], sprintf('-r%d', resolution));
end

fprintf('💾 Visualization saved: %s\n', savePath);
end