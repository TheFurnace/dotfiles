function ls --wraps=ls --description 'List directory contents'
    command ls --color=auto --group-directories-first $argv
end
