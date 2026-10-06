function settings = configureChannels(settings)
%CONFIGURECHANNELS Perform the configure channels operation for the TMS analysis pipeline.

% Syntax
%   settings = tms.config.configureChannels(settings)

% Description
%   Perform the configure channels operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    settings.filesString = ["mvc", "h_sinistro_rest", "h_sinistro_active", ...
                            "h_destro_rest", "h_destro_active"];
    settings.runString = settings.filesString(2 : 5);  % Exclude MVC for now

    % Muscle channel identifiers
    settings.chString = ["BBsx", "FDIsx", "BBdx", "FDIdx"];
    settings.mvcChString = ["BBsx", "BBdx"];  % MVC channels

    % CSV column labels as they appear in imported files
    settings.chLabelsExpected = ["Wired Analog Input"; "Var2"; "BBsx"; ...
                                 "FDIsx"; "BBdx"; "FDIdx"];

    % Standardized column labels after import
    settings.chLabelsDesired = ["tmsTrigger_V"; "trialClass_V"; ...
                                "BBsx_mV"; "FDIsx_mV"; "BBdx_mV"; "FDIdx_mV"];
end
