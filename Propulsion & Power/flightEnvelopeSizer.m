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
%   1) Reynold's number used for simulating airfoil data in XFLR5 was
%       418699.65, Mach number used was 0.04480
%   2) Various geometry values of the plane are estimated: c (only for Re
%       and M estimations), b, S, W, e (Oswald efficiency factor), and
%       eta_prop (propeller efficiency)
%   3) Air density constant at operating altitude (all operating altitudes
%       are low and close to each other, <= ~600 ft)
%   4) Currently, only set up to analyze one configuration at a time. That
%       is 1 airfoil, 1 motor, 1 propeller, 1 ESC
%   5) 2 motors, 1 ESC per motor, 1 propeller per motor, same airfoil for
%       entire vehicle
% -------------------------------------------------------------------------
% Sources
%   1) http://www.braeunig.us/space/atmos.htm
% -------------------------------------------------------------------------
% MATLAB Version R2025a, also compatible with:
%   - R2024b
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
airfoilConfigName = "e193r3";
motorConfigName = "Cobra_C3510_16";
propellerConfigName = "APC_8x6E";
ESCConfigName = "Aerostar_RVS_G2_30A";

%% Data read-in
airfoil = Airfoil(airfoilConfigName);
motorPropAssy = MotorPropAssy(motorConfigName, propellerConfigName);
thisESC = ESC(ESCConfigName);

% Airfoil data
a0 = airfoil.a_0;                      % 2D lift curve slope, 1/deg
alpha_L0 = airfoil.alpha_L0;           % Zero-lift AoA, deg
rawAlphaData = airfoil.c_d.alpha(:);   % AoA data, deg
rawcdData = airfoil.c_d.c_d(:);        % 2D/profile drag coefficient
% Geometry / Estimates
b = 9.56;            % span, ft
S = 10.73;           % planform area, ft^2
W0 = 9.3 - 24 / 16;  % no-payload weight, lbf
Wp = 24 / 16;        % payload weight, lbf
W = W0 + Wp;         % total weight, lbf
e = 0.67;             % Oswald efficiency factor
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
installedThrustLosses = 20 / 100; % percent to multiplier
% Include sweep angle to optionally account for motors being installed in
% slight off-axial direction, perpendicular to wing leading edge rather
% than straight ahead, pointing parallel with nose/body axis
sweepAngle = 25 / 180 * pi; % deg to rad
flagCountSweepAngleThrustLosses = true;
if flagCountSweepAngleThrustLosses
    sweepAngleThrustLosses = 1 - cos(sweepAngle); % multiplier, NOT percent. Basically, the
                                              % fraction of thrust that's lost due to thrust
                                              % vector not being perfectly in line with
                                              % vehicle's direction of travel
else
    sweepAngleThrustLosses = 0;
end
flagApplyThrustLosses = true; % Applies all or no thrust losses
if flagApplyThrustLosses
    totalThrustLosses = installedThrustLosses + sweepAngleThrustLosses;
else
    totalThrustLosses = 0;
end

% Atmosphere
rho = 0.0023769;     % Sea level air density, slug/ft^3

%% WITH PAYLOAD (ADD NO-PAYLOAD SECTION LATER)
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
RPMStringsAll = string(fieldnames(motorPropAssy.perfData.(bc))); % First 3 fields are RPMmax, nmax, and V. Ignore them
RPMStrings = RPMStringsAll(4:end);
RPMArray = zeros(size(RPMStrings));
vArray = zeros(vCount, numel(RPMStrings));
TAArray = zeros(size(vArray));
vpropmaxArray = zeros(1, numel(RPMArray));
% PShaftArray, shaft power, should theoretically be the same as available
% power, PAArray (defined once TAArray, thrust available, is)
PShaftArray = zeros(size(vArray));
PeArray = zeros(size(vArray));
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
    % Apply losses once all data is read in
    TAArray(:, R) = interp1(motorPropAssy.perfData.(bc).(RPMString).v .* 3.281, motorPropAssy.perfData.(bc).(RPMString).T, vArray(:, R)); % N
    % Read shaft power
    PShaftArray(:, R) = interp1(motorPropAssy.perfData.(bc).(RPMString).v .* 3.281, motorPropAssy.perfData.(bc).(RPMString).P, vArray(:, R)); % W
    % Read propeller efficiency
    PeArray(:, R) = interp1(motorPropAssy.perfData.(bc).(RPMString).v .* 3.281, motorPropAssy.perfData.(bc).(RPMString).Pe, vArray(:, R)); % 
end
% Apply losses and numMotors to TAArray
TAArray = TAArray * numMotors * (1 - totalThrustLosses);
% Apply numMotors to PShaftArray
PShaftArray = PShaftArray * numMotors;
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
% exceeded vpropmax. Delete those columns
validRPMMask = vArray(1, :) ~= 0;
invalidRPMs = RPMArray(~validRPMMask);
for i = 1:numel(invalidRPMs)
    fprintf("Stall speed %.2f ft/s was greater than max propeller speed %.2f ft/s for %d RPM: ignoring data\n", vstall, vpropmaxArray(i), invalidRPMs(i));
end
vArray = vArray(:, validRPMMask);
TAArray = TAArray(:, validRPMMask);
PShaftArray = PShaftArray(:, validRPMMask);
PeArray = PeArray(:, validRPMMask);
PAArray = PAArray(:, validRPMMask);
qArray = qArray(:, validRPMMask);
CLArray = CLArray(:, validRPMMask);
alphaTrimArray = alphaTrimArray(:, validRPMMask);
CDArray = CDArray(:, validRPMMask);
DArray = DArray(:, validRPMMask);
TRArray = TRArray(:, validRPMMask);
PRArray = PRArray(:, validRPMMask);
RPMArray = RPMArray(validRPMMask);
vpropmaxArray = vpropmaxArray(validRPMMask);

% Set negative excess T and P vals to 0 for visualization convenience in
% surfplot
TExcessArray = TAArray - TRArray;
TExcessArray((TExcessArray < 0)) = 0;
PExcessArray = PAArray - PRArray;
PExcessArray((PExcessArray < 0)) = 0;

flagPlot = true;
if flagPlot
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
    surf(axTSurf, vArray, RPMMesh, TExcessArray);
    
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
    surf(axPSurf, vArray, RPMMesh, PExcessArray);
end

% Cruise speed evaluation
% Find alpha for min cd
[~, alphaMinCDIdx] = min(cdDataPoscl);
alphaMinCD = alphaDataPoscl(alphaMinCDIdx);
CLcruise = a * (alphaMinCD - alpha_L0);
vCruise = sqrt(W * 2 / rho / CLcruise / S);
fprintf("Cruise speed is %.2f ft/s, cruise angle of attack is %.2f degrees\n", vCruise, alphaMinCD * 180 / pi);
% Besides level flight, cruise is also at zero acceleration. Find at what
% RPM this vcruise value is close to the speed at which TExcess becomes
% zero
% Finds, in each column of TExcessArray, the first row index where those
% values reach 0
% Can assume all columns will eventually reach zero
[~, rowIdx] = max(TExcessArray == 0, [], 1);
flagHasNonzero = TExcessArray(1, :) > 0;
rowIdx = rowIdx(flagHasNonzero);
% First argument, vArray with the complicated index, it just finds what
% number element in vArray, from 1 through the total number of elements in
% vArray, each index in rowIdx corresponds to. The index values in rowIdx
% are already organized by column, each column's value represents the index
% in the corresponding column in vArray to pull the value from. They're
% just not all in the same row, so it has to be more complicated than just
% finding every column's value in vArray for a given row- that row changes
% for each column
% Also, only look at vArray's columns that actually contain a max speed
% higher than vcruise. Make a temporary vArray for this that ignores those
% invalid columns
vArrayValidCruise = vArray(:, flagHasNonzero);
RPMCruise = interp1(vArrayValidCruise(sub2ind(size(vArrayValidCruise), rowIdx, 1:numel(rowIdx))), RPMArray(flagHasNonzero), vCruise);
fprintf("RPM for cruise speed %.2f ft/s is %.0f\n", vCruise, RPMCruise);
% Can also find cruise thrust
TAArrayValidCruise = TAArray(:, flagHasNonzero);
TCruise = interp1(vArrayValidCruise(sub2ind(size(vArrayValidCruise), rowIdx, 1:numel(rowIdx))), TAArrayValidCruise(sub2ind(size(TAArrayValidCruise), rowIdx, 1:numel(rowIdx))), vCruise);
fprintf("Cruise thrust is %.1f lbf\n", TCruise * 0.224809); % N to lbf
%{
%@@@@@@@@@@@@@@@@%%#**++++==+++======++++++==++++++++++++*******#****+++=++++****++++****************######%###%%%%%%%%%%%%%%%%%%%%%%%%%%%@%%%@@@@@@@@@@@@@@@@@@@@@@@@@
%%@@@@@@@@@@@@@@%%%%#**++================+===+++=+++++++=+++++++++++*****+++************#****##********#######%%%%%%%%%@%%%%%@@%@@%%%@%%%@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@
#%@@@@@@@@@@@@@@#**###++++==============================---::-====+++++++++++*******###********#*******###########%%%%%%@@%%%%%%%%%%@@%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#%@@@@@@@@@@@@@@@##**++=================================----::--::----========+*+++++++++++++++*****#############%%%%%%%%%%%@%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
%%@@@@%%@%@%%%%%%#%#*++=========+=============++++=+=+++=====+++====----========++==+==+=+++=+==+++**#######%%####%%%%%%%%%%%%%%%%%%%%#%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#%@@@@@%%%#%@%####****+=======================+===========-=======++++++++*******************++=+++****####################%###%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#%@@@@@%%@@%#*#####+=+=====-=====++=========+++++=======-----====+++==+++=+++++++++++****+****++++++******##############%##%####%%%%%%%%@%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#%@@@@@@@@%##@%#****+=============+++=++++=+++++++=+++===-=++============+==+++=+++++++++++++****************#*###################%#%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@
##@@@@@@@@@@%%%*+**+===-----=====+===+===++++++++===+=====+===-===================++++*++++++++*****##############%##############%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@
##%####@@@@@@@%*++++==------=============+==========-=========+++++======+=+==--===++++*++++++******##########%%%%%%%%%%%%#%%%%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@
##*++*%@@@@@@%#*==+====--=-======+++===+++===-----=-------===-====++++**+++++++++****#**#********#**#######################%%%%%%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@%@@@@@@
##+=+#@@@@@@@%%*====--==--=======+=====++++++++==++=----:-:---=---====++++++++*++++*************************#################%%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@
##++*#%%%@@@%%#*=-===-=---===================++++++++*****++++==----:--===+++++++++++****++++****++**********###################%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
##=-=#%%@@@@@@%+---=====--==-=====+===--============+===-++=+++++===--===-======++==++****#*******#*#######%%%%%%%%%%%%%%%#########%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@
#+--+#%%@@@@@@%+--=-=============+++======----------============++=+=::-:-:---===+=+++***+****#*###*######################%%%%%%%%%%%%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@
%=-:+###%@@@@%#+-----====+====+++++*+++====---===----=------==-=+++++====---=-==++++++=+++++****#**************###############%%%%%%%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@
%+--+#*#@@@@@%*=--=-======+++++****++======----==--:::---:---=-=++=++==-==-=-=====+++=++++++*++*****++*********#########*####%#%%%%%%%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@
%+--+#*#@%@@@%+------===++********++=======------::::---:---=-===++++=====---==============+*+++***********#*#*###############%%%%%%%%%%%%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@
%+-=+***%@@@%#=--------*#++=+*++*++++===-=+===--------==---==---========-----==-===-======+++=+++**********################%%%#%%%%#%%%%%###%%*#%%%%@@@@@@@@@@@@@@@@@@@
#+-=**++%@%@@*=-:---=+**++++#****+++++++*+=+***++*#**+*++=+==:---=====-=-=-:-====-==-====++++++++************#########%%###%%%%%%########%#%%#*##%%%%@@@@@@@@@@@@@@@@@@
#+-=**=*@@@@%+-::-:--+=-+-+++*=*********#######*##*+**+*++---==----=====--:::--====-=--=++++++++++++******#*##%%###%%%%%%%%%%%%%%%%####*#####+*###%%%@@@@@@@@@@@@@@@@@@
%*==*+=*@@@@#=-::..:----==-*++*+**+*#***+*#****##+=***+*++-===:==--:---=-::-:---=--:==-+**********#%#######%%%@%%@@@@@@@@@@@@@%%%%%%#*****##**####%%%%@@@@@@@@@@@@@@@@@
#*-====%@@@%*=-:::...:-::-==+++++******#***+++++++==+***+=--=--+-::::--=-:::::::---===+***############%%%%%%%@@@@@@@@@@@%@@@@@@@@@%%#*=-=+*+*=##**%%%%@@@@@@@@@@@@@@@@@
##=--:+%@@@#=::-:.:.......::-=-:--=+++***##%#*#%*#*=**+++#-=-+---::::---::.::.-.::-=++*#######**###%%#%%%%%@%@@@@@@@@%%%@@%%@@@@%@%%%%##++*=-*#####%%%@@@@@@@@@@@@@@@@@
##+---*@%%%=-:-:::...............::----=+=*##*****+===++=+---=---:::::=-....:::..-=+*++*#%%##*+*##########%@@%%%%%%%%@@%##%%%%%%%@@@%#%+-=+===**####%%%%@@@@@@@@@@@@@@@
##*-==#@%%+---:::..........::-+#+-+*-#%%%%@%%@#%@%%#=*+=-----::::..:.::...:..:.::-=**+##*###**#########%#%###****++****#*#####%%%%%%%%%#--++=++*#*###%%@@@@@@@@@@@@@@@@
*#*===#%%*-----:::.......:=*##**%*=-:#@%#@@@@@##%%**#*=-==--:.........:......:----=+****#**#***#########***+++==++++++++**##########%##*-*#***+*#*###%%@@@@@@@@@@@@@@@@
*#*==+#%#+--:--:::......-==++*#%%%%+:=%%*:-#%###%*++*#%*::+===:.......::::.::----==+++*++***##%%@%%%%**%@@@@@@@%%#====+++*****########%%#***#***###*##%@@@@@@@@@@@@@@@@
*#*==+#%#=::::::::::..::--=++=+*##%%%%#@@*@@@@%%**####%%@*=*==+=:....:::::-::-=++**####%@@@@@@%@@@@%#%@@@@@@@@%%@@%@@@%#*+*****#########%######**#**##%@@@@@%@@@@@@@@@@
*#*==*#%#-:::-::::::.::----===-++#%%*+*##%%%#%%%##%%%%@%%%%=+#*+=:..:::-:-----=+##%@@@@@@@@%%%@@@@%##%@%@@%*@@%%@%#%%@@@%%%#****##################****#%@%@@@%@@@@@@@@@
#%*-=+*#*-::::::-:::::--------:-=+*#+*=++==++=#+*****#####%#***+*-..::---=====+#*#@@@@@@@%%%@@@@%%##*#@%%#*#@@@@@@%%%%@@@@@@@#***#*################***=%%%%@@@@@@@@@@@@
***-:-=+=:--::::-------=----:::.:::-=---:-----====+=++*++++==-=++-:::--==+=+==+*#%@@@@@@@@@@@@@@@@@%#*%@%+@@@@@@@%###%###@@@@%##**################***+-%#%#%@@@@@@@@@@@
***-.:---::::::-----=====--:-::..........:.::----====++++-=--:=+=:::-=====++++**##%@@@%%%@%%%%@@@%%%%%%%#*##@@@%##%*###%%%@@@@%#####**###########*+++==*##%@@@@@%@@@@@@
**#=:..:-::::-:------=====------:...:::.::::--==-====+++++==-=++::::--==+=-=++***#%@@@@%%%%%%######**#**##*#########%%#%#%%##%%%####**############*+:---**%%@@@@@@@@@@@
****-:..-:::::::-----=====---------::::...:-==-=========+====++-::--===-==+++*%#*##%%@@%%%%%%%%##*****++#*###%########%%%####*#######***#########*#=--::++%%@@@@@@@@@@@
***#=.....::::::-----===+======--::-:-:---====-============+++-::-===-===++**%@####%%%%%%%#%%%%####**++=+=++*#-*#*##################****##########*==-:.=#%%@@@@@@@@@@@
**###:....:::::------==++++==+==--------==-==--==============-::::-======+++**@########%%%###########****+++++++++*************###*********#######*--=::++%@@@@%@@@@@@@
####%=....::::-------============---::-:::=-::----=-=----====-:::--===-==++***#%########%%##%####*********++++++++++++*********************#######+=:*-*-#@@@@@@@@@@@@@
#####+....:.:-::--------==-==+====-=--::--:---=-=====----=---::::-=====-=++#%##%%###########%####***#**+++++=+++++++++++******************######+#+=:-*:+#@@@@@@@@@@@@@
#####%:.....:-::.-::-----=-======++==-:------:::--=-:::-----::..:::---=-==++**%%########*########*#*+**++*++++=+++++++++**********#*+****########**+-+=-+%@@@@@@@@@@@@@
######+.....-*-::---::----=----======-=--=-=--=+==---------::..:::-=-=-====+#@@#%########**#########*+*+**++++++++++++++*****+***********#######++*:==::=%@@@@@@@@@%%%%
#######=..::=*-:--:-----::-:----==----:-=-------=-=-------::::::-====--+##%##%#%%#########**########****++++=+=++++++++*****+++++++*****########*-----:-+@@@@@@@@%%####
*#######-.::=*=..:::::-::::--:-------====--======-----==-::::--========+**###%%%%########******#**#####*****+==++++++++++*+++++++********#######+==-==-=#@@@@@%%###*++#
*******##=..:+=:::::::::::--:::------===--=-----=----=----::-==+===-==++**#%%##@%#######*##*#******#***+*+**=++++++++++++++++++*+********#######*==+=++=#@@@%%%%###*++#
*********#*.:-=-::::::::-::---::---====+===--===----=----::-======--:=+**+####%%%#######*********++****+=++*++++==++++++++*+++++++****########*##+=*+*+*%@@@@%%%##***#*
************-=+-..:::::::-.::::-:----:-====-==-------=-::::=+++===---=+**#**##%%########*****************++*-=+++++++++*++*+++*********#########*#**====@@@@@%%%%#####*
+****++++++*=:=-:...::.::::::--::::----==-===------=---:::-+++=====:--+++*+***###########**##*****+****++++==++++++++++++*++**+******##########*#*+====#@@@@%%########*
++++++++++++=:--......:::.:::::-:::::---=--=-------::-::--=========--=++**+**################********+**+++++-++++++++***+**********#######%%##*++*+-:-%@%%%%#########+
++++++++++++=:-=:.......::::::::::-------------=-==--::==-====+=----===+***++####%####%%%#####****++++++++=++-=+++*+*++*+**********#######%%##=*+==*=-=%@%%###########@
++++++++++++=::-:....:.....::::::::::::-----=-----::.:==---====------=+*+**++*###%%###%%%%####***++++====++===-=++**+++++**********#########%%*++---=-+%@%%#########%@@
++++++++++++=:::-..:......:::::::::::-----==----::::.==-:---==----=-=-=++****+*#######%%%%##******++++++++=++===++***++***********###########=*==+:=---@@%%#######%@@@@
+++++++++++++::=-..:....:.....::::::-:::---:-:::::::---:::---=--------=+++****#########%@%%#****++=-++++++=+++=-=+************#*############++-=-=-.:-=@@@%%%%%%@@@@@@@
+++++++++++++::--=:.......:...:::--:-----:-:--::::::::::...:-:::-----===+++**##########%@%###*+===+=====++++=++-=+++++********#*############+-+--=+:=-=@*-#@@@@@@@@@@@@
+++++++++++++::++**-..........::::::-:::::::--:::::-:.......::..::::--==++**############@%#*===--==========++++==**++********##############**=*++++:---+::*@@@@@@@@@@@@
+++++++++++++-:-+==-.......:.:::::::::::::::-:-:::--::-=#%+....::::--==++*****##*######%@%*+=------+-==-=====*=+****++****##**##########%%#*=++++-=-==--::#@@@@@@@@@@@@
+++++++++++++-::=#%-............::::::::::::---:--------+#%*:..::---==++******+++++**##%%#*+===---=-=====-==:=************#*####*#####%%%%###=*=-=+:-=-::-#@@@@@@@@@@@@
+++++++++++++-:-=*+=:...:......:..::::::::::::------=-=++:=#*:..::-=+++*##%%@@@@%+=+*#%%%#***++====--==-++--:+***************##########%%#%%===+-==:-=--:-%@@@@@@@@@@@@
++++++++++++*=:---=-:.:............:.:::::--:-------===++*+-:-:.:::-=+*#%#%######***#%%##****+++===-==========++*****++****############%%###=*#+=-==--:::-%@@@@@@@@@@@@
++++++++++++*=:-:-*=:::...........:::::::::-------=======++==#@=-:--=*##*****#*########******+++=========+===+++*++********#**#*######%%%###+*==++-=+-:..=%@@@@@@@@@@@@
++++++++++***=::::::...............::::--::----=--=====+=--=*@@+==-===++++***########********+++++=======+=++++++********##**########%%%%%%%#*#*+-==--:::-%@@@@@@@@@@@@
++++++*+******::::.:...............:::::::-------===+++=+==+%@@#====+===***#####**###********+++++++====+++++++*+++******#****######%%%%%%%#****+=-:--:::=%@@@@@@@@@@@@
++++**********-:-::.:...............::::--------===++++*+++*@@##+=++==--==+*########******+++++++++++=++++=+++++*+++***#********###%%%%%%%%###%*=++=--:::=%@@@@@@@@@@@@
**+**********#=:::.........:.......:::::--:----=====*+=++=++#%##==++=-==+++*####*####****+***++*+++=+++++++*++*+**+****##******####%%%%%%%%#*##**==++=:::=%@@@@@@@@@@@@
***********###*::-:........:........:::::::-----====+===*++===++==++--===+*+******##*****+******+*++==++++++++*********###*****###%%%%%%%#%%*###**+==-:::+@@@@@@@@@@@@@
***********####-:::.................:::----::---::--=========--==++==----==+***#*******##***#*****++++++++++************####*#####%%%%%%%%##%***##+*+-:::+@@@@@@@@@@@@@
*********#####%+:::........:........::--------:::.::-------==========+====++*********+**************++++++++*#******#***##########%%%%%##%%%%%##*+**+-:::+@@@@@@@@@@@@@
********#####%%%-::........:....:..::--------::...:--:-============+++++==++++******+**************+*+**+++++******#*##########%%%%%%%%%#%%%%#####**+=-::+@@@@@@@@@@@@@
********#####%%%#-::...........:...::::-===+**+=--::-=-=++=++++==+=+==+=+++************************++++**++++**##*****############%%##%%%%%%%%#*#***+=-:-*@@@@@@@@@@@@@
*******######%%%%+.:...........:::.::--=+=+++*#%%%%%%%%###********++==#####%#######**##*#***######**+++++++++**##*****###########%%%%%%%%%###%###*##*+-::+@@@@@@@@@@@@@
*******#####%%%%%%=................::-=======++**##########%%%%%%%#*##%##%##########%%%%%%%%%%@@@%#*+++++++++***##****##########%%%%%%%%%%%###%%####*+=::+@@@@@@@@@@@@@
*******#####%%%%%%#-...............::-====-==-==++****#*##########%%%%%%%%%%%%%%%%%@@%@%%%@@@@@@%%#*+++===+++++*##***##########%%%%%%%%%%%%%%%%%#%%##+--:+%@@@@@@@@@@@@
******#######%%%%##*-..............:-====--+=-:-=========+++**+*****+*****#########%%###############*========++**#############%%%%%%%%%%%%%%%%%%%%%%#*=::=%@@@@@@@@@@@@
******######%%%%%##*+:.............::-========----=====================+++++*+*****#***#############*===---==++**###########%%%%%%%%%%%%%%%%%%%%%%%%#*=-:+%@@@@@@@@@@@@
*****######%%%%%%##*+-:..........:.::---==--==-----=---===-===+*++++++++++*++*+********#########***#*+======++**###########%%%%%@%%%%@%%%%%%%%%@%%%%##+--=%@@@@@@@@@@@@
******######%%%%##**+-:::....:::::::-----=+==-------=======++++***********+++++++***********#*#*******+====++***###########%%%%%@@@%%%%%%%%%@@@@@@%%##*-:=#@@@@@@@@@@@@
******######%%%%###*+-...-::::::::::--=======-=------======+++******#*****+++++++***#******#*#********+++++++*+*#########%%%%@%@@@@@@%@@%@@@@@@@@%%%#*+-:-#@@@@@@@@@@@@
******#######%%%###*+-:...------:::-----========----========++**+********+*+++++++*********************+**++***#########%%%%@@@@@@@@@@@@@@@@@@@@%%%###*-::+@@@@@@@@@@@@
******########%%###*+=:....:=----:-=----=++================++***********###**++++++++++******************+******###%%###%%%@@@@@@@@%@@@@@@@@@@@%%%###*+-::=#@@@@@@@@@@@
******#############**=-.....-*==---=---==+++++++++========+++****+*+*****##*****+++++++*****************+*****#####%%%%%%%@@@@@@@@@@@@@@@@@@@%%%#####*+=-::=#@@@@@@@@@@
*******############**+=:....-**++======+*+++++++=========*++*****++=+*+**+***********+**************##****######%%%%%%%%%%@@@@@@@%%@@@@@@@@%%%#######*==::::=#%%%%%%%@@
********###########***+-:...-*+=++====++++*+++++==+==+++***+*+++++++*+++++*****#****#*******************######%%%%%%%%%%%@@@@@@@@@@@@@@@@@%%#########*++-:::-+#%%%%%%%%
*********###########***+=:..:**=+++++++***+++++++==+=+++***++++++++=++=******#*#######*******************####%%%%%%%%@@@@@@@@@@@@@@@@@@@%%############+==-:::=+#%%%%%%%
+**********###***#####***=-:.*#+=+*********++++++++==+++***++===-===+++*******#####********************+**##%%%%%%%%%%%%@@@@@@@@@@@@@@%%#############*++=--:::=+#%%%%%%
++*****************###****+=-*#*+++*********++++++=+++*****++==--=+==++*******#####*****+***********####*##%%%%%%%%%%%@@@@@@@@@@@@@@%################**++=-----=+#%%%%%
+++************************+=##*++*****##**+**++++++++*****+++=---=+*+****##***######*********#****######%%%%%%%%%@%%%@@@@@@@@@@@%%##***##****###*##**+++=-:---==+*#%%@
++++************************+##*******####******++++*******+++**+.=+*********###########*****###########%%%%%%@%%%%@@@@@@@@@@@@%####**####**########*****+=---====+*%%@
++++++***********************##*********####********++**#****+++**++**####***##############**##*###%%###%%%%%@@@@@@@@@@@@@@@@@%#***#****##***#######***#**==-==+++++*#@
+++++++*+++++++++************##*****#########*****++******#**********#########*####################%%%%%%@@%%@@@@@@@@@@@@@@%%%%#***#****##**######%######*++++*****++*%
++++++++++++++++++*+*********##********######%##*#####******##*****####%%#####################%####%#%%%%@@@@@@@@@@@@@@@%%%#########**####*#######%##*#********#####*+*
**+++*+++++++++++++++++******##***********#####%#*#########***########**#######*###%%####%%%%%%%%%%%##%%@@@@@@@@@@@@@@%%%###########**####*######%%%#######*#*##%%%###*
%}

% Get max speed capability
% Can assume will be at highest RPM
vMaxIdx = find(TExcessArray(:, end) > 0, 1, "last");
vMax = vArray(vMaxIdx, end);
fprintf("Max speed is %.2f ft/s at max RPM %.0f RPM\n", vMax, motorPropAssy.perfData.Battery3S.RPMmax);
% Can find max thrust
TMax = TAArray(vMaxIdx, end);
fprintf("Max thrust is %.2f lbf\n", TMax * 0.224809); % N to lbf

% Get power usage, continuous current, and capacity estimates
% Eventually, go through OpPhases and determine expected total power
% required and phase duration to get total Ah requirement of power plant
% for each phase, use that to size power plant's final form
% At first, just estimate based on a estimated total mission time and
% flying at cruise for that whole time with a design factor of 1.2
DF = 1.2; % design factor for required capacity of power plant
tMission = 5 * 60; % min to s
% Get power required to cruise
PShaftArrayValidCruise = PShaftArray(:, flagHasNonzero);
% Calculates total, so already accounts for number of motors/propellers.
% Account for DF and tMission later.
PShaftCruise = interp1(vArrayValidCruise(sub2ind(size(vArrayValidCruise), rowIdx, 1:numel(rowIdx))), PShaftArrayValidCruise(sub2ind(size(PShaftArrayValidCruise), rowIdx, 1:numel(rowIdx))), vCruise);
fprintf("Total required shaft power is %.2f W\n", PShaftCruise);
% PShaft is pre propeller losses, but post motor losses, which can be found
% by dividing PA / Pe / numMotors and seeing it's very close to equal to
% PShaft
% To go in reverse and count what power we actually need to provide from
% the power plant to run the propellers like this we need to get power
% losses in the motors, and power losses in the ESCs. Since PShaft is
% already accounting for power in both propellers, keep them lumped. This
% is a fair assumption because both motors are the same, and both ESCs will
% be the same. First, back-calculate power losses from motors
% Will need no load current, Io, at cruise, and EMF at cruise
EMFCruise = RPMCruise / motorPropAssy.motor.kv;
% Io technically changes with voltage, but just going to estimate motor's
% rated Io as constant
noLoadLosses = EMFCruise * motorPropAssy.motor.I_o;
% To get winding losses, need current in motor and then can use motor/shaft power
% Need to use per-motor shaft power though, right now it's lumped, so
% divide by numMotors. Gives per-motor current
IMotorCruise = PShaftCruise ./ numMotors / EMFCruise + motorPropAssy.motor.I_o;
% Then get per motor windinglosses
windingLosses = IMotorCruise^2 * motorPropAssy.motor.R;
% Then bring numMotors back in to get lumped motor losses
PLossesMotors = (noLoadLosses + windingLosses) * numMotors;
% Define new term, PPropulsion, which will keep track of total power required for propulsion system. Then add PLossesMotor to that new PPropulsion term
PPropulsion = PShaftCruise + PLossesMotors;
% Next, find power losses from ESCs. Again, assuming 1 ESC per motor, and
% that each is identical
% Voltage going into motor can be equated to the EMF that rotates the shaft
% plus that which is lost across the motor windings due to internal
% resistance
VMotorCruise = EMFCruise + IMotorCruise * motorPropAssy.motor.R;
% Throttle is basically the fraction of battery voltage that the motor
% voltage is set to
throttleCruise = VMotorCruise / motorPropAssy.perfData.Battery3S.V;
% Can get current supplied by battery by noting that the current through
% the motor, whose change is resisted by its inductance, is always "going
% through" the ESC, the MOSFETs effecting the PWM. However, current from
% the battery is only going through the ESC during the throttling duty
% cycle, and the two currents are related by that factor:
IBatteryCruise = IMotorCruise * throttleCruise * numMotors;
PLossesESCs = PPropulsion * (1/thisESC.eta - 1) * numMotors;
% And add those power losses to the total power budget, PPropulsion. Also,
% now account for DF and calculate capacity with tMission. This capacity
% would be the total mAh of capacity in the power plant that are estimated
% to be consumed by the propulsion system
PPropulsion = (PPropulsion + PLossesESCs) * DF; % W
fprintf("Nominal estimated power consumption of propulsion system with design factor of %.2f: %.2f W\n", DF, PPropulsion);
capacityPropulsion = IBatteryCruise * tMission / 3600 * 1000 * DF; % mAh
fprintf("Required power plant capacity for propulsion system with design factor of %.2f over mission duration of %.1f min (%.0f s): %.2f mAh\n", DF, tMission / 60, tMission, capacityPropulsion);
% Estimate nominal power draw from control system- start with receiver,
% then do servos
%% ---- In future, add functionality for accounting for receiver analytically ---- %%
% Archer R10+
% https://www.getfpv.com/radios/receivers/frsky-archer-r10-2-4ghz-receiver.html
WReceiver = 0.013; % kg
IReceiver = 0.1; % A
VReceiver = thisESC.VBEC;
PReceiver = IReceiver * VReceiver;
capacityReceiver = IReceiver * tMission / 3600 * 1000; % mAh
%% ---------------------------------------------------------------------------- %%
% Estimate of nominal power draw from control system servos
%% ---- In future, add functionality for accounting for servos analytically ---- %%
% Adrien's estimations based on some assumptions and conservative estimates
% 1. 8 servos. 2 high torque, 4 medium torque, 2 micro servos (torque
%   values not mentioned)
% 2. 5 minute mission
% 3. 85% BEC efficiency per ESC
% 4. 20% duty cycle for high and medium torque servos (control surfaces,
%   landing gear) and 5% for micro servos (payload release mechanism)
% 5. Servos at 6V
% Intial estimate of 0.61 Wh, conservative estimate due to limited
% information and potentially unforseeable additional required control
% surface manipulation, buff to 1 Wh
EnergyServos = 1; % Wh
VServos = 6; % V
% Convert to power. First conver to W-s, then to W
PServos = EnergyServos * 3600 / tMission;
% Get average continuous current draw to control system (servos)
IServos = PServos / VServos;
% Get total additional required capacity in mAh
capacityServos = IServos * tMission / 3600 * 1000; % Convert second term from Ah to mAh
%% ---------------------------------------------------------------------------- %%
PControls = PReceiver + PServos;
fprintf("Nominal estimated power consumption of control system with design factor of %.2f: %.2f W\n", DF, PControls);
capacityControls = (capacityReceiver + capacityServos) * DF; % mAh
fprintf("Required power plant capacity for control system with design factor of %.2f over mission duration of %.1f min (%.0f s): %.2f mAh\n", DF, tMission / 60, tMission, capacityControls);
PNet = PPropulsion + PControls;
fprintf("Net estimated power consumption with design factor of %.2f: %.2f W\n", DF, PNet);
capacityNet = (capacityPropulsion + capacityControls);
fprintf("Net required power plant capacity with design factor of %.2f over mission duration of %.1f min (%.0f s): %.2f mAh\n", DF, tMission / 60, tMission, capacityNet);

% Get power plant rating, W/lbf (power plant capability per unit weight of
% vehicle)
% Total weight of power plant
%% ---- In future, add functionality for accounting for battery analytically ---- %%
% Spektrum 2200 mAh 3S 30C LiPOo
% https://www.horizonhobby.com/product/spektrum-11.1v-2200mah-3s-30c-smart-g2-lipo-battery-ic3/SPMX223S30.html
WBattery = 0.225;
capacityBattery = 2200; % mAh
CRateBattery = 30; % Charge/discharge rate, C or 1/hr
fprintf("Battery capacity is %.1f mAh\n", capacityBattery);
%% ---------------------------------------------------------------------------- %%
% Used estimate weights from Meeks' slides for 2 high torque servos, 4
% "general use" servos, and 2 micro servos
WServos = 2 * 2.35 + 4 * 1.55 + 2 * 0.4; % oz
WPowerPlant = (motorPropAssy.W + thisESC.W) * numMotors * 35.274 + WServos + WReceiver * 35.274 + WBattery * 35.274; % Converts kg to oz for motor, prop, the receiver term, and the battery term
fprintf("Power plant weighs %.2f oz\n", WPowerPlant);
ICapability = CRateBattery * capacityBattery / 1000; % mA to A
fprintf("Max possible current draw is %.2f A\n", ICapability);
PCapability = ICapability * motorPropAssy.perfData.Battery3S.V; % W
fprintf("Power plant capability is %.2f W\n", PCapability);
powerPlantRating = PCapability / W; % W/lbf
fprintf("Power plant rating is %.2f W/lbf\n", powerPlantRating);

% Estimate endurance
finalChargePct = 30; % what pct of full charge to not take battery lower than so as not to damage it permanently
effectiveCapacityBattery = capacityBattery * (1 - finalChargePct / 100) / 1000; % convert from mAh to Ah
% Get net current in A
INominal = capacityNet / 1000 / tMission * 3600;
enduranceNominal = effectiveCapacityBattery / INominal * 60; % min
fprintf("Endurance is %.1f min\n", enduranceNominal);

%% NO PAYLOAD (LOWER WEIGHT)

%{
   .:   .:   -  .      .   + . +  =. :.  *    :   .  =                -         -   .  .    -.   :.    +   .      -    -    . :    +      
==+#%:#=#%=+=@:+#*#:+#*%:#-@=#+@==@#=%#*-@:#+*%++=@+ @+* .%@= *+#% *=-@ *+%+==++@.**#*=%*=*-#%-*=%%=+=+@-+*#+++**-@*+*=@***:%-%**--@+***+ 
==+#%.#=#%=+=@.=*+*.+##%:#-@=#+@==@*=%#*-@-#+*%++=@+ @*# .*@+ +*## +=-@ :-*-.:=+@.*#%#=%#-*-*%-*=%#-+=+@-+*#++***-@*+*=@*+*:%-%**-=@+***+ 
:#-**+%-#@*+=@#-*%#:*=#@.*-@+**@-=@#+*=*#@==**@++-@= %*@ .@**.=*=@:   :#@###+::.*=++.@=%#:**=@+:=#%+*=+@-=#@=-*+#.%%=#-@#*+:@++*%.=@%++## 
:#-#*+%=*%+==@*-*%#.*=#@.*-@***@-=@#+#+**@==**@++-@= %=@: @**:=-.-=@@@@@@@*%@@@@@:-*:@=%#.*+-%+-+%@*#+=@==*%+-#+%.%%=#-%#*+-%++*%==%%++*# 
.%++**%:#%*=*%*-=%#-*=*@ **@%.%@:+@#+**+#@+=**@++=@* %=@= @=*.:-%@@@@#%@@@@@@@@@@@=  *.%%-+*-*%:**%+++=@*:+@#-+**:%@-**+#+*+##==#+-%@*+** 
.#+=**%-###-*#%:=%#:++*@.*+%@.%@:+#%+**+*%*=+*@*+-@# *=@- %** .@@#==*@@@#++***%*@@@@@@ -*-=*-*@.#*%*=*-@*:+%*-=**-#@-+*+@+*-##+=#*-%%+**# 
.#+=**%:##%-+#@:=##:*+*@.*=#@-%@=**%+*++*%*+++@#=:@% ++@+ @%-.@@          ==-:-:**#@@@@#%-=*-*@.**%==+-@%:=#+-=**-*%-+*+@+*-#*==#+=@%-**# 
:%+=**@=#@#:=#@:-#@ +*-@ *+#@:@**-@#=**%*@+-#=@%=:%*  @%+.+# @@            :+*#*#*+#@@@@=.-%**@:*@**+*-@#-*@*==*#+*%=**+%=*=##*+*==%#+#*% 
.#++#*%-#%#-=#@:-#@ +*=@ *+#@:@*#-@#+#+#+@+-#=@%==%+- @#*:+=*@= :   .....-*=--+*#%@@@@%@@:-*==@-=%#++*-%%:*@*==*#=*@-=*+%=*=#%+=#++@%++*# 
 #++#=#:*##:=#@:-#@ =*=@ ++#@:@*#-@%+#+**@*-#=@%=-*== #**-+:@@  .         .+%#**###%@@@@@:=+-=@+-*@++*-%@:+#*-=**=*@:-#+%=#=*@=-%**@#+-+# 
.*#:@=#=*#%-=*@=:*@ +**@-#**@:@%+=*%==++#%+=*-%#--@*= #+*==:@# @@=* .  -@@@:.*@@@%=*@@@@@:-*+=@==*@*-#:%@:=%#=-*#-*@--#+@-%-*%*=#+-%@***%.
:##:%=#-**%==#@=-#@ +#-@+**+@.%@*+@@%##+#@#+#+@%+-++@+%*@#=+@@#: .@@+ :@@@*@@@@+*#%#%@@@@#.%-+@==*%#-#.%@:=%*=-*#-*@++=+@-%-+%*+#*-@@*++# 
:*#.%+%-*%%-+#@--+@ +#-@#*+*@.@#+@* -*#=*@@@@@@@@@@@#:##@*=*@@:@@@+  =@@:    =*:.:+%*@@%@@ @-*%+-*%%-#.#@:=##=-*#-*@++=+@-%-+#*=#*=%@*+*#.
.*%.%+%=#@#==#@+*+@ %@-@===*@-@#++   #@#-.     @   @@*%=%--%-@        @@-#.    :+%@%@%##@@ %==#*-*%%-#.#@==**=-*#-*%+=++@-%-*#%-*+=%%*++* 
.*%.%+%=#@#-=*%+*+@ #%=@*+=*@-@+-#@@@@@@@@@:  #@   %  .@@:-@=%     :@#@@@#    *%*%@#%%%@@# #=-@#=#%%-#:#@=-**+-#%=#@*=++@-%-*#%=#+=%%*=+* 
.## %#++*@+--+@+-+@ +#-@=++**+%#++#@*:++=@@@@  @+ =@% . @-@@#@:+     : :@*   *%%-###%%%#@--#+:%#=+%%=*-+@*:#+=-=#.+@=+*=@=**=##+*++%@%**%.
.## %#++*@*=-*@*-*@ +%-@+++##+@*+++@%*%+.== ..:@+ -%= .-@@        +*     +@*+*:+=@#%#@@%*=-#+-%#==%%=+-*@*:#*=-+%:*@=+*=@=**=##+*++#%#++#.
.%# %#==+%*==*@*-*@.+%=@-+=##*@*+=+%+=@@       @*  #= +=@%@@@@@@#+:.-*@@@@ =@*  =@#@@@%*++-#+-%#==@%-+-*@*:#+=-+%:*@=+*-@-++=##+*=+#%*++%.
 *@:#==**%#-:+@--*%.@*-@@@@@@@@-%+%%@=##@@    .@@  @  *@@%@@@@@@@@@@@-     - :.+#%%@%%@#+. -+*+*+-#@=*--%#-*#+-+@.#@+**=@=*+*=@=*++*%%+*# 
 *@:#+***%%--+@*:%% *@@:%    =@@@-##%+#@.  .@@@@@#@@%=@@##@@@%%@@%##@@@@@@#@=**#@@%%@@@@@@@@#=+#*=@%-*+=@#-#*+-+@.#@=+*=@=*+*=@=*++*%%+*# 
 *@.#*+*#%%==*@@.@@:+@#        =@=#%@=*@.      @@@@@@@@@@@@%@%%@%@@@%%%#%@@@*#%%%@@@@@#      ::*+=#*:=-:%+ -:: :* -*-=--#:=-=-#:-::*%%++#.
 +@ *#=*####-=@@@@% @@@       =*@-=+@*=*@@@:+  @@*#%%@@#*###%%@@@%@%%@@@%@%@%%%%@%   .   =++*##*##*%@%#=@@%#%#@@@@#@@@%%%%%%%@%%@@--**=+# 
.=@ ##=*##%.#+      :   +       @+##@#+*@*@@@@%@%---:. .+#*%@@@@@@%%@%@%@@@%@@@**@@@@@- @@@@%#*#%%#*#%%##%@@@@@%#%@@%#%#%%%%%+#@@#@@@%+*# 
:#@=*%+#%*%=++@@@@@ @@@@   @@@@@@*-*@#***%+=%*+#%=.=+#@@@@@@@@@%%@@@@%#%%%%%%%%@@%%%*@@%-*@@#%@%####%%%%@%%%%#%@%%#%##%########***#*#@@== 
.*@-+%+*##%=+=%% %@ -%@     #  =%* #@#+*#%*=#++%@*:%@@+       +%*####%@%%%@@%%@@%%@@%@@%%*=#@%%%%###%%%#%%%%%@@@@@@@@%@%#######%##%##@@%* 
.*%-+@=+%%%=+=%# @= .%@-@  :#:@*=@@%@#+*#@*=%**#@#@@      %.:  @@@#**@@%%#@@@%@@%%@%%%%#@=###@%@@@@%%@@@@@%%#@%#*%#@@@%@%%########%#%%@@= 
:#@==@++*%@+=*%@-@=       @@+=@@@% +%%*+*%=+#==@@%   ::@#:*:= @@ .@@@%+#@@#%@@@@@@@@%%%%@=###@%%%%%@@%%%%%%%%#@@*-.  .=+*##*#%#%%@%%@@@@= 
.#@==%**##@+#=@ #@% @@@+.       =*%@@%**%%=+#@%@  .%  .*=    -@-    @@@@@@@@@@@@%%@%@@@@@+%%%@@@@@@@%@%@%%%%#@@@%%@@=   -@@#%%#%#%##%@@@= 
.#@=+%####*.#-@:@       @      %@* -@@=-@#-+@@@   ** --*@+.* @@ @@:     @@@@@@@@@@@@%@@@##%##@@@@@@@@@%@%%%##@@@@@@@@@@@= :*#####%##%@@@= 
.#@-=%:**%#=*=+*:@@@@@@@.  @@@: ##*-#@==@@:#@#  *-@#:. #%    @=    -*%=      #@@@@@@@@*%@%@@@%##%@@%@@@@@@@@%@@@%@@@@@@@%#%@#####%@@#@@@: 
.*%-=#+#=@+==-@=-=+ +@:+@:@@@@@%@-++@@*=@#:@::%:--*+=- ##    @. *.     @* *  @  %.%@@@@@@@@#@@@@@@@@@%%@%%@%#@@@@@@@%%%@@%+-###%##@@#@@@: 
.#@-+*+#=@+:+.@+=***@%@  *@@@%##**=+#@*:@##%  @#*@#--: :@    @=  =*:  -+ @   #  +        -@@*+-=*%@%@@@@@@@%%@@@@%@@@@@%@@@@%@%%%%@##@@@= 
.#@-+#+#=@*-*:@#=*#-=#@   %%@%%%%*++%@#:@#*=  =+=%#-::  @+   @@   --. - +*   #  @@  *@%#* .#@@%%#*+#%@@%%@%%%@%%%%@@@@@@@@@@*###%#@#%@@@+ 
.#@-=#+%+@#+=*%#:=#=#+@   #@@=%%%*++#@*:@@. #%+*%+@. :+ .+*   @*   -=  =@ - == .@%  *@#*%%=-*%%#%%#%#%@@#%@@@@%@@%@@@@@@@@@@#%%@%%%##@@@% 
:*@=-*#%-@@*%*#****=+%@=  .@@*###+-=@@*##.+*+%##*%%   *   -=- .@#   -: @: * =  @@@  +**-*@++#%@%##*%%%@%%%%@%@@@@@%%%%%@@@@@#%###%##%@@@* 
.*@***#%-@+:+=**+++=*%@# :@%@@%@@#***@@=::+####**#@+  .*=      :#-  %@+@. =    @@:  ##*:=%##+*#*#%@%%%@%%%%@%@@@%@@@@@%@@@@@@@@@@@%%%@@@# 
.=*  :-= %  . ::.   .*%-   :%#*@@*-+@@-.*###%######@@    =    : :#+..    -:   :@@   #**:-=%@+#%##*###%%%@@@@%@@@%@@@@@%@@@@@@@@@%@@@@%@@# 
@@@@@@@@@@@@@@@@@@@@@@@    -*@%#*%%+--+#@%%####**=-*@@@@#@##-    :+==   ::-   @@@   %@@. *@%%##=#@%#%%%%%%@%%@@@%@@@@@%@%@@@@@@@%#%%%%@@@ 
**-:.   :=+%@@@@@@@@@#@=    -#%%@%#=@@@%%%%%###**#%@=  ..=**=       --=  .   =@@:  .@@@  -@@*#@=+@@#%%%%%%@%%@@@%@@@@@%@%@@@%@%%@%@%%@%@@ 
*%%@@@@@@@@@@@@@@@@@@@@#    :*###%@@@@#**#*##*+=+-@= *@@@@@@@@@+             @@@   .*@@   @@*%@:=#@%#%@%@%@%%@@@@@@@@@%@%@@@@@%%%%@@@@%@# 
%@@@@@@@@#@@@@@@@@@@#@@@    .##@%#%%@@####*#**%%+@@.#@@@@%@**+@@@@.:*@**=   *@@    +#%@   @@#%%++=@@#*#%@%@@@%%@@@@@@@%@%%%%%%%%%%%@@@%@= 
*%@%%@@@#*@@@@@@@@@@@@@@    .*+@##%#%@#*##*#*=.+@@ -@@##**#+-+-*@@@       :*=%    =%%@@-  @@#*@%* *@@#**%#%@@%%%%%%%@@%@@@@@#@@%%%@@@@%@= 
#@@@%%@#*@@@@@@%@@@%@%@@=   .*@@@@*##@%+#++*#@*@@:=@@+-+**=**++=+@@@@@#@@@@@#+*#@@@@@+   :@@+%%%*-:%@@##%%@@%@@@@@@@@@%@@@@@#%##%#%%@%@@+ 
#@@@@%@#*@@@@@@#@@@@@@@@@       -%@++@%+#*##**@@= @@+:=-===++++*=+@@@* %+%*=*#%@#.      #@@#+*%@#+-#@@%+%%@@%@@@@@@@@%%@@@@@#%#%##%%@@@@* 
#@@@%%@#*@@@@@@@@@%*@+@@@: @##.   @%%@%=*%%%%+@% +++=-++=-*+-=+*-:@@@@     -*@@@@@%%#@@@@#=.*+*@@*:-%@@**#@%#@@@@@@@@@%@@@@@##*###%%@@@@* 
#%%%%@##%@@@@@@@@@@@@@@@: -#%@#@ @@@@%#*%#%%@*@ #%++=-+-:%*:-:=#+:@@@@- -@@         :-=+%*@@@+##@@*:*@@@%#@@%@%@%%%%%%%@%@%@@@%@@@@%%%@@= 
#@@@%@@%@%@%%%%@@@@@@@   =*:.=++ @@@*++*@@%@@@  %*++=--.-@@+#*#%#=:@@%@@@  +@@@@@@@@@@@@@*. #@##@@@--*@@@#*@@@%@%%@@@@@%%@%%#@@%#%@@@@@@+ 
#@@@@@@@@@@@@@@@@@@@*   -  :+=+- @@@%%@@@@@@@@ +:*:-==@##@*-*#*++%.+@@@@@@@@#@@%@@%%@@@@@@@@#@@@@@%%+*@@@*=%@@%@@%@@@@@%%%%%@#*#@#%%@@@%+.
-++*******---::.=-               @%%####%#%@@            ++        :@@+@*%*@@%%%%%%%#*#%*%@@.    =%%+..#@*=*%@#####%%%%%%%**++++++**#%#-. 
%}

%% OUTPUT / CHECK VALUES
fprintf('\n--- Summary ---\n---------------\n');
fprintf('Aspect Ratio: %.3f\n', AR);
fprintf('2D Lift Curve Slope: %.4f 1/deg\n', a0 / 180 * pi);
fprintf('Finite-Wing Lift Curve Slope: %.4f 1/deg\n', a / 180 * pi);
fprintf('Airfoil AoA Range: %.2f to %.2f deg\n', min(alphaDataPoscl), max(alphaDataPoscl));
fprintf('Airfoil cd Range: %.5f to %.5f\n', min(cdDataPoscl), max(cdDataPoscl));