import groovy.csv.CsvParser

class WorkflowMolCart {
    //
    // Function to exclude columns from a CSV file
    //
    public static void excludeMcquantColumns(String file1, String file2) {
        // Read the column names to exclude from FILE2
        def columnNamesToExclude = new File(file2).readLines()

        // Parse the CSV content of FILE1
        def csvContent = new File(file1).getText()
        def parser = new CsvParser()
        def records = parser.parse(csvContent)

        // Find the indexes of the columns to exclude
        def header = records[0]
        def indexesToExclude = columnNamesToExclude.collect { header.indexOf(it) }.findAll { it >= 0 }

        // Filter the records, excluding the specified columns
        def filteredRecords = records.collect { record ->
            record.withIndex().findAll { !(it.index in indexesToExclude) }.collect { it.value }
        }

        // Convert the filtered records back to CSV
        def filteredCsv = filteredRecords.collect { it.join(',') }.join('\n')

        // Return the filtered CSV content
        return filteredCsv
        }
}