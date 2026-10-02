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
% Nomenclature
%   <Symbol> = <Meaning> (<Units>)
% -------------------------------------------------------------------------
% Document Version 1.0, former versions:
%   - <Later Version>
% -------------------------------------------------------------------------
% MATLAB Version <Oldest Version>, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef Airfoil

    properties (SetAccess = private)
        name % the airfoil name/classification
        a_0 % 2D lift curve slope (radians^-1)
        alpha_L0 % zero lift angle of attack (radians)
        c_d struct % 2D drag coefficient curve vs AoA
        c_l struct % 2D lift coefficient curve vs AOA
    end

    methods (Access = public)

        % Constructor
        function obj = Airfoil(configName)
            if nargin == 0
                return;
            end

            if ~isstring(configName)
                if ~ischar(configName)
                    error("Passed ""%s"" argument must be string or char types, but was passed as %s", configName, class(configName));
                else
                    configName = string(configName); % Useful for later when numel() and size() are used
                end
            end

            configFile = "airfoil_data.txt";
            configFileSearchMatches = dir(fullfile(pwd, "**", configFile));
            % Check if no matches
            if isempty(configFileSearchMatches)
                error("Config file ""%s"" not found in working directory ""%s""\n", configFile, pwd);
            end
            % If there's a match, continue
            configFilePath = fullfile(configFileSearchMatches(1).folder, configFileSearchMatches(1).name);
            data = GetConfigData(configFile = configFilePath, configName = configName);
            
            % Can assume what data will be in there because we know what
            % will be in the hardcoded configFile variables list
            numConfigNames = numel(configName);
            % If numConfigNames is not 1, flag there as being multiple and
            % preallocate array of obj types for speed's sake
            flagMultipleConfigNames = false;
            if numConfigNames ~= 1
                flagMultipleConfigNames = true;
                obj(numConfigNames) = Airfoil();
            else
            end
            % Assign each obj type's properties values from data's fields
            for i = 1:numConfigNames
                obj(i).name = data.name;
                obj(i).a_0 = data.a_0;
                obj(i).alpha_L0 = data.alpha_L0;
                obj(i).c_d = data.c_d;
                % Check if data.c_l is a struct
                if isstruct(data.c_l)
                    % If so, pull that struct from data, which
                    % GetConfigData() returned
                    obj(i).c_l = data.c_l;
                elseif isstring(data.c_l)
                    if data.c_l == "flagCorrelation"
                        % If not, check if value was "flagCorrelation" and
                        % call correlation method
    
                        alpha = obj(i).c_d.alpha;
                        obj(i).c_l = struct("alpha", alpha, "c_l", Getc_l(alpha));
                    else
                        error("Invalid string type value ""%s"" set to c_l variable for ""%s"" config in ""%s""", data.c_l, configName(i), configFile);
                    end
                else
                    error("Invalid value ""%s"" set to c_l variable for ""%s"" config in ""%s""", data.c_l, configName(i), configFile);
                end
            end
            % Make sure array of obj type is same size as configName, if
            % it's not 1
            if flagMultipleConfigNames
                obj = reshape(obj, size(configName));
            end

            return
        end
    end

    methods (Access = private)

        %
        function c_l = Getc_l(alpha)
        % Calculates c_l based on alpha using airfoil object properties
        % -----------------------------------------------------------------
            c_l = obj.a_0 .* (alpha - obj.alpha_L0);
            return;
        end
    end
end