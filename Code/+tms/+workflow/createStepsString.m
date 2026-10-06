function stepsStr = createStepsString(stepsVec)
%CREATESTEPSSTRING Perform the c re at es te ps st ri ng operation for the TMS analysis pipeline.

% Syntax
%   stepsStr = tms.workflow.createStepsString(stepsVec)

% Description
%   Perform the c re at es te ps st ri ng operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    stepsMap = containers.Map([1, 2, 3, 4], ["Raw2MAT", "MVC", "MEP", "Spasticity risk"]);

    % Fix: Use cell array to avoid non-scalar error
    stepNames = cell(1, length(stepsVec));
    for i = 1:length(stepsVec)
        stepNames{i} = stepsMap(stepsVec(i));
    end

    stepsStr = strjoin(string(stepNames), " → ");
end
