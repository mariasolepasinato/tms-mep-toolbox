function [subjStrList, mode, stepsToRun, doPlot, doSave] = selectSubjectsToProcess(settings, p)
%SELECTSUBJECTSTOPROCESS Perform the s el ec ts ub je ct st op ro ce ss operation for the TMS analysis pipeline.

% Syntax
%   [subjStrList, mode, stepsToRun, doPlot, doSave] = tms.workflow.selectSubjectsToProcess(settings, p)

% Description
%   Perform the s el ec ts ub je ct st op ro ce ss operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    if strcmpi(p.Results.mode, 'interactive') && isempty(p.Results.subjIds) && isempty(p.Results.steps)

        mode = 'interactive';

        % Show unified GUI for all options
        [subjStrList, stepsToRun, doPlot, doSave] = tms.workflow.selectAnalysisOptionsUnified(settings);
        if isempty(subjStrList) || isempty(stepsToRun)
            fprintf("Cancelled or no selection made.\n");
            return;
        end

    else

        allSubjDirs = dir(settings.dirDataRaw);
        allSubjDirs = allSubjDirs([allSubjDirs.isdir] & ~startsWith({allSubjDirs.name}, '.'));
        allSubjStrList = string({allSubjDirs.name}');

        if strcmpi(p.Results.mode, 'auto')

            mode = 'auto';

            subjStrList = allSubjStrList;

            if isempty(subjStrList)
                error('TMS:NoSubjectsFound', 'No subject folders found in: %s', settings.dirDataRaw);
            end

        elseif ~isempty(p.Results.subjIds)

            subjStrList = string(p.Results.subjIds);
            mode = 'manual';

            validIdx = ismember(subjStrList, allSubjStrList);
            if ~all(validIdx)
                warning('TMS:SubjectNotFound', 'Some subjects not found: %s', ...
                    strjoin(subjStrList(~validIdx), ", "));
                subjStrList = subjStrList(validIdx);
            end
        end

        stepsToRun = p.Results.steps;
        if isempty(stepsToRun)
            stepsToRun = [1 2 3];
        end

        doPlot = p.Results.plot;
        if isempty(doPlot), doPlot = true; end

        doSave = p.Results.save;
        if isempty(doSave), doSave = true; end

    end
end
