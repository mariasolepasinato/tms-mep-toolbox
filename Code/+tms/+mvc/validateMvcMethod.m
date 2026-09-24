function mvcMethod = validateMvcMethod(method)
%VALIDATEMVCMETHOD Perform the v al id at em vc me th od operation for the TMS analysis pipeline.

% Syntax
%   mvcMethod = tms.mvc.validateMvcMethod(method)

% Description
%   Perform the v al id at em vc me th od operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    validMethods = ["rectified", "envelope"];

    if ~ismember(string(method), validMethods)
        error('TMS:InvalidMVCMethod', ...
            'MVC method must be one of: %s', strjoin(validMethods, ", "));
    end

    mvcMethod = string(method);
end
