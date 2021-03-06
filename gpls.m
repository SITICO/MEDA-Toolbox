function [beta,W,P,Q,R,bel] = gpls(xcs,ycs,states,lvs)

% Group-wise Partial Least Squares. The original paper is Camacho, J., 
% Saccenti, E. Group-wise Partial Least Squares Regression. Submitted to
% Chemometrics and Intelligent Laboratory Systems, 2016.
%
% beta = gpls(xcs,ycs,states)     % minimum call
% [beta,W,P,Q,R,bel] = gpca(xcs,ycs,states,lvs)     % complete call
%
%
% INPUTS:
%
% xcs: [NxM] preprocessed billinear data set 
%
% ycs: [NxO] preprocessed billinear data set of predicted variables
%
% states: {Sx1} Cell with the groups of variables.
%
% lvs: [1xA] Latent Variables considered (e.g. lvs = 1:2 selects the
%   first two LVs). By default, lvs = 0:rank(xcs)
%
%
% OUTPUTS:
%
% beta: [MxO] matrix of regression coefficients: W*inv(P'*W)*Q'
%
% W: [MxA] matrix of weights
%
% P: [MxA] matrix of x-loadings
%
% Q: [OxA] matrix of y-loadings
%
% R: [MxA] matrix of modified weights: W*inv(P'*W)
%
% bel: [Ax1] correspondence between LVs and States.
%
%
% EXAMPLE OF USE: Random data:
%
% Y = randn(100,2);
% X(:,1:2) = Y + 0.1*randn(100,2);
% X(:,3:10) = simuleMV(100,8,6);
% lvs = 1:2;
% map = meda_pls(X,Y,lvs,[],[],[],0);
%
% Xcs = preprocess2D(X,2);
% Ycs = preprocess2D(Y,2);
% [bel,states] = gia(map,0.3,1);
% [beta,W,P,Q,R,bel] = gpls(Xcs,Ycs,states,lvs);
% 
% for i=lvs,
%   plot_vec(R(:,i),[],[],{'',sprintf('Regression coefficients LV %d',i)});
% end
%
% coded by: Jose Camacho Paez (josecamacho@ugr.es)
% last modification: 16/Nov/16.
%
% Copyright (C) 2014  University of Granada, Granada
% Copyright (C) 2014  Jose Camacho Paez
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

%% Arguments checking

% Set default values
routine=dbstack;
assert (nargin >= 3, 'Error in the number of arguments. Type ''help %s'' for more info.', routine.name);
N = size(xcs, 1);
M = size(xcs, 2);
O = size(ycs, 2);
if nargin < 4 || isempty(lvs), lvs = 0:rank(xcs); end;

% Convert column arrays to row arrays
if size(lvs,2) == 1, lvs = lvs'; end;

% Preprocessing
lvs = unique(lvs);
lvs(find(lvs==0)) = [];
lvs(find(lvs>M)) = [];
A = length(lvs);

% Validate dimensions of input data
assert (isequal(size(ycs), [N O]), 'Dimension Error: 2nd argument must be N-by-O. Type ''help %s'' for more info.', routine.name);
assert (isequal(size(lvs), [1 A]), 'Dimension Error: 4th argument must be 1-by-A. Type ''help %s'' for more info.', routine.name);

% Validate values of input data
assert (iscell(states), 'Value Error: 3rd argument must be a cell of positive integers. Type ''help %s'' for more info.', routine.name);
for i=1:length(states),
    assert (isempty(find(states{i}<1)) && isequal(fix(states{i}), states{i}), 'Value Error: 3rd argument must be a cell of positive integers. Type ''help %s'' for more info.', routine.name);
    assert (isempty(find(states{i}>M)), 'Value Error: 3rd argument must contain values not higher than M. Type ''help %s'' for more info.', routine.name);
end
assert (isempty(find(lvs<0)) && isequal(fix(lvs), lvs), 'Value Error: 4th argument must contain positive integers. Type ''help %s'' for more info.', routine.name);



%% Main code

map = xcs'*xcs;
mapy = xcs'*ycs;
I =  eye(M);
B = I;
beta = zeros(M,O);
W = zeros(M,max(lvs));
P = zeros(M,max(lvs));
Q = zeros(O,max(lvs));
T = zeros(N,max(lvs));
bel = zeros(1,max(lvs));
R = zeros(M,max(lvs));
    
for j = 1:max(lvs),  
    
    Rt = zeros(M,length(states));
    Tt = zeros(N,length(states));
    Wt = zeros(M,length(states));
    Pt = zeros(M,length(states));
    Qt = zeros(O,length(states));

    for i=1:length(states), % construct eigenvectors according to states
        map_aux = zeros(size(map));
        map_aux(states{i},states{i})= map(states{i},states{i});
        mapy_aux = zeros(size(mapy));
        mapy_aux(states{i},:)= mapy(states{i},:);
         if ~isnan(map_aux) & ~isinf(map_aux) & rank(map_aux) & rank(mapy_aux),
             [betai,Wi,Pi,Qi] = kernel_pls(map_aux,mapy_aux,1);
             
             Rt(:,i) = B*Wi; % Dayal & MacGregor eq. (22)
             Tt(:,i) = xcs*Rt(:,i);
             Wt(:,i) = Wi;
             Pt(:,i) = Pi;
             Qt(:,i) = Qi;
        end
    end

    sS = sum((preprocess2D(Tt,2)'*ycs).^2,2); % select pseudo-eigenvector with the highest covariance
    if max(sS),
        ind = find(sS==max(sS),1);
    else
        break;
    end
    R(:,j) = Rt(:,ind);
    T(:,j) = Tt(:,ind);
    W(:,j) = Wt(:,ind);
    Q(:,j) = Qt(:,ind);
    P(:,j) = Pt(:,ind);
    bel(j) = ind;
    
    %xcs = xcs - Tt(:,ind)*Pt(:,ind)'; % deflate (spls)
	d = ycs'*Tt(:,ind)/(Tt(:,ind)'*Tt(:,ind));
    ycs = ycs - Tt(:,ind)*d';
	%map = xcs'*xcs;
	mapy = xcs'*ycs;    
    q = B*Wt(:,ind)*Pt(:,ind)';
    B = B*(I-q); 
    
end

% Postprocessing
W = W(:,lvs);
P = P(:,lvs);
Q = Q(:,lvs);
T = T(:,lvs);
bel = bel(lvs);
R = R(:,lvs);
beta=R*Q';

