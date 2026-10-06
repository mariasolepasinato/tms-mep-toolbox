function checkCSVFilesExist(subjStrList, settings)
%CHECKCSVFILESEXIST Perform the c he ck cs vf il es ex is t operation for the TMS analysis pipeline.

% Syntax
%   tms.workflow.checkCSVFilesExist(subjStrList, settings)

% Description
%   Perform the c he ck cs vf il es ex is t operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   This function has no output arguments.

% See also
%   tms_main_workflow

    fprintf('\nChecking CSV file availability...\n');

    missingCSV = [];

    for subjStr = subjStrList(:)'
        subjDataDir = fullfile(settings.dirDataRaw, subjStr);

        if ~isfolder(subjDataDir)
            continue;
        end

        % Find date folder
        dateFolders = dir(subjDataDir);
        dateFolders = dateFolders([dateFolders.isdir]);
        isDateFolder = matches({dateFolders.name}, digitsPattern(4) + "-" + digitsPattern(2) + "-" + digitsPattern(2));
        dateFolders = dateFolders(isDateFolder);

        if isempty(dateFolders)
            continue;
        end

        dateFolder = fullfile(subjDataDir, dateFolders(1).name);

        % Check all run folders (mvc*, h_*)
        allRuns = dir(fullfile(dateFolder, '*'));
        allRuns = allRuns([allRuns.isdir] & ~startsWith({allRuns.name}, '.'));

        for run = allRuns'
            runFolder = fullfile(dateFolder, run.name);

            % Find SHPF files
            shpfFiles = dir(fullfile(runFolder, '*.shpf'));

            for shpf = shpfFiles'

                % Check if corresponding CSV exists
                [~, basename] = fileparts(shpf.name);
                csvPath = fullfile(runFolder, [basename '.csv']);

                if ~isfile(csvPath)
                    missingCSV = [missingCSV; string(csvPath)];
                end
            end
        end
    end

    % Report findings
    if ~isempty(missingCSV)
        fprintf(2, '\n⚠ ERROR: Missing CSV files for %d SHPF file(s):\n', length(missingCSV));
        for path = missingCSV(:)'
            fprintf(2, '  - %s\n', path);
        end
        fprintf(2, '\nAction required:\n');
        fprintf(2, '1. Open Trigno Discover (v1.7.0 recommended)\n');
        fprintf(2, '2. Convert each SHPF file to CSV\n');
        fprintf(2, '3. Save CSV in the same folder as SHPF\n\n');
        error('TMS:MissingCSV', 'CSV conversion required before processing.');
    else
        fprintf('✓ All SHPF files have corresponding CSV files\n');
    end
end
