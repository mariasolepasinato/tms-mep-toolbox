function dataTable = importCsv(csvPath, desiredOrder, unitMeasurement)
%IMPORTCSV Perform the i mp or tc sv operation for the TMS analysis pipeline.

% Syntax
%   dataTable = tms.io.importCsv(csvPath, desiredOrder, unitMeasurement)

% Description
%   Perform the i mp or tc sv operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow



    % Constants
    DATA_START_ROW = 8;
    HEADER_ROW = 4;

    % Handle optional arguments
    if nargin < 3
        unitMeasurement = [];
    end

    % Detect file format (decimal separator and delimiter)
    decimalSeparator = detectDecimalSeparator(csvPath, DATA_START_ROW);

    % Configure import options
    opts = configureImportOptions(csvPath, decimalSeparator, DATA_START_ROW, HEADER_ROW);
    % disp(opts.VariableNames)

    % Match and select desired columns
    matchedColumns = matchDesiredColumns(opts.VariableNames, desiredOrder);
    opts.SelectedVariableNames = matchedColumns;
    opts = setvartype(opts, matchedColumns, 'double');

    % Import data
    dataTable = readtable(csvPath, opts);

    % Reorder and rename columns
    dataTable = dataTable(:, matchedColumns);
    newColumnNames = generateColumnNames(desiredOrder, unitMeasurement);
    dataTable.Properties.VariableNames = cellstr(newColumnNames);

    % Remove trailing rows with all NaN values
    dataTable = removeTrailingNaNRows(dataTable);
end


function decimalSeparator = detectDecimalSeparator(csvPath, startRow)
%DETECTDECIMALSEPARATOR Perform the d et ec td ec im al se pa ra to r operation for the TMS analysis pipeline.

% Syntax
%   decimalSeparator = tms.io.detectDecimalSeparator(csvPath, startRow)

% Description
%   Perform the d et ec td ec im al se pa ra to r operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    NUM_SAMPLE_ROWS = 5;

    % Open file and skip header rows
    fid = fopen(csvPath, 'r');
    if fid == -1
        error('TMS:ImportCSV:FileNotFound', 'Cannot open file: %s', csvPath);
    end

    % Skip initial rows
    for i = 1 : (startRow - 1)
        fgetl(fid);
    end

    % Read sample data rows
    dataLines = cell(NUM_SAMPLE_ROWS, 1);
    for i = 1 : NUM_SAMPLE_ROWS
        dataLines{i} = fgetl(fid);
        if ~ischar(dataLines{i})
            break;
        end
    end
    fclose(fid);

    % Analyze decimal patterns
    text = strjoin(dataLines, ' ');
    commaDecimalCount = length(regexp(text, '\d+,\d+'));
    dotDecimalCount = length(regexp(text, '\d+\.\d+'));

    % Determine decimal separator
    if commaDecimalCount > dotDecimalCount
        decimalSeparator = ',';
    else
        decimalSeparator = '.';
    end
end


function opts = configureImportOptions(csvPath, decimalSeparator, dataStartRow, headerRow)
%CONFIGUREIMPORTOPTIONS Perform the c on fi gu re im po rt op ti on s operation for the TMS analysis pipeline.

% Syntax
%   opts = tms.io.configureImportOptions(csvPath, decimalSeparator, dataStartRow, headerRow)

% Description
%   Perform the c on fi gu re im po rt op ti on s operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    opts = detectImportOptions(csvPath, 'DecimalSeparator', decimalSeparator, ...
                               'VariableNamingRule', 'preserve');
    opts.DataLine = dataStartRow;
    opts.VariableNamesLine = headerRow;
end


function matchedColumns = matchDesiredColumns(availableColumns, desiredOrder)
%MATCHDESIREDCOLUMNS Perform the m at ch de si re dc ol um ns operation for the TMS analysis pipeline.

% Syntax
%   matchedColumns = tms.io.matchDesiredColumns(availableColumns, desiredOrder)

% Description
%   Perform the m at ch de si re dc ol um ns operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    matchedColumns = strings(size(desiredOrder));

    for i = 1 : length(desiredOrder)
        matchIdx = find(startsWith(availableColumns, desiredOrder(i), 'IgnoreCase', true), 1);

        if isempty(matchIdx)
            error('TMS:ImportCSV:ColumnNotFound', ...
                'Required column not found: %s', desiredOrder(i));
        end

        matchedColumns(i) = availableColumns{matchIdx};
    end
end


function columnNames = generateColumnNames(desiredOrder, unitMeasurement)
%GENERATECOLUMNNAMES Perform the g en er at ec ol um nn am es operation for the TMS analysis pipeline.

% Syntax
%   columnNames = tms.io.generateColumnNames(desiredOrder, unitMeasurement)

% Description
%   Perform the g en er at ec ol um nn am es operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow

    columnNames = strings(length(desiredOrder), 1);

    if isempty(unitMeasurement) || all(unitMeasurement == "")
        columnNames = desiredOrder;
        return;
    end

    for i = 1 : length(desiredOrder)
        if unitMeasurement(i) ~= ""
            columnNames(i) = strcat(desiredOrder(i), "_", unitMeasurement(i));
        else
            columnNames(i) = desiredOrder(i);
        end
    end
end


function dataTable = removeTrailingNaNRows(dataTable)
%REMOVETRAILINGNANROWS Perform the r em ov et ra il in gn an ro ws operation for the TMS analysis pipeline.

% Syntax
%   dataTable = tms.io.removeTrailingNaNRows(dataTable)

% Description
%   Perform the r em ov et ra il in gn an ro ws operation for the TMS analysis pipeline.

% Inputs
%   All inputs are required unless documented otherwise.

% Outputs
%   Returns the values shown in the syntax signature.

% See also
%   tms_main_workflow



    % Find first row where all columns are NaN
    firstAllNaNRow = find(all(ismissing(dataTable), 2), 1, 'first');

    % Truncate table if trailing NaN rows exist
    if ~isempty(firstAllNaNRow)
        dataTable = dataTable(1:(firstAllNaNRow - 1), :);
    end
end
