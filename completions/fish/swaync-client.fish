complete -f -c swaync-client
complete -c swaync-client -s h -l help --description "Show help options"
complete -c swaync-client -s R -l reload-config --description "Reload the config file" -r
complete -c swaync-client -s rs -l reload-css --description "Reload the css file. Location change requires restart" -r
complete -c swaync-client -s t -l toggle-panel --description "Toggle the notificaion panel" -r
complete -c swaync-client -s op -l open-panel --description "Opens the notificaion panel" -r
complete -c swaync-client -s cp -l close-panel --description "Closes the notificaion panel" -r
complete -c swaync-client -s d -l toggle-dnd --description "Toggle and print the current dnd state" -r
complete -c swaync-client -s D -l get-dnd --description "Print the current dnd state" -r
complete -c swaync-client -s c -l count --description "Print the current notificaion count" -r
complete -c swaync-client -s C -l close-all --description "Closes all notifications" -r
complete -c swaync-client -s sw -l skip-wait --description "Doesn't wait when swaync hasn't been started" -r
complete -c swaync-client -s s -l subscribe --description "Subscribe to notificaion add and close events" -r
complete -c swaync-client -s swb -l subscribe-waybar --description "Subscribe to notificaion add and close events with waybar support. Read README for example" -r
