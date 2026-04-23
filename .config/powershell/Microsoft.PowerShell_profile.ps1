$ompConfig = Join-Path $HOME ".config/oh-my-posh/themes/lambda.omp.json"

if (Test-Path $ompConfig) {
    oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
}

Import-Module git-completion
