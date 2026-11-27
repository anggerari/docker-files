# Records docs/demo.gif. Re-record from the repo root with:  vhs docs/demo.tape
# (needs https://github.com/charmbracelet/vhs; uses whatever is in your .env)

Output docs/demo.gif

Set Shell "bash"
Set FontSize 15
Set Width 1180
Set Height 760
Set Padding 20
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set TypingSpeed 60ms
Set Framerate 24

Hide
Type "export PS1='\[\e[1;36m\]docker-files\[\e[0m\] $ ' BASH_SILENCE_DEPRECATION_WARNING=1 && clear"
Enter
Sleep 500ms
Show

# 1. pick services
Type "make init"
Sleep 500ms
Enter
Wait+Screen@20s /Enter = save/
Sleep 2.5s
Type "8 9"
Sleep 700ms
Enter
Wait+Screen@20s /9 +\[x\] +rabbitmq/
Sleep 2.5s
Enter
Sleep 3.5s

# 2. start them (the wait for health checks is skipped in the recording)
Type "clear && make up"
Sleep 400ms
Enter
Sleep 5s
Hide
Wait+Screen@240s /Connection strings: make urls/
Show
Sleep 3.5s

# 3. connection strings for your app
Type "clear && make urls"
Sleep 400ms
Enter
Sleep 5s

# 4. prove it works
Type "clear && make check"
Sleep 400ms
Enter
Wait+Screen@120s /All checks passed|check\(s\) failed/
Sleep 4s
