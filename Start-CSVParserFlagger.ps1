<#
  # Name:       CSV Parser Flagger
  # Version:    1.0.0
  # Author:     Kyle Ratti (https://kyleratti.me)
  # Consultant: Jake Forry
  #
  # Purpose:    Detect if words or patterns that appear anywhere in a specific column
  #             of a CSV file and indicate in a new column if it does.
  #
  # Note:       This is a rough draft that does basic detection. It is built to be
  #             somewhat easily expandable to accomodate additional search patterns
  #             to avoid constantly rewriting the logic or making a giant if-then
  #             or for-each mess that makes it difficult to follow.
#>

param(
  [Parameter(Mandatory = $true)]
  [string]
  $CSVPath
)

if (-Not $CSVPath) {
  $CSVPath = Read-Host "Please specify the path to the .csv with data"
}

if (-Not (Test-Path -Path $CSVPath)) {
  Write-Error "Unable to find file at: $CSVPath"
  exit 1
}

$strInputFilePath = [System.IO.Path]::GetDirectoryName($CSVPath)
$strInputFileName = [System.IO.Path]::GetFileNameWithoutExtension($CSVPath)

# Source: https://devblogs.microsoft.com/scripting/weekend-scripter-remove-non-alphabetic-characters-from-string/
function Remove-NonAlphaCharacters {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]
    $str
  )

  process {
    $pattern = '[^a-zA-Z]'

    return $str -replace $pattern, ''
  }
}

function Remove-NonNumericCharacters {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]
    $str
  )

  process {
    $pattern = '[^0-9]'

    return $str -replace $pattern, ''
  }
}

<#
# This is a comma-separated list of words that will trigger
# the "Flaggable Data Trigger" pattern filter below
#
# NOTE: You should always enter each in lowercase
#>
$arrTriggerWords = @(
  "chicken",
  "potato",
  "peanut"
)

<#
  # The patterns are written in a structured hashmap
  # to make additions, modifications, and removals of
  # patterns mostly painless. The structure is as follows:
  #
  # $arrPatterns = @{
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
#>
$arrPatterns = @{
  "Flaggable Data Words"            = @{
    "PreProcess" = {
      param($strSearchColumn)
      
      $arrWords = @()
      
      foreach ($str in $strSearchColumn.ToLower().Split(" ")) {
        # Convert the entire string to lowercase
        # Then split it by space to pull out each word
        # Finally, push it into $arrWords with all non-alphabetic characters removed
        $newStr = $(Remove-NonAlphaCharacters $str)
        # Don't add empty strings to be checked - it's a waste of processing power
        if ($newStr.Length -gt 0) {
          $arrWords += $newStr
        }
      }

      return $arrWords
    };
    "Process"    = {
      param($strWord)

      foreach ($strTriggerWord in $arrTriggerWords) {
        # Convert the trigger word to lower case, just in
        # case it was accidentally entered with a capital
        # in the configuration above
        $strTriggerWord = $strTriggerWord.ToLower()

        if ($strWord -eq $strTriggerWord) {
          return $true, $strWord
        }
      }

      return $false
    };
  };
  "10 Consecutive Number Detection" = @{
    "PreProcess" = {
      param($strSearchColumn)

      $arrWords = @()

      foreach ($str in $strSearchColumn.ToLower().Split(" ")) {
        $newStr = $(Remove-NonNumericCharacters $str)
        # Don't add empty strings to be checked - it's a waste of processing power
        if ($newStr.Length -gt 0) {
          $arrWords += $newStr
        }
      }

      return $arrWords
    };
    "Process"    = {
      param($strWord)

      # If the "word" of non-numeric characters
      # is 10 characters long, it passes our test
      return $($strWord.Length -eq 10), $strWord
    }
  };
  "85 Consecutive Number Detection" = @{
    "PreProcess" = {
      param($strSearchColumn)

      $arrWords = @()

      foreach ($str in $strSearchColumn.ToLower().Split(" ")) {
        $newStr = $(Remove-NonNumericCharacters $str)
        # Don't add empty strings to be checked - it's a waste of processing power
        if ($newStr.Length -gt 0) {
          $arrWords += $newStr
        }
      }

      return $arrWords
    };
    "Process"    = {
      param($strWord)

      # If the "word" of non-numeric characters
      # is 85 characters long, it passes our test
      return $($strWord.Length -eq 85), $strWord
    }
  };
}

$strIdentifier = "User E-mail" # Unique identifier column name
$strSearchHeader = "User Lunch" # This is the column name where we are running the above patterns against
$strFlagHeader = "Good Taste in Lunch?" # The name of the header to add to the file (if it does not exist)
$objFlagValue = "Y" # The value to set $strFlagHeader to when $strFlagHeader on that row contains flaggable data

$arrData = Import-CSV -Path $CSVPath
$bFlagHeaderExists = $null -ne $($arrData | Get-Member -MemberType "NoteProperty" | Where-Object { $_.Name -eq $strFlagHeader } | Select-Object -ExpandProperty "Name")

if (-Not $bFlagHeaderExists) {
  Write-Host "No '$strFlagHeader' detected; adding to all rows"
  $arrData = $arrData | Select-Object *, $strFlagHeader
}
else {
  Write-Host "Detected existing '$strFlagHeader' header"
}

:itemLoop foreach ($objItem in $arrData) {
  $strID = $objItem.$strIdentifier
  $strSearchColumn = $objItem.$strSearchHeader

  Write-Host "Checking '" -NoNewLine
  Write-Host $strID -NoNewLine -ForegroundColor Green -BackgroundColor Black
  Write-Host "'"

  :patternLoop foreach ($strPatternName in $arrPatterns.Keys) {
    $objPattern = $arrPatterns[$strPatternName]

    Write-Host "`t- '" -NoNewLine
    Write-Host $strPatternName -NoNewLine -ForegroundColor Yellow
    Write-Host "'..." -NoNewLine


    $arrPreProcessed = $(& $objPattern['PreProcess'] $strSearchColumn) # Returns an array of strings to be checked (processed)
    $bFlaggedDataFound = $false
    $arrFlaggedData = @() # Our found flaggable data, if any, for later use (reporting)

    :wordLoop foreach ($strWord in $arrPreProcessed) {
      # Process each word/thing the preprocessor found to see if it has flaggable data
      # The '&' symbol here executes the ScriptBlock stored at $objPattern['Process']
      # If you remove the '&' symbol, it will just print the ScriptBlock to the console
      $arrPatternMatch = $(& $objPattern['Process'] $strWord)
      $bPatternFoundFlaggable = $arrPatternMatch[0]
      $strPatternFlaggedData = $arrPatternMatch[1]

      if ($bPatternFoundFlaggable) {
        $bFlaggedDataFound = $true
        $arrFlaggedData += $strPatternFlaggedData

        # I decided not to break the loop so that the script will
        # output every flaggable data match. This is less efficient, but
        # could be adapted to indicate _what_ flaggable data matched
        # instead of a blanket "YES" or "NO" column
        # break wordLoop
      }
    }

    if ($bFlaggedDataFound) {
      Write-Host "FAIL: " -NoNewLine -ForegroundColor Red
      Write-Host $($arrFlaggedData -Join ", ") -ForegroundColor Cyan
      # I decided not to break the loop so that the script will
      # output every flaggable data match. This is less efficient, but
      # could be adapted to indicate _what_ flaggable data matched
      # instead of a blanket "YES" or "NO" column
      # break patternLoop

      $objItem.$strFlagHeader = $objFlagValue
    }
    else {
      Write-Host "OK" -ForegroundColor Green
    }
  }
}

$strOutputFileName = $($strInputFileName + "_" + [System.IO.Path]::GetRandomFileName() + ".csv")
$strOutputFullPath = Join-Path -Path $strInputFilePath -ChildPath $strOutputFileName

Write-Host "Output Path: " -NoNewLine
Write-Host $strOutputFullPath -ForegroundColor Green

$arrData | Export-Csv -Path $strOutputFullPath -NoTypeInformation
