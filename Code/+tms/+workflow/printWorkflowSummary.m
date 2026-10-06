function printWorkflowSummary(workflowLog, subjStrList, settings, stepsToRun)
%PRINTWORKFLOWSUMMARY Perform the p ri nt wo rk fl ow su mm ar y operation for the TMS analysis pipeline.

% Syntax
%   tms.workflow.printWorkflowSummary(workflowLog, subjStrList, settings)

% Description
%   Perform the p ri nt wo rk fl ow su mm ar y operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf("WORKFLOW SUMMARY\n");
    fprintf('%s\n', repmat('=', 1, 70));

    if nargin < 4
        stepsToRun = [1 2 3];
    end
    completed = true(1, numel(workflowLog));
    if ismember(1, stepsToRun), completed = completed & [workflowLog.raw2Mat]; end
    if ismember(2, stepsToRun), completed = completed & [workflowLog.mvc]; end
    if ismember(3, stepsToRun), completed = completed & [workflowLog.mepAnalysis]; end
    if ismember(4, stepsToRun), completed = completed & [workflowLog.spasticityRisk]; end

    numSuccess = sum(completed);
    numFailed = sum(~cellfun(@isempty, {workflowLog.error}));
    numTotal = length(subjStrList);
    totalTime = sum([workflowLog.elapsedTime]);

    fprintf("Total Subjects:  %d\n", numTotal);
    fprintf("Completed:       %d\n", numSuccess);
    fprintf("Failed:          %d\n", numFailed);
    fprintf("Total Time:      %.1f seconds (%.1f min)\n", totalTime, totalTime/60);

    if numFailed > 0
        fprintf("\n--- Failed Subjects ---\n");
        for i = 1:length(workflowLog)
            if ~isempty(workflowLog(i).error)
                fprintf("  ✗ %s: %s\n", workflowLog(i).subjStr, workflowLog(i).error);
            end
        end
    end

    partialSubj = ~completed & ...
                  cellfun(@isempty, {workflowLog.error});

    if any(partialSubj)
        fprintf("\n--- Partially Completed ---\n");
        for i = find(partialSubj)
            steps = strings(0, 1);
            if workflowLog(i).mvc, steps = [steps; "MVC"]; end
            if workflowLog(i).raw2Mat, steps = [steps; "Raw2MAT"]; end
            if workflowLog(i).mepAnalysis, steps = [steps; "MEP"]; end
            if isfield(workflowLog, 'spasticityRisk') && workflowLog(i).spasticityRisk
                steps = [steps; "Spasticity risk"];
            end
            fprintf("  ○ %s: %s\n", workflowLog(i).subjStr, strjoin(steps, " → "));
            if isfield(workflowLog, 'mepRunErrors') && any(strlength(workflowLog(i).mepRunErrors) > 0)
                failedRuns = find(strlength(workflowLog(i).mepRunErrors) > 0);
                for runIdx = failedRuns
                    fprintf("      MEP run %d: %s\n", runIdx, workflowLog(i).mepRunErrors(runIdx));
                end
            end
        end
    end

    fprintf('\n%s\n', repmat('=', 1, 70));

    % Save log to file with seconds in timestamp to avoid overwrite
    logFile = fullfile(settings.dirResults, ...
        sprintf('workflow_log_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));

    fid = fopen(logFile, 'w');
    if fid > 0
        fprintf(fid, 'TMS Workflow Log - %s\n', datestr(now));
        fprintf(fid, '%s\n', repmat('=', 1, 70));
        for i = 1:length(workflowLog)
            fprintf(fid, '%s: MVC=%d | Raw2MAT=%d | MEP=%d | SpasticityRisk=%d | Time=%.1fs', ...
                workflowLog(i).subjStr, workflowLog(i).mvc, workflowLog(i).raw2Mat, ...
                workflowLog(i).mepAnalysis, workflowLog(i).spasticityRisk, workflowLog(i).elapsedTime);
            if ~isempty(workflowLog(i).error)
                fprintf(fid, ' | ERROR: %s', workflowLog(i).error);
            end
            if isfield(workflowLog, 'mepRunErrors') && any(strlength(workflowLog(i).mepRunErrors) > 0)
                failedRuns = find(strlength(workflowLog(i).mepRunErrors) > 0);
                for runIdx = failedRuns
                    fprintf(fid, ' | MEP run %d: %s', runIdx, workflowLog(i).mepRunErrors(runIdx));
                end
            end
            fprintf(fid, '\n');
        end
        fclose(fid);
        fprintf("Log saved: %s\n", logFile);
    end
end
