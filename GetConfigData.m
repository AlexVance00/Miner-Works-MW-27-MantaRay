function data = GetConfigData(args)
% Reads a config. file, searches for the config. by name, which is passed
% in as an argument, and returns a struct containing the data, or an
% identifier that indicates that property is calculated as the output of a
% method specific to that configs. subclass dependent on state conditions.
%                                                    Returns data as struct
% -------------------------------------------------------------------------
% Arguments
%   1) configFile = config. file name, pass as string
%   2) configName = name of specific config. in config. file, pass as
%       string
% -------------------------------------------------------------------------
% Dependencies
%   #) <Dependency Filepath>
% -------------------------------------------------------------------------
% Assumptions
%   #) <Assumption>
% -------------------------------------------------------------------------
% Sources
%   #) <Source>
% -------------------------------------------------------------------------
% MATLAB Version <Oldest Version>, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
% -------------------------------------------------------------------------

    % Allows arguments to be optional and assigned in the function call
    %   as in: FunctionTemplate(<arg_name> = <arg_val>, ...)

    % List all argument names
    arguments
        args.configFile = [];
        args.configName = [];
    end
    arg_name_list = fieldnames(args);

    % List those argument names which are optional in 1D string array
    optional_arg_names = [];

    % Makes variables out of args' fieldnames
    for i_fieldname = 1:length(arg_name_list)
        arg_name = arg_name_list{i_fieldname};
        arg_val = args.(arg_name);

        % Input Checking
        % Checks if this argument was assigned
        if ~isempty(arg_val) 

            % Checks if assigned argument was string - all arguments passed
            %   should be strings
            if class(arg_val) == "string"

                % Initializes assigned arguments
                eval(append(arg_name, " = arg_val;"));
            else

                % If assigned argument was not string type
                error("Passed '%s' argument must be string type, but was passed as %s", arg_name, class(arg_val));
            end

        % If argument was unassigned, checks if it was optional
        elseif ~ismember(arg_name, optional_arg_names)
            
            % If unassigned argument was non-optional, throws error
            error("No input for non-optional '%s' argument", arg_name);
        end
    end

    splitChar = "%"; % Character denoting end of instructions section and beginning of configs.
    data = struct;

    % Unit Conversions

    % Intermediate Calculations
    % Take out instructions header
    rawText = readlines(configFile);
    splitLineNumber = find(rawText == splitChar);
    allConfigsText = rawText(splitLineNumber + 1:end);
    % Take out everything except config. of interest, filtered by
    %   configName
    configStartLineNumber = find(allConfigsText == "\" + configName + "\");
    remainingConfigsText = allConfigsText(configStartLineNumber:end);
    configEndLineNumber = find(remainingConfigsText == "\END\", 1);
    thisConfigText = remainingConfigsText(1:configEndLineNumber);
    % Remove header and footer lines
    thisConfigText = thisConfigText(2:end - 1);
    % Loop through lines
    for i = 1:length(thisConfigText)
        thisLine = thisConfigText(i);
        % Check if value is a string
        wordsOfLine = split(thisLine, " ");
        lastWord = wordsOfLine(3);
        lastValue = eval(lastWord + ";");
        varName = wordsOfLine(1);
        if ~isstring(lastValue)
            % If not, eval this variable and assign it to data struct
            eval(thisLine + ";");
            % Split line by spaces
            % First "word" is this line's variable name
            data.(varName) = eval(varName + ";");
        else
            % If this line's value was a string, check for whether it was a
            % filename or "correlation"
            if ~isempty(dir(fullfile(pwd, "**", lastValue)))
                % If the string was a filename, read in its contents
                cellData = readcell(lastValue);
                cellDataStringVersion = string(cellData);
                structFieldnames = cellData(1, :);
                numColumns = size(cellData, 2);
                % For this varName struct, make a field for each value in
                % structFieldnames, and assign the values under it in that
                % column in cellData to that field
                for j = 1:numColumns
                    data.(varName).(structFieldnames{j}) = [cellData{2:end, j}]';
                end
                % data.(varName)

            % Or, if the string was "correlation"
            elseif lastValue == "correlation"
                % Set value to "flagCorrelation" flag, as a string, that
                % will signal for the calling subclass object to
                % initialize/overwrite this value by running its
                % correlation method for this variable.
                data.(varName) = "flagCorrelation";
            % If the string was not a filename or "correlation", throw
            % error
            else
                error("Invalid string type value assigned to ""%s"" variable: ""%s""\n", varName, lastValue);
            end
        end
    end

    % Final Calculations

    % Display Results and/or Plotting

    return;
end