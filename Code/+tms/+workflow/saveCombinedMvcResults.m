function saveCombinedMvcResults(allMvcTables, allMvcPpTables, sessionResultsDir, settings)
%SAVECOMBINEDMVCRESULTS Perform the s av ec om bi ne dm vc re su lt s operation for the TMS analysis pipeline.

% Syntax
%   tms.workflow.saveCombinedMvcResults(allMvcTables, allMvcPpTables, sessionResultsDir, settings)

% Description
%   Perform the s av ec om bi ne dm vc re su lt s operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    combinedMvcTable  = [];
    combinedMvcPpTable = [];

    for i = 1:length(allMvcTables)
        if ~isempty(allMvcTables{i})
            combinedMvcTable = [combinedMvcTable; allMvcTables{i}];
        end
        if ~isempty(allMvcPpTables{i})
            combinedMvcPpTable = [combinedMvcPpTable; allMvcPpTables{i}];
        end
    end

    % Salva in Excel unico
    excelPath = fullfile(sessionResultsDir, 'mvc_results_all_subjects.xlsx');
    if ~isempty(combinedMvcTable)
        writetable(combinedMvcTable, excelPath, 'Sheet', 'MVC');
    end
    if ~isempty(combinedMvcPpTable)
        writetable(combinedMvcPpTable, excelPath, 'Sheet', 'Peak-to-Peak');
    end

    fprintf('\n✓ Combined MVC results saved: %s\n', excelPath);
end
