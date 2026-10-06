function projectRoot = findProjectRoot(startDir)
%FINDPROJECTROOT Perform the f in dp ro je ct ro ot operation for the TMS analysis pipeline.

% Syntax
%   projectRoot = tms.config.findProjectRoot(startDir)

% Description
%   Perform the f in dp ro je ct ro ot operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    currentDir = string(startDir);

    if ~isfolder(currentDir)
        error('TMS:ProjectRootNotFound', ...
            'The starting directory does not exist: %s', currentDir);
    end

    while true
        if isfolder(fullfile(currentDir, "Code")) && ...
           isfolder(fullfile(currentDir, "Data"))
            projectRoot = currentDir;
            return;
        end

        parentDir = string(fileparts(currentDir));
        if parentDir == currentDir
            error('TMS:ProjectRootNotFound', ...
                'Could not find a project root containing Code and Data.');
        end

        currentDir = parentDir;
    end
end
