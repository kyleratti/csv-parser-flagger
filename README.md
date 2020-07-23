# csv-parser-flagger

A basic CSV parser that checks columns for specified content and indicates in a new column if it exists

# Usage

## Parameters

| Name       | Type     | Description                      |
| ---------- | -------- | -------------------------------- |
| `-CSVPath` | `string` | Path to the `.csv` file to parse |

## Example

```powershell
.\Start-CSVParserFlagger.ps1 -CSVPath "C:\Users\kyleratti\Desktop\User Lunches.csv"
```

## Output

This script will never modify your input file. Instead, it will output a new `.csv` file, with any flagged data indicated in a new column, to the same directory but with a random string appended to the input file name.

For example, `C:\Users\kyleratti\Desktop\User Lunches.csv` might save to `C:\Users\kyleratti\Desktop\User Lunches_dj23k1jrf.csv`.

# Adding Patterns

This script was designed in a way to (hopefully) make it pretty straightforward to add additional pattern matchers to the processor without having to create a massive loops, if-then, or otherwise weird logic chains.

You can add a pattern by adding a new entry to the `$arrPatterns` hash map using the structure below:

```powershell
$arrPatterns = @{
  "Short, Descriptive Pattern Name" = @{
    "PreProcess" = {
      # !!! ALWAYS include this line !!!
      # A string of the $strSearchHeader column value is always
      # passed as a parameter to this ScriptBlock
      param($strSearchColumn)

      # Your code here
      # Basically, you want to 'pre-process' the string pulled from the .csv
      # to make an array of strings that you'll process to determine if they
      # match what this pattern searcher finds
      #
      # At time of writing of this brain teaser, it always seems to make sense
      # to make the entire string lower-case and split it up by " "

      # return an array of strings that should be checked by the Process ScriptBlock
    };
    "Process" = {
      # !!! ALWAYS include this line !!!
      # A string of the word/thing you need to validate
      # is always passed as a parameter to this ScriptBlock
      #
      # This is each value in the array returned from
      # the PreProcess ScriptBlock above
      param($strWord)

      # Your code here
      # Check/validate $strWord and determine if it contains flaggable data
      # If it does, you should return $true !!! AND !!! the flaggable data
      # This gets picked up by the progress indicator/script output
      # Example: return $true, $strWord

      # You should always return false at the end of this ScriptBlock
      # If flaggable data was found, this ScriptBlock will have short circuited above
      return $false
    };
  }
}
```

# License

This project is licensed under the [MIT License](/LICENSE).
