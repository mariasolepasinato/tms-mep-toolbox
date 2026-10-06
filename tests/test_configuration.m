function tests = test_configuration
%TEST_CONFIGURATION Smoke tests for the public toolbox configuration.
    tests = functiontests(localfunctions);
end

function testCreateSettings(testCase)
    repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
    codeDirectory = fullfile(repositoryRoot, "Code");
    addpath(codeDirectory);
    cleanup = onCleanup(@() rmpath(codeDirectory)); %#ok<NASGU>

    settings = tms.config.createSettings("projectRoot", repositoryRoot);

    verifyEqual(testCase, settings.dirGeneral, string(repositoryRoot));
    verifyEqual(testCase, settings.fs_analog, 24000);
    verifyEqual(testCase, numel(settings.runString), 4);
    verifyEqual(testCase, settings.chLabelsDesired(3), "BBsx_mV");
    verifyTrue(testCase, isfolder(settings.dirDataPreprocessed));
    verifyTrue(testCase, isfolder(settings.dirResults));
end
