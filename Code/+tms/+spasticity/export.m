function outputFile = export(subjectResults, conditionResults, metrics, outputDirectory)
%EXPORT Write spasticity-risk classification and clinical verification to Excel.

    arguments
        subjectResults table
        conditionResults table
        metrics table
        outputDirectory (1,1) string
    end

    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    outputFile = fullfile(outputDirectory, "spasticity_risk_results.xlsx");
    if isfile(outputFile)
        delete(outputFile);
    end

    subjectResultsComplete = makeSubjectResultsComplete(subjectResults);
    subjectResultsSummary = subjectResultsComplete(:, {'ID', 'high_risk_profile', ...
        'spasticity_present', 'spasticity_category', 'evaluation_status'});

    writetable(subjectResultsSummary, outputFile, 'Sheet', 'Subject_results_summary');
    writetable(subjectResultsComplete, outputFile, 'Sheet', 'Subject_results_complete');
    writetable(conditionResults, outputFile, 'Sheet', 'Algorithm_results');
    writeTableWithCustomHeaders(metrics, outputFile, 'Performance_metrics', ...
        replace(string(metrics.Properties.VariableNames), "_pct", "%"));

    parameters = table( ...
        ["cMEP criterion"; "iMEP criterion"; "High-risk decision"; "Clinical outcome"; "NIHSS T0"], ...
        ["Affected FDI cMEP < 50% of unaffected FDI cMEP"; ...
         "Affected BB iMEP > unaffected BB iMEP OR affected FDI iMEP > unaffected FDI iMEP"; ...
         "Both cMEP and iMEP criteria true in at least one condition"; ...
         "MAS >= 1 at T2; use T1 when MAS at T2 is missing"; ...
         "Exported for traceability; not part of the supplied R decision rule"], ...
        'VariableNames', {'Parameter', 'Definition'});
    writetable(parameters, outputFile, 'Sheet', 'Algorithm_parameters');
end

function subjectResultsComplete = makeSubjectResultsComplete(subjectResults)
    selectedColumns = {'ID', 'high_risk_profile', 'positive_condition', ...
        'any_followup_available', 'decision_timepoint', 'MAS_decision', ...
        'spasticity_present', 'spasticity_category', 'evaluation_status'};

    subjectResultsComplete = subjectResults(:, selectedColumns);
    subjectResultsComplete.high_risk_profile = formatLogicalFlag(subjectResultsComplete.high_risk_profile);
    subjectResultsComplete.any_followup_available = formatLogicalFlag(subjectResultsComplete.any_followup_available);
    subjectResultsComplete.spasticity_present = formatLogicalFlag(subjectResultsComplete.spasticity_present);
end

function formatted = formatLogicalFlag(values)
    formatted = strings(size(values));

    if islogical(values)
        formatted(values) = "True";
        formatted(~values) = "False";
        return;
    end

    numericValues = double(values);
    formatted(numericValues == 1) = "True";
    formatted(numericValues == 0) = "False";
    formatted(isnan(numericValues)) = "NA";
end

function writeTableWithCustomHeaders(T, outputFile, sheetName, headers)
    outputCell = [cellstr(headers); table2cell(T)];
    writecell(outputCell, outputFile, 'Sheet', sheetName);
end
