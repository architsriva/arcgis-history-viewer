param(
    [string]$SourceDir = $PSScriptRoot,
    [string]$OutputDir = (Join-Path $PSScriptRoot "html")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AppName = "ArcGIS Geoprocessing History Report Viewer"
$ArcGisHistorySamplePath = "%AppData%\Esri\ArcGISPro\ArcToolbox\History"
$ArcGisHistoryHelpUrl = "https://doc.esri.com/en/arcgis-pro/latest/help/analysis/geoprocessing/basics/geoprocessing-history.html#537"

function Escape-Html {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-RegenerationCommand {
    param([string]$OutputDir)
    return 'powershell -NoProfile -ExecutionPolicy Bypass -File ".\Convert-ArcGISHistoryToHtml.ps1" -SourceDir "." -OutputDir ".\html"'
}

function New-ReportFooter {
    param([string]$OutputDir)
    $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $regenerationCommand = Get-RegenerationCommand -OutputDir $OutputDir
    return @"
  <div class="footer-note">
    <p>Generated $(Escape-Html $generatedAt). Source XML was not modified.</p>
    <p><strong>XML source:</strong> ArcGIS Pro can write geoprocessing history to XML log files. See <a href="$(Escape-Html $ArcGisHistoryHelpUrl)">Esri's geoprocessing history documentation</a>.</p>
    <p><strong>Original ArcGIS Pro history folder:</strong> <code>$(Escape-Html $ArcGisHistorySamplePath)</code></p>
    <p><strong>Copy latest XML here before running:</strong> <code>the repository root folder, next to Convert-ArcGISHistoryToHtml.ps1</code></p>
    <p><strong>Generate latest report:</strong> <code>$(Escape-Html $regenerationCommand)</code></p>
  </div>
"@
}

function Get-AttributeValue {
    param(
        [AllowNull()][System.Xml.XmlNode]$Node,
        [string]$Name
    )
    if ($null -eq $Node -or $null -eq $Node.Attributes -or $null -eq $Node.Attributes[$Name]) {
        return ""
    }
    return [string]$Node.Attributes[$Name].Value
}

function Get-NodeText {
    param(
        [AllowNull()][System.Xml.XmlNode]$Node,
        [string]$Path
    )
    if ($null -eq $Node) { return "" }
    $found = $Node.SelectSingleNode($Path)
    if ($null -eq $found) { return "" }
    return ([string]$found.InnerText).Trim()
}

function Get-Nodes {
    param(
        [AllowNull()][System.Xml.XmlNode]$Node,
        [string]$Path
    )
    if ($null -eq $Node) { return @() }
    $nodes = $Node.SelectNodes($Path)
    if ($null -eq $nodes) { return @() }
    return @($nodes)
}

function Get-ResultViewBlocks {
    param([string]$RawXml)
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    return @([regex]::Matches($RawXml, "<ResultView\b.*?</ResultView>", $options))
}

function Convert-ResultViewBlockToNode {
    param([string]$Block)
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $false
    $doc.LoadXml($Block)
    return $doc.DocumentElement
}

function Get-MessageClass {
    param([string]$Type)
    $lower = $Type.ToLowerInvariant()
    if ($lower -match "error|fail|severe") { return "danger" }
    if ($lower -match "warn") { return "warning" }
    if ($lower -match "success|succeed") { return "success" }
    return "info"
}

function Get-CountText {
    param([hashtable]$Counts)
    if ($Counts.Count -eq 0) { return "None" }
    return (($Counts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        "$($_.Name): $($_.Value)"
    }) -join ", ")
}

function Add-Count {
    param(
        [hashtable]$Counts,
        [string]$Key
    )
    if ([string]::IsNullOrWhiteSpace($Key)) { $Key = "Unspecified" }
    if ($Counts.ContainsKey($Key)) {
        $Counts[$Key] += 1
    } else {
        $Counts[$Key] = 1
    }
}

function Render-ParameterTable {
    param(
        [string]$Title,
        [object[]]$Nodes
    )
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<section class='section'>")
    [void]$sb.AppendLine("<h3>$(Escape-Html $Title) <span class='count'>$($Nodes.Count)</span></h3>")
    if ($Nodes.Count -eq 0) {
        [void]$sb.AppendLine("<p class='empty'>No entries.</p>")
    } else {
        [void]$sb.AppendLine("<table>")
        [void]$sb.AppendLine("<thead><tr><th>Label</th><th>Type</th><th>Value</th></tr></thead>")
        [void]$sb.AppendLine("<tbody>")
        foreach ($node in $Nodes) {
            $label = Get-AttributeValue $node "Label"
            $type = Get-AttributeValue $node "Type"
            $value = ([string]$node.InnerText).Trim()
            [void]$sb.AppendLine("<tr><td>$(Escape-Html $label)</td><td><span class='tag'>$(Escape-Html $type)</span></td><td><code>$(Escape-Html $value)</code></td></tr>")
        }
        [void]$sb.AppendLine("</tbody></table>")
    }
    [void]$sb.AppendLine("</section>")
    return $sb.ToString()
}

function Render-LayerTable {
    param([object[]]$Nodes)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<section class='section'>")
    [void]$sb.AppendLine("<h3>Layer Info <span class='count'>$($Nodes.Count)</span></h3>")
    if ($Nodes.Count -eq 0) {
        [void]$sb.AppendLine("<p class='empty'>No layer info.</p>")
    } else {
        [void]$sb.AppendLine("<table>")
        [void]$sb.AppendLine("<thead><tr><th>Name</th><th>Value</th></tr></thead><tbody>")
        foreach ($node in $Nodes) {
            $name = Get-AttributeValue $node "Name"
            $value = ([string]$node.InnerText).Trim()
            [void]$sb.AppendLine("<tr><td>$(Escape-Html $name)</td><td><code>$(Escape-Html $value)</code></td></tr>")
        }
        [void]$sb.AppendLine("</tbody></table>")
    }
    [void]$sb.AppendLine("</section>")
    return $sb.ToString()
}

function Render-EnvironmentTable {
    param([object[]]$Nodes)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<section class='section'>")
    [void]$sb.AppendLine("<h3>Environments <span class='count'>$($Nodes.Count)</span></h3>")
    if ($Nodes.Count -eq 0) {
        [void]$sb.AppendLine("<p class='empty'>No environment settings.</p>")
    } else {
        [void]$sb.AppendLine("<table>")
        [void]$sb.AppendLine("<thead><tr><th>Label</th><th>Value</th></tr></thead><tbody>")
        foreach ($node in $Nodes) {
            $label = Get-AttributeValue $node "Label"
            $value = ([string]$node.InnerText).Trim()
            [void]$sb.AppendLine("<tr><td>$(Escape-Html $label)</td><td><code>$(Escape-Html $value)</code></td></tr>")
        }
        [void]$sb.AppendLine("</tbody></table>")
    }
    [void]$sb.AppendLine("</section>")
    return $sb.ToString()
}

function Get-TrainingMetricRows {
    param([object[]]$MessageNodes)
    $rows = @()
    $format = ""
    $metricLabel = ""
    foreach ($messageNode in $MessageNodes) {
        $text = ([string]$messageNode.InnerText).Trim()
        if ($text -match "Training loss\s+Validation loss\s+Accuracy") {
            $format = "AutoDL"
            $metricLabel = "Accuracy"
            continue
        }
        if ($text -match "^epoch\s+training loss\s+validation loss\s+average_precision\s+time") {
            $format = "DeepLearning"
            $metricLabel = "Average Precision"
            continue
        }
        if ([string]::IsNullOrWhiteSpace($format)) { continue }
        $parts = @($text -split "\s+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

        if ($format -eq "AutoDL" -and $parts.Count -ge 3) {
            $numbers = @()
            $isNumeric = $true
            for ($i = 0; $i -lt 3; $i++) {
                $parsed = 0.0
                if ([double]::TryParse($parts[$i], [ref]$parsed)) {
                    $numbers += $parsed
                } else {
                    $isNumeric = $false
                    break
                }
            }
            if ($isNumeric) {
                $rows += [pscustomobject]@{
                    Epoch = $rows.Count + 1
                    TrainingLoss = $numbers[0]
                    ValidationLoss = $numbers[1]
                    MetricLabel = $metricLabel
                    MetricValue = $numbers[2]
                    Duration = ""
                }
                continue
            }
        }

        if ($format -eq "DeepLearning" -and $parts.Count -ge 5) {
            $epoch = 0
            $trainingLoss = 0.0
            $validationLoss = 0.0
            $metricValue = 0.0
            $parsed = [int]::TryParse($parts[0], [ref]$epoch) -and
                [double]::TryParse($parts[1], [ref]$trainingLoss) -and
                [double]::TryParse($parts[2], [ref]$validationLoss) -and
                [double]::TryParse($parts[3], [ref]$metricValue)
            if ($parsed) {
                $rows += [pscustomobject]@{
                    Epoch = $epoch
                    TrainingLoss = $trainingLoss
                    ValidationLoss = $validationLoss
                    MetricLabel = $metricLabel
                    MetricValue = $metricValue
                    Duration = $parts[4]
                }
                continue
            }
        }

        if ($rows.Count -gt 0) { break }
    }
    return $rows
}

function Render-TrainingMetrics {
    param([object[]]$Rows)
    if ($Rows.Count -eq 0) { return "" }
    $maxLoss = ($Rows | ForEach-Object { $_.TrainingLoss; $_.ValidationLoss } | Measure-Object -Maximum).Maximum
    if ($null -eq $maxLoss -or $maxLoss -le 0) { $maxLoss = 1 }
    $metricLabel = "Metric"
    if ($Rows[0].PSObject.Properties.Name -contains "MetricLabel" -and -not [string]::IsNullOrWhiteSpace($Rows[0].MetricLabel)) {
        $metricLabel = $Rows[0].MetricLabel
    }
    $hasDuration = @($Rows | Where-Object { $_.PSObject.Properties.Name -contains "Duration" -and -not [string]::IsNullOrWhiteSpace($_.Duration) }).Count -gt 0
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<section class='section'>")
    [void]$sb.AppendLine("<h3>Training Metrics <span class='count'>$($Rows.Count)</span></h3>")
    [void]$sb.AppendLine("<table class='metrics'>")
    $durationHeader = ""
    if ($hasDuration) { $durationHeader = "<th>Time</th>" }
    [void]$sb.AppendLine("<thead><tr><th>Epoch</th><th>Training Loss</th><th>Validation Loss</th><th>$(Escape-Html $metricLabel)</th>$durationHeader</tr></thead><tbody>")
    foreach ($row in $Rows) {
        $trainWidth = [Math]::Max(2, [Math]::Round(($row.TrainingLoss / $maxLoss) * 100, 1))
        $validWidth = [Math]::Max(2, [Math]::Round(($row.ValidationLoss / $maxLoss) * 100, 1))
        $metricWidth = [Math]::Max(2, [Math]::Round($row.MetricValue * 100, 1))
        $durationCell = ""
        if ($hasDuration) { $durationCell = "<td><code>$(Escape-Html $row.Duration)</code></td>" }
        [void]$sb.AppendLine("<tr><td>$($row.Epoch)</td><td><span class='bar loss' style='width:$trainWidth%'></span><code>$('{0:N4}' -f $row.TrainingLoss)</code></td><td><span class='bar valid' style='width:$validWidth%'></span><code>$('{0:N4}' -f $row.ValidationLoss)</code></td><td><span class='bar metric' style='width:$metricWidth%'></span><code>$('{0:P1}' -f $row.MetricValue)</code></td>$durationCell</tr>")
    }
    [void]$sb.AppendLine("</tbody></table>")
    [void]$sb.AppendLine("</section>")
    return $sb.ToString()
}

function Render-MessagesTable {
    param([object[]]$Nodes)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<section class='section'>")
    [void]$sb.AppendLine("<h3>Messages <span class='count'>$($Nodes.Count)</span></h3>")
    if ($Nodes.Count -eq 0) {
        [void]$sb.AppendLine("<p class='empty'>No messages.</p>")
    } else {
        [void]$sb.AppendLine("<table class='messages'>")
        [void]$sb.AppendLine("<thead><tr><th>#</th><th>Type</th><th>Message</th></tr></thead><tbody>")
        for ($i = 0; $i -lt $Nodes.Count; $i++) {
            $node = $Nodes[$i]
            $type = Get-AttributeValue $node "Type"
            $className = Get-MessageClass $type
            $message = ([string]$node.InnerText).Trim()
            [void]$sb.AppendLine("<tr><td>$($i + 1)</td><td><span class='pill $className'>$(Escape-Html $type)</span></td><td><code>$(Escape-Html $message)</code></td></tr>")
        }
        [void]$sb.AppendLine("</tbody></table>")
    }
    [void]$sb.AppendLine("</section>")
    return $sb.ToString()
}

function Render-ResultCard {
    param(
        [System.Xml.XmlNode]$ResultView,
        [string]$RawBlock,
        [int]$Index,
        [bool]$Open
    )
    $tool = Get-AttributeValue $ResultView "Tool"
    $startTime = Get-NodeText $ResultView "StartTime"
    $endTimes = @(Get-Nodes $ResultView "EndTime")
    $endTime = (($endTimes | ForEach-Object { ([string]$_.InnerText).Trim() } | Where-Object { $_ } | Select-Object -Last 1) -join "")
    $commandLine = Get-NodeText $ResultView "CommandLine"
    $toolSource = Get-NodeText $ResultView "ToolSource"
    $inputs = @(Get-Nodes $ResultView "Parameters/Inputs/Parameter")
    $outputs = @(Get-Nodes $ResultView "Parameters/Outputs/Parameter")
    $layers = @(Get-Nodes $ResultView "Parameters/LayerInfo/Layer")
    $environments = @(Get-Nodes $ResultView "Environments/Environment")
    $messages = @(Get-Nodes $ResultView "Messages/Message")
    $messageCounts = @{}
    foreach ($message in $messages) {
        Add-Count $messageCounts (Get-AttributeValue $message "Type")
    }
    $openAttribute = ""
    if ($Open) { $openAttribute = " open" }

    $trainingMetrics = @(Get-TrainingMetricRows $messages)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<article class='result-card' data-search='$(Escape-Html "$tool $startTime $endTime $commandLine $toolSource")'>")
    [void]$sb.AppendLine("<details$openAttribute>")
    [void]$sb.AppendLine("<summary>")
    [void]$sb.AppendLine("<span class='summary-main'><span class='index'>$Index</span><span><strong>$(Escape-Html $tool)</strong><small>$(Escape-Html $startTime)</small></span></span>")
    [void]$sb.AppendLine("<span class='summary-meta'><span class='pill info'>$($messages.Count) messages</span><span class='pill neutral'>$($inputs.Count) inputs</span><span class='pill neutral'>$($outputs.Count) outputs</span></span>")
    [void]$sb.AppendLine("</summary>")
    [void]$sb.AppendLine("<div class='card-body'>")
    [void]$sb.AppendLine("<section class='overview-grid'>")
    [void]$sb.AppendLine("<div><span>Tool</span><strong>$(Escape-Html $tool)</strong></div>")
    [void]$sb.AppendLine("<div><span>Start</span><strong>$(Escape-Html $startTime)</strong></div>")
    [void]$sb.AppendLine("<div><span>End</span><strong>$(Escape-Html $endTime)</strong></div>")
    [void]$sb.AppendLine("<div><span>Message Types</span><strong>$(Escape-Html (Get-CountText $messageCounts))</strong></div>")
    [void]$sb.AppendLine("</section>")
    if (-not [string]::IsNullOrWhiteSpace($toolSource)) {
        [void]$sb.AppendLine("<section class='section compact'><h3>Tool Source</h3><pre>$(Escape-Html $toolSource)</pre></section>")
    }
    if (-not [string]::IsNullOrWhiteSpace($commandLine)) {
        [void]$sb.AppendLine("<section class='section compact'><h3>Command Line</h3><pre>$(Escape-Html $commandLine)</pre></section>")
    }
    [void]$sb.AppendLine((Render-ParameterTable "Inputs" $inputs))
    [void]$sb.AppendLine((Render-ParameterTable "Outputs" $outputs))
    [void]$sb.AppendLine((Render-LayerTable $layers))
    [void]$sb.AppendLine((Render-EnvironmentTable $environments))
    [void]$sb.AppendLine((Render-TrainingMetrics $trainingMetrics))
    [void]$sb.AppendLine((Render-MessagesTable $messages))
    [void]$sb.AppendLine("<details class='raw'><summary>Raw ResultView XML</summary><pre>$(Escape-Html $RawBlock)</pre></details>")
    [void]$sb.AppendLine("</div>")
    [void]$sb.AppendLine("</details>")
    [void]$sb.AppendLine("</article>")
    return $sb.ToString()
}

$StyleBlock = @'
<style>
:root {
  --bg: #f6f7f9;
  --panel: #ffffff;
  --text: #17202a;
  --muted: #667085;
  --line: #d8dee8;
  --soft: #edf1f6;
  --accent: #2854c5;
  --accent-2: #0f8b8d;
  --danger: #bd2d2d;
  --warning: #936900;
  --success: #16794c;
  --shadow: 0 8px 26px rgba(23, 32, 42, 0.08);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.5 "Segoe UI", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
}
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
.page {
  width: min(1180px, calc(100vw - 32px));
  margin: 0 auto;
  padding: 28px 0 44px;
}
header.hero {
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 8px;
  box-shadow: var(--shadow);
  padding: 24px;
  margin-bottom: 18px;
}
.kicker {
  color: var(--muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: .08em;
  margin-bottom: 8px;
  text-transform: uppercase;
}
h1 {
  font-size: clamp(24px, 3vw, 36px);
  line-height: 1.12;
  margin: 0 0 10px;
}
.hero p { color: var(--muted); max-width: 850px; margin: 0; }
.stats {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  margin-top: 18px;
}
.stat {
  background: var(--soft);
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 12px;
}
.stat span, .overview-grid span {
  color: var(--muted);
  display: block;
  font-size: 12px;
  margin-bottom: 3px;
}
.stat strong, .overview-grid strong { display: block; font-size: 15px; word-break: break-word; }
.toolbar {
  align-items: center;
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 8px;
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 14px;
  padding: 12px;
  position: sticky;
  top: 0;
  z-index: 10;
}
input[type="search"] {
  border: 1px solid var(--line);
  border-radius: 6px;
  flex: 1 1 260px;
  font: inherit;
  min-width: 0;
  padding: 9px 10px;
}
button {
  background: var(--text);
  border: 0;
  border-radius: 6px;
  color: white;
  cursor: pointer;
  font: 600 13px/1 "Segoe UI", system-ui, sans-serif;
  padding: 10px 12px;
}
button.secondary { background: #475467; }
.match-count { color: var(--muted); font-size: 13px; }
.result-card, .index-panel {
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 8px;
  box-shadow: var(--shadow);
  margin-bottom: 12px;
  overflow: hidden;
}
details > summary {
  align-items: center;
  cursor: pointer;
  display: flex;
  gap: 14px;
  justify-content: space-between;
  list-style: none;
  padding: 16px 18px;
}
details > summary::-webkit-details-marker { display: none; }
.summary-main {
  align-items: center;
  display: flex;
  gap: 12px;
  min-width: 0;
}
.summary-main strong { display: block; font-size: 16px; }
.summary-main small { color: var(--muted); display: block; margin-top: 2px; }
.summary-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  justify-content: flex-end;
}
.index {
  align-items: center;
  background: var(--accent);
  border-radius: 6px;
  color: white;
  display: inline-flex;
  font-weight: 800;
  height: 30px;
  justify-content: center;
  min-width: 30px;
  padding: 0 7px;
}
.card-body {
  border-top: 1px solid var(--line);
  padding: 18px;
}
.overview-grid {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
  margin-bottom: 14px;
}
.overview-grid > div {
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 12px;
}
.section {
  margin-top: 16px;
}
.section h3 {
  align-items: center;
  display: flex;
  font-size: 15px;
  gap: 8px;
  margin: 0 0 8px;
}
.count {
  background: var(--soft);
  border: 1px solid var(--line);
  border-radius: 999px;
  color: var(--muted);
  font-size: 12px;
  padding: 1px 7px;
}
.empty { color: var(--muted); margin: 0; }
table {
  border-collapse: collapse;
  width: 100%;
}
th {
  background: #f2f4f7;
  color: #344054;
  font-size: 12px;
  text-align: left;
}
th, td {
  border: 1px solid var(--line);
  padding: 9px 10px;
  vertical-align: top;
}
td:first-child, th:first-child { width: 190px; }
code, pre {
  font-family: "Cascadia Mono", Consolas, "Courier New", monospace;
  font-size: 12px;
  white-space: pre-wrap;
  word-break: break-word;
}
pre {
  background: #111827;
  border-radius: 8px;
  color: #e5e7eb;
  margin: 0;
  max-height: 360px;
  overflow: auto;
  padding: 12px;
}
.compact pre { max-height: 220px; }
.raw {
  margin-top: 16px;
}
.raw summary {
  border: 1px solid var(--line);
  border-radius: 8px;
  color: var(--muted);
  display: block;
  font-weight: 700;
  padding: 10px 12px;
}
.raw pre { margin-top: 8px; }
.pill, .tag {
  border-radius: 999px;
  display: inline-flex;
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
  padding: 5px 8px;
  white-space: nowrap;
}
.pill.info { background: #e8efff; color: var(--accent); }
.pill.neutral, .tag { background: var(--soft); color: #475467; }
.pill.danger { background: #ffe8e8; color: var(--danger); }
.pill.warning { background: #fff3c4; color: var(--warning); }
.pill.success { background: #dcfce7; color: var(--success); }
.messages td:first-child, .messages th:first-child { width: 54px; }
.messages td:nth-child(2), .messages th:nth-child(2) { width: 130px; }
.metrics td { position: relative; }
.bar {
  border-radius: 999px;
  display: inline-block;
  height: 8px;
  margin-right: 8px;
  vertical-align: middle;
}
.bar.loss { background: #ef8a62; }
.bar.valid { background: #67a9cf; }
.bar.metric { background: #1a9850; }
.index-panel { padding: 16px; }
.index-table td:first-child, .index-table th:first-child { width: 240px; }
.tools-list {
  color: var(--muted);
  margin: 8px 0 0;
}
.footer-note {
  color: var(--muted);
  font-size: 12px;
  margin-top: 20px;
}
@media (max-width: 720px) {
  .page { width: min(100vw - 18px, 1180px); padding-top: 10px; }
  header.hero { padding: 16px; }
  details > summary { align-items: flex-start; flex-direction: column; }
  .summary-meta { justify-content: flex-start; }
  .toolbar { position: static; }
  table { display: block; overflow-x: auto; }
  td:first-child, th:first-child { width: auto; }
}
</style>
'@

$ScriptBlock = @'
<script>
const cards = Array.from(document.querySelectorAll(".result-card"));
const search = document.querySelector("#search");
const matchCount = document.querySelector("#matchCount");
function updateMatches() {
  if (!search || !matchCount) return;
  const term = search.value.trim().toLowerCase();
  let visible = 0;
  cards.forEach((card) => {
    const text = card.dataset.search.toLowerCase() + " " + card.innerText.toLowerCase();
    const match = !term || text.includes(term);
    card.hidden = !match;
    if (match) visible += 1;
  });
  matchCount.textContent = `${visible} of ${cards.length} shown`;
}
if (search) search.addEventListener("input", updateMatches);
document.querySelector("#expandAll")?.addEventListener("click", () => {
  document.querySelectorAll(".result-card > details").forEach((detail) => detail.open = true);
});
document.querySelector("#collapseAll")?.addEventListener("click", () => {
  document.querySelectorAll(".result-card > details").forEach((detail) => detail.open = false);
});
updateMatches();
</script>
'@

function New-PageHtml {
    param(
        [string]$Title,
        [string]$Body
    )
    return @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(Escape-Html $Title)</title>
$StyleBlock
</head>
<body>
$Body
$ScriptBlock
</body>
</html>
"@
}

function Convert-OneFile {
    param(
        [System.IO.FileInfo]$File,
        [string]$DestinationDir
    )

    $raw = Get-Content -LiteralPath $File.FullName -Raw
    $blocks = @(Get-ResultViewBlocks $raw)
    $htmlName = "$([System.IO.Path]::GetFileNameWithoutExtension($File.Name)).html"
    $outputPath = Join-Path $DestinationDir $htmlName
    $cards = [System.Text.StringBuilder]::new()
    $toolCounts = @{}
    $messageCounts = @{}
    $parseErrors = @()
    $firstStart = ""
    $lastEnd = ""
    $resultCount = 0

    for ($i = 0; $i -lt $blocks.Count; $i++) {
        $block = $blocks[$i].Value
        try {
            $node = Convert-ResultViewBlockToNode $block
            $resultCount += 1
            $tool = Get-AttributeValue $node "Tool"
            Add-Count $toolCounts $tool
            $start = Get-NodeText $node "StartTime"
            if ([string]::IsNullOrWhiteSpace($firstStart)) { $firstStart = $start }
            $ends = @(Get-Nodes $node "EndTime")
            $end = (($ends | ForEach-Object { ([string]$_.InnerText).Trim() } | Where-Object { $_ } | Select-Object -Last 1) -join "")
            if (-not [string]::IsNullOrWhiteSpace($end)) { $lastEnd = $end }
            foreach ($message in @(Get-Nodes $node "Messages/Message")) {
                Add-Count $messageCounts (Get-AttributeValue $message "Type")
            }
            [void]$cards.AppendLine((Render-ResultCard $node $block ($i + 1) ($i -lt 3)))
        } catch {
            $parseErrors += "ResultView $($i + 1): $($_.Exception.Message)"
            [void]$cards.AppendLine("<article class='result-card'><details open><summary><span class='summary-main'><span class='index'>$($i + 1)</span><span><strong>Parse error</strong><small>Could not parse this ResultView block.</small></span></span></summary><div class='card-body'><section class='section compact'><h3>Error</h3><pre>$(Escape-Html $_.Exception.Message)</pre></section><details class='raw' open><summary>Raw ResultView XML</summary><pre>$(Escape-Html $block)</pre></details></div></details></article>")
        }
    }

    $rootClosed = [bool]($raw -match "</ResultViews>\s*$")
    $warning = ""
    if (-not $rootClosed) {
        $warning = "<p class='tools-list'>Note: this source file is missing the final <code>&lt;/ResultViews&gt;</code> close tag. The page was generated from complete <code>ResultView</code> blocks.</p>"
    }
    if ($parseErrors.Count -gt 0) {
        $warning += "<p class='tools-list'>Parse issues: $(Escape-Html ($parseErrors -join ' | '))</p>"
    }

    $toolSummary = Get-CountText $toolCounts
    $messageSummary = Get-CountText $messageCounts
    $sourceLink = "../$($File.Name)"
    $footer = New-ReportFooter -OutputDir $OutputDir

    $body = @"
<main class="page">
  <header class="hero">
    <h1>$(Escape-Html $File.Name)</h1>
    <p>Generated from <a href="$(Escape-Html $sourceLink)">source XML</a> created by ArcGIS Pro geoprocessing history logging. Use search to find tools, parameters, paths, messages, and command line text.</p>
    $warning
    <div class="stats">
      <div class="stat"><span>Result Views</span><strong>$resultCount</strong></div>
      <div class="stat"><span>File Size</span><strong>$([Math]::Round($File.Length / 1KB, 1)) KB</strong></div>
      <div class="stat"><span>First Start</span><strong>$(Escape-Html $firstStart)</strong></div>
      <div class="stat"><span>Last End</span><strong>$(Escape-Html $lastEnd)</strong></div>
      <div class="stat"><span>Message Types</span><strong>$(Escape-Html $messageSummary)</strong></div>
    </div>
    <p class="tools-list"><strong>Tools:</strong> $(Escape-Html $toolSummary)</p>
  </header>
  <nav class="toolbar">
    <a href="index.html">Back to index</a>
    <input id="search" type="search" placeholder="Search this history file">
    <button id="expandAll" type="button">Expand all</button>
    <button id="collapseAll" class="secondary" type="button">Collapse all</button>
    <span id="matchCount" class="match-count"></span>
  </nav>
  $($cards.ToString())
  $footer
</main>
"@

    New-PageHtml -Title $File.Name -Body $body | Set-Content -LiteralPath $outputPath -Encoding UTF8

    return [pscustomobject]@{
        SourceFile = $File.Name
        HtmlFile = $htmlName
        ResultViews = $resultCount
        FileSizeKB = [Math]::Round($File.Length / 1KB, 1)
        FirstStart = $firstStart
        LastEnd = $lastEnd
        RootClosed = $rootClosed
        Tools = $toolSummary
        Messages = $messageSummary
        ParseErrors = $parseErrors.Count
        OutputPath = $outputPath
    }
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Source directory not found: $SourceDir"
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$xmlFiles = @(Get-ChildItem -LiteralPath $SourceDir -Filter *.xml -File | Sort-Object Name)
if ($xmlFiles.Count -eq 0) {
    throw "No .xml files found in $SourceDir"
}

$results = @()
foreach ($file in $xmlFiles) {
    $results += Convert-OneFile -File $file -DestinationDir $OutputDir
}

$indexRows = [System.Text.StringBuilder]::new()
foreach ($result in $results) {
    $status = if ($result.RootClosed) { "Closed root" } else { "Recovered missing root close" }
    if ($result.ParseErrors -gt 0) { $status += "; $($result.ParseErrors) parse issue(s)" }
    [void]$indexRows.AppendLine("<tr><td><a href='$(Escape-Html $result.HtmlFile)'>$(Escape-Html $result.SourceFile)</a></td><td>$($result.ResultViews)</td><td>$($result.FileSizeKB) KB</td><td>$(Escape-Html $result.FirstStart)</td><td>$(Escape-Html $result.LastEnd)</td><td>$(Escape-Html $result.Messages)</td><td>$(Escape-Html $status)</td></tr>")
}

$allToolCounts = @{}
$totalViews = 0
foreach ($result in $results) {
    $totalViews += $result.ResultViews
    foreach ($part in ($result.Tools -split ", ")) {
        if ($part -match "^(.*):\s+(\d+)$") {
            $name = $Matches[1]
            $count = [int]$Matches[2]
            if ($allToolCounts.ContainsKey($name)) {
                $allToolCounts[$name] += $count
            } else {
                $allToolCounts[$name] = $count
            }
        }
    }
}
$topTools = (($allToolCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 12 | ForEach-Object {
    "$($_.Name): $($_.Value)"
}) -join ", ")
$indexFooter = New-ReportFooter -OutputDir $OutputDir

$indexBody = @"
<main class="page">
  <header class="hero">
    <h1>$(Escape-Html $AppName)</h1>
    <p>This demo visualizes XML log files created by ArcGIS Pro geoprocessing history. ArcGIS Pro can write these logs to <code>$(Escape-Html $ArcGisHistorySamplePath)</code>; see <a href="$(Escape-Html $ArcGisHistoryHelpUrl)">Esri's geoprocessing history documentation</a>.</p>
    <div class="stats">
      <div class="stat"><span>XML Files</span><strong>$($results.Count)</strong></div>
      <div class="stat"><span>Total Result Views</span><strong>$totalViews</strong></div>
      <div class="stat"><span>Output Folder</span><strong>.\html</strong></div>
    </div>
    <p class="tools-list"><strong>Most common tools:</strong> $(Escape-Html $topTools)</p>
  </header>
  <section class="index-panel">
    <table class="index-table">
      <thead><tr><th>HTML Report</th><th>Views</th><th>Size</th><th>First Start</th><th>Last End</th><th>Messages</th><th>Status</th></tr></thead>
      <tbody>
      $($indexRows.ToString())
      </tbody>
    </table>
  </section>
  $indexFooter
</main>
"@

$indexPath = Join-Path $OutputDir "index.html"
New-PageHtml -Title $AppName -Body $indexBody | Set-Content -LiteralPath $indexPath -Encoding UTF8

$results | Select-Object SourceFile, HtmlFile, ResultViews, FileSizeKB, RootClosed, ParseErrors, OutputPath | Format-Table -AutoSize
Write-Host ""
Write-Host "Index: $indexPath"


