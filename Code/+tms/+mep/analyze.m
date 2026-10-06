function [mepResultsControAvg, mepResultsIpsiAvg, runStatus] = analyze(subjIdStr, settings, varargin)
%ANALYZE Run the complete MEP analysis for one subject.

% Syntax
%   [mepResultsControAvg, mepResultsIpsiAvg, runStatus] = tms.mep.analyze(subjIdStr, settings, varargin)

% Description
%   Run the complete MEP analysis for one subject.

% Inputs
%   subjIdStr - Subject identifier as a string scalar.
%   settings - Validated settings structure from tms.config.createSettings.

% Name-Value Arguments
%   plot - Enable diagnostic plots (default: false).
%   save - Export subject-level summary tables (default: false).
%   includeRestInActive - Include rest trials recorded during active runs.
%   sessionTimestamp - Timestamp used to group generated output files.

% Outputs
%   mepResultsControAvg - Contralateral MEP summary table for each run.
%   mepResultsIpsiAvg - Ipsilateral MEP summary table for each run.
%   runStatus - Selected runs, success flags, and per-run error messages.

% See also
%   tms_main_workflow



    % Parse input arguments
    p = inputParser;
    addRequired(p, 'subjIdStr', @isstring);
    addRequired(p, 'settings', @isstruct);
    addParameter(p, 'plot', false, @islogical);
    addParameter(p, 'save', false, @islogical);
    addParameter(p, 'includeRestInActive', true, @islogical);
    addParameter(p, 'sessionTimestamp', string(datetime("now",'Format','yyyy-MM-dd_HH-mm-ss')), @isstring);
    parse(p, subjIdStr, settings, varargin{:});

    doPlot              = p.Results.plot;
    doSave              = p.Results.save;
    includeRestInActive = p.Results.includeRestInActive;
    sessionTimestamp    = p.Results.sessionTimestamp;

    fprintf("MEP Analysis for subject: %s\n", subjIdStr);

    % --- STEP 0: METADATA CHECK (CRITICAL) ---
    % Load subject metadata from JSON using readstruct (as preferred)
    metadataPath = fullfile(settings.dirMetaData, strcat(subjIdStr, ".json"));
    if ~isfile(metadataPath)
         error('TMS:MetadataNotFound', ...
            ['CRITICAL ERROR: Metadata file missing for subject %s.\n' ...
             'Expected at: %s\n' ...
             'Please create one from "notes.txt" file in subject''s raw data folder.'], ...
             subjIdStr, fullfile(settings.dirMetaData, subjIdStr + ".json"));
    end

    try
        % Using readstruct as requested for consistency with existing data structures
        subjData = readstruct(metadataPath);
        fprintf('  Metadata loaded successfully.\n');
    catch ME
        error('TMS:MetadataInvalid', 'Failed to read JSON for %s using readstruct: %s', subjIdStr, ME.message);
    end

    % Determine run order based on affected hemisphere and missing trials
    [selectedRuns, hAffected] = tms.mep.determineRunOrder(subjData);

    % Initialize output tables
    nConfiguredRuns = length(settings.runString);
    mepResultsControAvg = cell(nConfiguredRuns, 1);
    mepResultsIpsiAvg   = cell(nConfiguredRuns, 1);
    runSuccessful = false(1, nConfiguredRuns);
    runErrors = strings(1, nConfiguredRuns);

    % Template building state
    bBuildTemplate = true;
    bPlotRho       = false;
    templateContro = [];

    % --- RUN LOOP ---
    for i = 1 : length(selectedRuns)
        idxRun = selectedRuns(i);
        runName = settings.runString(idxRun);

        fprintf("  Processing run: %s... \n", runName);
        try
            % 1. Load Data
            mepData = loadMepData(subjIdStr, runName, settings);
            if isempty(mepData)
                runErrors(idxRun) = "File not found or empty.";
                warning('TMS:RunSkipped', 'Skipping run %s: File not found or empty.', runName);
                continue;
            end

            % 2. Setup Analysis Parameters
            [hemisphereTmsStr, activityRun] = parseRunName(runName);
            params = tms.mep.parameters(activityRun, hemisphereTmsStr, settings);

            % 3. Extract Trials (Active/Rest Logic)
            [mepTrials, nTrials, boolActiveTrials, ~, ~] = ...
                extractTrials(mepData, subjIdStr, runName, settings, ...
                              activityRun, includeRestInActive, subjData, hemisphereTmsStr, params);

            % 4. Perform Detection (Peak-to-Peak, Template, Latency)
            [mepResultsRun, templateContro, bBuildTemplate, isValidTrial] = tms.mep.identify(...
                mepTrials, boolActiveTrials, hemisphereTmsStr, params, ...
                settings, templateContro, bBuildTemplate, bPlotRho);

            % 5. Compute Averages
            [resultsControAvg, resultsIpsiAvg] = computeAverages(...
                mepResultsRun, hemisphereTmsStr, activityRun, subjIdStr, hAffected, nTrials, settings);

            mepResultsControAvg{idxRun} = resultsControAvg;
            mepResultsIpsiAvg{idxRun}   = resultsIpsiAvg;

            fprintf('    > DONE (Valid Trials: %d)\n', sum(mepResultsRun.idxTrialValidArray > 0));

            % 6. Plotting
            if doPlot
                tms.mep.plot(subjIdStr, settings, params, mepResultsRun, activityRun, mepTrials, isValidTrial, hAffected, sessionTimestamp);
            end

            runSuccessful(idxRun) = true;

        catch ME
            runErrors(idxRun) = string(ME.message);
            warning('TMS:RunFailed', 'ERROR in run %s: %s', runName, ME.message);
            % disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
            continue;
        end
    end

    % Save combined results
    if doSave
        tms.mep.export(mepResultsControAvg, mepResultsIpsiAvg, subjIdStr, hAffected, settings, sessionTimestamp);
    end

    runStatus.selectedRuns = selectedRuns;
    runStatus.successful = runSuccessful;
    runStatus.errors = runErrors;
    runStatus.allSelectedRunsSuccessful = all(runSuccessful(selectedRuns));
end

% =========================================================
% HELPER FUNCTIONS
% =========================================================

function mepData = loadMepData(subjIdStr, runName, settings)
%LOADMEPDATA Perform the l oa dm ep da ta operation for the TMS analysis pipeline.

% Syntax
%   mepData = tms.mep.loadMepData(subjIdStr, runName, settings, idxRun)

% Description
%   Perform the l oa dm ep da ta operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    mepData = [];
    matPath = fullfile(settings.dirDataPreprocessed, subjIdStr, strcat(runName, ".mat"));
    if ~isfile(matPath)
        return;
    end

    % Enforce variable name 'mepData'
    loaded = load(matPath, 'mepData');
    if isfield(loaded, 'mepData')
        mepData = loaded.mepData;
    else
        % Fail if mepData is missing (no fallback to 'data')
        warning('TMS:VarNotFound', 'Variable "mepData" not found in %s', matPath);
        return;
    end

end

function [hemisphereTmsStr, activityTypeStr] = parseRunName(runName)
%PARSERUNNAME Perform the p ar se ru nn am e operation for the TMS analysis pipeline.

% Syntax
%   [hemisphereTmsStr, activityTypeStr] = tms.mep.parseRunName(runName)

% Description
%   Perform the p ar se ru nn am e operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    tokens = strsplit(runName, "_");
    hemisphereTmsStr = tokens(2);
    activityTypeStr  = tokens(3);

    % Strict hemisphere check
    if hemisphereTmsStr == "destro"
        hemisphereTmsStr = "right";
    elseif hemisphereTmsStr == "sinistro"
        hemisphereTmsStr = "left";
    else
        error('TMS:InvalidHemisphere', 'Unrecognized hemisphere: %s', hemisphereTmsStr);
    end
end

function [mepTrials, nTrials, boolActiveTrials, idxTrialsActive, idxTrialsRest] = ...
    extractTrials(mepData, subjIdStr, runName, settings, ...
                  activityType, includeRestInActive, subjData, hemisphereTmsStr, params)
%EXTRACTTRIALS Perform the e xt ra ct tr ia ls operation for the TMS analysis pipeline.

% Syntax
%   [mepTrials, nTrials, boolActiveTrials, idxTrialsActive, idxTrialsRest] = tms.mep.extractTrials(mepData, subjIdStr, runName, settings, activityType, includeRestInActive, subjData, hemisphereTmsStr, params)

% Description
%   Perform the e xt ra ct tr ia ls operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    emgLabels = ["BBsx_mV", "FDIsx_mV", "BBdx_mV", "FDIdx_mV"];

    if activityType == "rest"
        nTrialsRest = sum(mepData.tmsTrigger);
        nTrials = nTrialsRest;

        % Try to load corresponding active run for augmentation
        temp = strsplit(runName, '_');
        activeFileName = strcat(temp(1), "_", temp(2), "_active.mat");
        activeFilePath = fullfile(settings.dirDataPreprocessed, subjIdStr, activeFileName);

        if includeRestInActive && isfile(activeFilePath)
            % Enforce 'mepData' variable name in Active file as well
            tempData = load(activeFilePath, 'mepData');
            if ~isfield(tempData, 'mepData')
                 error('TMS:VarNotFound', 'mepData not found in active file %s', activeFilePath);
            end
            tData = tempData.mepData;

            nTrialsActive = sum(tData.tmsTrigger);
            idxActiveInActiveRun = tms.mep.validateActiveTrialIndices( ...
                subjData, hemisphereTmsStr, nTrialsActive, subjIdStr, activeFilePath);
            idxTrialsActive = nTrialsRest + idxActiveInActiveRun;
            nTrialsTotal = nTrialsRest + nTrialsActive;

            maskTrialRest = ones(nTrialsTotal, 1);
            maskTrialRest(idxTrialsActive) = 0;
            idxTrialsRest = find(maskTrialRest > 0);

            nTrials = length(idxTrialsRest);
            boolActiveTrials = abs((maskTrialRest - 1));

            commonVars = intersect(mepData.Properties.VariableNames, ...
                                   tData.Properties.VariableNames, 'stable');
            mepData = [mepData(:, commonVars); tData(:, commonVars)];
        else
            idxTrialsActive = [];
            idxTrialsRest   = (1 : nTrials)';
            boolActiveTrials = zeros(nTrials, 1); % Default to all rest
        end
        idxTrialListCurrent = idxTrialsRest;

    elseif activityType == "active"
        nTriggersActive = sum(mepData.tmsTrigger);
        idxTrialsActive = tms.mep.validateActiveTrialIndices( ...
            subjData, hemisphereTmsStr, nTriggersActive, subjIdStr, runName);
        nTrials = length(idxTrialsActive);
        boolActiveTrials = ones(nTrials, 1);
        idxTrialsRest = [];
        idxTrialListCurrent = idxTrialsActive;
    end

    % Extract trial windows
    idxTms = find(mepData.tmsTrigger);
    idx_start = idxTms - params.lengthPreTms;

    mepTrials = cell(nTrials, 1);

    for idxTrial = 1 : length(idxTrialListCurrent)
        trialIdx = idxTrialListCurrent(idxTrial);

        if trialIdx > length(idx_start)
             error('TMS:IndexError', 'Trial index %d exceeds detected triggers (%d).', trialIdx, length(idx_start));
        end

        % Boundary Check
        if idx_start(trialIdx) < 1 || (idx_start(trialIdx) + params.T_len - 1) > height(mepData)
            error('TMS:BoundaryError', 'Trial %d window is out of data bounds.', trialIdx);
        end

        emg_temp = mepData(idx_start(trialIdx):(idx_start(trialIdx) + params.T_len - 1), emgLabels);

        detrended = detrend(emg_temp, 'linear');
        detrended = [detrended ...
                     mepData((idx_start(trialIdx) : (idx_start(trialIdx) + params.T_len - 1)), "trialClass")];

        mepTrials{idxTrial} = addvars(detrended, ...
                                       zeros(params.T_len, 1) + boolActiveTrials(idxTrial), ...
                                       'NewVariableNames', "boolActive");
    end
end

function [mepResultsControAvg, mepResultsIpsiAvg] = computeAverages(...
    mepResultsRun, hemisphereTmsStr, activityRun, subjIdStr, hAffected, nTrials, settings)
%COMPUTEAVERAGES Perform the c om pu te av er ag es operation for the TMS analysis pipeline.

% Syntax
%   [mepResultsControAvg, mepResultsIpsiAvg] = tms.mep.computeAverages( mepResultsRun, hemisphereTmsStr, activityRun, subjIdStr, hAffected, nTrials, settings)

% Description
%   Perform the c om pu te av er ag es operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    idxTrialValid = height(mepResultsRun);

    % Contro-lateral
    idxValidContro           = false(size(mepResultsRun.mepAmplitudeContro_mV));
    mepAmplitudeControAvg_mV = nan(1,2);
    mepLatencyControAvg_ms   = nan(1,2);
    numValidTrialsContro     = nan(1,2);

    for idxCh = 1:2
        idxValidContro(:,idxCh) = mepResultsRun.mepAmplitudeContro_mV(:,idxCh) > settings.thresholdRestContro;
        mepAmplitudeControAvg_mV(idxCh) = mean(mepResultsRun.mepAmplitudeContro_mV(idxValidContro(:,idxCh), idxCh));
        mepLatencyControAvg_ms(idxCh)   = mean(mepResultsRun.mepLatencyContro_ms(  idxValidContro(:,idxCh), idxCh));
        numValidTrialsContro(idxCh)     = sum(idxValidContro(:,idxCh));
    end

    stimSide = "L";
    if strcmpi(hemisphereTmsStr, "right")
        stimSide = "R";
    end

    actLetter = "R";
    if strcmpi(activityRun, "active")
        actLetter = "A";
    end

    mepResultsControAvg = table(...
        subjIdStr, hAffected, stimSide, actLetter, ...
        numValidTrialsContro(1), numValidTrialsContro(2), ...
        nTrials, idxTrialValid, ...
        mepAmplitudeControAvg_mV(1), mepLatencyControAvg_ms(1), ...
        mepAmplitudeControAvg_mV(2), mepLatencyControAvg_ms(2) );

    mepResultsControAvg.Properties.VariableNames = ["ID", "affected_h", "stim_h", "Active/Rest", ...
        "n_cMEP_BB_valid", "n_cMEP_FDI_valid", "n_trials_tot (with SAS and not)", "n_trials_valid", ...
        "BB_amplitude", "BB_latency", "FDI_amplitude", "FDI_latency" ];

    % =====================================================================
    % Ipsi-lateral (With SAS Combine Logic)
    % =====================================================================
    if isfield(settings, 'exportCombineSas') && settings.exportCombineSas
        combineSas = true;
        sasLoopCount = 1;
    else
        combineSas = false;
        sasLoopCount = 2;
    end

    validIpsiAmp = cell(sasLoopCount,1);
    validIpsiLat = cell(sasLoopCount,1);
    idxValidIpsi = cell(sasLoopCount,1);
    mepAmplitudeIpsiAvg_mV = nan(sasLoopCount,2);
    mepLatencyIpsiAvg_ms   = nan(sasLoopCount,2);
    numValidTrialsIpsi     = nan(sasLoopCount,2);

    for idxSas = 1:sasLoopCount
        if combineSas
            % Combine all trials regardless of SAS
            validIpsiAmp{idxSas} = mepResultsRun.mepAmplitudeIpsi_mV;
            validIpsiLat{idxSas} = mepResultsRun.mepLatencyIpsi_ms;
        else
            % Classic behavior: Split by SAS (0 then 1)
            validIpsiAmp{idxSas} = mepResultsRun.mepAmplitudeIpsi_mV(mepResultsRun.boolSasArray == (idxSas-1),:);
            validIpsiLat{idxSas} = mepResultsRun.mepLatencyIpsi_ms(  mepResultsRun.boolSasArray == (idxSas-1),:);
        end

        thresholdIpsi = settings.thresholdRestIpsi;
        if strcmpi(activityRun, "active")
            thresholdIpsi = settings.thresholdActiveIpsi;
        end

        for idxCh = 1:2
            idxValidIpsi{idxSas}(:,idxCh)        = validIpsiAmp{idxSas}(:,idxCh) > thresholdIpsi;
            mepAmplitudeIpsiAvg_mV(idxSas,idxCh) = mean(validIpsiAmp{idxSas}(idxValidIpsi{idxSas}(:,idxCh), idxCh));
            mepLatencyIpsiAvg_ms(idxSas,idxCh)   = mean(validIpsiLat{idxSas}(idxValidIpsi{idxSas}(:,idxCh), idxCh));
            numValidTrialsIpsi(idxSas,idxCh)     = sum(idxValidIpsi{idxSas}(:,idxCh));
        end
    end

    % Format the table output based on the toggle
    if combineSas
        boolSas = NaN;
        idIpsi = subjIdStr;
        hAffectedVec = hAffected;
        stimSideVec = stimSide;
        actLetterVec = actLetter;
        nTrialsVec = nTrials;
        idxTrialValidVec = idxTrialValid;
    else
        boolSas = [0;1];
        idIpsi = [subjIdStr; subjIdStr];
        hAffectedVec = repmat(hAffected,2,1);
        stimSideVec = [stimSide; stimSide];
        actLetterVec = [actLetter; actLetter];
        nTrialsVec = [nTrials;nTrials];
        idxTrialValidVec = [idxTrialValid;idxTrialValid];
    end

    mepResultsIpsiAvg = table(...
        idIpsi, hAffectedVec, stimSideVec, actLetterVec, boolSas, ...
        numValidTrialsIpsi(:,1), numValidTrialsIpsi(:,2), ...
        nTrialsVec, idxTrialValidVec, ...
        mepAmplitudeIpsiAvg_mV(:,1), mepLatencyIpsiAvg_ms(:,1),...
        mepAmplitudeIpsiAvg_mV(:,2), mepLatencyIpsiAvg_ms(:,2));

    mepResultsIpsiAvg.Properties.VariableNames = ["ID", "affected_h", "stim_h", "Active/Rest", "SAS", ...
        "n_iMEP_BB_valid", "n_iMEP_FDI_valid", "n_trials_tot (with SAS and not)", "n_trials_valid", ...
        "BB_amplitude", "BB_latency", "FDI_amplitude", "FDI_latency" ];
end
