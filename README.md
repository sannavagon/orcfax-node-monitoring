# orcfax-node-monitoring
Monitoring scripts for Orcfax node operators
Error Reporting and Data Interpretation:

In the 'Types of errors found' section, errors related to feed submissions to the validator that receive 'OK' responses, as well as those resulting in timeout messages, are intentionally omitted. These are not considered critical errors in the context of this monitoring script. All other encountered errors, along with their respective occurrence counts, are displayed.

It's important to note that occasional minor discrepancies in the data may be observed. This is due to the data being captured at specific minute intervals rather than over a continuous 60-second window. Consequently, some events occurring near the minute boundary might fall outside the captured range. This limitation is addressed in the subsequent section of the report.

A known minor issue exists where data retrieval for the time range 00:00 to 00:59 results in no output. This issue does not affect the full-day data retrieval and has been deemed a low priority for immediate correction.

Script Functionality:

This script provides on-demand monitoring data for:

The previous hour
A specific hour on a given day
A specific full day
To ensure accurate data interpretation, please maintain a consistent time format.

We hope this script proves to be a valuable tool for your monitoring needs.
Complete README documentation
