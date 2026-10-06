function strVal = boolToStr(val)
%BOOLTOSTR Perform the b oo lt os tr operation for the TMS analysis pipeline.

% Syntax
%   strVal = tms.workflow.boolToStr(val)

% Description
%   Perform the b oo lt os tr operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    if val, strVal = "Yes"; else, strVal = "No"; end
end
