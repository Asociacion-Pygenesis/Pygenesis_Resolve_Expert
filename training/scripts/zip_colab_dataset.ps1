# Pack resolve_train.json and resolve_eval.json for Colab upload.
$trainingRoot = Split-Path $PSScriptRoot -Parent
$train = Join-Path $trainingRoot "data\train\resolve_train.json"
$eval = Join-Path $trainingRoot "data\eval\resolve_eval.json"
$out = Join-Path $trainingRoot "data\colab_dataset.zip"

foreach ($f in @($train, $eval)) {
    if (-not (Test-Path $f)) {
        Write-Error "Missing $f - run: python scripts/process_dataset.py"
        exit 1
    }
}

Compress-Archive -Path $train, $eval -DestinationPath $out -Force
Write-Host "Created: $out"
