function [cumpress,press,nze] = crossval_gpls1(x,y,lvs,gammas,blocks_r,prepx,prepy,opt,mtype)

% Row-wise k-fold (rkf) cross-validation for square-prediction-errors
% computing in GPLS1. 
%
% [cumpress,press] = crossval_pls(x,y) % minimum call
% [cumpress,press,nze] =
% crossval_pls(x,y,lvs,gammas,blocks_r,prepx,prepy,opt,mtype) % complete call
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
% gammas: [1xJ] gamma values considered. By default, gammas = 0:0.1:1
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
%   1: Common correlation matrix, filtered out by oMEDA.
%   2: XYYX normalized, filtered out by oMEDA.
%   3: MEDA map, filtered out by oMEDA.
%   4: oMEDA map.
%
%
% OUTPUTS:
%
% cumpress: [A x gammas x 1] Cumulative PRESS
%
% press: [A x gammas x O] PRESS per variable.
%
% nze: [A x gammas x 1] Average number of non-zero elements
%
%
% EXAMPLE OF USE: Random data with structural relationship
%
% Y = randn(100,2);
% X(:,1:2) = Y + 0.1*randn(100,2);
% X(:,3:10) = simuleMV(100,8,6);
% lvs = 0:10;
% gammas = 0:0.1:1;
% [cumpress,press,nze] = crossval_gpls1(X,Y,lvs,gammas);
%
%
% coded by: Jose Camacho Paez (josecamacho@ugr.es)
% last modification: 18/Nov/16.
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
M = size(x, 2);
O = size(y, 2);
if nargin < 3 || isempty(lvs), lvs = 0:rank(x); end;
A = length(lvs);
if nargin < 4 || isempty(gammas), gammas = 0:0.1:1; end;
J =  length(gammas);
if nargin < 5 || isempty(blocks_r), blocks_r = N; end;
if nargin < 6 || isempty(prepx), prepx = 2; end;
if nargin < 7 || isempty(prepy), prepy = 2; end;
if nargin < 8 || isempty(opt), opt = 1; end;
if nargin < 9 || isempty(mtype), mtype = 3; end;

% Convert column arrays to row arrays
if size(lvs,2) == 1, lvs = lvs'; end;
if size(gammas,2) == 1, gammas = gammas'; end;

% Validate dimensions of input data
assert (isequal(size(y), [N O]), 'Dimension Error: 2nd argument must be N-by-O. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(lvs), [1 A]), 'Dimension Error: 3rd argument must be 1-by-A. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(gammas), [1 J]), 'Dimension Error: 4th argument must be 1-by-J. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(blocks_r), [1 1]), 'Dimension Error: 5th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(prepx), [1 1]), 'Dimension Error: 6th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(prepy), [1 1]), 'Dimension Error: 7th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(opt), [1 1]), 'Dimension Error: 8th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(size(mtype), [1 1]), 'Dimension Error: 9th argument must be 1-by-1. Type ''help %s'' for more info.', routine(1).name);

% Preprocessing
lvs = unique(lvs);
gammas = unique(gammas);

% Validate values of input data
assert (isempty(find(lvs<0)), 'Value Error: 3rd argument must not contain negative values. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(fix(lvs), lvs), 'Value Error: 3rd argumentmust contain integers. Type ''help %s'' for more info.', routine(1).name);
assert (isempty(find(gammas<0 | gammas>1)), 'Value Error: 4th argument must not contain values out of [0,1]. Type ''help %s'' for more info.', routine(1).name);
assert (isequal(fix(blocks_r), blocks_r), 'Value Error: 5th argument must be an integer. Type ''help %s'' for more info.', routine(1).name);
assert (blocks_r>2, 'Value Error: 5th argument must be above 2. Type ''help %s'' for more info.', routine(1).name);
assert (blocks_r<=N, 'Value Error: 5th argument must be at most N. Type ''help %s'' for more info.', routine(1).name);
assert (isempty(find(mtype~=1 & mtype~=2 & mtype~=3 & mtype~=4)), 'Value Error: 9th argument must contain an integer from 1 to 4. Type ''help %s'' for more info.', routine(1).name);


%% Main code

% Initialization
cumpress = zeros(length(lvs),length(gammas),1);
press = zeros(length(lvs),length(gammas),O);
nze = zeros(length(lvs),length(gammas));

rows = rand(1,N);
[a,r_ind]=sort(rows);
elem_r=N/blocks_r;

% Cross-validation
        
for i=1:blocks_r,
    
    ind_i = r_ind(round((i-1)*elem_r+1):round(i*elem_r)); % Sample selection
    i2 = ones(N,1);
    i2(ind_i)=0;
    sample = x(ind_i,:);
    calibr = x(find(i2),:); 
    sample_y = y(ind_i,:);
    calibr_y = y(find(i2),:); 

    [ccs,av,st] = preprocess2D(calibr,prepx);
    [ccs_y,av_y,st_y] = preprocess2D(calibr_y,prepy);
        
    scs = preprocess2Dapp(sample,av,st);
    scs_y = preprocess2Dapp(sample_y,av_y,st_y);
    
    for gamma=1:length(gammas),
        
        for lv=1:length(lvs),
                
            if lvs(lv) > 0,
                beta = gpls1(ccs,ccs_y,1:lvs(lv),gammas(gamma),mtype);
                srec = scs*beta;
                
                pem = scs_y-srec;
                nze(lv,gamma) = nze(lv,gamma) + length(find(beta));
                            
            else % Modelling with the average
                pem = scs_y;
            end
                
            press(lv,gamma,:) = squeeze(press(lv,gamma,:))' + sum(pem.^2,1);

        end
    end
    
end

cumpress = sum(press,3);

%% Show results

if opt == 1,
    fig_h = plot_vec(cumpress',gammas,[],{'\gamma','PRESS'},[],0,lvs); 
end

