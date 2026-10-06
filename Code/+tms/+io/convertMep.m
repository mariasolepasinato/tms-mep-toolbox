function convertMep(subjIds, settings, varargin)
%CONVERTMEP Convert raw MEP CSV recordings into preprocessed MAT files.

% Syntax
%   tms.io.convertMep(subjIds, settings, varargin)

% Description
%   Convert raw MEP CSV recordings into preprocessed MAT files.

% Inputs
%   Options are supplied as name-value pairs; see the input parser for accepted names and defaults.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    p = inputParser;
    addRequired(p, 'subjIds', @(x) isstring(x) || ischar(x));
    addRequired(p, 'settings', @isstruct);
    addParameter(p, 'runIndices', [], @isvector);
    parse(p, subjIds, settings, varargin{:});

    subjIds = string(p.Results.subjIds);
    runIndices = p.Results.runIndices;

    % Default: process all runs
    if isempty(runIndices)
        runIndices = 1 : length(settings.runString);
    end

    % Process each subject
    for subjId = subjIds
        processSubject(subjId, settings, runIndices);
    end
end


function processSubject(subjId, settings, runIndices)
%PROCESSSUBJECT Perform the p ro ce ss su bj ec t operation for the TMS analysis pipeline.

% Syntax
%   tms.io.processSubject(subjId, settings, runIndices)

% Description
%   Perform the p ro ce ss su bj ec t operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    fprintf("Processing subject: %s\n", subjId);

    subjDataDir = fullfile(settings.dirDataRaw, subjId);

    % Validate subject directory exists
    if ~isfolder(subjDataDir)
        error('TMS:SubjectNotFound', 'Subject directory not found: %s', subjDataDir);
    end

    % Process each run
    for idxRun = runIndices
        if idxRun > length(settings.runString)
            warning('TMS:InvalidRunIndex', 'Run index %d exceeds number of available runs (%d)', ...
                idxRun, length(settings.runString));
            continue;
        end

        runSelectedStr = settings.runString(idxRun);
        processRun(subjId, subjDataDir, runSelectedStr, settings);
    end
end


function processRun(subjId, subjDataDir, runSelectedStr, settings)
%PROCESSRUN Perform the p ro ce ss ru n operation for the TMS analysis pipeline.

% Syntax
%   tms.io.processRun(subjId, subjDataDir, runSelectedStr, settings)

% Description
%   Perform the p ro ce ss ru n operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    fprintf("  Processing run: %s\n", runSelectedStr);

    % Find run folder
    runFolder = tms.io.findRunFolder(subjDataDir, runSelectedStr);

    if isempty(runFolder) || ~isfolder(runFolder)
        warning('TMS:RunNotFound', 'Run folder not found for: %s', runSelectedStr);
        return;
    end

    % Find and validate CSV file
    csvPath = findCSVFile(runFolder, runSelectedStr);
    if isempty(csvPath)
        return;
    end

    % Import and process data
    mepData = importAndProcessCSV(csvPath, settings);

    if isempty(mepData)
        return;
    end

    % Save to MAT file
    saveToMAT(mepData, subjId, runSelectedStr, settings);
end


function csvPath = findCSVFile(runFolder, runSelectedStr)
%FINDCSVFILE Perform the f in dc sv fi le operation for the TMS analysis pipeline.

% Syntax
%   csvPath = tms.io.findCSVFile(runFolder, runSelectedStr)

% Description
%   Perform the f in dc sv fi le operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    csvFiles = dir(fullfile(runFolder, "*.csv"));

    if isempty(csvFiles)
        warning('TMS:CSVNotFound', ...
            'No CSV file found in: %s\nHave you converted the SHPF file to CSV with Trigno Discover?', ...
            runFolder);
        csvPath = [];
        return;
    end

    if length(csvFiles) > 1
        warning('TMS:MultipleCSV', ...
            'Found %d CSV files for "%s". Using first: %s', ...
            length(csvFiles), runSelectedStr, csvFiles(1).name);
    end

    csvPath = fullfile(runFolder, csvFiles(1).name);
end


function mepData = importAndProcessCSV(csvPath, settings)
%IMPORTANDPROCESSCSV Perform the i mp or ta nd pr oc es sc sv operation for the TMS analysis pipeline.

% Syntax
%   mepData = tms.io.importAndProcessCSV(csvPath, settings)

% Description
%   Perform the i mp or ta nd pr oc es sc sv operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    try
        % Import raw data from CSV
        mepDataRaw = tms.io.importCsv(csvPath, settings.chLabelsExpected);
        mepDataRaw = renamevars(mepDataRaw, 1 : size(mepDataRaw, 2), settings.chLabelsDesired);
    catch ME
        warning('TMS:ImportFailed', 'Failed to import CSV: %s\nError: %s', csvPath, ME.message);
        mepData = [];
        return;
    end

    % Extract EMG columns
    emgCols = settings.chLabelsDesired(3 : end)';

    % Find where EMG data ends (becomes all NaN due to lower sampling rate)
    emgLength = find(all(isnan(mepDataRaw{:, 3 : end}), 2), 1) - 1;

    if isempty(emgLength) || emgLength <= 0
        warning('TMS:InvalidDataLength', 'No valid EMG data found in: %s', csvPath);
        mepData = [];
        return;
    end

    % Initialize processed data table
    mepData = table('Size', [emgLength, 6], ...
                    'VariableTypes', repmat("double", 1, 6), ...
                    'VariableNames', ["tmsTrigger", "trialClass", emgCols]);

    % Copy EMG data
    mepData(:, emgCols) = mepDataRaw(1 : emgLength, emgCols);

    % Process trial class signal (sound activation detection)
    mepData = processTrialClassSignal(mepData, mepDataRaw, settings);

    % Process TMS trigger signal
    mepData = processTMSTriggerSignal(mepData, mepDataRaw, settings);
end


function mepData = processTrialClassSignal(mepData, mepDataRaw, settings)
%PROCESSTRIALCLASSSIGNAL Perform the p ro ce ss tr ia lc la ss si gn al operation for the TMS analysis pipeline.

% Syntax
%   mepData = tms.io.processTrialClassSignal(mepData, mepDataRaw, settings)

% Description
%   Perform the p ro ce ss tr ia lc la ss si gn al operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow



    % Find rising edges (signal activation)
    logicalTcRising = mepDataRaw.trialClass_V > settings.thresholdVoltDigitalHigh;
    idxTcRising = find(diff(logicalTcRising) == 1) + 1;
    idxTcRisingResampled = ceil(idxTcRising * settings.fs_emg / settings.fs_analog);

    % Find falling edges (signal deactivation)
    logicalTcFalling = mepDataRaw.trialClass_V < settings.thresholdVoltDigitalLow;
    idxTcFalling = find(diff(logicalTcFalling) == 1) + 1;
    idxTcFallingResampled = ceil(idxTcFalling * settings.fs_emg / settings.fs_analog);

    % Ensure matching pairs of rising and falling edges
    nPairs = min(length(idxTcRisingResampled), length(idxTcFallingResampled));

    % Fill trial class array between matching rising and falling edges
    for idx = 1 : nPairs
        startIdx = idxTcRisingResampled(idx);
        endIdx = min(idxTcFallingResampled(idx), height(mepData));
        if startIdx <= height(mepData)
            mepData.trialClass(startIdx : endIdx) = 1;
        end
    end
end


function mepData = processTMSTriggerSignal(mepData, mepDataRaw, settings)
%PROCESSTMSTRIGGERSIGNAL Perform the p ro ce ss tm st ri gg er si gn al operation for the TMS analysis pipeline.

% Syntax
%   mepData = tms.io.processTMSTriggerSignal(mepData, mepDataRaw, settings)

% Description
%   Perform the p ro ce ss tm st ri gg er si gn al operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    logicalTtRising = mepDataRaw.tmsTrigger_V > settings.thresholdVoltDigitalHigh;
    idxTtRising = find(diff(logicalTtRising) == 1) + 1;
    idxTtRisingResampled = ceil(idxTtRising * settings.fs_emg / settings.fs_analog);

    % Mark trigger points (saturate to valid indices)
    validIndices = idxTtRisingResampled(idxTtRisingResampled <= height(mepData));
    mepData.tmsTrigger(validIndices) = 1;
end


function saveToMAT(mepData, subjId, runSelectedStr, settings)
%SAVETOMAT Perform the s av et om at operation for the TMS analysis pipeline.

% Syntax
%   tms.io.saveToMAT(mepData, subjId, runSelectedStr, settings)

% Description
%   Perform the s av et om at operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow



    % Create output directory if needed
    matDir = fullfile(settings.dirDataPreprocessed, subjId);
    if ~isfolder(matDir)
        mkdir(matDir);
    end

    % Save data
    matPath = fullfile(matDir, strcat(runSelectedStr, ".mat"));

    try
        save(matPath, "mepData");

        % Verify save was successful
        if isfile(matPath)
            fileInfo = dir(matPath);
            fprintf("    Saved: %s (%.1f KB)\n", matPath, fileInfo.bytes/1024);
        else
            error('TMS:SaveFailed', 'Failed to save: %s', matPath);
        end
    catch ME
        error('TMS:SaveError', 'Error saving MAT file: %s\nError: %s', matPath, ME.message);
    end
end
