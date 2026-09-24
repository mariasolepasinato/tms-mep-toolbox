function settings = configureMEPCharacteristics(settings)
%CONFIGUREMEPCHARACTERISTICS Perform the c on fi gu re me pc ha ra ct er is ti cs operation for the TMS analysis pipeline.

% Syntax
%   settings = tms.config.configureMEPCharacteristics(settings)

% Description
%   Perform the c on fi gu re me pc ha ra ct er is ti cs operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    settings.latencyMinTime = 0.010;                 % [s] Minimum MEP latency (10 ms)
    settings.latencyMaxTime = 0.045;                 % [s] Maximum MEP latency (45 ms)

    % MEP amplitude thresholds for validity detection
    settings.thresholdRestIpsi   = 0.020;            % [mV] Rest ipsilateral threshold
    settings.thresholdRestContro = 0.050;            % [mV] Rest contralateral threshold
    settings.thresholdActiveIpsi = 0.050;            % [mV] Active ipsilateral threshold

    % Pre-TMS to post-TMS amplitude ratio for MEP validity
    settings.factorPrePostTms = 0.5;                 % Ratio: ppPre < factor * ppPost

    % Latency detection method
    settings.methodLatStr = "power";                 % Options: "power" or "derivative"

    % Export Format Preferences
    settings.exportSingleHemisphereCol = true;  % Merges affected/stim hemisphere cols
    settings.exportRemoveTrialCounts   = true;  % Removes total and valid trial count cols
    settings.exportCombineSas          = true;  % Combines SAS and non-SAS trials for Ipsi-lateral MEPs
end
