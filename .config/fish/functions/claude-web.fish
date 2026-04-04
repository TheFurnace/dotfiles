function claude-web --description "Claude with unrestricted internet (git credentials blocked)"
    set -x GIT_CONFIG_PARAMETERS "'credential.helper='"
    set -x GIT_TERMINAL_PROMPT 0
    claude $argv
end
