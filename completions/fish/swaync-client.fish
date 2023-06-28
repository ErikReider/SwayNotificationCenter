complete -f -c swaync-client
complete -c swaync-client -s h -l help --description "Show help options"
complete -c swaync-client -s v -l version --description "Prints version"
complete -c swaync-client -s R -l reload-config --description "Reload the config file" -r
complete -c swaync-client -s rs -l reload-css --description "Reload the css file. Location change requires restart" -r
complete -c swaync-client -s t -l toggle-panel --description "Toggle the notification panel" -r
complete -c swaync-client -s op -l open-panel --description "Opens the notification panel" -r
complete -c swaync-client -s cp -l close-panel --description "Closes the notification panel" -r
complete -c swaync-client -s d -l toggle-dnd --description "Toggle and print the current dnd state" -r
complete -c swaync-client -s D -l get-dnd --description "Print the current dnd state" -r
complete -c swaync-client -s dn -l dnd-on --description "Turn dnd on and print the new dnd state" -r
complete -c swaync-client -s df -l dnd-off --description "Turn dnd off and print the new dnd state" -r
complete -c swaync-client -s I -l get-inhibited --description "Print if currently inhibited or not" -r
complete -c swaync-client -s In -l get-num-inhibitors --description "Print number of inhibitors" -r
complete -c swaync-client -s Ia -l inhibitor-add --description "Add an inhibitor" -r
complete -c swaync-client -s Ir -l inhibitor-remove --description "Remove an inhibitor" -r
complete -c swaync-client -s Ic -l inhibitors-clear --description "Clears all inhibitors" -r
complete -c swaync-client -s c -l count --description "Print the current notification count" -r
complete -c swaync-client      -l hide-latest --description "Hides latest notification. Still shown in Control Center" -r
complete -c swaync-client      -l close-latest --description "Closes latest notification" -r
complete -c swaync-client -s C -l close-all --description "Closes all notifications" -r
complete -c swaync-client -s sw -l skip-wait --description "Doesn't wait when swaync hasn't been started" -r
complete -c swaync-client -s s -l subscribe --description "Subscribe to notification add and close events" -r
complete -c swaync-client -s swb -l subscribe-waybar --description "Subscribe to notification add and close events with waybar support. Read README for example" -r
