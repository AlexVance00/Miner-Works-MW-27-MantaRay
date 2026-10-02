% Stores motor data. Initialized with a configName input, which it uses
% to search the configFile for what data to pull.
% -------------------------------------------------------------------------
% Dependencies
%   1) motor_data.txt
%   2) GetConfigData.m
% -------------------------------------------------------------------------
% Assumptions
%   #) <Assumption>
% -------------------------------------------------------------------------
% Comments
%   #) <Comment>
% -------------------------------------------------------------------------
% Nomenclature
%   <Symbol> = <Meaning> (<Units>)
% -------------------------------------------------------------------------
% Document Version <Oldest Version>, earlier versions:
%   - <Version>
% -------------------------------------------------------------------------
% MATLAB Version <Oldest Version>, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef Motor

    properties (SetAccess = private)
        name % the motor name/classification
        data % Temporary
    end

    methods (Access = public)

        % Constructor
        function obj = Motor(configName)
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

            configFile = "motor_data.txt";
            configFileSearchMatches = dir(fullfile(pwd, "**", configFile));
            % Check if no matches
            if isempty(configFileSearchMatches)
                error("Config file ""%s"" not found in working directory ""%s""\n", configFile, pwd);
            end
            % If there's a match, continue
            configFilePath = fullfile(configFileSearchMatches(1).folder, configFileSearchMatches(1).name);

            % Can assume what data will be in there because we know what
            % will be in the hardcoded configFile variables list
            numConfigNames = numel(configName);
            % If numConfigNames is not 1, flag there as being multiple and
            % preallocate array of obj types for speed's sake
            flagMultipleConfigNames = false;
            if numConfigNames ~= 1
                flagMultipleConfigNames = true;
                obj(numConfigNames) = Motor();
            end
            % Assign each obj type's properties values from data's fields
            for i = 1:numConfigNames
                thisConfigName = configName(i);
                data = GetConfigData(configFile = configFilePath, configName = thisConfigName);
                obj.data = data;                
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
        
        function result = FunctionTemplate(args)
        % <Function Purpose>
        %                                             <Output> in (<Units>)
        % -----------------------------------------------------------------
        % Arguments
        %   <Symbol> = <Explanation> (<Units>)
        % -----------------------------------------------------------------
        
            % Allows arguments to be optional and assigned in the function
            %   call as in: FunctionTemplate(<arg_name> = <arg_val>, ...)
        
            % List all argument names
            arguments
                args.arg_1 = [];
            end
            arg_name_list = fieldnames(args);
        
            % List those argument names which are optional in 1D string
            %   array
            optional_arg_names = [];
        
            % Makes variables out of args' fieldnames
            for i_fieldname = 1:length(arg_name_list)
                arg_name = arg_name_list{i_fieldname};
                arg_val = args.(arg_name);
        
                % Input Checking
                % Checks if this argument was assigned
                if ~isempty(arg_val)
        
                    % Initializes assigned arguments
                    eval(append(arg_name, " = arg_val;"));
                % If argument was unassigned, checks if it was optional
                elseif ~ismember(arg_name, optional_arg_names)
                    
                    % If unassigned argument was non-optional, throws error
                    error("No input for non-optional '%s' argument", ...
                        arg_name);
                end
            end
        
            % Unit Conversions
        
            % Intermediate Calculations
        
            % Final Calculations
        
            % Display Results and/or Plotting
        
            return;
        end

    end

    methods (Access = private)

    end

end