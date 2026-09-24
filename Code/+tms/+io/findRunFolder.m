function folderPaths = findRunFolder(subjDataDir, prefix)
%FINDRUNFOLDER Perform the f in dr un fo ld er operation for the TMS analysis pipeline.

% Syntax
%   folderPaths = tms.io.findRunFolder(subjDataDir, prefix)

% Description
%   Perform the f in dr un fo ld er operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow



    % Convert prefix to char if string
    if isstring(prefix)
        prefix = char(prefix);
    end

    % Validate subject directory exists
    if ~isfolder(subjDataDir)
        error('TMS:DirectoryNotFound', 'Directory does not exist: %s', subjDataDir);
    end

    % Find date folder (YYYY-MM-DD format)
    dateFolder = findDateFolder(subjDataDir);

    % Find folders matching prefix
    folderPaths = findMatchingFolders(dateFolder, prefix);
end


function dateFolder = findDateFolder(subjDataDir)
%FINDDATEFOLDER Perform the f in dd at ef ol de r operation for the TMS analysis pipeline.

% Syntax
%   dateFolder = tms.io.findDateFolder(subjDataDir)

% Description
%   Perform the f in dd at ef ol de r operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow



    % List all subdirectories
    dateDirs = dir(subjDataDir);
    dateDirs = dateDirs([dateDirs.isdir]);
    dateDirs = dateDirs(~ismember({dateDirs.name}, {'.', '..'}));

    % Filter for date format (YYYY-MM-DD)
    isDateFolder = cellfun(@(x) ~isempty(regexp(x, '^\d{4}-\d{2}-\d{2}$', 'once')), ...
                           {dateDirs.name});
    dateDirs = dateDirs(isDateFolder);

    if isempty(dateDirs)
        error('TMS:NoDateFolder', ...
            'No date folder (format "YYYY-MM-DD") found in: %s', subjDataDir);
    elseif isscalar(dateDirs)
        dateFolder = fullfile(subjDataDir, dateDirs(1).name);
    else
        % Multiple date folders - prompt user to select
        warning('TMS:MultipleDateFolders', ...
            'Found %d date folders in %s. Prompting user to select.', ...
            length(dateDirs), subjDataDir);

        dateFolder = selectDateFolder(subjDataDir, dateDirs);
    end
end


function dateFolder = selectDateFolder(subjDataDir, dateDirs)
%SELECTDATEFOLDER Perform the s el ec td at ef ol de r operation for the TMS analysis pipeline.

% Syntax
%   dateFolder = tms.io.selectDateFolder(subjDataDir, dateDirs)

% Description
%   Perform the s el ec td at ef ol de r operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    folderNames = {dateDirs.name};
    [indx, tf] = listdlg('PromptString', 'Select date folder to use:', ...
                         'SelectionMode', 'single', ...
                         'ListString', folderNames);

    if tf == 0
        error('TMS:NoFolderSelected', 'No date folder selected. Aborting.');
    end

    dateFolder = fullfile(subjDataDir, folderNames{indx});
end

function folderPaths = findMatchingFolders(dateFolder, prefix)
%FINDMATCHINGFOLDERS Perform the f in dm at ch in gf ol de rs operation for the TMS analysis pipeline.

% Syntax
%   folderPaths = tms.io.findMatchingFolders(dateFolder, prefix)

% Description
%   Perform the f in dm at ch in gf ol de rs operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    matchingFolders = dir(fullfile(dateFolder, [prefix, '*']));
    matchingFolders = matchingFolders([matchingFolders.isdir]);

    if isempty(matchingFolders)
        warning('TMS:NoMatchingFolder', ...
            'No folder starting with "%s" found in: %s', prefix, dateFolder);
        folderPaths = "";
        return;
    end

    if length(matchingFolders) > 1
        warning('TMS:MultipleFolders', ...
            'Found %d folders starting with "%s" in %s. Returning the first one: %s .', ...
            length(matchingFolders), prefix, dateFolder, matchingFolders(1).name);
    end

    % Build full paths
    folderPaths = fullfile(dateFolder, matchingFolders(1).name);
end
