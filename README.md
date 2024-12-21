# ManaBox Diff

This script allows you to take 2 CSV exports from the ManaBox app and outputs a file that contains only the new cards in the newer export. 
This is useful for importing into other collection/deck building websites like Moxfield, where you will get duplicates if you upload a CSV that has the same cards in it as a previous file

## Usage

The script accepts the following options: 
`-r` - rename the input and output files with the timestamp of when they were created. Helpful if you just use the default export name
`-n NEWFILENAME` file path to the most recent export file
`-o OLDFILENAME` file path to the previous export file to compare with

i.e.
`ruby manabox_diff.rb -r -n ~/MyFolder/ManaBox_Collection.csv -o ~/MyFolder/ManaBox_Collection_old.csv`

Alternatively, if you pass a single file name with no flag in front of it, the script assumes this is the newest export file and uses the modified dates on other files in the folder to find the next most recent export

i.e.
`ruby manabox_diff.rb -r ~/MyFolder/ManaBox_Collection.csv`

The result will be a file named `diff_ManaBox_Collection_<datetime_stamp>_ManaBox_Collection<datetime_stamp>.csv` that contains only new cards or cards with changed quantities.

Cards that are removed from one export to the next are not added to the CSV file, but are instead printed as the command output, since many collection websites don't allow removing a card during an import.
