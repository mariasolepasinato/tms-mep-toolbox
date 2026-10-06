function settings = createSettings(varargin)
%CREATESETTINGS Create, populate, and validate the project settings structure.

% Syntax
%   settings = tms.config.createSettings(varargin)

% Description
%   Create, populate, and validate the project settings structure.

% Inputs
%   varargin - Optional configuration supplied as name-value pairs.

% Name-Value Arguments
%   projectRoot - Root folder containing Code and Data. If omitted, it is
%                 detected from this function location.

% Outputs
%   settings - Validated structure with paths, acquisition settings, channel
%              labels, MEP thresholds, and export preferences.

% See also
%   tms_main_workflow

    p = inputParser;
    addParameter(p, 'projectRoot', "", @(x) isstring(x) || ischar(x));
    parse(p, varargin{:});

    % Initialize settings struct
    settings = struct();

    % Configure directories from the project structure or an explicit root
    settings = tms.config.configurePaths(settings, 'projectRoot', p.Results.projectRoot);

    % Configure data acquisition parameters
    settings = tms.config.configureDataAcquisition(settings);

    % Configure data labels and channel information
    settings = tms.config.configureChannels(settings);

    % Configure MEP analysis parameters
    settings = tms.config.configureMEPCharacteristics(settings);

    % Validate settings
    tms.config.validateSettings(settings);
end
