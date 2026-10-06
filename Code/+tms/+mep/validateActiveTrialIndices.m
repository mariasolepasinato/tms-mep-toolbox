function activeIdx = validateActiveTrialIndices(subjData, hemisphere, nTriggers, subjId, activeDataSource)
%VALIDATEACTIVETRIALINDICES Perform the v al id at ea ct iv et ri al in di ce s operation for the TMS analysis pipeline.

% Syntax
%   activeIdx = tms.mep.validateActiveTrialIndices(subjData, hemisphere, nTriggers, subjId, activeDataSource)

% Description
%   Perform the v al id at ea ct iv et ri al in di ce s operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    if ~isfield(subjData, 'active_trials') || ...
       ~isfield(subjData.active_trials, hemisphere)
        error('TMS:MissingActiveTrialMetadata', ...
            ['Missing active_trials.%s metadata for subject %s. ' ...
             'Cannot classify trials in %s.'], ...
            hemisphere, subjId, activeDataSource);
    end

    activeIdx = subjData.active_trials.(hemisphere);
    if isempty(activeIdx)
        activeIdx = zeros(0, 1);
        return;
    end

    validateattributes(activeIdx, {'numeric'}, ...
        {'vector', 'real', 'finite', 'positive'}, mfilename, 'active_trials');
    activeIdx = activeIdx(:);

    if any(mod(activeIdx, 1) ~= 0)
        error('TMS:InvalidActiveTrialMetadata', ...
            'active_trials.%s for subject %s contains non-integer indices.', ...
            hemisphere, subjId);
    end
    if numel(unique(activeIdx)) ~= numel(activeIdx)
        error('TMS:InvalidActiveTrialMetadata', ...
            'active_trials.%s for subject %s contains duplicate indices.', ...
            hemisphere, subjId);
    end
    if any(activeIdx > nTriggers)
        error('TMS:InvalidActiveTrialMetadata', ...
            ['active_trials.%s for subject %s contains an index greater than ' ...
             'the %d triggers in %s.'], ...
            hemisphere, subjId, nTriggers, activeDataSource);
    end
end
