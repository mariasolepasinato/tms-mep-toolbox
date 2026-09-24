function params = parameters(activityType, hemisphere, settings)
%PARAMETERS Perform the p ar am et er s operation for the TMS analysis pipeline.

% Syntax
%   params = tms.mep.parameters(activityType, hemisphere, settings)

% Description
%   Perform the p ar am et er s operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    params.activityType = activityType;
    params.hemisphere = hemisphere;

    % =====================================================================
    % 1. ALGORITHM HYPERPARAMETERS (Tweak these for performance)
    % =====================================================================
    params.winSizeTime = 0.015;  % [s] Size of the moving window
    params.maxLag      = 0.012;  % [s] Maximum lag for cross-correlation

    % SNR and Rho thresholds dynamically assigned based on activity type
    if activityType == "rest"
        params.snr    = 2.0;     % Minimum Signal-to-Noise Ratio
        params.rhoMin = 0.55;    % Minimum correlation coefficient with template
    elseif activityType == "active"
        params.snr    = 1.6;
        params.rhoMin = 0.51;
    end

    % =====================================================================
    % 2. TRIAL WINDOW DEFINITIONS
    % =====================================================================
    params.timePreTms   = 0.050; % [s] Pre-TMS baseline window
    params.timePostTms  = 0.080; % [s] Post-TMS analysis window

    % Calculate exact sample lengths using settings
    params.lengthPreTms = ceil(params.timePreTms * settings.fs_emg);
    params.T_len        = ceil((params.timePreTms + params.timePostTms) * settings.fs_emg);
    params.t_trial_ms   = ((-params.lengthPreTms):(params.T_len-params.lengthPreTms-1))' * settings.ts_emg * 1000;

    % =====================================================================
    % 3. CHANNEL ASSIGNMENTS & MATRIX GENERATION (Do not edit)
    % =====================================================================
    % Assign ipsilateral and contralateral channels
    if hemisphere == "left"
        params.idxChContro = [3; 4]; % Right limb
        params.idxChIpsi   = [1; 2]; % Left limb
    else  % right
        params.idxChContro = [1; 2]; % Left limb
        params.idxChIpsi   = [3; 4]; % Right limb
    end

    % Pre-allocate threshold matrices for vectorized processing
    nCh = 4;
    params.snrMat       = nan(nCh, 1);
    params.maxLagMat    = nan(nCh, 1);
    params.rhoMinMat    = nan(nCh, 1);
    params.thresholdMat = nan(nCh, 1);

    % Apply SNR
    params.snrMat(params.idxChIpsi)   = params.snr;
    params.snrMat(params.idxChContro) = 2.0; % Contro is strictly 2.0

    % Apply Lag
    params.maxLagMat(:) = params.maxLag;

    % Apply Rho
    params.rhoMinMat(params.idxChIpsi)   = params.rhoMin;
    params.rhoMinMat(params.idxChContro) = 0.55; % Contro is strictly 0.55

    % Apply Amplitude Thresholds (imported from global settings)
    if activityType == "rest"
        params.thresholdMat(params.idxChIpsi)   = settings.thresholdRestIpsi;
        params.thresholdMat(params.idxChContro) = settings.thresholdRestContro;
    elseif activityType == "active"
        params.thresholdMat(params.idxChIpsi)   = settings.thresholdActiveIpsi;
        params.thresholdMat(params.idxChContro) = settings.thresholdRestContro;
    end
end
