% Stores complicated data for configuration combining motor and propeller
% into one structure
% -------------------------------------------------------------------------
% Dependencies
%   1) Propeller.m Version 1.0
%   2) Motor.m Version 1.0
% -------------------------------------------------------------------------
% Assumptions
%   1) motorConfigName and propConfigName will be 2D and the same
%   length
% -------------------------------------------------------------------------
% Comments
%   1) perfData contains performance data resulting from combining the
%   motor with the propeller, and has 1 field per compatible battery
%   configuration the motor and propeller can run with. For example, if a
%   motor and prop can be used together either with a 3S power plant or a
%   4S one, perfData will have a "Battery3S" field and a "Battery4S" field
%   2) If both are mx1, that's fine, and if motorConfigName is mx1 and
%   propConfigName is 1xm, that's also fine. The returned array will be the
%   same size as motorConfigName, mx1 in this example
% -------------------------------------------------------------------------
% Document Version 1.0, earlier versions:
%   - <Version>
% -------------------------------------------------------------------------
% MATLAB Version R2025a, also compatible with:
%   - R2024b
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef MotorPropAssy

    properties (Constant)
        LiPoBatteryVnom = 3.7; % nominal LiPo battery voltage for 1S battery
    end

    properties (SetAccess = private)
        motor Motor
        propeller Propeller
        perfData = struct() % performance data struct with fields:
            % RPMmax:  max RPM of assy
            % nmax:    max revs/s of assy
            % v:    Speed array, m/s
            % T:    Thrust array, N
            % P:    Power array, W
        W % weight kg
    end

    methods (Access = public)

        % Constructor
        function obj = MotorPropAssy(motorConfigName, propConfigName)
            % If not enough arguments were passed, just return empty
            % objects
            if nargin == 0
                return;
            end
            % If only 1 was passed, it must have been the first mandatory
            % argument, so generate 1 MotorPropAssy for each
            % motorConfigName passed
            if nargin == 1
                % If numMotors is not 1, flag there as being multiple and
                % preallocate array of obj types for speed's sake
                numMotors = numel(motorConfigName);
                flagMultipleMotors = false;
                if numMotors ~= 1
                    flagMultipleMotors = true;
                    obj(numMotors) = MotorPropAssy();
                end
                for m = 1:numMotors
                    obj(m).motor = Motor(motorConfigName(m));
                end
                % Make sure array of obj type is same size as motorConfigName, if
                % it's not 1
                if flagMultipleMotors
                    obj = reshape(obj, size(motorConfigName));
                end
                return;
            end
            % Check if args are the right size
            if ~isvector(motorConfigName)
                error("motorConfigName was not passed in as vector\n");
            elseif ~isvector(propConfigName)
                error("motorConfigName was not passed in as vector\n");
            end

            numMotors = numel(motorConfigName);
            numProps = numel(propConfigName);
            % Check if sizes are equal
            if numMotors ~= numProps
                error("Number of motors, %d, needs to equal number of propellers, %d\n", numMotors, numProps);
            end
            
            % Below is the normal case, both arguments were passed. Return
            % a MotorPropAssy for each combination of motor and propeller
            flagMultipleAssys = false;
            if numMotors ~= 1
                flagMultipleAssys = true;
                obj(numMotors) = MotorPropAssy();
            end

            for m = 1:numMotors
                obj(m).motor = Motor(motorConfigName(m));
                obj(m).propeller = Propeller(propConfigName(m));
                obj(m).W = obj(m).motor.W + obj(m).propeller.W;

                % Get which row numbers in motor's data table this
                % propeller lives. It could be more than 1. If it's 0,
                % throw warning and set perfData to missing
                rowNumber = find(obj(m).motor.perfData.propSize == obj(m).propeller.size);
                if isempty(rowNumber)
                    % 0 matches case
                    warning("Propeller %s incompatible with motor %s", propConfigName(m), motorConfigName(m));
                    obj(m).perfData = missing;
                    continue;
                elseif isscalar(rowNumber)
                    % 1 match case
                    % Check colorRating. If it's not green, this isn't a
                    % usable case
                    if obj(m).motor.perfData.colorRating(rowNumber) ~= "g"
                        warning("Propeller %s incompatible with motor %s\n", propConfigName(m), motorConfigName(m));
                        obj(m).perfData = missing;
                        continue;
                    end
                    Scount = string(round(obj(m).motor.perfData.V(rowNumber) / MotorPropAssy.LiPoBatteryVnom));
                    obj(m).perfData.("Battery" + Scount + "S").RPMmax = obj(m).motor.perfData.RPM(rowNumber);
                else
                    % >1 matches case
                    for r = 1:numel(rowNumber)
                        thisRowNumber = rowNumber(r);
                        Scount = string(round(obj(m).motor.perfData.V(thisRowNumber) / MotorPropAssy.LiPoBatteryVnom));
                        % Check colorRating. If it's not green, this isn't a
                        % usable case
                        if obj(m).motor.perfData.colorRating(thisRowNumber) ~= "g"
                            warning("Propeller %s incompatible with motor %s for %sS battery config.", propConfigName(m), motorConfigName(m), Scount);
                            continue;
                        end
                        obj(m).perfData.("Battery" + Scount + "S").RPMmax = obj(m).motor.perfData.RPM(thisRowNumber);
                        obj(m).perfData.("Battery" + Scount + "S").nmax = obj(m).perfData.("Battery" + Scount + "S").RPMmax / 60; % n is rev/s, used in calculating other params
                        % Find which RPM block for the prop is closest to motor-prop combo RPMmax
                        fields = fieldnames(obj(m).propeller.perfData);
                        RPMs = str2double(erase(string(fields), "RPM"));
                        [~, closestBlockNum] = min(abs(RPMs - obj(m).perfData.("Battery" + Scount + "S").RPMmax));
                        % Now go from the 1st block through the closest
                        % block and save that data
                        for b = 1:closestBlockNum
                            blockName = fields{b};
                            blockData = obj(m).propeller.perfData.(blockName);
                            % Store T and P data for different speeds
                            obj(m).perfData.("Battery" + Scount + "S").(blockName).v = [blockData{3:end, 1}]' ./ 2.237; % mph to m/s
                            obj(m).perfData.("Battery" + Scount + "S").(blockName).T = [blockData{3:end, 11}]';
                            obj(m).perfData.("Battery" + Scount + "S").(blockName).P = [blockData{3:end, 9}]';
                        end
                    end
                end
            end

            obj = reshape(obj, size(motorConfigName));

            return;
        end
    end

    methods (Access = private)

    end
end