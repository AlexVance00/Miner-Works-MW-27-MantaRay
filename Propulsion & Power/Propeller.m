% Stores propeller data. Initialized with a configName input, which it uses
% to search the configFile for what data to pull.
% -------------------------------------------------------------------------
% Dependencies
%   1) propeller_data.txt
%   2) GetConfigData.m Version 2.0
% -------------------------------------------------------------------------
% Assumptions
%   #) <Assumption>
% -------------------------------------------------------------------------
% Comments
%   1) Vectorized. Pass in configName as an array and a same-sized array of
%       Propeller objects will be returned
% -------------------------------------------------------------------------
% Document Version 1.0, earlier versions:
%   - <Version>
% -------------------------------------------------------------------------
% MATLAB Version R2025a, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef Propeller

    properties (Constant)
        configFile = "propeller_data.txt";
    end

    properties (SetAccess = private)
        name % the propeller name/classification
        temp
    end

    methods (Access = public)

        % Constructor
        function obj = Propeller(configName)
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

            configFile = Propeller.configFile;

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
                obj(i).temp = data(i).temp;
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