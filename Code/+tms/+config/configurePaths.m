function settings = configurePaths(settings, varargin)
%CONFIGUREPATHS Perform the c on fi gu re pa th s operation for the TMS analysis pipeline.

% Syntax
%   settings = tms.config.configurePaths(settings, varargin)

% Description
%   Perform the c on fi gu re pa th s operation for the TMS analysis pipeline.

% Inputs
%   Options are supplied as name-value pairs; see the input parser for accepted names and defaults.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    p = inputParser;
    addParameter(p, 'projectRoot', "", @(x) isstring(x) || ischar(x));
    parse(p, varargin{:});

    requestedRoot = string(p.Results.projectRoot);
    if strlength(requestedRoot) > 0
        if ~isfolder(requestedRoot) || ...
           ~isfolder(fullfile(requestedRoot, "Code")) || ...
           ~isfolder(fullfile(requestedRoot, "Data"))
            error('TMS:InvalidProjectRoot', ...
                'projectRoot must contain both Code and Data folders: %s', requestedRoot);
        end
        baseDir = requestedRoot;
    else
        try
            baseDir = tms.config.findProjectRoot(fileparts(mfilename('fullpath')));
        catch ME
            if ~strcmp(ME.identifier, 'TMS:ProjectRootNotFound')
                rethrow(ME);
            end

            fprintf('\nProject root was not detected. Please select it manually.\n');
            userSelectedDir = uigetdir(pwd, 'Select the project folder containing Code and Data');
            if isequal(userSelectedDir, 0)
                error('TMS:FolderNotSelected', ...
                    'Analysis cancelled: a project folder is required to proceed.');
            end

            baseDir = string(userSelectedDir);
            if ~isfolder(fullfile(baseDir, "Code")) || ...
               ~isfolder(fullfile(baseDir, "Data"))
                error('TMS:InvalidProjectRoot', ...
                    'The selected folder must contain both Code and Data folders: %s', baseDir);
            end
            fprintf('User selected project root: %s\n', baseDir);
        end
    end

    settings.dirGeneral = baseDir;

    % Define all subdirectories based on the project root
    settings.dirCode               = fullfile(settings.dirGeneral, "Code");
    settings.dirData               = fullfile(settings.dirGeneral, "Data");
    settings.dirResults            = fullfile(settings.dirGeneral, "Results");
    settings.dirDataRaw            = fullfile(settings.dirData, "0_raw", "Trigno Discover", "TMS_RST");
    settings.dirDataPreprocessed   = fullfile(settings.dirData, "1_preprocessed");
    settings.dirDataProcessed      = fullfile(settings.dirData, "2_processed");
    settings.dirMetaData           = fullfile(settings.dirData, "3_metadata");

    % Create output directories; raw data and metadata remain required inputs.
    outputDirs = [settings.dirResults, settings.dirDataPreprocessed, settings.dirDataProcessed];
    for outputDir = outputDirs
        if ~isfolder(outputDir)
            mkdir(outputDir);
        end
    end
end
