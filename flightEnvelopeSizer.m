% <Script Purpose>
%                                                     <Output> in (<Units>)
% -------------------------------------------------------------------------
% Dependencies
%   #) <Dependency Filepath>
% -------------------------------------------------------------------------
% Assumptions
%   #) <Assumption>
% -------------------------------------------------------------------------
% Sources
%   #) <Source>
% -------------------------------------------------------------------------
% MATLAB Version <Oldest Version>, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github) and Adrien Hartman
% (adrienh01 on Github)
% -------------------------------------------------------------------------

% INFORMATION FOR CONFIG READ-IN
% "data" will be a struct type
% data will have fieldnames:
%   a_0         : lift curve slope   
%   alpha_L0    : zero lift angle of attack
%   c_d         : 100-element 2D array of [alpha, c_d], where alpha is a
%       100 element 1D column vector of angle of attack values, and c_d is
%       a 100 element 1D column vector of 2D drag coefficient values
%       e.g.:
%       [1, 0.2;
%        2, 0.3;
%        3, 0.5;
%        ...]

configFile = "airfoils.txt"; % Sample comment
configName = "NACA24_9019";

% Data read-in
data = GetConfigData(configFile, configName);
%Start here
% Variable assignments
% a = data.a;
% alpha_L0 = data.alpha_L0;
% c_d = data.c_d;

% Test 1