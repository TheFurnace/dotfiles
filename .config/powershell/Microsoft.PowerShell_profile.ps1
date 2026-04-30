$ompConfig = Join-Path $HOME ".config/oh-my-posh/themes/lambda.omp.json"

if (Test-Path $ompConfig) {
    oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
}

zoxide init powershell | Invoke-Expression

Import-Module git-completion

if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete
}

Set-Alias g git

function ll {
    Get-ChildItem @args
}

function la {
    Get-ChildItem -Force @args
}

function which {
    param([Parameter(Mandatory)] [string] $Name)
    Get-Command $Name -All |
        Select-Object CommandType, Name, Source
}
