function export(mvcTable, mvcPpTable, settings, sessionTimestamp)
%EXPORT Perform the e xp or t operation for the TMS analysis pipeline.

% Syntax
%   tms.mvc.export(mvcTable, mvcPpTable, settings, sessionTimestamp)

% Description
%   Perform the e xp or t operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    resultsDir = fullfile(settings.dirResults, sessionTimestamp);
    mkdir(resultsDir);

    % Save Excel files
    excelPath = fullfile(resultsDir, "mvcTable.xlsx");
    writetable(mvcTable, excelPath, 'Sheet', 1);
    fprintf("Saved rectified MVC results: %s\n", excelPath);

    excelPpPath = fullfile(resultsDir, "mvcPpTable.xlsx");
    writetable(mvcPpTable, excelPpPath, 'Sheet', 1);
    fprintf("Saved peak-to-peak MVC results: %s\n", excelPpPath);
end
