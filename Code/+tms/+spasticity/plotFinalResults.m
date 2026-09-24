function outputFiles = plotFinalResults(subjectResults, metrics, outputDirectory)
%PLOTFINALRESULTS Save final spasticity-risk plots matching the R workflow.

    arguments
        subjectResults table
        metrics table
        outputDirectory (1,1) string
    end

    plotDirectory = fullfile(outputDirectory, "spasticity_risk_plots");
    if ~isfolder(plotDirectory)
        mkdir(plotDirectory);
    end

    outputFiles = strings(2, 1);
    outputFiles(1) = plotConfusionMatrix(metrics, plotDirectory);
    outputFiles(2) = plotPerformanceMetrics(metrics, plotDirectory);
end

function outputFile = plotConfusionMatrix(metrics, plotDirectory)
    tp = getMetricValue(metrics, "TP");
    fp = getMetricValue(metrics, "FP");
    tn = getMetricValue(metrics, "TN");
    fn = getMetricValue(metrics, "FN");

    categories = ["True positive", "False positive"; "False negative", "True negative"];
    counts = [tp, fp; fn, tn];
    correctColor = [217, 242, 221] ./ 255;
    errorColor = [250, 218, 218] ./ 255;

    hFig = figure('Visible', 'off', 'Color', 'w', ...
        'Name', 'Algorithm classification vs MAS-based spasticity outcome');
    ax = axes(hFig);
    hold(ax, 'on');

    for y = 1:2
        for x = 1:2
            if x == y
                fillColor = correctColor;
            else
                fillColor = errorColor;
            end
            rectangle(ax, ...
                'Position', [x - 0.5, y - 0.5, 1, 1], ...
                'FaceColor', fillColor, ...
                'EdgeColor', 'w', ...
                'LineWidth', 1.2);
            text(ax, x, y, sprintf('%s\nN = %d', categories(y, x), counts(y, x)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 12);
        end
    end

    axis(ax, [0.5, 2.5, 0.5, 2.5]);
    axis(ax, 'square');
    set(ax, ...
        'XTick', 1:2, ...
        'XTickLabel', {'MAS ≥ 1', 'MAS < 1'}, ...
        'YTick', 1:2, ...
        'YTickLabel', {'High-risk', 'Not high-risk'}, ...
        'YDir', 'reverse', ...
        'Box', 'off', ...
        'TickLength', [0, 0], ...
        'FontSize', 13);
    xlabel(ax, 'Observed outcome', 'FontWeight', 'bold');
    ylabel(ax, 'Algorithm prediction', 'FontWeight', 'bold');
    title(ax, 'Algorithm classification vs MAS-based spasticity outcome', ...
        'FontWeight', 'bold');

    outputFile = fullfile(plotDirectory, "spasticity_confusion_matrix.png");
    exportgraphics(hFig, outputFile, 'Resolution', 300);
    close(hFig);
end

function outputFile = plotPerformanceMetrics(metrics, plotDirectory)
    metricColumns = ["sensitivity_pct", "specificity_pct", "PPV_pct", "NPV_pct", ...
        "accuracy_pct", "balanced_accuracy_pct"];
    metricLabels = ["Sensitivity", "Specificity", "PPV", "NPV", ...
        "Accuracy", "Balanced accuracy"];
    values = arrayfun(@(name) getMetricValue(metrics, name), metricColumns);

    [sortedValues, order] = sort(values, 'ascend', 'MissingPlacement', 'first');
    sortedLabels = metricLabels(order);
    barValues = sortedValues;
    barValues(isnan(barValues)) = 0;

    hFig = figure('Visible', 'off', 'Color', 'w', ...
        'Name', 'Preliminary algorithm performance');
    ax = axes(hFig);
    barh(ax, barValues, 0.65);
    xlim(ax, [0, 110]);
    ax.XGrid = 'on';
    ax.YGrid = 'off';
    ax.XTick = 0:10:100;
    ax.YTick = 1:numel(sortedLabels);
    ax.YTickLabel = cellstr(sortedLabels);
    ax.FontSize = 13;
    ax.Box = 'off';

    for idx = 1:numel(sortedValues)
        if isnan(sortedValues(idx))
            label = "NA";
            xPosition = 1;
        else
            label = sprintf('%.1f%%', sortedValues(idx));
            xPosition = min(sortedValues(idx) + 2, 108);
        end
        text(ax, xPosition, idx, label, ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 12);
    end

    title(ax, 'Preliminary algorithm performance', 'FontWeight', 'bold');
    subtitle(ax, 'Outcome defined as MAS ≥ 1');
    xlabel(ax, 'Performance (%)', 'FontWeight', 'bold');
    ylabel(ax, '');

    outputFile = fullfile(plotDirectory, "spasticity_performance_metrics.png");
    exportgraphics(hFig, outputFile, 'Resolution', 300);
    close(hFig);
end

function value = getMetricValue(metrics, variableName)
    if ~ismember(variableName, string(metrics.Properties.VariableNames)) || isempty(metrics)
        value = NaN;
        return;
    end
    value = metrics.(variableName)(1);
end
