# orcfax-node-monitoring
Installation Instructions

Create the Script File:
Open a text editor (e.g., nano) by running the following command:

nano monitoring_orcfax.sh                                                                                                

Copy the contents of the attached monitoring_orcfax.sh file and paste them into the nano editor.
Save the file by pressing Ctrl + O, then press Enter.
Exit nano by pressing Ctrl + X.

Grant Execute Permissions:
Make the script executable by running the following command:

chmod +x monitoring_orcfax.sh

Usage Instructions
To retrieve monitoring information using the script, use the following commands:

Last Hour Data:

./monitoring_orcfax.sh
This command provides monitoring data for the previous hour.
Specific Hour Data:

./monitoring_orcfax.sh YYYY-MM-DD HH
Replace YYYY-MM-DD with the desired date and HH with the desired hour (24-hour format).
Example: ./monitoring_orcfax.sh 2025-02-25 11 will provide data for 11:00 on February 25, 2025.

Full Day Data:

./monitoring_orcfax.sh YYYY-MM-DD
Replace YYYY-MM-DD with the desired date.
Example: ./monitoring_orcfax.sh 2025-02-24 will provide data for the entire day of February 24, 2025.

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


