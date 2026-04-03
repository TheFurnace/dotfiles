function bwrap-clean --description "Remove empty files left behind by failed bwrap sandbox operations"
    set -l search_path (pwd)
    if test (count $argv) -gt 0
        set search_path $argv[1]
    end
    set -l targets (find $search_path -empty -type f ! -name "*.py" ! -name "*.lock" 2>/dev/null)

    if test (count $targets) -eq 0
        echo "Nothing to clean."
        return 0
    end

    echo "Empty files to remove:"
    for f in $targets
        echo "  $f"
    end

    read --prompt-str "Remove these files? [y/N] " confirm
    if test "$confirm" = y -o "$confirm" = Y
        for f in $targets
            rm -f -- $f
        end
        echo "Removed "(count $targets)" file(s)."
    else
        echo "Aborted."
    end
end
