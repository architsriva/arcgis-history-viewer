# ArcGIS Geoprocessing History Report Viewer

A small PowerShell-based converter that turns ArcGIS Pro geoprocessing history XML logs into readable, searchable HTML reports.

ArcGIS Pro can write geoprocessing operations to XML log files in `%AppData%\Esri\ArcGISPro\ArcToolbox\History`. See Esri's geoprocessing history documentation:

https://doc.esri.com/en/arcgis-pro/latest/help/analysis/geoprocessing/basics/geoprocessing-history.html#537

## Demo

This repository includes one sanitized demo XML file:

`sample-arcgis-history.xml`

The demo report intentionally contains only one tool card:

`Train Deep Learning Model`

The sample paths in the XML and HTML are demo paths, not real project paths.

Open the generated demo:

- [Demo Index](https://architsriva.github.io/arcgis-history-viewer/html/index.html)
- [Deep Learning Model report](https://architsriva.github.io/arcgis-history-viewer/html/sample-arcgis-history.html)

## Generate Reports

Copy ArcGIS Pro history XML files into this folder, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Convert-ArcGISHistoryToHtml.ps1" -SourceDir "." -OutputDir ".\html"
```

The converter does not modify the source XML.

## Verify

Regenerate the demo HTML and run the checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Convert-ArcGISHistoryToHtml.ps1" -SourceDir "." -OutputDir ".\html"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Test-GeneratedHtml.ps1"
```

## Notes For Publishing

Real ArcGIS Pro history XML can include local paths, machine names, project names, and other environment details. Keep real XML files out of public GitHub repositories unless they have been reviewed or sanitized.

This project is released under the MIT License. See [LICENSE](LICENSE).



