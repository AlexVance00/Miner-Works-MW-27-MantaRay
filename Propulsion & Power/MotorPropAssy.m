% Stores complicated data for configuration combining motor and propeller
% into one structure
% -------------------------------------------------------------------------
% Dependencies
%   1) Propeller.m Version 1.0
%   2) Motor.m Version 1.0
%   3) GetConfigData.m Version 2.1
% -------------------------------------------------------------------------
% Assumptions
%   1) motorConfigName and propConfigName need *not* be the same size as
%   one another
% -------------------------------------------------------------------------
% Comments
%   1) Vectorized. Will return a MotorPropAssy object array equal in size
%   to mxn where m is the size of the motorConfigName array and n is the
%   size of the propConfigName array. If either or both are
%   multidiminesional already, the returned object array shall be a size of
%   their sizes' product such that if motorConfigName is of size 2x3 and
%   propConfigName is of size 4x5, the returned array shall be of size
%   2x3x4x5
% -------------------------------------------------------------------------
% Document Version 1.0, earlier versions:
%   - <Version>
% -------------------------------------------------------------------------
% MATLAB Version R2025a, also compatible with:
%   - <Later Version>
% -------------------------------------------------------------------------
% Developed by Alex Vance (AlexVance00 on Github)
classdef MotorPropAssy

    properties (SetAccess = private)
        motor Motor
        propeller Propeller        
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
            % Below is the normal case, both arguments were passed. Return
            % a MotorPropAssy for each combination of motor and propeller
            numMotors = numel(motorConfigName);
            numProps = numel(propConfigName);
            flagMultipleAssys = false;
            if numMotors ~= 1 || numProps ~= 1
                flagMultipleAssys = true;
                sizeMotors = size(motorConfigName);
                sizeProps = size(propConfigName);
                obj([sizeMotors, sizeProps]) = MotorPropAssy();
            end

            for m1 = 1:sizeMotors(1)
                for n1 = 1:sizeMotors(2)
                    thisMotorConfigName = motorConfigName(m1, n1);
                    for m2 = 1:sizeProps(1)
                        for n2 = 1:sizeProps(2)
                            thisPropConfigName = propConfigName(m2, n2);
                            obj(m1, n1, m2, n2).motor = Motor(thisMotorConfigName);
                            obj(m1, n1, m2, n2).prop = Propeller(thisPropConfigName);                            
                        end
                    end
                end
            end

            return;
        end
    end

    methods (Access = private)

    end
end