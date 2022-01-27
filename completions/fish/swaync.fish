complete -f -c swaync
complete -c swaync -s h -l help --description "Show help options"
complete -c swaync -s v -l version --description "Prints version"
complete -c swaync -s s -l style --description "Use a custom Stylesheet file" -r
complete -c swaync -s c -l config --description "Use a custom config file" -r
