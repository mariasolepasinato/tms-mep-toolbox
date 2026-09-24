function [selectedRuns, hAffected] = determineRunOrder(subjData)
%DETERMINERUNORDER Perform the d et er mi ne ru no rd er operation for the TMS analysis pipeline.

% Syntax
%   [selectedRuns, hAffected] = tms.mep.determineRunOrder(subjData)

% Description
%   Perform the d et er mi ne ru no rd er operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    affectedSide = string(subjData.h_affected);
    if strcmpi(affectedSide, "right")
        selectedRuns = [1, 2, 3, 4];
        hAffected = "R";
    elseif strcmpi(affectedSide, "left")
        selectedRuns = [3, 4, 1, 2];
        hAffected = "L";
    else
        error('TMS:InvalidHemisphere', ...
            'Invalid affected hemisphere in JSON: %s', affectedSide);
    end

    if ~isfield(subjData, 'active_trials')
        return;
    end

    if isfield(subjData.active_trials, 'left') && isempty(subjData.active_trials.left)
        warning('TMS:MissingActiveTrials', ...
            'No active trials for left limb. Skipping run h_sinistro_active.');
        selectedRuns(selectedRuns == 2) = [];
    end
    if isfield(subjData.active_trials, 'right') && isempty(subjData.active_trials.right)
        warning('TMS:MissingActiveTrials', ...
            'No active trials for right limb. Skipping run h_destro_active.');
        selectedRuns(selectedRuns == 4) = [];
    end
end
