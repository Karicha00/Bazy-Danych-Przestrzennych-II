<#

Skrypt obejmuje wczytanie i rozpakowanie danych, walidację rekordów,
wczytanie danych do bazy MySQL, aktualizuje kolumnę a następnie zostaje wyeksportowany do pliku .csv

Data utworzenia: 28.01.2026
#>



$ScriptName = "projekt10_skrypt"
$LogTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogDir = $PSScriptRoot
$LogFile = Join-Path $LogDir "${ScriptName}_${LogTimestamp}.log"


$TIMESTAMP = Get-Date -Format "MMddyyyy"
$ZipFile = "C:\Users\Kacper\Desktop\BDPII\InternetSales_new.zip"
$TempFolder = "C:\Users\Kacper\Desktop\BDPII\pr10"
$ArchivePassword = "bdp2agh"

$SevenZipPath = "C:\Program Files\7-Zip\7z.exe"
$BadFile = Join-Path $TempFolder "InternetSales_new.bad_$TIMESTAMP"

#Rozpakowanie i wczytanie pliku

if (-Not (Test-Path $TempFolder)) { New-Item -ItemType Directory -Path $TempFolder | Out-Null }

& $SevenZipPath x $ZipFile "-o$TempFolder" "-p$ArchivePassword" -y | Out-Null

Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Extract ZIP> - Successful"

$txtFile = Get-ChildItem -Path $extractFolder -Filter "*.txt" | Select-Object -First 1



$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$badFile = "InternetSales_new.bad_$TIMESTAMP.txt"




$allLines = Get-Content $txtFile.FullName

$header = $allLines[0]
$colNames = $header -split '\|'
$colCount = $colNames.Count
$orderQtyIndex = $colNames.IndexOf("OrderQuantity")
$customerNameIndex = $colNames.IndexOf("Customer_Name")




$newHeader = @()

for ($i = 0; $i -lt $colNames.Count; $i++) {
    if ($i -eq $customerNameIndex) {
        $newHeader += "FIRST_NAME"
        $newHeader += "LAST_NAME"
    } else {
        $newHeader += $colNames[$i]
    }
}

$cleanLines = @($newHeader -join '|')

$badLines   = @()
$seen       = @{}

# Poprawność walidacji
foreach ($line in $allLines[1..($allLines.Count - 1)]) {

    # 1. odrzuć puste linie
    if ([string]::IsNullOrWhiteSpace($line)) {
        $badLines += "$line"
        continue
    }

    $cols = $line -split '\|'

    # 2. pozostaw tylko unikalne wiersze, 
    if ($cols.Count -ne $colCount) {
        $badLines += "$line"
        continue
    }

    # 3. pozostaw wiersze, które mają ilość kolumn taką jak nagłówek pliku
    if ($seen.ContainsKey($line)) {
        $badLines += "$line"
        continue
    }

    # 4. kolumna OrderQuantity może przyjmować maksymalną wartość 100
    $orderQty = [int]($cols[$orderQtyIndex].Trim())
    if ($orderQty -gt 100) {
        $badLines += "$line"
        continue
    }

    # 5. brak wartości w SecretCode (usuń wszelkie wartości SecretCode przed przeslaniem do pliku .bad)
    $secretCode = $cols[-1]
    if (-not [string]::IsNullOrWhiteSpace($secretCode)) {
        $badLines += "$line"
        continue
    }

    # 6.  Customer_Name powinno być zapisane w formacie "nazwisko,imie"
    $customerName = $cols[$customerNameIndex]
    if (
        -not $customerName.StartsWith('"') -or
        -not $customerName.EndsWith('"') -or
        ($customerName -split ',').Count -ne 2
    ) {
        $badLines += "$line"
        continue
    }

    # 7. podziel Customer_Name na dwie osobne kolumny (z odpowiednim separatorem i bez ""): FIRST_NAME, LAST_NAME, 
    $nameParts = $customerName.Trim('"') -split ','
    $firstName = $nameParts[1].Trim()
    $lastName  = $nameParts[0].Trim()
    $cleanCols = @()
    for ($i = 0; $i -lt $cols.Count; $i++) {
        if ($i -eq $customerNameIndex) {
            $cleanCols += $firstName
            $cleanCols += $lastName
        }
        elseif ($colNames[$i] -eq "UnitPrice") {
            $cleanCols += $cols[$i].Trim() -replace ',', '.'
        }
        else {
            $cleanCols += $cols[$i].Trim()
        }
}


    # 9. Dodanie do clean i rejestrowanie unikalności
    $cleanLines += ($cleanCols -join '|')
    $seen[$line] = $true
}



$cleanFile = Join-Path $TempFolder "InternetSales_new_clean.txt"

$cleanLines | Out-File $cleanFile -Encoding utf8
$badLines   | Out-File "$badFile.txt"


Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Data Validation> - Successful"





# parametry 

$server = "mysql.agh.edu.pl"
$database = "kacpercz"
$user = "kacpercz"
$passwordEncoded = "ZVNlZWZENzhUcnlzUGRWVg=="
$password = [System.Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($passwordEncoded)
)
$numerIndeksu = "401001"
$port = 3306
$mysqlExe = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
$tabela = "CUSTOMERS_$numerIndeksu"


# d.) Tworzenie tabeli

$query = @"
DROP TABLE IF EXISTS $tabela;

CREATE TABLE $tabela (
    ProductKey INT,
    CurrencyAlternateKey VARCHAR(10),
    FIRST_NAME VARCHAR(50),
    LAST_NAME VARCHAR(50),
    OrderDateKey INT,
    OrderQuantity INT,
    UnitPrice DECIMAL(10,2),
    SecretCode VARCHAR(10)
);
"@

& $mysqlExe --host=$server --port=$port --user=$user --password=$password $database --execute=$query

$cleanFileMysql = $cleanFile -replace '\\','/'

Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Creating MySQL Table> - Successful"

# e.) Ładowanie danych ze zweryfikowanego pliku

$loadQuery = @"
LOAD DATA LOCAL INFILE '$cleanFileMysql'
INTO TABLE $tabela
FIELDS TERMINATED BY '|'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(ProductKey,
 CurrencyAlternateKey,
 FIRST_NAME,
 LAST_NAME,
 OrderDateKey,
 OrderQuantity,
 UnitPrice);
"@

& $mysqlExe `
  --local-infile=1 `
  --host=$server `
  --port=$port `
  --user=$user `
  --password=$password `
  $database `
  --execute=$loadQuery



Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Load Data into MySQL Table> - Successful"


# f.) Przeniesienie przetworzonego pliku do podkatalogu



$processedDir = Join-Path $TempFolder "PROCESSED"
if (-not (Test-Path $processedDir)) {
    New-Item -ItemType Directory -Path $processedDir | Out-Null
}

$originalName = Split-Path $cleanFile -Leaf
$newName = "${TIMESTAMP}_$originalName"
$destination = Join-Path $processedDir $newName

Move-Item -Path $cleanFile -Destination $destination -Force

Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Move File> - Successful"

# g.) Aktualizacja Secret Code

$updateQuery = @"
UPDATE $tabela
SET SecretCode = SUBSTRING(MD5(RAND()), 1, 10);
"@

& $mysqlExe --host=$server --port=$port --user=$user --password=$password $database --execute=$updateQuery

Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Update Secred Code> - Successful"

# h.) Eksport tabeli do CSV

$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$exportDir = Join-Path $TempFolder "EXPORTS"
if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir | Out-Null
}

$exportFile = Join-Path $exportDir "CUSTOMERS_${numerIndeksu}_${TIMESTAMP}.csv"

$query = @"
SELECT 
    ProductKey,
    CurrencyAlternateKey,
    FIRST_NAME,
    LAST_NAME,
    OrderDateKey,
    OrderQuantity,
    UnitPrice,
    SecretCode
FROM $tabela;
"@

$rows = & $mysqlExe `
    --host=$server `
    --port=$port `
    --user=$user `
    --password=$password `
    --batch `
    --skip-column-names `
    $database `
    --execute="$query"

$header = 'ProductKey,CurrencyAlternateKey,FIRST_NAME,LAST_NAME,OrderDateKey,OrderQuantity,UnitPrice,SecretCode'
[System.IO.File]::WriteAllText($exportFile, $header + "`n", [System.Text.Encoding]::UTF8)

foreach ($row in $rows) {
    $fields = $row -split "`t", -1
    $cleanFields = $fields | ForEach-Object { ($_ -replace '"','').Trim() }
    $csvLine = $cleanFields -join ','
    Add-Content -Path $exportFile -Value $csvLine -Encoding UTF8
}

$csvFile = $exportFile

Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Exporting to CSV > - Successful"


#Kompresja 
$zipDir = Split-Path $csvFile -Parent
$zipName = [System.IO.Path]::GetFileNameWithoutExtension($csvFile) + ".zip"
$zipFile = Join-Path $zipDir $zipName

$zipArgs = @(
    "a",                  
    "`"$zipFile`"",       
    "`"$csvFile`""      
)

& $SevenZipPath @zipArgs

Add-Content $LogFile "$(Get-Date -Format 'yyyyMMddHHmmss') - <Archive CSV > - Successful"
