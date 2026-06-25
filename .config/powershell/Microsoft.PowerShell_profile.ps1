$ompConfig = Join-Path $HOME ".config/oh-my-posh/themes/lambda.omp.json"

if (Test-Path $ompConfig) {
    oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
}

zoxide init powershell | Out-String | Invoke-Expression

if (Get-Module -ListAvailable git-completion) {
    Import-Module git-completion
}

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

# Wrap the active prompt to also emit OSC 9;9 for Windows Terminal CWD tracking.
# This is placed last so it captures whatever prompt function is active after all
# shell integrations (oh-my-posh, etc.) have been initialised.
$__prevPrompt = $function:prompt
function prompt {
    [Console]::Write("`e]9;9;$($PWD.Path)`a")
    & $__prevPrompt
}
