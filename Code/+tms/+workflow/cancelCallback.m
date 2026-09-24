function cancelCallback(dlg)
%CANCELCALLBACK Perform the c an ce lc al lb ac k operation for the TMS analysis pipeline.

% Syntax
%   tms.workflow.cancelCallback(dlg)

% Description
%   Perform the c an ce lc al lb ac k operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    set(dlg, 'UserData', 'cancelled');
    uiresume(dlg);
end
