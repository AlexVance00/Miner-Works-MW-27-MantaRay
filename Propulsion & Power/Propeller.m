% Stores propeller data. Initialized with a configName input, which it uses
% to search the configFile for what data to pull.
% -------------------------------------------------------------------------
% Dependencies
%   1) propeller_data.txt
%   2) GetConfigData.m Version 2.1
%   3) Various PER3_xxxx.txt files
% -------------------------------------------------------------------------
% Assumptions
%   1) Performance data will come from .dat files from "Polar Diagrams" 
%       PER3 analysis files from APC's website
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
        manf % manufacturer
        size % size classification
        pitch % pitch, m
        d_prop % prop. diam., m
        d_hub % hub diam., m
        t_hub % hub thickness, m
        d_shaft % shaft diam., m
        W % weight, kg
        perfDataFilename % performance data filename
        perfData = struct() % performance data struct
    end

    methods (Access = public)

        % Constructor
        function obj = Propeller(configName)
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
                obj(numConfigNames) = Propeller();
            end

            % Assign obj properties values from data's fields for each
            % config name passed
            for i = 1:numConfigNames
                thisConfigName = configName(i);

                % This is where the assumptions about each config's
                % variables is useful
                obj(i).name = thisConfigName;
                obj(i).manf = data(i).manf;
                obj(i).size = data(i).size;
                obj(i).pitch = data(i).pitch;
                obj(i).d_prop = data(i).d_prop;
                obj(i).d_hub = data(i).d_hub;
                obj(i).t_hub = data(i).t_hub;
                obj(i).d_shaft = data(i).d_shaft;
                obj(i).W = data(i).W;
                obj(i).perfDataFilename = data(i).perfDataFilename;
                obj(i) = obj(i).readPerfDataFile();
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
        function obj = readPerfDataFile(obj)
            configFileSearchMatches = dir(fullfile(pwd, "**", obj.perfDataFilename));

            % Check if no matches were found
            if isempty(configFileSearchMatches)
                % If none were found, throw error- it needs to be found
                error("Propeller performance data file ""%s"" not found in working directory ""%s""\n", obj.perfDataFilename, pwd);
            end
        
            % If there's a match, continue. Use first match found, ignore
            % dupes
            filePath = fullfile(configFileSearchMatches(1).folder, configFileSearchMatches(1).name);
            rawText = readlines(filePath); % Read in data, it's a .dat so it can't be read in from a .csv or .xlsx, must be from .txt with readlines
            % Ignore everything before this phrase is first used
            splitPhrase = "PROP RPM";
            splitLineNumbers = find(contains(rawText, splitPhrase));
            allDataText = rawText(splitLineNumbers(1):end); %
            % Get rid of empty lines, but keep lines with numerical data,
            % column headers, and column unit labels
            allDataText = allDataText(contains(allDataText, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "Thrust", "Lbf"]));
            % Get lines where new RPM block starts
            blockStartLines = find(contains(allDataText, splitPhrase));
            % Make row of indices to navigate through when transcribing
            % data
            blockBorderLines = [blockStartLines; numel(allDataText)];
            % Loop through blocks
            for b = 1:numel(blockStartLines)
                i1 = blockBorderLines(b);
                % If this isn't the last block, subtract 1 from the end
                % index
                if b ~= numel(blockStartLines)
                    i2 = blockBorderLines(b + 1) - 1;
                else
                    i2 = blockBorderLines(b + 1);
                end
                % Get RPM
                thisRPMLine = split(allDataText(i1), " ");
                thisRPMMask = thisRPMLine ~= ["", "PROP", "RPM" "="];
                thisRPMIndex = all(thisRPMMask, 2);
                thisRPM = thisRPMLine(thisRPMIndex);
                % For first row, get column names
                colNames = split(allDataText(i1 + 1), " ");
                colNames = colNames(colNames ~= "")';
                numRows = i2 - i1;
                obj.perfData.("RPM" + thisRPM) = cell(numRows, numel(colNames));
                obj.perfData.("RPM" + thisRPM)(1, 1:15) = cellstr(colNames);
                % For second row, get unit labels
                unitLabels = split(allDataText(i1 + 2), " ");
                unitLabels = unitLabels(unitLabels ~= "")';
                obj.perfData.("RPM" + thisRPM)(2, 1:15) = cellstr(unitLabels);
                % For rest of rows, just read raw numbers
                for r = (i1 + 3):i2
                    thisRowData = split(allDataText(r), " ");
                    thisRowData = thisRowData(thisRowData ~= "")';
                    % Sometimes rows are incomplete, just set those rows to
                    % missing
                    if numel(thisRowData) ~= numel(colNames)
                        obj.perfData.("RPM" + thisRPM)(r - b - ((b - 1) * numRows), 1:15) = {missing};
                        continue;
                    end
                    obj.perfData.("RPM" + thisRPM)(r - b - ((b - 1) * numRows), 1:15) = num2cell(str2double(thisRowData));
                end
            end
            return;
        end
    end
end