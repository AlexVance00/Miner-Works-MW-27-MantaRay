% Stores motor data. Initialized with a configName input, which it uses
% to search the configFile for what data to pull.
% -------------------------------------------------------------------------
% Dependencies
%   1) motor_data.txt
%   2) GetConfigData.m Version 2.1
% -------------------------------------------------------------------------
% Assumptions
%   #) <Assumption>
% -------------------------------------------------------------------------
% Comments
%   1) Vectorized. Pass in configName as an array and a same-sized array of
%       Motor objects will be returned
% -------------------------------------------------------------------------
% Document Version 1.0, earlier versions:
%   - <Version>
% -------------------------------------------------------------------------
% MATLAB Version R2025a, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef Motor

    properties (Constant)
        configFile = "motor_data.txt";
    end

    properties (SetAccess = private)
        name % the motor name/classification
    	kv % kv rating (RPM/V)
	    I_o % No load current at 14V (A)
	    R % Resistance (Ohm)
	    I_max % Max continuous current (A)
	    P_max % Max power (W)
	    d_o % Outer diameter (m)
	    L_body % Body length (m)
	    L_shaft % Total shaft length (m)
	    d_shaft % Shaft diameter (m)
	    W % Weight (kg)
        perfData struct % performance data struct with fields for:
            %{
            propManf: propeller manufacturer
            propSize: propeller size
            V: input voltage (V)
            I: input current/motor amps (A)
            P_input: input power/watts input (W)
            RPM: propeller RPM (RPM)
            pitchSpeed: pitch speed
            T_g: thrust in grams (g)
            T_oz: thrust in ounces (oz)
            eta_T: thrust efficiency (g/W)
            colorRating: compatibility rating, from cobra:
                b: blue, The prop is to small to get good performance from the motor. (Less than 50% power)
                g: green, The prop is sized right to get good power from the motor. (50 to 80% power)
                y: yellow, The prop can be used, but full throttle should be kept to short bursts. (80 to 100% power)	
                r: red, The prop is too big for the motor and should not be used. (Over 100% power)
            %}
    end

    methods (Access = public)

        % Constructor
        function obj = Motor(configName)
            % If no arguments were passed, just return empty Airfoil object
            if nargin == 0
                return;
            end

            % Check if configName was correctly passed as string
            if ~isstring(configName)
                % Check if it was a char instead
                if ~ischar(configName)
                    % If not, it needs to be 1 or the other, so throw error
                    error("Passed ""%s"" argument must be string or char types, but was passed as %s", configName, class(configName));
                else
                    % If so, convert to string for ease later when using
                    % numel() and size()
                    configName = string(configName); % Useful for later when numel() and size() are used
                end
            end

            configFile = Motor.configFile;

            % Can assume what data will be in there because we know what
            % will be in the hardcoded configFile variables list
            % Get number of config names passed- configName could be an
            % array, this is vectorized
            data = GetConfigData(configFile = configFile, configName = configName);

            % If numConfigNames is not 1, flag there as being multiple and
            % preallocate array of obj types for speed's sake
            numConfigNames = numel(configName);
            flagMultipleConfigNames = false;
            if numConfigNames ~= 1
                flagMultipleConfigNames = true;
                obj(numConfigNames) = Motor();
            end

            % Assign obj properties values from data's fields for each
            % config name passed
            for i = 1:numConfigNames
                thisConfigName = configName(i);

                % This is where the assumptions about each config's
                % variables is useful
                obj(i).name = thisConfigName;
                obj(i).kv = data(i).kv;
                obj(i).I_o = data(i).I_o;
                obj(i).R = data(i).R;
                obj(i).I_max = data(i).I_max;
                obj(i).P_max = data(i).P_max;
                obj(i).d_o = data(i).d_o;
                obj(i).L_body = data(i).L_body;
                obj(i).L_shaft = data(i).L_shaft;
                obj(i).d_shaft = data(i).d_shaft;
                obj(i).W = data(i).W;
                obj(i).perfData = data(i).perfData;
            end

            % Make sure array of obj type is same size as configName, if
            % it's not 1
            if flagMultipleConfigNames
                obj = reshape(obj, size(configName));
            end

            return;
        end
    end

    methods (Access = private)

    end
end