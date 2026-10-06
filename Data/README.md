# Local Data Directory

Participant and clinical data belong here on your local computer only. They are intentionally excluded from Git.

Create the following structure before running the workflow:

```text
Data/
|-- 0_raw/
|   `-- Trigno Discover/
|       `-- TMS_RST/
|           `-- <subject-id>/
|               `-- YYYY-MM-DD/
|                   |-- mvc_1/
|                   |-- h_sinistro_rest_1/
|                   |-- h_sinistro_active_1/
|                   |-- h_destro_rest_1/
|                   `-- h_destro_active_1/
`-- 3_metadata/
    `-- <subject-id>.json
```

The pipeline creates `1_preprocessed` and `2_processed` automatically. Copy `examples/subject_metadata.json` to `Data/3_metadata/<subject-id>.json` and edit it for each subject.

Before committing, run `git status` and confirm that no participant files are listed.
