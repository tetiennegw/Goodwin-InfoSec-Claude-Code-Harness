# Split GWIN_File_Inventory by column L (CRA) into one xlsx per unique value + blanks
$ErrorActionPreference = 'Stop'
$src  = '{{paths.home}}\Downloads\_split_source.xlsx'
$outDir = '{{paths.home}}\Downloads\GWIN_File_Inventory_split'
$brandOrange = 13651413  # BGR for #D34D25 -> 0x254DD3 = 2444243; recompute below
# Excel uses BGR. #D34D25 = R=D3 G=4D B=25 -> BGR = 0x254DD3
$brandOrange = [int]('0x' + '254DD3')

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$xl.ScreenUpdating = $false

try {
    $wb = $xl.Workbooks.Open($src)
    $ws = $wb.Sheets.Item(1)
    $lastRow = $ws.Cells.Item($ws.Rows.Count, 12).End(-4162).Row
    $lastCol = 15
    $headerRange = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item(1,$lastCol))
    $fullRange   = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item($lastRow,$lastCol))

    # Build list of unique CRA values (and a blanks marker)
    $vals = $ws.Range("L2:L$lastRow").Value2
    $set  = New-Object System.Collections.Generic.HashSet[string]
    $hasBlank = $false
    for ($i=1; $i -le $vals.GetLength(0); $i++) {
        $v = $vals[$i,1]
        if ([string]::IsNullOrWhiteSpace("$v")) { $hasBlank = $true }
        else { [void]$set.Add(("$v").Trim()) }
    }

    function Sanitize([string]$s) {
        $bad = '\/:*?"<>|'
        foreach ($c in $bad.ToCharArray()) { $s = $s.Replace([string]$c, '_') }
        return $s.Trim().TrimEnd('.')
    }

    function Save-Filtered($criteria, $fileName, $isBlank) {
        $newWb = $xl.Workbooks.Add()
        while ($newWb.Sheets.Count -gt 1) { $newWb.Sheets.Item($newWb.Sheets.Count).Delete() }
        $newWs = $newWb.Sheets.Item(1)
        $newWs.Name = 'File Inventory'

        # Clear any existing filter, then apply
        if ($ws.AutoFilterMode) { $ws.AutoFilterMode = $false }
        if ($isBlank) {
            $fullRange.AutoFilter(12, '=') | Out-Null
        } else {
            $fullRange.AutoFilter(12, $criteria) | Out-Null
        }

        # Copy visible cells
        $visible = $fullRange.SpecialCells(12) # xlCellTypeVisible
        $visible.Copy() | Out-Null
        $newWs.Range("A1").PasteSpecial(-4163) | Out-Null   # xlPasteValues
        $newWs.Range("A1").PasteSpecial(-4122) | Out-Null   # xlPasteFormats
        $xl.CutCopyMode = $false

        # Brand header
        $nLastCol = 15
        $hdr = $newWs.Range($newWs.Cells.Item(1,1), $newWs.Cells.Item(1,$nLastCol))
        $hdr.Interior.Color = $brandOrange
        $hdr.Font.Color = 16777215  # white
        $hdr.Font.Bold = $true
        $hdr.RowHeight = 20
        $newWs.Columns.AutoFit() | Out-Null
        # Cap absurd widths
        for ($c=1; $c -le $nLastCol; $c++) {
            if ($newWs.Columns.Item($c).ColumnWidth -gt 60) { $newWs.Columns.Item($c).ColumnWidth = 60 }
        }
        # Freeze top row
        $newWs.Activate() | Out-Null
        $xl.ActiveWindow.SplitRow = 1
        $xl.ActiveWindow.FreezePanes = $true

        $outPath = Join-Path $outDir $fileName
        $newWb.SaveAs($outPath, 51)  # xlOpenXMLWorkbook
        $newWb.Close($false)

        $ws.AutoFilterMode = $false
    }

    $i = 0
    $total = $set.Count + [int]$hasBlank
    foreach ($name in ($set | Sort-Object)) {
        $i++
        $safe = Sanitize $name
        $file = "GWIN_CRA_{0}.xlsx" -f $safe
        Write-Host "[$i/$total] $name -> $file"
        Save-Filtered -criteria $name -fileName $file -isBlank $false
    }
    if ($hasBlank) {
        $i++
        Write-Host "[$i/$total] (blanks) -> GWIN_CRA__BLANK.xlsx"
        Save-Filtered -criteria $null -fileName 'GWIN_CRA__BLANK.xlsx' -isBlank $true
    }

    $wb.Close($false)
    Write-Host "DONE: $total files written to $outDir"
}
finally {
    $xl.ScreenUpdating = $true
    $xl.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}
