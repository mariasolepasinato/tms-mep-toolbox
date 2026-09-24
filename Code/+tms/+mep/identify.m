function [mepResultsRun, templateContro, bBuildTemplate, isValidTrial] = identify(...
    mepTrials, boolActiveTrials, hemisphereTmsStr, params, settings, templateContro, bBuildTemplate, bPlotRho)
%IDENTIFY Perform the i de nt if y operation for the TMS analysis pipeline.

% Syntax
%   [mepResultsRun, templateContro, bBuildTemplate, isValidTrial] = tms.mep.identify( mepTrials, boolActiveTrials, hemisphereTmsStr, params, settings, templateContro, bBuildTemplate, bPlotRho)

% Description
%   Perform the i de nt if y operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    idxTrigTrial = params.lengthPreTms + 1;

    % Moving-Window Setup
    t_trial_ms = params.t_trial_ms;
    maskLatency = (t_trial_ms >= settings.latencyMinTime * 1000) & (t_trial_ms < settings.latencyMaxTime*1000);
    idxLatMin = ceil( settings.latencyMinTime*settings.fs_emg) + idxTrigTrial;
    idxLatMax = round(settings.latencyMaxTime*settings.fs_emg) + idxTrigTrial;

    winSizeLen    = round(params.winSizeTime * settings.fs_emg);
    winOverlapLen = round(0.014 * settings.fs_emg);
    winShiftLen   = winSizeLen - winOverlapLen;
    nWinTrial     = floor((idxLatMax-idxLatMin+1-winSizeLen)/winShiftLen) + 1;
    f = settings.fs_emg * (0:floor(winSizeLen / 2)) / winSizeLen;

    nCh = 4;
    nTrials = length(mepTrials);

    % Initialize variables
    idxTrialValid = 0;
    ppCurr        = zeros(nWinTrial, nCh, nTrials);
    ppMax         = zeros(nTrials, nCh, 1);
    emgWinPowSum  = nan(nTrials, nCh, nWinTrial);
    idxMepStart   = nan(nTrials, nCh, 1);

    % Output structures
    mepAmplitudeContro_mV  = nan(nTrials, 2);
    mepLatencyContro_ms    = nan(nTrials, 2);
    mepAmplitudeIpsi_mV    = nan(nTrials, 2);
    mepLatencyIpsi_ms      = nan(nTrials, 2);

    varNames = ["idxTrialValidArray", "mepTestedSide", "boolActiveArray", "boolSasArray"];
    varTypes = ["uint8", "string", "double", "double"];
    mepResultsRun = table('Size', [nTrials, length(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
    mepResultsRun = addvars(mepResultsRun, mepAmplitudeContro_mV, mepLatencyContro_ms, mepAmplitudeIpsi_mV, mepLatencyIpsi_ms);
    mepResultsRun.Properties.VariableUnits = ["", "", "", "", "mV", "ms", "mV", "ms"];

    % Peak-to-Peak Detection
    for t = 1 : nTrials
        for ch = 1 : nCh
            dataCh = table2array(mepTrials{t}(maskLatency,ch));
            for w = 1 : nWinTrial
                i0 = 1 + (w - 1) * winShiftLen;
                i1 = (i0 + winSizeLen) - 1;
                if i1 > length(dataCh), continue; end
                win = dataCh(i0 : i1);
                pp  = max(win) - min(win);
                ppCurr(w, ch, t) = pp;
                if pp>ppMax(t, ch), ppMax(t, ch)=pp; end
            end
        end
    end

    % Pre-stimulus Rejection
    isValidTrial = double(ppMax' > params.thresholdMat)';
    mask_pre = (t_trial_ms >= -50) & (t_trial_ms < 0);

    for t = 1 : nTrials
        for ch = 1 : nCh
            pre = table2array(mepTrials{t}(mask_pre, ch));
            if max(pre) - min(pre) > (1/params.snrMat(ch)) * ppMax(t, ch)
                isValidTrial(t, ch)=0;
            end
        end
    end
    mask_post = (t_trial_ms >= 0)&(t_trial_ms <= 50);

    % Build Contralateral Template
    if bBuildTemplate
        nSampl       = sum(mask_post);
        cnt          = numel(params.idxChContro);
        accum        = zeros(nSampl, cnt);
        validCount   = zeros(1, cnt);

        for t = 1 : nTrials
            block = table2array(mepTrials{t}(mask_post, :));
            for k = 1 : cnt
                c = params.idxChContro(k);
                if isValidTrial(t, c)
                    accum(:, k) = accum(:, k) + block(:, c);
                    validCount(k) = validCount(k) + 1;
                end
            end
        end

        templateContro = nan(nSampl, cnt);
        for k = 1 : cnt
            if validCount(k) > 0
                templateContro(:, k) = accum(:, k) / validCount(k);
            end
        end
        templateContro = (templateContro-mean(templateContro)) ./ std(templateContro);

        % Fallback if one channel is bad
        if all(isnan(templateContro(:, 1))) && ~all(isnan(templateContro(:, 2)))
            templateContro(:, 1) = templateContro(:, 2);
        elseif all(isnan(templateContro(:, 2))) && ~all(isnan(templateContro(:, 1)))
            templateContro(:, 2) = templateContro(:, 1);
        end
        bBuildTemplate = false;
    end

    % Template-Based Validation (xcorr)
    maxLag = round(params.maxLag * settings.fs_emg);
    for t = 1 : nTrials
        for ch = 1 : nCh
            if ismember(ch, params.idxChIpsi)
                col = (ch == 1 || ch == 3) * 1 + (ch == 2 || ch == 4) * 2;
                T = templateContro(:,col);

                % Skip if template is invalid
                if any(isnan(T)), continue; end

                emgPost = table2array(mepTrials{t}(mask_post,ch));
                Xnorm   = (emgPost - mean(emgPost)) ./ std(emgPost);

                [y, ~] = xcorr(Xnorm, T, maxLag, 'coeff');
                rho = max(abs(y));

                if isValidTrial(t, ch)
                    if rho < params.rhoMinMat(ch)
                        isValidTrial(t, ch) = false;
                    end
                    if bPlotRho
                        t_post_ms = t_trial_ms(mask_post);
                        figure;
                        plot(t_post_ms, T, 'k'); hold on;
                        plot(t_post_ms, Xnorm, 'r');
                        xlabel('Time [ms]');
                        ylabel('Normalized amplitude');
                        title(sprintf('%s - Trial %d, Ch %d, rho=%.2f', status, t, ch, rho));
                    end
                end
            end
        end
    end

    % Latency Computation via Power
    for t = 1:  nTrials
        for ch = 1 : nCh
            dataCh = table2array(mepTrials{t}(maskLatency, ch));
            thr    = params.thresholdMat(ch);
            for w = 1 : nWinTrial
                i0 = 1 + (w - 1) * winShiftLen;
                i1 = min(i0 + winSizeLen - 1, length(dataCh));

                win = dataCh(i0 : i1);
                if max(win) - min(win) > thr
                    Y  = fft(win);
                    P2 = abs(Y / winSizeLen) .^ 2;
                    P1 = P2(1 : floor(winSizeLen / 2) + 1);
                    P1(2 : end - 1) = 2 * P1(2 : end - 1);
                    emgWinPowSum(t, ch, w) = sum(P1(f <= 234));
                end
            end

            % Find max power window
            [~,wMax] = max(squeeze(emgWinPowSum(t,ch,:)));
            if ppCurr(wMax, ch, t) > thr && isValidTrial(t, ch)
                idxMepStart(t, ch) = 1 + (wMax - 1) * winShiftLen + idxLatMin - 1;
            end
        end
    end

    % Finalize Validity and Compile Results
    ppMax(~isValidTrial) = NaN;
    idxMepStart(~isValidTrial) = NaN;

    for idxTrial = 1 : nTrials
        if any(isValidTrial(idxTrial, :))
            idxTrialValid = idxTrialValid + 1;
            mepResultsRun.idxTrialValidArray(idxTrialValid)         = idxTrial;
            mepResultsRun.mepTestedSide(idxTrialValid)              = hemisphereTmsStr;
            mepResultsRun.boolActiveArray(idxTrialValid)            = boolActiveTrials(idxTrial);
            mepResultsRun.boolSasArray(idxTrialValid)               = mepTrials{idxTrial}{idxTrigTrial,"trialClass"};
            mepResultsRun.mepAmplitudeContro_mV(idxTrialValid,:)    = round(ppMax(idxTrial,params.idxChContro), 4);
            mepResultsRun.mepAmplitudeIpsi_mV(idxTrialValid,:)      = round(ppMax(idxTrial,params.idxChIpsi), 4);

            % Calculate latency in ms
            latC = (idxMepStart(idxTrial, params.idxChContro) - idxTrigTrial) / settings.fs_emg * 1000;
            latI = (idxMepStart(idxTrial, params.idxChIpsi)   - idxTrigTrial) / settings.fs_emg * 1000;

            mepResultsRun.mepLatencyContro_ms(idxTrialValid,:)      = round(latC, 2);
            mepResultsRun.mepLatencyIpsi_ms(idxTrialValid,:)        = round(latI, 2);
        end
    end
    mepResultsRun(idxTrialValid + 1 : end, :) = [];
end
