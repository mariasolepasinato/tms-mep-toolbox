function settings = configureDataAcquisition(settings)
%CONFIGUREDATAACQUISITION Perform the configure operation for the TMS analysis pipeline.

% Syntax
%   settings = tms.config.configureDataAcquisition(settings)

% Description
%   Perform the c on fi gu re da ta ac qu is it io n operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    settings.fs_analog = 24000;                     % [Hz] Analog acquisition frequency
    settings.fs_emg = 1000 * 2146 / 999;            % [Hz] EMG resampled frequency (~2148.15 Hz)
    settings.ts_emg = 1 / settings.fs_emg;          % [s] EMG sampling period

    % Digital signal thresholds for trigger detection
    settings.thresholdVoltDigitalHigh = 2.0;        % [V] Minimum HIGH logic level
    settings.thresholdVoltDigitalLow = 0.8;         % [V] Maximum LOW logic level
end
