function [Q,lvso,press] = dcrossval_gpls2(x,y,lvs,alpha,blocks_r,prepx,prepy,opt,mtype)

% Row-wise k-fold (rkf) double cross-validation for square-prediction-errors computing in GPLS2.
%
% Q = dcrossval_pls2(x,y) % minimum call
% [Q,lvso,press] = dcrossval_gpls2(x,y,lvs,alpha,blocks_r,prepx,prepy,opt,mtype) % complete call
%
%
% INPUTS:
%
% x: [NxM] billinear data set for model fitting
%
% y: [NxO] billinear data set of predicted variables
%
% lvs: [1xA] Latent Variables considered (e.g. lvs = 1:2 selects the
%   first two LVs). By default, lvs = 0:rank(x)
%
% blocks_r: [1x1] maximum number of blocks of samples (N by default)
%
% prepx: [1x1] preprocesing of the x-block
%       0: no preprocessing
%       1: mean centering
%       2: autoscaling (default)  
%
% prepy: [1x1] preprocesing of the y-block
%       0: no preprocessing
%       1: mean centering
%       2: autoscaling (default)  
%
% opt: [1x1] options for data plotting
%       0: no plots
%       1: bar plot (default)
%
% mtype: [1x1] type of correlation map used (3 by default)
%   1: Common correlation matrix.
%   2: XYYX normalized.
%   3: MEDA map.
%   4: oMEDA map.
%
%
% OUTPUTS:
%
% Q: [1x1] Index Q2
%
% lvso: [blocks_rx1] optimum number of LVs in the inner loop
%
% press: [NxO] PRESS per observations and variable
%
%
% EXAMPLE OF USE: Random data with structural relationship
%
% Y = randn(100,2);
% X(:,1:2) = Y + 0.1*randn(100,2);
% X(:,3:10) = simuleMV(100,8,6);
% lvs = 0:10;
% [Q,lvso] = dcrossval_gpls2(X,Y,lvs,1,7);
% [Qb,lvsob] = dcrossval_gpls2(X,Y,lvs,0.5,7);
%
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
assert (nargin >= 2, 'Error in the number of arguments. Type ''help %s'' for more info.', routine(1).name);
N = size(x, 1);
O = size(y, 2);
if nargin < 3 || isempty(lvs), lvs = 0:rank(x); end;
A = length(lvs);
if nargin < 4 || isempty(alpha), alpha = 1; end;
if nargin < 5 || isempty(blocks_r), blocks_r = N; end;
if nargin < 6 || isempty(prepx), prepx = 2; end;
if nargin < 7 || isempty(prepy), prepy = 2; end;
if nargin < 8 || isempty(opt), opt = 1; end;
if nargin < 9 || isempty(mtype), mtype = 3; end;

% Convert column arrays to row arrays
if size(lvs,2) == 1, lvs = lvs'; end;

% Validate dimensions of input data
assert (isequal(size(y), [N O]), 'Dimension Error: 2nd argument must be N-by-O. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(lvs), [1 A]), 'Dimension Error: 3rd argument must be 1-by-A. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(alpha), [1 1]), 'Dimension Error: 4th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(blocks_r), [1 1]), 'Dimension Error: 5th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(prepx), [1 1]), 'Dimension Error: 6th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(prepy), [1 1]), 'Dimension Error: 7th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(opt), [1 1]), 'Dimension Error: 8th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(mtype), [1 1]), 'Dimension Error: 9th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);

% Preprocessing
lvs = unique(lvs);

% Validate values of input data
assert (isempty(find(lvs<0)), 'Value Error: 3rd argument must not contain negative values. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(fix(lvs), lvs), 'Value Error: 3rd argumentmust contain integers. Type ''help %s'' for more info.', routine(1).name);
assert (alpha>=0 & alpha<=1, 'Value Error: 4th argument must not be out of [0,1]. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(fix(blocks_r), blocks_r), 'Value Error: 5th argument must be an integer. Type ''help %s'' for more info.', routine(1).name);
assert (blocks_r>2, 'Value Error: 5th argument must be above 2. Type ''help %s'' for more info.', routine(1).name);
assert (blocks_r<=N, 'Value Error: 5th argument must be at most N. Type ''help %s'' for more info.', routine(1).name);
assert (isempty(find(mtype~=1 & mtype~=2 & mtype~=3 & mtype~=4)), 'Value Error: 9th argument must contain an integer from 1 to 4. Type ''help %s'' for more info.', routine(1).name);


%% Main code

% Cross-validation
        
press = zeros(N,O);
press0 = zeros(N,O);

rows = rand(1,N);
[a,r_ind]=sort(rows);
elem_r=N/blocks_r;

for i=1:blocks_r,
    disp(sprintf('Crossvalidation block %i of %i',i,blocks_r))
    ind_i = r_ind(round((i-1)*elem_r+1):round(i*elem_r)); % Sample selection
    i2 = ones(N,1);
    i2(ind_i)=0;
    val = x(ind_i,:);
    rest = x(find(i2),:); 
    val_y = y(ind_i,:);
    rest_y = y(find(i2),:);
    
    [cumpress,kk,nze] = crossval_gpls2(rest,rest_y,lvs,blocks_r-1,prepx,prepy,0,mtype);
        
    cumpressb = alpha*cumpress/max(max(cumpress)) + (1-alpha)*nze/max(max(nze));
    [l,g]=find(cumpressb==min(min(cumpressb)));
    lvso(i) = lvs(l(1));
    
    [ccs,av,st] = preprocess2D(rest,prepx);
    [ccs_y,av_y,st_y] = preprocess2D(rest_y,prepy);
       
    vcs = preprocess2Dapp(val,av,st);
    vcs_y = preprocess2Dapp(val_y,av_y,st_y);
        
    beta = gpls2(ccs,ccs_y,1:lvso(i),mtype);
    srec = vcs*beta;
    
    press(ind_i,:) = vcs_y-srec;
    press0(ind_i,:) = vcs_y;
    
end

Q = 1 - sum(sum(press.^2))/sum(sum(press0.^2));

%% Show results

if opt == 1,
   fig_h = plot_vec(sum(press.^2,2),[],[],{'#Observation','PRESS'},[],1); 
end

