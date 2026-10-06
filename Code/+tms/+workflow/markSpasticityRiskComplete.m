function workflowLog = markSpasticityRiskComplete(workflowLog)
%MARKSPASTICITYRISKCOMPLETE Record completion of the cohort-level risk step.

    for idx = 1:numel(workflowLog)
        workflowLog(idx).spasticityRisk = true;
    end
end
