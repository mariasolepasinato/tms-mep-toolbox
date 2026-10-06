function finalExcelPath = saveCombinedMepResults(sessionResultsDir, settings)
%SAVECOMBINEDMEPRESULTS Perform the s av ec om bi ne dm ep re su lt s operation for the TMS analysis pipeline.

% Syntax
%   tms.workflow.saveCombinedMepResults(sessionResultsDir, settings)

% Description
%   Perform the s av ec om bi ne dm ep re su lt s operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    subjDirs = dir(sessionResultsDir);
    subjDirs = subjDirs([subjDirs.isdir] & ~startsWith({subjDirs.name}, '.'));

    resultsIpsiAll   = table();
    resultsControAll = table();

    % Read each subject's Excel file and concatenate
    for subj = subjDirs'
        subjPath = fullfile(sessionResultsDir, subj.name);
        subjExcelFile = fullfile(subjPath, sprintf('%s_mep_results.xlsx', subj.name));

        if isfile(subjExcelFile)
            try
                % Read iMEP safely
                optsIpsi = detectImportOptions(subjExcelFile, 'Sheet', 'iMEP');
                optsIpsi.VariableNamingRule = 'preserve';
                % Force all text fields to string to prevent cell vs string errors
                charVars = optsIpsi.VariableNames(strcmp(optsIpsi.VariableTypes, 'char'));
                if ~isempty(charVars), optsIpsi = setvartype(optsIpsi, charVars, 'string'); end

                tIpsi = readtable(subjExcelFile, optsIpsi);
                resultsIpsiAll = safeTableConcat(resultsIpsiAll, tIpsi);

                % Read cMEP safely
                optsContro = detectImportOptions(subjExcelFile, 'Sheet', 'cMEP');
                optsContro.VariableNamingRule = 'preserve';
                charVarsC = optsContro.VariableNames(strcmp(optsContro.VariableTypes, 'char'));
                if ~isempty(charVarsC), optsContro = setvartype(optsContro, charVarsC, 'string'); end

                tContro = readtable(subjExcelFile, optsContro);
                resultsControAll = safeTableConcat(resultsControAll, tContro);

            catch ME
                % If it fails, print the EXACT reason so we can debug it
                warning('TMS:ExcelMergeFailed', 'Could not merge file: %s\nReason: %s', subjExcelFile, ME.message);
            end
        end
    end

    % Save a single Excel file containing all subjects
    finalExcelPath = fullfile(sessionResultsDir, 'mep_results_all_subjects.xlsx');

    if ~isempty(resultsIpsiAll)
        writetable(resultsIpsiAll, finalExcelPath, 'Sheet', 'iMEP');
    end

    if ~isempty(resultsControAll)
        writetable(resultsControAll, finalExcelPath, 'Sheet', 'cMEP');
    end

    fprintf('\n✓ Combined MEP results saved: %s\n', finalExcelPath);
end

function T_all = safeTableConcat(T_all, T_new)
    if isempty(T_all)
        T_all = T_new;
        return;
    end
    T_all = [T_all; T_new];
end
