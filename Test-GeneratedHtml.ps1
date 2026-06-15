param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "html")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Contains {
    param(
        [string]$FilePath,
        [string]$Expected,
        [string]$Description
    )
    $content = Get-Content -LiteralPath $FilePath -Raw
    if ($content -notlike "*$Expected*") {
        throw "Missing expected content in $([System.IO.Path]::GetFileName($FilePath)): $Description"
    }
}
function Assert-NotContains {
    param(
        [string]$FilePath,
        [string]$Unexpected,
        [string]$Description
    )
    $content = Get-Content -LiteralPath $FilePath -Raw
    if ($content -like "*$Unexpected*") {
        throw "Unexpected content in $([System.IO.Path]::GetFileName($FilePath)): $Description"
    }
}

$autoDlReport = Join-Path $OutputDir "H06102026_121830.html"
$deepLearningReport = Join-Path $OutputDir "sample-arcgis-history.html"
$indexReport = Join-Path $OutputDir "index.html"

Assert-Contains $indexReport "ArcGIS Geoprocessing History Report Viewer" "updated application display name"
Assert-NotContains $indexReport 'class="kicker"' "top eyebrow label removed from index"
Assert-Contains $indexReport "ArcGIS Pro" "ArcGIS Pro XML source description"
Assert-Contains $indexReport "https://doc.esri.com/en/arcgis-pro/latest/help/analysis/geoprocessing/basics/geoprocessing-history.html#537" "Esri geoprocessing history source link"
Assert-Contains $indexReport "Copy latest XML here before running" "copy latest XML instruction"
Assert-Contains $indexReport "the repository root folder, next to Convert-ArcGISHistoryToHtml.ps1" "portable XML input folder"
Assert-Contains $indexReport "%AppData%\Esri\ArcGISPro\ArcToolbox\History" "ArcGIS Pro history sample path"
Assert-Contains $indexReport "powershell -NoProfile -ExecutionPolicy Bypass -File" "detailed regeneration PowerShell command"
Assert-Contains $indexReport "-SourceDir &quot;.&quot;" "PowerShell source directory argument"
Assert-Contains $indexReport "-OutputDir &quot;.\html&quot;" "PowerShell output directory argument"
Assert-Contains $indexReport "sample-arcgis-history.xml" "single sanitized demo report link"
Assert-NotContains $indexReport "D:\Learning" "local install path removed from index"
Assert-NotContains $indexReport "D:\Codex" "staging path removed from index"

Assert-Contains $deepLearningReport "Training Metrics <span class='count'>9</span>" "first Train Deep Learning Model metrics table"
Assert-Contains $deepLearningReport "<th>Average Precision</th>" "Train Deep Learning Model average precision column"
Assert-Contains $deepLearningReport "Train Deep Learning Model" "single target demo tool"
Assert-NotContains $deepLearningReport "Export Training Data For Deep Learning" "non-target demo tool removed"
Assert-NotContains $deepLearningReport "Detect Objects Using Deep Learning" "non-target demo tool removed"
Assert-NotContains $deepLearningReport 'class="kicker"' "top eyebrow label removed from detail pages"
Assert-NotContains $deepLearningReport "C:\Users\archi" "personal user path removed from demo output"
Assert-NotContains $deepLearningReport "D:\Classes" "personal class path removed from demo output"
Assert-NotContains $deepLearningReport "E:\Packages" "personal package path removed from demo output"
Assert-NotContains $deepLearningReport "D:\Learning" "local install path removed from report"
Assert-NotContains $deepLearningReport "D:\Codex" "staging path removed from report"

Write-Host "Generated HTML checks passed."





