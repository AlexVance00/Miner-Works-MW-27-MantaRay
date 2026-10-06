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
% Look at Airfoil.m for how to read its properties

clc
clear
close all

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
airfoil = Airfoil(configName);
%Start here
% Airfoil data
a0 = airfoil.a_0;                    % 2D lift curve slope, 1/deg
alpha_L0 = airfoil.alpha_L0;         % Zero-lift AoA, deg
alpha_data = airfoil.c_d.alpha(:);   % AoA data, deg
cd_data = airfoil.c_d.c_d(:);        % 2D/profile drag coefficient

% Aircraft / atmosphere
rho = 0.0023769;     
b = 8.5;             % Wingspan, ft JUST A PLACEHOLDER FOR NOW
S = 11.33;           % Wing area, ft^2 JUST A PLACEHOLDER FOR NOW
W = 20;              % Aircraft weight, lbf JUST A PLACEHOLDER FOR NOW
e = 0.8;             % Oswald efficiency factor JUST A PLACEHOLDER FOR NOW

% Flight conditions
V_min = 10;          % Minimum velocity, ft/s 
V_max = 150;         % Maximum velocity, ft/s
numV = 500;
V_cruise = 60;       % Cruise velocity, ft/s JUST A PLACEHOLDER FOR NOW

V = linspace(V_min, V_max, numV);

% Optional propulsion inputs
% Leave motorPower_W = [] to suppress Power/Thrust Available plots.
numMotors = 2;
motorPower_W = [];   % Shaft power per motor in Watts
eta_prop = 0.8;      % Prop efficiency

% Convert propulsion power to useful propulsive power
if isempty(motorPower_W)
    PA = [];
else
    PA_W = numMotors * motorPower_W * eta_prop;
    PA = PA_W * 0.737562;            
end

% Wing geometry / finite-wing lift slope
AR = b^2 / S;

a0_rad = a0 * 180/pi;
a_rad = a0_rad / (1 + a0_rad/(pi*e*AR));
a = a_rad * pi/180;                  


%% POWER REQUIRED VS VELOCITY, LEVEL FLIGHT

% Level-flight lift requirement
q = 0.5 .* rho .* V.^2;
CL = W ./ (q .* S);

% Required AoA
alpha = CL ./ a + alpha_L0;

% Profile drag from airfoil data
cd = interp1(alpha_data, cd_data, alpha, 'linear', NaN);

% Total drag
CDi = CL.^2 ./ (pi .* e .* AR);
CD = cd + CDi;
D = q .* S .* CD;

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

CL_alpha = a .* (alpha_data - alpha_L0);
CDi_alpha = CL_alpha.^2 ./ (pi .* e .* AR);
CD_alpha = cd_data + CDi_alpha;

q_cruise = 0.5 * rho * V_cruise^2;
D_alpha = q_cruise .* S .* CD_alpha;
PR_alpha = D_alpha .* V_cruise;

figure
plot(alpha_data, PR_alpha, 'LineWidth', 2)
hold on

if ~isempty(PA)
    PA_alpha = PA .* ones(size(alpha_data));
    plot(alpha_data, PA_alpha, 'LineWidth', 2)
    legend('Power Required', 'Power Available', 'Location', 'best')
end

grid on
xlabel('Angle of Attack, \alpha (deg)')
ylabel('Power, P (ft·lbf/s)')
title(sprintf( ...
    'Power Required vs Angle of Attack at V_{cruise} = %.1f ft/s', ...
    V_cruise))


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

V_surface_range = linspace(V_min, V_max, numV);

[V_surface, alpha_surface] = meshgrid( ...
    V_surface_range, alpha_data);

CL_surface = a .* (alpha_surface - alpha_L0);

cd_surface = repmat(cd_data, 1, length(V_surface_range));

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
        min(alpha_data), max(alpha_data));

fprintf('Airfoil cd Range: %.5f to %.5f\n', ...
        min(cd_data), max(cd_data));

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