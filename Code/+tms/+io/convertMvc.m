function convertMvc(subjStr, settings)
%CONVERTMVC Convert a raw MVC CSV recording into a preprocessed MAT file.

% Syntax
%   tms.io.convertMvc(subjStr, settings)

% Description
%   Convert a raw MVC CSV recording into a preprocessed MAT file.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    subjDataDir = fullfile(settings.dirDataRaw, subjStr);
    matDir = fullfile(settings.dirDataPreprocessed, subjStr);

    if ~isfolder(matDir)
        mkdir(matDir);
    end

    % =====================================================================
    % 1. FIND THE DATE FOLDER FIRST
    % =====================================================================
    dateFolders = dir(subjDataDir);
    dateFolders = dateFolders([dateFolders.isdir]);
    isDateFolder = matches({dateFolders.name}, digitsPattern(4) + "-" + digitsPattern(2) + "-" + digitsPattern(2));
    dateFolders = dateFolders(isDateFolder);

    if isempty(dateFolders)
        warning('TMS:DateFolderNotFound', 'No date folder found for: %s', subjStr);
        return;
    end

    dateFolder = fullfile(subjDataDir, dateFolders(1).name);

    % =====================================================================
    % 2. FIND MVC FOLDERS INSIDE THE DATE FOLDER
    % =====================================================================
    mvcPattern = 'mvc';
    allDirs = dir(dateFolder);
    allDirs = allDirs([allDirs.isdir] & ~startsWith({allDirs.name}, '.'));

    mvcFolders = allDirs(startsWith({allDirs.name}, mvcPattern));

    if isempty(mvcFolders)
        warning('TMS:MVCNotFound', 'No MVC folder found inside %s', dateFolder);
        return;
    end

    % =====================================================================
    % 3. PROCESS AND CONCATENATE
    % =====================================================================
    mvcData = table();  % Empty table to concatenate

    for i = 1 : length(mvcFolders)
        mvcFolder = fullfile(dateFolder, mvcFolders(i).name);

        % Find CSV file(s) in this MVC folder
        csvFiles = dir(fullfile(mvcFolder, '*.csv'));

        if isempty(csvFiles)
            warning('TMS:MVCCSVNotFound', 'No CSV found in: %s', mvcFolder);
            continue;
        end

        csvPath = fullfile(csvFiles(1).folder, csvFiles(1).name);

        % Import data using settings.chString
        try
            mvcDataTemp = tms.io.importCsv(csvPath, settings.chString);

            % Concatenate to all data
            if isempty(mvcData)
                mvcData = mvcDataTemp;
            else
                mvcData = vertcat(mvcData, mvcDataTemp);
            end

            fprintf("    Loaded MVC data from: %s\n", mvcFolders(i).name);

        catch ME
            warning('TMS:MVCImportFailed', 'Failed to import %s: %s', csvPath, ME.message);
            continue;
        end
    end

    % Save concatenated data to single MAT file
    if ~isempty(mvcData)
        matPath = fullfile(matDir, "mvc.mat");
        save(matPath, "mvcData", "-v7.3");  % Use -v7.3 for large files
        fprintf("    Saved concatenated MVC MAT (rows = %d): %s\n", ...
            height(mvcData), matPath);
    else
        warning('TMS:NoMVCDataLoaded', 'No MVC data loaded for: %s', subjStr);
    end
end
