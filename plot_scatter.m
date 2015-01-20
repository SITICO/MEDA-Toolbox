
function fig_h = plot_scatter(bdata,olabel,classes,axlabel,opt)

% Scatter plot.
%
% plot_scatter(bdata) % minimum call
% plot_scatter(bdata,olabel,classes,axlabel,opt) % complete call
%
%
% INPUTS:
%
% bdata: (Nx2) bidimensional data to plot. 
%
% olabel: {Nx1} name of the observations/variables
%   Allowed cell array of strings, eg. {'first', 'second', 'third', ...}
%   use [] to set the default, empty labels.
%
% classes: (Nx1) vector with the assignment of the observations/variables to classes,
%   Allowed numerical classes, eg. [1 1 2 2 2 3], 
%   and cell array of strings, eg. {'blue','red','red','green','blue'}.
%   use [] to set the default, a single class.
%
% axlabel: {2x1} variable/statistic plotted (nothing by default)
%
% opt: (1x1) options for data plotting.
%       0: filled marks (by default)
%       1: empty marks
%
%
% OUTPUTS:
%
% fig_h: (1x1) figure handle.
%
%
% coded by: José Camacho Páez (josecamacho@ugr.es)
%           Alejandro Pérez Villegas (alextoni@gmail.com)
% last modification: 20/Jan/15.
%
% Copyright (C) 2014  University of Granada, Granada
% Copyright (C) 2014  José Camacho Páez
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

%% Parameters checking
assert (nargin >= 1, 'Error: Missing arguments.');
N = size(bdata, 1);
if nargin < 2 || isempty(olabel)
    olabel = repmat({''}, N, 1);
end
if nargin < 3 || isempty(classes)
    classes = ones(N, 1);
end
if nargin < 4 || isempty(axlabel)
    axlabel = {'Dim 1';'Dim 2'};
end
if nargin < 5, opt = 0; end;

if isrow(olabel), olabel = olabel'; end;
if isrow(classes), classes = classes'; end;
if isrow(axlabel), axlabel = axlabel'; end;

assert (size(bdata,2) == 2, 'Dimension Error: bdata must be n-by-2.')
assert (isequal(size(olabel), [N 1]), 'Dimension Error: label must be n-by-1.');
assert (isequal(size(classes), [N 1]), 'Dimension Error: classes must be n-by-1.')
assert (isequal(size(axlabel), [2 1]), 'Dimension Error: axlabel must be 2-by-1.')

%% Main code
% Preprocess classes to force them start with 1, 2...n,
unique_classes = unique(classes);
if iscell(classes)
    normal_classes = arrayfun(@(x) find(strcmp(unique_classes, x), 1), classes);
else
    normal_classes = arrayfun(@(x) find(unique_classes == x, 1), classes);
end

% Map classes to colors
color_list = hsv(length(unique_classes));
color_array = color_list(normal_classes, :);

% Plot points and labels
fig_h = figure;
hold on;
if opt
    scatter(bdata(:,1), bdata(:,2), [], color_array)
else
    scatter(bdata(:,1), bdata(:,2), [], color_array, 'filled')
end    
text(bdata(:,1), bdata(:,2), olabel(:,1), 'VerticalAlignment','bottom','HorizontalAlignment','left');

% Set axis labels and plot origin lines
xlabel(axlabel(1), 'FontSize', 16);
ylabel(axlabel(2), 'FontSize', 16);

ax = axis;
plot([0 0], ax(3:4), 'k--');
plot(ax(1:2), [0 0], 'k--');
axis(ax)

box on
