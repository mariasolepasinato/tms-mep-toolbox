function workflowLog = tms_main_workflow(varargin)
%TMS_MAIN_WORKFLOW Run the complete TMS processing workflow.

% Syntax
%   workflowLog = tms_main_workflow(varargin)

% Description
%   Coordinates conversion, MVC analysis, MEP analysis, result aggregation,
%   progress reporting, and per-subject error logging.

% Inputs
%   varargin - Optional workflow configuration supplied as name-value pairs.

% Name-Value Arguments
%   subjIds - Subject ID or array of IDs to process.
%   steps - Selected steps: 1 (conversion), 2 (MVC), 3 (MEP), and/or 4
%       (spasticity-risk prediction and clinical MAS follow-up verification).
%   plot, save - Logical flags controlling diagnostic plots and export.
%   mode - 'interactive' or 'auto' subject-selection mode.
%   projectRoot - Optional root folder containing Code and Data.
%   clinicalDatabaseFile - Excel file containing clinical T0, T1, and T2
%       sheets used by step 4 for NIHSS extraction and MAS/H-reflex
%       follow-up verification. If omitted when step 4 is selected, a file
%       selection dialog opens and asks the user to choose the clinical
%       database file.

% Outputs
%   workflowLog - Per-subject completion flags, elapsed time, and errors.

% See also
%   tms_main_workflow

    p = inputParser;
    addParameter(p, 'subjIds', [], @(x) isstring(x) || ischar(x) || iscell(x));
    addParameter(p, 'steps', [], @isvector);
    addParameter(p, 'plot', [], @(x) islogical(x) || isempty(x));
    addParameter(p, 'save', [], @(x) islogical(x) || isempty(x));
    addParameter(p, 'mode', 'interactive', @ischar);
    addParameter(p, 'projectRoot', "", @(x) isstring(x) || ischar(x));
    addParameter(p, 'clinicalDatabaseFile', "", @(x) isstring(x) || ischar(x));
    parse(p, varargin{:});

    % Load settings
    codeDir = fileparts(mfilename('fullpath'));
    addpath(codeDir);
    settings = tms.config.createSettings('projectRoot', p.Results.projectRoot);

    % Get analysis parameters
    [subjStrList, ~, stepsToRun, doPlot, doSave] = tms.workflow.selectSubjectsToProcess(settings, p);

    if isempty(subjStrList) || isempty(stepsToRun)
        return;
    end

    % The risk algorithm uses the MEP occurrence counts generated in step 3.
    if ismember(4, stepsToRun) && ~ismember(3, stepsToRun)
        fprintf("Spasticity-risk prediction requires MEP results; automatically adding MEP analysis.\n");
        stepsToRun = unique([stepsToRun, 3]);
    end

    % Check that CSV files have been converted from Delsys SHPF files.
    tms.workflow.checkCSVFilesExist(subjStrList, settings);

    % Smart conversion detection for MEP analysis
    [subjStrList_ready, subjStrList_mvcConv, subjStrList_mepConv] = tms.workflow.identifyConversionNeeds(subjStrList, settings);
    subjStrList_needConv = unique([subjStrList_mvcConv; subjStrList_mepConv]);

    if ~isempty(subjStrList_needConv)
        fprintf("\nChecking data availability for MEP analysis...\n");
        fprintf("  OK   %d subject(s) have all required MAT files\n", length(subjStrList_ready));
        fprintf("  INFO %d subject(s) need MAT file conversion\n", (length(subjStrList_mvcConv) + length(subjStrList_mepConv)));

        if ~ismember(1, stepsToRun)
            fprintf("       -> Automatically adding Raw to MAT conversion\n");
            stepsToRun = unique([stepsToRun, 1]);
        end
    end

    % Initialize workflow log
    workflowLog = tms.workflow.initializeWorkflowLog(subjStrList);

    % Display parameters
    fprintf("\n%s\n", repmat('=', 1, 70));
    fprintf("TMS WORKFLOW - Analysis Parameters\n");
    fprintf("%s\n", repmat('=', 1, 70));
    fprintf("  Subjects: %d\n", length(subjStrList));
    fprintf("  Steps:    %s\n", tms.workflow.createStepsString(stepsToRun));
    fprintf("  Plot:     %s | Save: %s\n", tms.workflow.boolToStr(doPlot), tms.workflow.boolToStr(doSave));
    fprintf("%s\n\n", repmat('=', 1, 70));

    % Create progress bar
    hProgress = waitbar(0, 'Starting workflow...', 'Name', 'TMS Workflow Progress');

    sessionTimestamp  = string(datetime("now",'Format','yyyy-MM-dd_HH-mm-ss'));
    sessionResultsDir = fullfile(settings.dirResults, sessionTimestamp);
    mkdir(sessionResultsDir)

    fprintf("Session Results Folder: %s\n", sessionResultsDir);

    allMvcTables   = cell(length(subjStrList), 1);
    allMvcPpTables = cell(length(subjStrList), 1);
    mustSaveMepResults = doSave || ismember(4, stepsToRun);
    numberOfSteps = 3 + ismember(4, stepsToRun);

    % Process each subject
    for subjIdx = 1 : length(subjStrList)

        subjStr = subjStrList(subjIdx);

        % Calculate progress increments for steps
        baseProgress = (subjIdx - 1) / length(subjStrList);
        stepIncrement = 1 / length(subjStrList) / numberOfSteps;

        fprintf('\n%s\n', repmat('=', 1, 70));
        fprintf('Subject %d/%d: %s\n', subjIdx, length(subjStrList), subjStr);
        fprintf('%s\n', repmat('=', 1, 70));

        tic;  % Start timer

        try

            subjStrTemp = split(subjStr, '_');
            % Step 1: Raw to MAT conversion
            if ismember(1, stepsToRun)
                waitbar(baseProgress + 0*stepIncrement, hProgress, ...
                        sprintf('Pz\\_%s (%d/%d) - Step 1/%d: Raw to MAT Conversion...', subjStrTemp{2}, subjIdx, length(subjStrList), numberOfSteps));

                if ~ismember(subjStr, subjStrList_ready)
                    fprintf("\n[STEP 1/%d] Raw to MAT Conversion...\n", numberOfSteps);
                    if ismember(subjStr, subjStrList_mvcConv)
                        fprintf("  Converting MVC data...\n");
                        tms.io.convertMvc(subjStr, settings);
                    end
                    if ismember(subjStr, subjStrList_mepConv)
                        fprintf("  Converting MEP data...\n");
                        tms.io.convertMep(subjStr, settings);
                    end
                    workflowLog(subjIdx).raw2Mat = true;
                else
                    fprintf("\n[STEP 1/%d] Skipped - All MAT files exist\n", numberOfSteps);
                    workflowLog(subjIdx).raw2Mat = true;
                end
            end

            % Step 2: MVC Analysis
            if ismember(2, stepsToRun)
                waitbar(baseProgress + 1*stepIncrement, hProgress, ...
                        sprintf('%s (%d/%d) - Step 2/%d: MVC Analysis...', subjStr, subjIdx, length(subjStrList), numberOfSteps));
                fprintf("\n[STEP 2/%d] MVC Analysis...\n", numberOfSteps);
                [mvcTable, mvcPpTable] = tms.mvc.analyze(subjStr, settings, ...
                                                            'save', false, ...
                                                            'plot', doPlot, ...
                                                            'sessionTimestamp', sessionTimestamp);
                allMvcTables{subjIdx}   = mvcTable;
                allMvcPpTables{subjIdx} = mvcPpTable;
                workflowLog(subjIdx).mvc = true;
            end

            % Step 3: MEP Analysis
            if ismember(3, stepsToRun)
                waitbar(baseProgress + 2*stepIncrement, hProgress, ...
                        sprintf('%s (%d/%d) - Step 3/%d: MEP Analysis...', subjStr, subjIdx, length(subjStrList), numberOfSteps));
                fprintf("\n[STEP 3/%d] MEP Analysis...\n", numberOfSteps);
                [~, ~, mepStatus] = tms.mep.analyze(subjStr, settings, ...
                    'plot', doPlot, 'save', mustSaveMepResults, 'sessionTimestamp', sessionTimestamp);
                workflowLog(subjIdx).mepAnalysis = mepStatus.allSelectedRunsSuccessful;
                workflowLog(subjIdx).mepRunErrors = mepStatus.errors;
            end

            % Record elapsed time
            workflowLog(subjIdx).elapsedTime = toc;

            fprintf("\n✓ Subject %s: COMPLETED (%.1f seconds)\n", subjStr, workflowLog(subjIdx).elapsedTime);

        catch ME
            workflowLog(subjIdx).elapsedTime = toc;
            fprintf(2, "\n✗ ERROR processing subject %s:\n  %s\n", subjStr, ME.message);
            workflowLog(subjIdx).error = ME.message;
        end
    end

    % Close progress bar
    if ishandle(hProgress)
        close(hProgress);
    end

    if doSave && ismember(2, stepsToRun) && any(~cellfun(@isempty, allMvcTables))
        tms.workflow.saveCombinedMvcResults(allMvcTables, allMvcPpTables, sessionResultsDir, settings);
    end

    % Save combined results spreadsheet
    combinedMepFile = "";
    if mustSaveMepResults && ismember(3, stepsToRun)
        combinedMepFile = tms.workflow.saveCombinedMepResults(sessionResultsDir, settings);
    end

    if ismember(4, stepsToRun)
        clinicalDatabaseFile = string(p.Results.clinicalDatabaseFile);
        if strlength(clinicalDatabaseFile) == 0
            [clinicalFileName, clinicalFilePath] = uigetfile( ...
                {'*.xlsx;*.xls', 'Excel files (*.xlsx, *.xls)'; '*.*', 'All files (*.*)'}, ...
                'Select the clinical database file for spasticity-risk analysis');

            if isequal(clinicalFileName, 0)
                error("tms_main_workflow:MissingClinicalDatabase", ...
                    "Step 4 requires a clinical database Excel file. " + ...
                    "Pass it with 'clinicalDatabaseFile' or select it in the file dialog.");
            end

            clinicalDatabaseFile = string(fullfile(clinicalFilePath, clinicalFileName));
        end
        try
            [subjectResults, conditionResults, metrics] = tms.spasticity.analyze( ...
                combinedMepFile, clinicalDatabaseFile, subjStrList);
            riskOutputFile = tms.spasticity.export(subjectResults, conditionResults, metrics, sessionResultsDir);
            riskPlotFiles = tms.spasticity.plotFinalResults(subjectResults, metrics, sessionResultsDir);
            workflowLog = tms.workflow.markSpasticityRiskComplete(workflowLog);
            fprintf("\n[STEP 4/%d] Spasticity-risk results saved: %s\n", numberOfSteps, riskOutputFile);
            fprintf("[STEP 4/%d] Spasticity-risk plots saved:\n", numberOfSteps);
            fprintf("  %s\n", riskPlotFiles);
        catch ME
            fprintf(2, "\n[STEP 4/%d] Spasticity-risk analysis failed: %s\n", numberOfSteps, ME.message);
            for subjIdx = 1 : numel(workflowLog)
                workflowLog(subjIdx).error = sprintf('Spasticity-risk analysis: %s', ME.message);
            end
        end
    end

    % Print and save workflow summary after all selected steps, including the
    % cohort-level spasticity-risk analysis, have completed.
    tms.workflow.printWorkflowSummary(workflowLog, subjStrList, settings, stepsToRun);
end
