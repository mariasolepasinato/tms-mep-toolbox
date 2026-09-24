function workflowLog = initializeWorkflowLog(subjStrList)
%INITIALIZEWORKFLOWLOG Perform the i ni ti al iz ew or kf lo wl og operation for the TMS analysis pipeline.

% Syntax
%   workflowLog = tms.workflow.initializeWorkflowLog(subjStrList)

% Description
%   Perform the i ni ti al iz ew or kf lo wl og operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    numSubj = length(subjStrList);
    % Pre-allocate struct array
    workflowLog(numSubj) = struct('subjStr',      '', ...
                                   'mvc',         false, ...
                                    'raw2Mat',     false, ...
                                    'mepAnalysis', false, ...
                                    'mepRunErrors', strings(1, 0), ...
                                    'spasticityRisk', false, ...
                                    'elapsedTime', 0, ...
                                   'error',       '');

    % Initialize each subject entry
    for i = 1:numSubj
        workflowLog(i).subjStr      = subjStrList(i);
        workflowLog(i).mvc          = false;
        workflowLog(i).raw2Mat      = false;
        workflowLog(i).mepAnalysis  = false;
        workflowLog(i).mepRunErrors = strings(1, 0);
        workflowLog(i).spasticityRisk = false;
        workflowLog(i).elapsedTime  = 0;
        workflowLog(i).error        = '';
    end
end
