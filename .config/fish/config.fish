fish_add_path ~/.local/bin

if status is-interactive
    oh-my-posh init fish --config ~/.config/oh-my-posh/themes/lambda.omp.json | source
end
