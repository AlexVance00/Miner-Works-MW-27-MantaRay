% This script is meant to estimate propeller and motor sizing by estimating
% some other geometric wing properties and testing different airfoils by
% generating a power-available vs. power-required graph for different
% velocities and angles of attack
%                                                     <Output> in (<Units>)
% -------------------------------------------------------------------------
% Dependencies
%   1) airfoil_data.txt
% -------------------------------------------------------------------------
% Assumptions
%   #) <Assumption>
% -------------------------------------------------------------------------
% Sources
%   1) http://www.braeunig.us/space/atmos.htm
% -------------------------------------------------------------------------
% MATLAB Version R2025a, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github) and Adrien Hartman
% (adrienh01 on Github)
% -------------------------------------------------------------------------

% INFORMATION FOR CONFIG READ-IN
% "data" will be a struct
% data will have fieldnames:
%   a_0:        2D lift curve slope   
%   alpha_L0:   zero lift angle of attack
%   c_d:        struct with fieldnames "alpha" and "c_d" where alpha is a
%                   100 element 1D column vector of angle of attack values,
%                   and c_d is a 100 element 1D column vector of 2D drag
%                   coefficient values
%
%   e.g.:
%   data.c_d.alpha =    <100 element 1D column vector of angle of attack
%                           values>
%   data.c_d.c_d =      <100 element 1D column vector of 2D drag
%                           coefficient values>

clc
clear
close all

% Only change if you rename the folder where the tabulated c_d values are
% for each airfoil config. This assumes these tabulated value files are in
% a subfolder of the current working directory/folder this script is in
airfoild_c_d_values_folder = "Tabulated Airfoil c_d Values";
addpath(pwd + "\" + airfoild_c_d_values_folder);
% Only change if you rename the file where the airfoil data configs are
% stored
configFile = "airfoil_data.txt";

% Estimates to gauge Reynold's and Mach Numbers, for XFLR5 analysis
% parameters
% characteristic length is chord -> estimate
c = 12^-1 * 16; % in to ft
% Need some nominal speed -> estimate
u = 50; % ft/s
% Need air kinematic viscosity -> estimate (standard atmosphere conditions
% at sea level)
% Was able to find mu, dynamic viscosity [1]. Get density [1] to convert to
% kinematic
mu = 1.81206E-5; % Pa-s
rho = 1.22500; % kg/m^3
nu = mu / rho * 10.7639; % m^2/s to ft^2/s
% Finally, estimate Reynold's Number
Re = c * u / nu;
% Estimate Mach Number now
% Get temperature [1]
T = 288 * 1.8; % K to deg R
% Use common estimate for specific heat ratio of air
gammay = 1.4;
% Use common value for air's gas constant
R_air = 1716; % (lbf-ft)/(slug-deg R)
% Get speed of sound
a = sqrt(gammay * R_air * T);
% Finally calculate Mach Number
M = u / a;
% Print estimated values
fprintf("Estimated Reynold's Number: %.2f\n", Re);
fprintf("Estimated Mach Number: %.5f\n\n", M);
% Clear variables so they don't mess with later work
clear c u mu rho nu Re T gammay R_air a M

% Change to work with a different airfoil config, or add multiple in an
% array
configName = "NACA2412";

% Data read-in
data = GetConfigData(configFile = configFile, configName = configName);
%Start here
% Variable assignments
% a = data.a;
% alpha_L0 = data.alpha_L0;
% c_d = data.c_d;

% Test 1