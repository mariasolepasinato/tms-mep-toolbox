function plot(subjIdStr, settings, params, mepResultsRun, activityRun, mepTrials, isValidTrial, hAffected, sessionTimestamp)
%PLOT Perform the p lo t operation for the TMS analysis pipeline.

% Syntax
%   tms.mep.plot(subjIdStr, settings, params, mepResultsRun, activityRun, mepTrials, isValidTrial, hAffected, sessionTimestamp)

% Description
%   Perform the p lo t operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    nTrials = length(mepTrials);
    t_trial_ms = params.t_trial_ms;
    dirResultsSubj = fullfile(settings.dirResults, sessionTimestamp, subjIdStr);

    if ~isfolder(dirResultsSubj), mkdir(dirResultsSubj); end

    % Define channel-to-limb mapping based on affected hemisphere
    % If affected hemisphere is right (hAffected="R") → left  limb is affected → BBsx/FDIsx = affected
    % If affected hemisphere is left  (hAffected="L") → right limb is affected → BBdx/FDIdx = affected
    chLimbStatus = strings(4,1);
    if hAffected == "R"
        chLimbStatus = ["affected"; "affected"; "healthy"; "healthy"];  % BBsx, FDIsx, BBdx, FDIdx
    elseif hAffected == "L"
        chLimbStatus = ["healthy"; "healthy"; "affected"; "affected"];  % BBsx, FDIsx, BBdx, FDIdx
    end

    colorAffected = [1.0, 0.92, 0.92];   % Very light red (almost white with red tint)
    colorHealthy  = [0.92, 1.0, 0.92];   % Very light green (almost white with green tint)

    plotConfigs = {
        'mep_contro',        params.idxChContro, mepResultsRun.idxTrialValidArray, 1;
        'mep_ipsi_tms_only', params.idxChIpsi,   mepResultsRun.idxTrialValidArray(mepResultsRun.boolSasArray==0), 1;
        'mep_ipsi_sas',      params.idxChIpsi,   mepResultsRun.idxTrialValidArray(mepResultsRun.boolSasArray==1), 2
    };

    for cfg = 1:size(plotConfigs,1)
        subfolder  = plotConfigs{cfg,1};
        channels   = plotConfigs{cfg,2};
        trialsAll  = plotConfigs{cfg,3};

        saveDir = fullfile(dirResultsSubj, strcat(subfolder ,"_", activityRun));
        if ~isfolder(saveDir), mkdir(saveDir); end

        for ch = channels(:)'
            limbStatus = chLimbStatus(ch);
            if limbStatus == "affected"
                bgColor = colorAffected;
                limbLabel = "affected limb";
            else
                bgColor = colorHealthy;
                limbLabel = "healthy limb";
            end

            hFig = figure('Name', sprintf("%s - %s (%s) - %s", subfolder, settings.chString(ch), limbLabel, activityRun)); % 'NumberTitle', 'off');
            set(hFig, 'Color', bgColor, 'InvertHardcopy', 'off');
            ax = gca;
            set(ax, 'Color', bgColor);
            hold on

            validTrials = trialsAll(trialsAll <= nTrials & isValidTrial(trialsAll,ch));
            nValid      = length(validTrials);

            for t = validTrials(:)'
                emgPlot = table2array(mepTrials{t}(:,ch)).*1000;
                plot(t_trial_ms, emgPlot, 'LineWidth', 0.8);
            end

            xlabel("Time [ms]", 'FontSize', 11); ylabel("EMG [uV]", 'FontSize', 11);
            xline(0, "--k", "TMS", 'LineWidth', 1.5);
            xlim([t_trial_ms(1), t_trial_ms(end)]);
            xlim([0, t_trial_ms(end)]) % da provare xlim([t_trial_ms(1), t_trial_ms(end)]);
            titleStr = sprintf("%s | %s (%s) | N valid = %d | %s", replace(subfolder,"_"," "), settings.chString(ch), limbLabel, nValid, activityRun);
            title(titleStr, 'FontSize', 12, 'FontWeight', 'bold')
            grid on

            figName = sprintf('%s_%s_%s_trials_%d_%s.png', subjIdStr, settings.chString(ch), limbLabel, nValid, activityRun);
            saveas(hFig, fullfile(saveDir, figName));
            close(hFig);
        end
    end
end
