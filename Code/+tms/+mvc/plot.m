function plot(t, emgDetrended, emgBp, emgRectified, emgForPlot, mvc, mvcMethod, settings, subjStr, bicepIdx)
%PLOT Perform the p lo t operation for the TMS analysis pipeline.

% Syntax
%   tms.mvc.plot(t, emgDetrended, emgBp, emgRectified, emgForPlot, mvc, mvcMethod, settings, subjStr, bicepIdx)

% Description
%   Perform the p lo t operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    figure('Name', sprintf('%s - MVC Analysis (%s)', subjStr, mvcMethod), 'NumberTitle', 'off');
    tiledlayout(3, 1);

    % Raw EMG
    ax(1) = nexttile;
    plot(t, emgDetrended, 'LineWidth', 1);
    title(sprintf('Raw EMG Signal - %s', settings.mvcChString(bicepIdx)));
    xlabel('Time [s]');
    ylabel('Amplitude [mV]');
    grid on;

    % Bandpass filtered EMG
    ax(2) = nexttile;
    plot(t, emgBp, 'LineWidth', 1);
    title('Bandpass Filtered EMG (10-500 Hz)');
    xlabel('Time [s]');
    ylabel('Amplitude [mV]');
    grid on;

    % MVC metric (rectified or envelope)
    ax(3) = nexttile;
    plot(t, emgForPlot, 'LineWidth', 1.5, 'DisplayName', sprintf('%s Signal', capitalize(mvcMethod)));
    hold on;
    mvcIdx = find(emgForPlot == mvc, 1);
    if ~isempty(mvcIdx)
        plot(t(mvcIdx), mvc, 'ro', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', sprintf('MVC = %.3f mV', mvc));
    end
    if strcmpi(mvcMethod, 'rectified')
        plot(t, emgRectified, 'LineWidth', 0.5, 'Color', [0.7 0.7 0.7], 'DisplayName', 'Rectified (detail)');
    end
    title(sprintf('MVC (%s method)', mvcMethod));
    xlabel('Time [s]');
    ylabel('Amplitude [mV]');
    legend;
    grid on;

    % Link axes for better visualization
    linkaxes(ax, 'x');
end


function str = capitalize(str)
    % CAPITALIZE Capitalize first letter of string
    str = string(str);
    str = upper(extractBefore(str, 2)) + extractAfter(str, 1);
end
