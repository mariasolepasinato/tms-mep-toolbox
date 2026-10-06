function validateSettings(settings)
%VALIDATESETTINGS Perform the v al id at es et ti ng s operation for the TMS analysis pipeline.

% Syntax
%   tms.config.validateSettings(settings)

% Description
%   Perform the v al id at es et ti ng s operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    requiredDirs = {settings.dirDataRaw; settings.dirDataPreprocessed; ...
                    settings.dirDataProcessed; settings.dirMetaData};

    for dir = requiredDirs
        if ~isfolder(dir{1})
            warning('TMS:MissingDirectory', ...
                'Directory not found: %s\nPlease mount or create this directory.', dir{1});
        end
    end

    % Validate sampling rate ratios
    if settings.fs_emg > settings.fs_analog
        error('TMS:InvalidSamplingRate', ...
            'EMG sampling rate (%.1f Hz) cannot exceed analog rate (%.1f Hz)', ...
            settings.fs_emg, settings.fs_analog);
    end

    % Validate latency times
    if settings.latencyMinTime >= settings.latencyMaxTime
        error('TMS:InvalidLatencyWindow', ...
            'Minimum latency (%.3f s) must be less than maximum (%.3f s)', ...
            settings.latencyMinTime, settings.latencyMaxTime);
    end

    % Validate amplitude thresholds (should be positive)
    if settings.thresholdRestIpsi <= 0 || settings.thresholdRestContro <= 0 || ...
       settings.thresholdActiveIpsi <= 0
        error('TMS:InvalidThreshold', 'Amplitude thresholds must be positive values');
    end

    % Validate pre-post ratio
    if settings.factorPrePostTms <= 0 || settings.factorPrePostTms > 1
        warning('TMS:UnusualRatio', ...
            'Pre-post TMS ratio (%.2f) is unusual. Expected range: 0-1', ...
            settings.factorPrePostTms);
    end

    % Validate latency method
    validMethods = ["power", "derivative"];
    if ~ismember(settings.methodLatStr, validMethods)
        error('TMS:InvalidLatencyMethod', ...
            'Latency method must be one of: %s', strjoin(validMethods, ", "));
    end
end
