function [filtNum, filtDen] = designButterworthFilter(bandpassFreq, fs_emg, filterOrder)
%DESIGNBUTTERWORTHFILTER Perform the d es ig nb ut te rw or th fi lt er operation for the TMS analysis pipeline.

% Syntax
%   [filtNum, filtDen] = tms.mvc.designButterworthFilter(bandpassFreq, fs_emg, filterOrder)

% Description
%   Perform the d es ig nb ut te rw or th fi lt er operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    lowCutoff = bandpassFreq(1) / (fs_emg / 2);
    highCutoff = bandpassFreq(2) / (fs_emg / 2);

    if lowCutoff <= 0 || highCutoff >= 1
        error('TMS:InvalidFilterFreq', ...
            'Filter frequencies out of range. Check bandpass frequencies and sampling rate.');
    end

    [filtNum, filtDen] = butter(filterOrder, [lowCutoff, highCutoff]);
end
