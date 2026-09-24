function [mvcTable, mvcPpTable] = analyze(subjIds, settings, varargin)
%ANALYZE Run MVC analysis and return subject-level amplitude summaries.

% Syntax
%   [mvcTable, mvcPpTable] = tms.mvc.analyze(subjIds, settings, varargin)

% Description
%   Run MVC analysis and return subject-level amplitude summaries.

% Inputs
%   subjIds - One subject ID or an array of subject IDs.
%   settings - Validated settings structure from tms.config.createSettings.

% Name-Value Arguments
%   plot - Enable diagnostic plots (default: false).
%   save - Export MVC result tables (default: true).
%   method - 'rectified' or 'envelope' MVC extraction method.
%   sessionTimestamp - Timestamp used to group generated output files.

% Outputs
%   mvcTable - MVC amplitude summary for each requested subject.
%   mvcPpTable - Raw peak-to-peak amplitude summary for each subject.

% See also
%   tms_main_workflow


    % Parse input arguments
    p = inputParser;
    addRequired(p, 'subjIds', @(x) isstring(x) || ischar(x) || iscell(x));
    addRequired(p, 'settings', @isstruct);
    addParameter(p, 'plot', false, @islogical);
    addParameter(p, 'save', true, @islogical);
    addParameter(p, 'method', 'rectified', @ischar);
    addParameter(p, 'sessionTimestamp', string(datetime("now",'Format','yyyy-MM-dd_HH-mm-ss')), @isstring);
    parse(p, subjIds, settings, varargin{:});

    subjIds = string(p.Results.subjIds);
    doPlot = p.Results.plot;
    doSave = p.Results.save;
    mvcMethod = tms.mvc.validateMvcMethod(p.Results.method);
    sessionTimestamp = p.Results.sessionTimestamp;

    % Prepare filter
    bandpassFreq = [10, 500];
    filterOrder = 4;
    [filtNum, filtDen] = tms.mvc.designButterworthFilter(bandpassFreq, settings.fs_emg, filterOrder);

    % Initialize output tables
    numSubj = length(subjIds);
    mvcTable   = table('Size', [numSubj, 3], ...
                       'VariableTypes', ["string", "double", "double"], ...
                       'VariableNames', ["Subject", settings.mvcChString]);

    mvcPpTable = table('Size', [numSubj, 3], ...
                       'VariableTypes', ["string", "double", "double"], ...
                       'VariableNames', ["Subject", settings.mvcChString]);

    fprintf("MVC Analysis Method: %s\n\n", mvcMethod);

    % Process each subject
    for idxSubj = 1 : numSubj

        subjStr = subjIds(idxSubj);
        fprintf("Processing MVC for subject: %s\n", subjStr);

        try

            % Find and load MVC data
            mvcData = loadMvcData(subjStr, settings);

            if isempty(mvcData)
                warning('TMS:MVCNotFound', 'MVC data not found for subject: %s', subjStr);
                continue;
            end

            % Select biceps only (columns 1 and 3)
            trialBicep = mvcData(:, [1, 3]);

            % Extract MVC values for each bicep
            mvcTable(  idxSubj, 1) = table(subjStr);  % Initialize
            mvcPpTable(idxSubj, 1) = table(subjStr);

            for idxBicep = 1 : 2
                [mvc, pp] = extractMvcValues(trialBicep{:, idxBicep}, settings, ...
                                              filtNum, filtDen, mvcMethod, doPlot, subjStr, idxBicep);
                mvcTable(  idxSubj, idxBicep + 1) = table(mvc);
                mvcPpTable(idxSubj, idxBicep + 1) = table(pp);

                fprintf("  %s: %.4f mV (peak-to-peak: %.4f mV)\n", ...
                    settings.mvcChString(idxBicep), mvc, pp);
            end

        catch ME
            warning('TMS:MVCAnalysisFailed', ...
                'Failed to process MVC for subject %s: %s', subjStr, ME.message);
        end
    end

    % Save results if requested
    if doSave
        tms.mvc.export(mvcTable, mvcPpTable, settings, sessionTimestamp);
    end
end


function mvcData = loadMvcData(subjStr, settings)
%LOADMVCDATA Perform the l oa dm vc da ta operation for the TMS analysis pipeline.

% Syntax
%   mvcData = tms.mvc.loadMvcData(subjStr, settings)

% Description
%   Perform the l oa dm vc da ta operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    mvcData = [];
    matPath = fullfile(settings.dirDataPreprocessed, subjStr, 'mvc.mat');

    if isfile(matPath)
        fprintf("  Loading MAT: %s\n", matPath);
        loaded = load(matPath, 'mvcData');
        mvcData = loaded.mvcData;
    else
        warning('TMS:MVCMATNotFound', 'MVC MAT file not found.');
    end

end

function [mvc, pp] = extractMvcValues(emgSignal, settings, filtNum, filtDen, mvcMethod, doPlot, subjStr, bicepIdx)
%
%EXTRACTMVCVALUES Extract MVC and peak-to-peak values from EMG data.
% This function processes an EMG signal and extracts the MVC amplitude and
% raw peak-to-peak amplitude.
%
% Input Arguments
%    emgSignal - Raw EMG signal from one MVC channel.
%
%    settings - Settings structure containing the EMG sampling frequency.
%
%    filtNum - Numerator coefficients of the bandpass filter.
%
%    filtDen - Denominator coefficients of the bandpass filter.
%
%    mvcMethod - MVC extraction method.
%                Supported options are:
%                   - 'rectified'
%                   - 'envelope'
%
%    doPlot - Plot-generation flag.
%             Logical scalar. If true, diagnostic MVC plots are generated.
%
%    subjStr - Subject identifier.
%
%    bicepIdx - Index of the biceps channel being processed.
%
% Output Arguments
%    mvc - Extracted MVC amplitude.
%
%    pp - Raw peak-to-peak amplitude, computed as max minus min of the raw
%         EMG signal.
%
% The function removes NaN samples, detrends the EMG signal, applies the
% bandpass filter, rectifies the filtered signal, and computes the MVC
% value according to the selected method. With the 'envelope' method, MVC
% is computed as the maximum of the RMS envelope.
%
% Error
%    TMS is thrown if the input EMG signal contains only NaN
%    values.
%
% See also DETREND, FILTER, ENVELOPE, TMS_MVC_PLOT

    validIdx = ~isnan(emgSignal);
    emgSignal = emgSignal(validIdx);

    if isempty(emgSignal)
        error('TMS:EmptySignal', 'EMG signal contains only NaN values');
    end

    % Create time vector
    t = ((0 : length(emgSignal) - 1) / settings.fs_emg)';

    % Signal processing pipeline
    emgDetrended = detrend(emgSignal, 'linear');
    emgBp = filter(filtNum, filtDen, emgDetrended);
    emgRectified = abs(emgBp);

    % Calculate MVC based on selected method
    if strcmpi(mvcMethod, 'rectified')
        mvc = max(emgRectified);
        emgForPlot = emgRectified;
    else  % envelope
        % Signal processing parameters
        window_sec = 0.100;  % 100 ms moving average window
        window_samples = round(window_sec * settings.fs_emg);
        emgEnvelope = envelope(emgRectified, window_samples, 'rms');
        mvc = max(emgEnvelope);
        emgForPlot = emgEnvelope;
    end

    % Extract peak-to-peak from raw signal
    pp = max(emgSignal) - min(emgSignal);

    % Plot if requested
    if doPlot
        tms.mvc.plot(t, emgDetrended, emgBp, emgRectified, emgForPlot, mvc, mvcMethod, settings, subjStr, bicepIdx);
    end
end
