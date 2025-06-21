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


We hope this script proves to be a valuable tool for your monitoring needs.


