function [subjectResults, conditionResults, metrics] = analyze(mepResultsFile, clinicalDatabaseFile, subjIds)
%ANALYZE Classify spasticity risk and compare it with MAS follow-up data.
%
% The implementation mirrors R/Algoritmo_solo_MAS_(05_06_26).R:
% - cMEP: affected FDI occurrence is < 50% of unaffected FDI occurrence.
% - iMEP: affected BB or FDI occurrence is > unaffected occurrence.
% - High risk: both criteria are true in at least one condition (R or A).
% - Outcome: MAS >= 1 at T2, falling back to T1 when MAS at T2 is absent.
%
% NIHSS at T0 is included in the output for traceability.  It is not used
% to classify risk because the supplied R algorithm does not define a NIHSS
% threshold or a rule for combining it with the MEP criteria.

    arguments
        mepResultsFile (1,1) string
        clinicalDatabaseFile (1,1) string
        subjIds string = strings(0, 1)
    end

    mustExist(mepResultsFile, "MEP results workbook");
    mustExist(clinicalDatabaseFile, "clinical database workbook");

    cMep = readMepSheet(mepResultsFile, "cMEP");
    iMep = readMepSheet(mepResultsFile, "iMEP");
    clinical = readClinicalData(clinicalDatabaseFile);

    requestedSubjectLabels = string(subjIds(:));
    requestedIds = unique(normalizeId(requestedSubjectLabels));
    if isempty(requestedIds)
        requestedIds = unique([cMep.ID; iMep.ID]);
    end

    cMep = cMep(ismember(cMep.ID, requestedIds), :);
    iMep = iMep(ismember(iMep.ID, requestedIds), :);
    clinical = clinical(ismember(clinical.ID, requestedIds), :);

    conditionResults = buildConditionResults(cMep, iMep, requestedIds);
    algorithm = summarizeAlgorithm(conditionResults, requestedIds);
    subjectResults = outerjoin(algorithm, clinical, 'Keys', 'ID', ...
        'MergeKeys', true, 'Type', 'left');
    subjectResults = sortrows(subjectResults, 'ID');
    subjectResults.Workflow_ID = subjectResults.ID;
    for row = 1:numel(requestedSubjectLabels)
        matchingRows = subjectResults.ID == normalizeId(requestedSubjectLabels(row));
        subjectResults.Workflow_ID(matchingRows) = requestedSubjectLabels(row);
    end

    subjectResults = addOutcomeAndEvaluation(subjectResults);
    metrics = calculateMetrics(subjectResults);
end

function mustExist(filePath, description)
    if ~isfile(filePath)
        error('TMS:Spasticity:MissingInput', '%s not found: %s', description, filePath);
    end
end

function T = readMepSheet(filePath, sheetName)
    opts = detectImportOptions(filePath, 'Sheet', sheetName);
    opts.VariableNamingRule = 'preserve';
    T = readtable(filePath, opts);
    required = ["ID", "stim_on_affected_h"];
    assertRequiredColumns(T, required, sprintf('%s sheet', sheetName));

    conditionColumn = ["Cond", "Active/Rest"];
    conditionColumn = conditionColumn(ismember(conditionColumn, string(T.Properties.VariableNames)));
    if isempty(conditionColumn)
        error('TMS:Spasticity:MissingColumn', ...
            '%s sheet is missing the condition column Cond or Active/Rest.', sheetName);
    end

    T.ID = normalizeId(T.ID);
    T.Cond = string(T.(conditionColumn(1)));
    T.stim_on_affected_h = parseNumeric(T.("stim_on_affected_h"));
end

function clinical = readClinicalData(filePath)
    t0 = readClinicalSheet(filePath, "T0", ["ID", "NIHSS"]);
    t1 = readClinicalSheet(filePath, "T1", ["ID", "MAS_UL"]);
    t2 = readClinicalSheet(filePath, "T2", ["ID", "MAS_UL"]);

    h1 = getOptionalColumn(t1, ["H_reflex", "H_refelex"]);
    h2 = getOptionalColumn(t2, ["H_reflex", "H_refelex"]);

    t0Small = table(normalizeId(t0.ID), parseNumeric(t0.("NIHSS")), ...
        'VariableNames', {'ID', 'NIHSS_T0'});
    t1Small = table(normalizeId(t1.ID), parseNumeric(t1.("MAS_UL")), h1, ...
        'VariableNames', {'ID', 'MAS_T1', 'H_T1'});
    t2Small = table(normalizeId(t2.ID), parseNumeric(t2.("MAS_UL")), h2, ...
        'VariableNames', {'ID', 'MAS_T2', 'H_T2'});

    t0Small = t0Small(t0Small.ID ~= "", :);
    t1Small = t1Small(t1Small.ID ~= "", :);
    t2Small = t2Small(t2Small.ID ~= "", :);
    clinical = outerjoin(t0Small, t1Small, 'Keys', 'ID', 'MergeKeys', true, 'Type', 'full');
    clinical = outerjoin(clinical, t2Small, 'Keys', 'ID', 'MergeKeys', true, 'Type', 'full');
    clinical = clinical(clinical.ID ~= "", :);
    clinical.any_followup_available = ~isnan(clinical.MAS_T1) | ~isnan(clinical.H_T1) | ...
        ~isnan(clinical.MAS_T2) | ~isnan(clinical.H_T2);
end

function T = readClinicalSheet(filePath, sheetName, requiredColumns)
    opts = detectImportOptions(filePath, 'Sheet', sheetName);
    opts.VariableNamingRule = 'preserve';
    T = readtable(filePath, opts);
    assertRequiredColumns(T, requiredColumns, sprintf('%s sheet', sheetName));
end

function value = getOptionalColumn(T, candidates)
    columnName = candidates(ismember(candidates, string(T.Properties.VariableNames)));
    if isempty(columnName)
        value = nan(height(T), 1);
    else
        value = parseNumeric(T.(columnName(1)));
    end
end

function assertRequiredColumns(T, requiredColumns, sourceDescription)
    missing = requiredColumns(~ismember(requiredColumns, string(T.Properties.VariableNames)));
    if ~isempty(missing)
        error('TMS:Spasticity:MissingColumn', '%s is missing required column(s): %s', ...
            sourceDescription, strjoin(missing, ', '));
    end
end

function conditionResults = buildConditionResults(cMep, iMep, requestedIds)
    conditionResults = table('Size', [0 14], ...
        'VariableTypes', ["string", "string", repmat("double", 1, 12)], ...
        'VariableNames', {'ID', 'Cond', 'cMEP_FDI_aff', 'cMEP_FDI_unaff', ...
        'ratio_cMEP_FDI', 'iMEP_BB_aff', 'iMEP_BB_unaff', 'iMEP_FDI_aff', ...
        'iMEP_FDI_unaff', 'flag_cMEP', 'flag_iMEP_BB', 'flag_iMEP_FDI', 'flag_iMEP', ...
        'high_risk_profile_cond'});

    % Match the R left_join: a condition is evaluated only when cMEP data
    % are available; iMEP values are then attached to that condition.
    allConditions = unique(cMep(:, {'ID', 'Cond'}));
    allConditions = allConditions(ismember(allConditions.ID, requestedIds), :);
    allConditions = sortrows(allConditions, {'ID', 'Cond'});

    for row = 1:height(allConditions)
        id = allConditions.ID(row);
        cond = allConditions.Cond(row);
        cRows = cMep(cMep.ID == id & cMep.Cond == cond, :);
        iRows = iMep(iMep.ID == id & iMep.Cond == cond, :);

        cAff = getMepValue(cRows, "n_cMEP_FDI_valid", true);
        cUnaff = getMepValue(cRows, "n_cMEP_FDI_valid", false);
        iBbAff = getMepValue(iRows, "n_iMEP_BB_valid", false); % iMEP arm mapping is inverted.
        iBbUnaff = getMepValue(iRows, "n_iMEP_BB_valid", true);
        iFdiAff = getMepValue(iRows, "n_iMEP_FDI_valid", false);
        iFdiUnaff = getMepValue(iRows, "n_iMEP_FDI_valid", true);

        ratio = safeDivide(cAff, cUnaff);
        flagC = NaN;
        if ~isnan(cAff) && ~isnan(cUnaff) && cUnaff ~= 0
            flagC = cAff < 0.5 * cUnaff;
        end
        flagIBb = compareGreater(iBbAff, iBbUnaff);
        flagIFdi = compareGreater(iFdiAff, iFdiUnaff);
        flagI = logicalOrWithMissing(flagIBb, flagIFdi);
        highRisk = logicalAndWithMissing(flagC, flagI);

        conditionResults = [conditionResults; table(id, cond, cAff, cUnaff, ratio, ...
            iBbAff, iBbUnaff, iFdiAff, iFdiUnaff, flagC, flagIBb, flagIFdi, flagI, highRisk, ...
            'VariableNames', conditionResults.Properties.VariableNames)]; %#ok<AGROW>
    end
end

function value = getMepValue(T, columnName, stimulatedAffected)
    if isempty(T) || ~ismember(columnName, string(T.Properties.VariableNames))
        value = NaN;
        return;
    end
    matches = T.stim_on_affected_h == double(stimulatedAffected);
    values = parseNumeric(T.(columnName));
    values = values(matches);
    values = values(~isnan(values));
    if isempty(values)
        value = NaN;
    else
        value = values(1);
    end
end

function algorithm = summarizeAlgorithm(conditionResults, requestedIds)
    algorithm = table(requestedIds, nan(numel(requestedIds), 1), strings(numel(requestedIds), 1), ...
        'VariableNames', {'ID', 'high_risk_profile', 'positive_condition'});
    for row = 1:height(algorithm)
        rows = conditionResults(conditionResults.ID == algorithm.ID(row), :);
        if isempty(rows) || all(isnan(rows.high_risk_profile_cond))
            continue;
        end
        positive = rows.high_risk_profile_cond == 1;
        if any(positive)
            algorithm.high_risk_profile(row) = true;
            algorithm.positive_condition(row) = strjoin(unique(rows.Cond(positive)), ", ");
        else
            algorithm.high_risk_profile(row) = false;
        end
    end
end

function subjectResults = addOutcomeAndEvaluation(subjectResults)
    n = height(subjectResults);
    subjectResults.decision_timepoint = strings(n, 1);
    subjectResults.MAS_decision = nan(n, 1);
    subjectResults.spasticity_present = nan(n, 1);
    subjectResults.spasticity_category = strings(n, 1);
    subjectResults.evaluation_status = strings(n, 1);

    for row = 1:n
        if ~isnan(subjectResults.MAS_T2(row))
            subjectResults.decision_timepoint(row) = "T2";
            subjectResults.MAS_decision(row) = subjectResults.MAS_T2(row);
        elseif ~isnan(subjectResults.MAS_T1(row))
            subjectResults.decision_timepoint(row) = "T1";
            subjectResults.MAS_decision(row) = subjectResults.MAS_T1(row);
        end

        if ~isnan(subjectResults.MAS_decision(row))
            subjectResults.spasticity_present(row) = subjectResults.MAS_decision(row) >= 1;
            if subjectResults.spasticity_present(row)
                subjectResults.spasticity_category(row) = "MAS_based_spasticity";
            else
                subjectResults.spasticity_category(row) = "no_spasticity";
            end
        elseif subjectResults.any_followup_available(row)
            subjectResults.spasticity_category(row) = "follow-up_available_but_MAS_missing";
        end

        prediction = subjectResults.high_risk_profile(row);
        outcome = subjectResults.spasticity_present(row);
        subjectResults.evaluation_status(row) = evaluationStatus(prediction, outcome);
    end
end

function metrics = calculateMetrics(subjectResults)
    valid = ~isnan(subjectResults.high_risk_profile) & ~isnan(subjectResults.spasticity_present);
    prediction = subjectResults.high_risk_profile(valid);
    outcome = subjectResults.spasticity_present(valid);
    tp = sum(prediction & outcome);
    fp = sum(prediction & ~outcome);
    tn = sum(~prediction & ~outcome);
    fn = sum(~prediction & outcome);
    sensitivity = safeDivide(tp, tp + fn);
    specificity = safeDivide(tn, tn + fp);
    metrics = table(numel(prediction), sum(~subjectResults.any_followup_available), sum(~valid), ...
        tp, fp, tn, fn, 100 * sensitivity, 100 * specificity, 100 * safeDivide(tp, tp + fp), ...
        100 * safeDivide(tn, tn + fn), 100 * safeDivide(tp + tn, tp + tn + fp + fn), ...
        100 * mean([sensitivity, specificity], 'omitnan'), 100 * safeDivide(2 * tp, 2 * tp + fp + fn), ...
        'VariableNames', {'N_included', 'N_excluded_no_followup', 'N_excluded_from_performance', ...
        'TP', 'FP', 'TN', 'FN', 'sensitivity_pct', 'specificity_pct', 'PPV_pct', 'NPV_pct', ...
        'accuracy_pct', 'balanced_accuracy_pct', 'F1_score_pct'});
end

function status = evaluationStatus(prediction, outcome)
    if isnan(prediction) && isnan(outcome)
        status = "Not evaluable";
    elseif isnan(prediction)
        status = "MAS outcome available, algorithm classification missing";
    elseif isnan(outcome)
        if prediction
            status = "High-risk by algorithm, follow-up available but MAS outcome missing";
        else
            status = "Not high-risk by algorithm, follow-up available but MAS outcome missing";
        end
    elseif prediction && outcome
        status = "True positive";
    elseif prediction && ~outcome
        status = "False positive";
    elseif ~prediction && ~outcome
        status = "True negative";
    else
        status = "False negative";
    end
end

function value = parseNumeric(value)
    if isnumeric(value)
        value = double(value);
        return;
    end
    textValue = strrep(string(value), ',', '.');
    match = regexp(textValue, '-?\d+\.?\d*', 'match', 'once');
    value = str2double(match);
end

function id = normalizeId(value)
    if isnumeric(value)
        id = string(value);
    else
        id = strtrim(string(value));
    end
    numericId = str2double(id);
    id(~isnan(numericId)) = string(numericId(~isnan(numericId)));
    % The MATLAB pipeline may name subjects sub-001, while the clinical
    % workbook stores the same participant as 1.  Use a trailing numeric
    % identifier only when the complete value is not already numeric.
    nonNumeric = isnan(numericId);
    numericSuffix = regexp(id(nonNumeric), '\d+$', 'match', 'once');
    suffixValue = str2double(numericSuffix);
    hasSuffix = ~isnan(suffixValue);
    nonNumericIndex = find(nonNumeric);
    id(nonNumericIndex(hasSuffix)) = string(suffixValue(hasSuffix));
end

function result = safeDivide(numerator, denominator)
    if isnan(numerator) || isnan(denominator) || denominator == 0
        result = NaN;
    else
        result = numerator / denominator;
    end
end

function result = compareGreater(left, right)
    result = NaN;
    if ~isnan(left) && ~isnan(right)
        result = left > right;
    end
end

function result = logicalOrWithMissing(left, right)
    if (~isnan(left) && left) || (~isnan(right) && right)
        result = true;
    elseif isnan(left) && isnan(right)
        result = NaN;
    else
        result = false;
    end
end

function result = logicalAndWithMissing(left, right)
    if ~isnan(left) && ~isnan(right) && left && right
        result = true;
    elseif (~isnan(left) && ~left) || (~isnan(right) && ~right)
        result = false;
    else
        result = NaN;
    end
end
