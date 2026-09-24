function export(mepResultsControAvg, mepResultsIpsiAvg, subjIdStr, hAffected, settings, sessionTimestamp)
%EXPORT Perform the e xp or t operation for the TMS analysis pipeline.

% Syntax
%   tms.mep.export(mepResultsControAvg, mepResultsIpsiAvg, subjIdStr, hAffected, settings, sessionTimestamp)

% Description
%   Perform the e xp or t operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    resultsDir = fullfile(settings.dirResults, sessionTimestamp, subjIdStr);
    if ~isfolder(resultsDir), mkdir(resultsDir); end

    resultsIpsiAll   = table();
    resultsControAll = table();

    % Determine if we are combining SAS
    if isfield(settings, 'exportCombineSas') && settings.exportCombineSas
        combineSas = true;
    else
        combineSas = false;
    end

    % Helper to create empty row if run is missing (Now uses dynamic A/R and L/R)
    createEmptyRow = @(hAff, sSide, aStr) table(string(subjIdStr), string(hAff), string(sSide), string(aStr), NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'ID', 'affected_h', 'stim_h', 'Active/Rest', 'SAS', 'n_iMEP_BB_valid', 'n_iMEP_FDI_valid', 'n_trials_tot (with SAS and not)', 'n_trials_valid', 'BB_amplitude', 'BB_latency', 'FDI_amplitude', 'FDI_latency'});

    createEmptyRowContro = @(hAff, sSide, aStr) table(string(subjIdStr), string(hAff), string(sSide), string(aStr), NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'ID', 'affected_h', 'stim_h', 'Active/Rest', 'n_cMEP_BB_valid', 'n_cMEP_FDI_valid', 'n_trials_tot (with SAS and not)', 'n_trials_valid', 'BB_amplitude', 'BB_latency', 'FDI_amplitude', 'FDI_latency'});

    % Iterate through ALL expected runs in settings
    for idxRun = 1:length(settings.runString)
        expectedRunName = settings.runString(idxRun);

        % Extract Activity (A/R) from the missing run name
        if contains(expectedRunName, "active", 'IgnoreCase', true)
            actStr = "A";
        else
            actStr = "R";
        end

        % Extract Stim Side (L/R) from the missing run name
        if contains(expectedRunName, "destro", 'IgnoreCase', true)
            stimSide = "R";
        else
            stimSide = "L";
        end

        % Ipsi
        if idxRun <= length(mepResultsIpsiAvg) && ~isempty(mepResultsIpsiAvg{idxRun})
            resultsIpsiAll = [resultsIpsiAll; mepResultsIpsiAvg{idxRun}];
        else
            % Handle missing run placeholders
            row = createEmptyRow(hAffected, stimSide, actStr);
            if combineSas
                row.SAS = NaN; % Just 1 row
                resultsIpsiAll = [resultsIpsiAll; row];
            else
                row = [row; row]; % Duplicate for SAS 0 and 1
                row.SAS = [0; 1];
                resultsIpsiAll = [resultsIpsiAll; row];
            end
        end

        % Contro
        if idxRun <= length(mepResultsControAvg) && ~isempty(mepResultsControAvg{idxRun})
            resultsControAll = [resultsControAll; mepResultsControAvg{idxRun}];
        else
            resultsControAll = [resultsControAll; createEmptyRowContro(hAffected, stimSide, actStr)];
        end
    end

    % =====================================================================
    % FORMAT EXPORT 1: Single vs. Double Hemisphere Columns & Sorting
    % =====================================================================
    if isfield(settings, 'exportSingleHemisphereCol') && settings.exportSingleHemisphereCol
        if ~isempty(resultsIpsiAll)
            resultsIpsiAll = applyHemisphereMerge(resultsIpsiAll);
            % Sort descending to guarantee Affected (1) appears before Healthy (0)
            resultsIpsiAll = sortrows(resultsIpsiAll, 'stim_on_affected_h', 'descend', 'MissingPlacement', 'last');
        end
        if ~isempty(resultsControAll)
            resultsControAll = applyHemisphereMerge(resultsControAll);
            resultsControAll = sortrows(resultsControAll, 'stim_on_affected_h', 'descend', 'MissingPlacement', 'last');
        end
    end

    % =====================================================================
    % FORMAT EXPORT 2: Remove Trial Count Columns
    % =====================================================================
    if isfield(settings, 'exportRemoveTrialCounts') && settings.exportRemoveTrialCounts
        colsToRemove = {'n_trials_tot (with SAS and not)', 'n_trials_valid'};
        if ~isempty(resultsIpsiAll)
            resultsIpsiAll = removevars(resultsIpsiAll, colsToRemove);
        end
        if ~isempty(resultsControAll)
            resultsControAll = removevars(resultsControAll, colsToRemove);
        end
    end

    % =====================================================================
    % FORMAT EXPORT 3: Remove SAS Column if Combined
    % =====================================================================
    if combineSas
        if ~isempty(resultsIpsiAll) && ismember('SAS', resultsIpsiAll.Properties.VariableNames)
            resultsIpsiAll = removevars(resultsIpsiAll, {'SAS'});
        end
    end

    % =====================================================================
    % SAVE TO EXCEL
    % =====================================================================
    excelPath = fullfile(resultsDir, sprintf("%s_mep_results.xlsx", subjIdStr));

    if ~isempty(resultsIpsiAll)
        writetable(resultsIpsiAll, excelPath, 'Sheet', "iMEP");
    end
    if ~isempty(resultsControAll)
        writetable(resultsControAll, excelPath, 'Sheet', "cMEP");
    end

    fprintf("    Saved MEP results: %s\n", excelPath);
end

% =========================================================================
% LOCAL HELPER FUNCTION
% =========================================================================
function T = applyHemisphereMerge(T)
%APPLYHEMISPHEREMERGE Perform the a pp ly he mi sp he re me rg e operation for the TMS analysis pipeline.

% Syntax
%   T = tms.mep.applyHemisphereMerge(T)

% Description
%   Perform the a pp ly he mi sp he re me rg e operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    isUnknown = (T.affected_h == "Unknown") | (T.stim_h == "Unknown");

    stim_on_affected_h = nan(height(T), 1);
    stim_on_affected_h(~isUnknown) = double(T.affected_h(~isUnknown) == T.stim_h(~isUnknown));

    T = addvars(T, stim_on_affected_h, 'After', 'ID');
    T = removevars(T, {'affected_h', 'stim_h'});
end
