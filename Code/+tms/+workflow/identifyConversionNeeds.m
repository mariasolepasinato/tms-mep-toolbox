function [subjStrList_ready, subjStrList_mvcConv, subjStrList_mepConv] = identifyConversionNeeds(subjStrList, settings)
%IDENTIFYCONVERSIONNEEDS Perform the i de nt if yc on ve rs io nn ee ds operation for the TMS analysis pipeline.

% Syntax
%   [subjStrList_ready, subjStrList_mvcConv, subjStrList_mepConv] = tms.workflow.identifyConversionNeeds(subjStrList, settings)

% Description
%   Perform the i de nt if yc on ve rs io nn ee ds operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    subjStrList = string(subjStrList);
    subjStrList_ready = strings(0, 1);
    subjStrList_mvcConv = strings(0, 1);
    subjStrList_mepConv = strings(0, 1);

    for subjStr = subjStrList(:)'
        needsConv = checkConversionNeeded(subjStr, settings);

        if needsConv.mvc
            subjStrList_mvcConv = [subjStrList_mvcConv; subjStr];
        end
        if needsConv.mep
            subjStrList_mepConv = [subjStrList_mepConv; subjStr];
        end
        if ~needsConv.mvc && ~needsConv.mep
            subjStrList_ready = [subjStrList_ready; subjStr];
        end
    end
end

function needsConv = checkConversionNeeded(subjStr, settings)
    needsConv = struct('mvc', false, 'mep', false);
    subjDataDir = fullfile(settings.dirDataRaw, subjStr);
    subjMatDir = fullfile(settings.dirDataPreprocessed, subjStr);
    if ~isfolder(subjDataDir), return; end

    dateFolders = dir(subjDataDir);
    dateFolders = dateFolders([dateFolders.isdir]);
    isDateFolder = matches({dateFolders.name}, ...
        digitsPattern(4) + "-" + digitsPattern(2) + "-" + digitsPattern(2));
    dateFolders = dateFolders(isDateFolder);
    if isempty(dateFolders), return; end

    dateFolder = fullfile(subjDataDir, dateFolders(1).name);
    mvcFolders = dir(fullfile(dateFolder, 'mvc*'));
    if any([mvcFolders.isdir])
        needsConv.mvc = isempty(dir(fullfile(subjMatDir, 'mvc*.mat')));
    end

    mepFolders = dir(fullfile(dateFolder, 'h_*'));
    mepFolders = mepFolders([mepFolders.isdir]);
    if ~isempty(mepFolders)
        needsConv.mep = numel(dir(fullfile(subjMatDir, 'h_*.mat'))) < numel(mepFolders);
    end
end
