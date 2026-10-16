% Stores ESC data. Initialized with a configName input, which it uses
% to search the configFile for what data to pull.
% -------------------------------------------------------------------------
% Dependencies
%   1) ESC_data.txt
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
%   - R2024b
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef ESC

    properties (Constant)
        configFile = "ESC_data.txt";
        % Estimation of efficiency, based on this paper. Rough,
        % conservative estimate. ~18A 920KV 3S battery/motor config,
        % ~10kRPM at no load, across various throttles, 82-94% ESC
        % efficiency
        % https://drum.lib.umd.edu/items/99aa1e18-8a78-4029-a7c8-6bf2b5f18d6c
        eta = 0.82;
    end

    properties (SetAccess = private)
        name % the motor name/classification
        Icont % continuous current (A)
        W % weight (kg)
        type % "brushless" or "brushed"
        VBEC % BEC (battery elimination circuit) voltage (V)
    end

    methods (Access = public)

        % Constructor
        function obj = ESC(configName)
            % If no arguments were passed, just return empty object
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

            configFile = ESC.configFile;

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
                obj(i).Icont = data(i).Icont;
                obj(i).W = data(i).W;
                obj(i).type = data(i).type;
                obj(i).VBEC = data(i).VBEC;
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