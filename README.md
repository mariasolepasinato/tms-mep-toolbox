# TMS cMEP/iMEP Analysis Toolbox

A MATLAB workflow for converting Delsys Trigno Discover recordings, calculating maximum voluntary contraction (MVC), and identifying contralateral motor-evoked potentials (cMEPs) and ipsilateral motor-evoked potentials (iMEPs). An optional cohort-level step compares an MEP-derived spasticity-risk classification with follow-up Modified Ashworth Scale (MAS) outcomes.

This is research software. It is not a medical device and must not be used as the sole basis for clinical decisions. Validate the acquisition settings, thresholds, and outputs for your protocol before drawing scientific or clinical conclusions.

## Features

- Converts Trigno Discover CSV exports to MATLAB tables stored in MAT files.
- Calculates MVC from rectified EMG or an RMS envelope.
- Detects cMEPs and iMEPs using amplitude, pre-stimulus noise, latency, and template-correlation criteria.
- Processes resting and active trials from both stimulation hemispheres.
- Exports participant-level and cohort-level Excel summaries and diagnostic plots.
- Optionally evaluates a spasticity-risk rule against longitudinal MAS data.

## Requirements

- MATLAB. The current release was tested with R2025b.
- Signal Processing Toolbox (`butter`, `envelope`, and `xcorr` are used).
- Delsys Trigno Discover CSV exports following the format below.

## Installation

Download the repository from GitHub or clone it with Git:

```text
git clone https://github.com/mariasolepasinato/tms-mep-toolbox.git
```

In MATLAB, set the current folder to the repository root and add the code folder:

```matlab
addpath("Code")
```

## Quick Start

Interactive subject and workflow selection:

```matlab
addpath("Code")
workflowLog = tms_main_workflow;
```

Automated processing of selected subjects:

```matlab
addpath("Code")

workflowLog = tms_main_workflow( ...
    "subjIds", ["sub-001", "sub-002"], ...
    "steps", [1 2 3], ...
    "plot", false, ...
    "save", true, ...
    "mode", "auto", ...
    "projectRoot", pwd);
```

Workflow steps are:

1. Convert raw CSV recordings to MAT files.
2. Calculate MVC values.
3. Identify and summarize cMEPs and iMEPs.
4. Calculate the spasticity-risk classification and compare it with clinical follow-up.

Step 4 automatically runs step 3, and conversion is added when required MAT files are missing.

## Project Structure

```text
tms-mep-toolbox/
|-- Code/
|   |-- tms_main_workflow.m
|   `-- +tms/
|-- Data/
|   `-- README.md
|-- examples/
|   |-- run_example.m
|   `-- subject_metadata.json
|-- tests/
|-- CITATION.cff
|-- LICENSE
`-- README.md
```

The pipeline creates `Data/1_preprocessed`, `Data/2_processed`, and `Results` as needed. You must create the raw-data and metadata directories described in [Data/README.md](Data/README.md). The `Data`, `Results`, and `Figures` contents are excluded from Git to protect participant data.

## Acquisition Data

For each subject, use this directory pattern:

```text
Data/0_raw/Trigno Discover/TMS_RST/<subject-id>/YYYY-MM-DD/
|-- mvc_1/
|-- h_sinistro_rest_1/
|-- h_sinistro_active_1/
|-- h_destro_rest_1/
`-- h_destro_active_1/
```

Each run directory must contain a `.shpf` acquisition and a same-name CSV export. The four required MEP run prefixes are `h_sinistro_rest`, `h_sinistro_active`, `h_destro_rest`, and `h_destro_active`.

The importer expects Trigno Discover CSV files with channel headers on row 4 and numeric samples beginning on row 8. Delimiters and decimal separators are detected automatically. Required header prefixes are:

| Signal | Accepted prefix |
| --- | --- |
| TMS trigger | `Wired Analog Input` |
| Trial class | `Var2` |
| Left biceps | `BBsx` |
| Left FDI | `FDIsx` |
| Right biceps | `BBdx` |
| Right FDI | `FDIdx` |

The default acquisition configuration assumes a 24 kHz analog rate and an EMG rate of approximately 2148.15 Hz. Review [configureDataAcquisition.m](Code/+tms/+config/configureDataAcquisition.m), [configureChannels.m](Code/+tms/+config/configureChannels.m), and [configureMEPCharacteristics.m](Code/+tms/+config/configureMEPCharacteristics.m) before using a different setup.

## Subject Metadata

Each subject requires `Data/3_metadata/<subject-id>.json`. Start from [subject_metadata.json](examples/subject_metadata.json). The raw-data folder name, metadata filename, and `subj_id` should match.

- `h_affected` must be `left` or `right`.
- `active_trials.left` and `active_trials.right` contain one-based trial indices for active runs.
- Use an empty array when a side has no active trials; the corresponding active run will be skipped.
- Indices must be positive, unique integers no greater than the number of detected TMS triggers.

## Clinical Analysis

Step 4 requires an Excel workbook with sheets named `T0`, `T1`, and `T2`:

| Sheet | Required columns | Use |
| --- | --- | --- |
| `T0` | `ID`, `NIHSS` | Baseline NIHSS for traceability |
| `T1` | `ID`, `MAS_UL` | Fallback MAS when T2 is missing |
| `T2` | `ID`, `MAS_UL` | Preferred clinical outcome |

Run it by passing the workbook explicitly:

```matlab
workflowLog = tms_main_workflow( ...
    "subjIds", ["sub-001", "sub-002"], ...
    "steps", 4, ...
    "plot", false, ...
    "save", true, ...
    "mode", "auto", ...
    "projectRoot", pwd, ...
    "clinicalDatabaseFile", "C:\path\to\clinical_database.xlsx");
```

The MEP-based high-risk profile requires both of the following in at least one condition:

- Affected-side FDI cMEP occurrence is below 50% of unaffected-side FDI cMEP occurrence.
- Affected-side biceps or FDI iMEP occurrence is greater than the corresponding unaffected-side occurrence.

The clinical outcome is considered positive when upper-limb MAS is at least 1, using T2 when available and T1 otherwise.

## Outputs

Each run creates `Results/YYYY-MM-DD_HH-mm-ss/`, which can contain:

- `mvc_results_all_subjects.xlsx`
- `mep_results_all_subjects.xlsx`, with `cMEP` and `iMEP` sheets
- `<subject-id>/<subject-id>_mep_results.xlsx`
- diagnostic MEP plots when plotting is enabled
- `spasticity_risk_results.xlsx` and `spasticity_risk_plots/` for step 4
- a workflow log containing completion, timing, and error information

## Testing

From the repository root in MATLAB:

```matlab
results = runtests("tests");
assertSuccess(results)
```

The included test is a configuration smoke test and does not validate scientific performance. Add protocol-specific tests and representative de-identified data before relying on the workflow for a study.

## Privacy

Never commit raw recordings, MAT files, result spreadsheets, clinical workbooks, metadata containing direct identifiers, or any other protected participant information. The `.gitignore` provides a first line of protection, but always inspect `git status` before every commit.

## Citation

Use the repository's `CITATION.cff` file. GitHub will display a **Cite this repository** panel after publication.

### Related conference work

The algorithmic component that identifies cMEPs and iMEPs was presented as an oral presentation at the 2026 IEEE Engineering in Medicine and Biology Conference (EMBC). A corresponding paper is expected to be published in the conference proceedings by the end of 2026 and is currently cited as:

> Pasinato M, Bertuccelli M, Vomiero A, et al. Automatic detection of ipsilateral Motor Evoked Potentials elicited by Transcranial Magnetic Stimulation in post-stroke patients. In: *Proceedings of the 48th Annual International Conference of the IEEE Engineering in Medicine and Biology Society (EMBC).* IEEE; 2026. In press.

This reference applies specifically to the cMEP/iMEP identification component, rather than to every part of the toolbox. The citation should be updated when the final proceedings record and DOI become available.

## License

Copyright (c) 2026 Mariasole Pasinato. Released under the [GNU General Public License v3.0 only](LICENSE). Redistributed versions and modifications must remain available under the GPL. The license covers the software, not any third-party data or proprietary acquisition formats.
