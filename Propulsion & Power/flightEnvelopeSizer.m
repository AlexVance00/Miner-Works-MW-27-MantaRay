% This script is meant to estimate propeller and motor sizing by estimating
% some other geometric wing properties and testing different airfoils by
% generating a power-available vs. power-required graph for different
% velocities and angles of attack
% -------------------------------------------------------------------------
% Dependencies
%   1) Airfoil.m Version 2.0
%   2) MotorPropAssy.m Version 1.0
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

clc
clear
close all

% Estimates to gauge Reynold's and Mach Numbers, for XFLR5 analysis
% parameters
% characteristic length is chord -> estimate
c = 16 / 12; % in to ft
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
a = sqrt(gammay * R_air * T); % ft/s
% Finally calculate Mach Number
M = u / a;
% Print estimated values
fprintf("Estimated Reynold's Number: %.2f\n", Re);
fprintf("Estimated Mach Number: %.5f\n\n", M);
% Clear variables so they don't mess with later work
clear c u mu rho nu Re T gammay R_air a M

% Change to work with a different airfoil config, or add multiple in a
% string array
airfoilConfigName = "E210";
motorConfigName = "Cobra_C3510_16";
propellerConfigName = "APC_8x6E";

%% Data read-in
airfoil = Airfoil(airfoilConfigName);
motorPropAssy = MotorPropAssy(motorConfigName, propellerConfigName);

% Airfoil data
a0 = airfoil.a_0;                      % 2D lift curve slope, 1/deg
alpha_L0 = airfoil.alpha_L0;           % Zero-lift AoA, deg
rawAlphaData = airfoil.c_d.alpha(:);   % AoA data, deg
rawcdData = airfoil.c_d.c_d(:);        % 2D/profile drag coefficient
% Geometry / Estimates
b = 9.56;            % span, ft
S = 10.73;           % planform area, ft^2
W = 11;              % weight, lbf
e = 0.8;             % Oswald efficiency factor
AR = b^2 / S;        % aspect ratio

% Convert airfoil data units
a0 = a0 .* 180 ./ pi; % 1/deg to 1/rad
alpha_L0 = alpha_L0 ./ 180 .* pi; % deg to rad
rawAlphaData = rawAlphaData ./ 180 .* pi; % deg to rad

% Ignore angles of attack below which cl is negative (lower than alpha_L0)
alphaDataMaskPoscl = rawAlphaData >= alpha_L0;
alphaDataPoscl = rawAlphaData(alphaDataMaskPoscl);
cdDataPoscl = rawcdData(alphaDataMaskPoscl);

% Motor data
eta_prop = 0.8;
numMotors = 2;

% Atmosphere
rho = 0.0023769;     % Sea level air density, slug/ft^3

% Calculate thrust available and power available curves
% Thrust available depends on RPM and speed
% For thrust available curve, want max thrust available, which would be for
% max RPM. Then sweep across speeds
% Use RPM value from motor data table in the row where the imported
% propeller can be found. Will be stored in performance data of
% motorPropAssy
% Will need to specify what range of velocities we care about. vstall
% through vpropmax
% Get stall speed, speed at CLmax where L=W
% Get a from a0, e, and AR
a = a0 / (1 + a0 / (pi * e * AR)); % 1/rad
% Get CLmax
CLmax = a .* (max(alphaDataPoscl) - alpha_L0);
fprintf("Max CL is %.4f\n", CLmax);
vstall = sqrt(W ./ CLmax .* 2 ./ rho ./ S); % ft/s
fprintf("Stall speed is %.4f ft/s\n", vstall);
bcs = string(fieldnames(motorPropAssy.perfData)); % bcs - batteryConfigs
for bc = 1:numel(bcs)
    fprintf("Max RPM of propeller %s with motor %s for battery config %s is %d RPM\n", motorPropAssy.propeller.name, motorPropAssy.motor.name, erase(bcs(bc), "Battery"), motorPropAssy.perfData.(bcs(bc)).RPMmax);
end
vCount = 20; % number of speeds to sweep through
%% Sweep through all valid RPM blocks
% This will get 2D array of TA, PA, TR, and PR vals for varying v and RPM
% vals. Will surf plot later
flagJustCheckFirstBC = true; % True: just reads data for first battery config
if ~flagJustCheckFirstBC
    error("Analysis of motorPropAssy objects with multiple valid battery configurations (e.g 3S, 4S, etc.) not yet implemented\n");
end
bc = bcs(1);
% Make 2D array for all this. each column will be for different RPMs. First
% column for lowest, final for highest
RPMStringsAll = string(fieldnames(motorPropAssy.perfData.(bc))); % First 2 fields are RPMmax, and nmax. Ignore them
RPMStrings = RPMStringsAll(3:end);
RPMArray = zeros(size(RPMStrings));
vArray = zeros(vCount, numel(RPMStrings));
TAArray = zeros(size(vArray));
vpropmaxArray = zeros(1, numel(RPMArray));
for R = 1:numel(RPMStrings)
    RPMString = RPMStrings{R};
    RPM = str2double(erase(RPMString, "RPM"));
    RPMArray(R) = RPM;
    % Get vpropmax, speed at which prop can provide no more thrust
    % Values near end of array might be negative, chop em off
    posThrustMask = motorPropAssy.perfData.(bc).(RPMString).T >= 0;
    % Can assume will only chop off values on end of array, not at beginning or
    % in middle
    [~, vpropmaxIdx] = min(motorPropAssy.perfData.(bc).(RPMString).T(posThrustMask));
    vpropmax = motorPropAssy.perfData.(bc).(RPMString).v(vpropmaxIdx) .* 3.281; % m/s to ft/s
    vpropmaxArray(R) = vpropmax;
    fprintf("Max propeller airspeed is %.4f ft/s for %d RPM\n", vpropmax, RPM);
    % Check if vstall is greater than this vpropmax. If so, skip this data
    if vstall > vpropmax
        continue;
    end
    vArray(:, R) = linspace(vstall, vpropmax, vCount)';
    % Converts motorPropAssy's v array from m/s to ft/s in-line for
    % interpolation because vArray is in ft/s
    TAArray(:, R) = interp1(motorPropAssy.perfData.(bc).(RPMString).v .* 3.281, motorPropAssy.perfData.(bc).(RPMString).T, vArray(:, R)) * numMotors; % N
end
% Converts vArray from ft/s to m/s in-line to get PA in W because TA is in N
PAArray = TAArray .* vArray ./ 3.281; % W

% Get thrust required and power required curves
% Need drag to get thrust required, so CD is needed
% q is available from v, and S is known/estimated. To get CD, need cd and
% CDi. Have cd for various angles of attack. Can get what angle of attack
% each speed is at by calculating trim angle of attack. Will need to
% calculate CL at those points, using qArray and L=W (level flight
% requirement)
% Start with qArray
qArray = 0.5 .* rho .* vArray.^2; % slug/ft-s^2
CLArray = W ./ qArray / S;
% Get trim angles of attack from CL values
alphaTrimArray = CLArray / a + alpha_L0; % rad
CDArray = interp1(alphaDataPoscl, cdDataPoscl, alphaTrimArray);
DArray = qArray .* CDArray * S * 4.448; % lbf to N
TRArray = DArray; % N
% Converts vArray from ft/s to m/s in-line to get PR in W because TR is in N
PRArray = TRArray .* vArray ./ 3.281; % W
% Go back and check if any columns in vArray were left at 0. This would
% indicate that RPM value's computations were skipped because stall speed
% exceeded vpropmax. Delete those rows
validRPMMask = vArray(1, :) ~= 0;
invalidRPMs = RPMArray(~validRPMMask);
for i = 1:numel(invalidRPMs)
    fprintf("Stall speed %.2f ft/s was greater than max propeller speed %.2f ft/s for %d RPM: ignoring data\n", vstall, vpropmaxArray(i), invalidRPMs(i));
end
vArray = vArray(:, validRPMMask);
TAArray = TAArray(:, validRPMMask);
PAArray = PAArray(:, validRPMMask);
qArray = qArray(:, validRPMMask);
CLArray = CLArray(:, validRPMMask);
alphaTrimArray = alphaTrimArray(:, validRPMMask);
CDArray = CDArray(:, validRPMMask);
DArray = DArray(:, validRPMMask);
TRArray = TRArray(:, validRPMMask);
PRArray = PRArray(:, validRPMMask);
RPMArray = RPMArray(validRPMMask);
vpropmaxArray = (validRPMMask);

%% Surfplots for T and P, available and required, vs v and RPM
% T
figTSurf = figure();
axTSurf = axes(figTSurf);
RPMMesh = repmat(RPMArray', size(vArray, 1), 1);
grid(axTSurf, "on");
hold(axTSurf, "on");
view(axTSurf, 3);
xlabel(axTSurf, "v, ft/s");
ylabel(axTSurf, "RPM");
zlabel(axTSurf, "TA - TR, N");
title(axTSurf, "Excess Thrust vs RPM, v");
surf(axTSurf, vArray, RPMMesh, TAArray - TRArray);

% P
figPSurf = figure();
axPSurf = axes(figPSurf);
grid(axPSurf, "on");
hold(axPSurf, "on");
view(axPSurf, 3);
xlabel(axPSurf, "v, ft/s");
ylabel(axPSurf, "RPM");
zlabel(axPSurf, "PA - PR, W");
title(axPSurf, "Excess Power vs RPM, v");
surf(axPSurf, vArray, RPMMesh, PAArray - PRArray);

% Debugged through here as of 10/13/2026, 2:38 am CT

% Find v cruise, v for max L/D
[~, cruiseIdx] = max(CL ./ CD);
alphaCruise = rawAlphaData(cruiseIdx); % cruise angle of attack
% Estimate how much pct higher than vstall to set vcruise, for safety buffer
vcruiseBuffer = 20; % percent
vcruise = vstall(cruiseIdx) .* (1 + vcruiseBuffer ./ 100);
fprintf("vstall at cruise is %.2f ft/s, vcruise is %.1f%% higher, %.2f ft/s\n", vstall(cruiseIdx), vcruiseBuffer, vcruise);

% Leave motorPower_W = [] to suppress Power/Thrust Available plots.
motorPower_W = (motor.perfData.I - motor.I_o) .* (1);   % Shaft power per motor in Watts

% Convert propulsion power to useful propulsive power
if isempty(motorPower_W)
    PA = [];
else
    PA_W = numMotors * motorPower_W * eta_prop;
    PA = PA_W * 0.737562; % conversion from W to ft-lbf/s
end           

%% POWER REQUIRED VS VELOCITY, LEVEL FLIGHT



% Required AoA
alpha = CL ./ a + alpha_L0;

% Profile drag from airfoil data
cd = interp1(rawAlphaData, rawcdData, alpha, 'linear', NaN);

% Total drag
D = qArray .* S .* CD;

% Power required
PR = D .* V;

% Ignore points requiring AoA outside available airfoil data
valid = isfinite(PR);

V_plot = V(valid);
PR_plot = PR(valid);
alpha_plot = alpha(valid);
CL_plot = CL(valid);

% Plot
figure
plot(V_plot, PR_plot, 'LineWidth', 2)
hold on

if ~isempty(PA)
    PA_plot = PA .* ones(size(V_plot));
    plot(V_plot, PA_plot, 'LineWidth', 2)
    legend('Power Required', 'Power Available', 'Location', 'best')
end

grid on
xlabel('Velocity, V (ft/s)')
ylabel('Power, P (ft·lbf/s)')
title('Power Required vs Velocity - Level Flight')


%% POWER REQUIRED VS ANGLE OF ATTACK AT CRUISE

CL_alpha = a .* (rawAlphaData - alpha_L0);
CDi_alpha = CL_alpha.^2 ./ (pi .* e .* AR);
CD_alpha = rawcdData + CDi_alpha;

q_cruise = 0.5 * rho * vcruise^2;
D_alpha = q_cruise .* S .* CD_alpha;
PR_alpha = D_alpha .* vcruise;

figure
plot(rawAlphaData, PR_alpha, 'LineWidth', 2)
hold on

if ~isempty(PA)
    PA_alpha = PA .* ones(size(rawAlphaData));
    plot(rawAlphaData, PA_alpha, 'LineWidth', 2)
    legend('Power Required', 'Power Available', 'Location', 'best')
end

grid on
xlabel('Angle of Attack, \alpha (deg)')
ylabel('Power, P (ft·lbf/s)')
title(sprintf( ...
    'Power Required vs Angle of Attack at V_{cruise} = %.1f ft/s', ...
    vcruise))


%% THRUST REQUIRED VS VELOCITY

% In steady level flight:
%       T_R = D = P_R/V

TR = PR_plot ./ V_plot;

figure
plot(V_plot, TR, 'LineWidth', 2)
hold on

if ~isempty(PA)
    TA = PA ./ V_plot;
    plot(V_plot, TA, 'LineWidth', 2)
    legend('Thrust Required', 'Thrust Available', 'Location', 'best')
end

grid on
xlabel('Velocity, V (ft/s)')
ylabel('Thrust, T (lbf)')
title('Thrust Required vs Velocity - Level Flight')


%% SURFACE PLOT POWER REQUIRED VS VELOCITY AND ANGLE OF ATTACK

V_surface_range = linspace(vstall, vmax, vCount);

[V_surface, alpha_surface] = meshgrid( ...
    V_surface_range, rawAlphaData);

CL_surface = a .* (alpha_surface - alpha_L0);

cd_surface = repmat(rawcdData, 1, length(V_surface_range));

CDi_surface = CL_surface.^2 ./ (pi .* e .* AR);
CD_surface = cd_surface + CDi_surface;

q_surface = 0.5 .* rho .* V_surface.^2;
D_surface = q_surface .* S .* CD_surface;
PR_surface = D_surface .* V_surface;

figure
surf(V_surface, alpha_surface, PR_surface, ...
     'EdgeColor', 'none', ...
     'FaceAlpha', 0.90)

hold on

if ~isempty(PA)
    PA_surface = PA .* ones(size(V_surface));

    surf(V_surface, alpha_surface, PA_surface, ...
         'EdgeColor', 'none', ...
         'FaceAlpha', 0.40)

    legend('Power Required', 'Power Available', 'Location', 'best')
end

grid on
xlabel('Velocity, V (ft/s)')
ylabel('Angle of Attack, \alpha (deg)')
zlabel('Power, P (ft·lbf/s)')
title('Power Required vs Velocity and Angle of Attack')
view(3)


%% OUTPUT / CHECK VALUES

fprintf('\n--- FLIGHT ENVELOPE SIZER ---\n');

fprintf('Aspect Ratio: %.3f\n', AR);
fprintf('2D Lift Curve Slope: %.4f 1/deg\n', a0);
fprintf('Finite-Wing Lift Curve Slope: %.4f 1/deg\n', a);

fprintf('Airfoil AoA Range: %.2f to %.2f deg\n', ...
        min(rawAlphaData), max(rawAlphaData));

fprintf('Airfoil cd Range: %.5f to %.5f\n', ...
        min(rawcdData), max(rawcdData));

fprintf('Valid Level-Flight Points: %d of %d\n', ...
        sum(valid), length(V));

if any(valid)

    [PR_min, i_min] = min(PR_plot);

    fprintf('\nMinimum Power Required: %.2f ft-lbf/s\n', PR_min);
    fprintf('Velocity at Minimum PR: %.2f ft/s\n', V_plot(i_min));
    fprintf('AoA at Minimum PR: %.2f deg\n', alpha_plot(i_min));
    fprintf('CL at Minimum PR: %.3f\n', CL_plot(i_min));

    [TR_min, i_TRmin] = min(TR);

    fprintf('\nMinimum Thrust Required: %.3f lbf\n', TR_min);
    fprintf('Velocity at Minimum TR: %.2f ft/s\n', ...
            V_plot(i_TRmin));

end

if ~isempty(PA)

    fprintf('\n--- PROPULSION ---\n');

    fprintf('Number of Motors: %d\n', numMotors);
    fprintf('Power per Motor: %.1f W\n', motorPower_W);
    fprintf('Propeller Efficiency: %.1f%%\n', eta_prop * 100);
    fprintf('Useful Power Available: %.1f W\n', PA_W);
    fprintf('Useful Power Available: %.1f ft-lbf/s\n', PA);

end