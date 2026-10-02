% Stores airfoil data. Initialized with a configName input, which it uses
% to search the configFile for what data to pull.
% -------------------------------------------------------------------------
% Dependencies
%   1) airfoil_data.txt
%   2) GetConfigData.m
% -------------------------------------------------------------------------
% Assumptions
%   #) <Assumption>
% -------------------------------------------------------------------------
% Comments
%   1) Vectorized
% -------------------------------------------------------------------------
% Document Version 2.0, earlier versions:
%   - 1.0
% -------------------------------------------------------------------------
% MATLAB Version R2024b, also compatible with:
%   - <Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef Airfoil

    properties (Constant)
        configFile = "airfoil_data.txt";
    end

    properties (SetAccess = private)
        name % the airfoil name/classification
        a_0 % 2D lift curve slope, string (degrees^-1)
        alpha_L0 % zero lift angle of attack, numeric (degrees)
        c_d struct % 2D drag coefficient curve vs AoA, struct (alpha field has units of degrees)
        c_l struct % 2D lift coefficient curve vs AOA, struct (alpha field has units of degrees)
    end

    methods (Access = public)

        % Constructor
        function obj = Airfoil(configName)
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
                    configName = string(configName);
                end
            end

            configFile = Airfoil.configFile;
            
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
                obj(numConfigNames) = Airfoil();
            end

            % Assign obj properties values from data's fields for each
            % config name passed
            for i = 1:numConfigNames
                thisConfigName = configName(i);

                % This is where the assumptions about each config's
                % variables is useful
                obj(i).name = thisConfigName;
                obj(i).a_0 = data(i).a_0;
                obj(i).alpha_L0 = data(i).alpha_L0;

                % c_d needs to be either a set value or come from tabulated
                % values, so it's safe to assume this is already
                % calculated. Really it should always be from tabulated
                % values, so it should be a struct of its own, with a field
                % for alpha values and a field for c_d values
                obj(i).c_d = data(i).c_d;

                % Like with c_d, c_l can be a struct with appropriate
                % fields and arrays, but unlike c_d, the config could also
                % be set to "correlation" for c_l, which needs to be
                % checked for. Then it would need to be calculated upon
                % initialization of this Airfoil object
                % Check if data(i).c_l is a struct
                if isstruct(data(i).c_l)
                    % If so, pull it from data, which
                    % GetConfigData() returned. It's either a value or a
                    % filled-out struct already, which is what we want
                    obj(i).c_l = data(i).c_l;

                % If not, check if it was a string
                elseif isstring(data(i).c_l)
                    % If it was, check if GetConfigData returned
                    % "flagCorrelation", which signals to call c_l's
                    % correlation method
                    if data(i).c_l == "flagCorrelation"
                        % If so, call the Getc_l() method
                        alpha = obj(i).c_d.alpha;
                        obj(i).c_l = struct("alpha", alpha, "c_l", Getc_l(alpha));
                    else
                        % If not, its value was set to some string which is
                        % wrong
                        error("Invalid string type value ""%s"" set to c_l variable for ""%s"" config in ""%s""", data(i).c_l, thisConfigName, configFile);
                    end
                % If data.c_l was not a struct or a string, it's most
                % likely just a constant value, which is not correct
                else
                    error("Invalid value ""%s"" set to c_l variable for ""%s"" config in ""%s""", data(i).c_l, thisConfigName, configFile);
                end
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

        function c_l = Getc_l(alpha)
        % Calculates c_l based on alpha using airfoil object properties
        % -----------------------------------------------------------------
            c_l = obj.a_0 .* (alpha - obj.alpha_L0);
            return;
        end
    end
end