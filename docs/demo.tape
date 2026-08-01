Require zig

Output docs/assets/chroma-logger-demo.gif
Output docs/assets/chroma-logger-demo.mp4

Set Shell "zsh"
Set FontFamily "JetBrainsMono Nerd Font Mono, Menlo, monospace"
Set FontSize 16
Set LetterSpacing 0
Set LineHeight 1.2
Set Width 1180
Set Height 650
Set Padding 24
Set Margin 24
Set MarginFill "#11111b"
Set BorderRadius 14
Set WindowBar "Colorful"
Set WindowBarSize 38
Set Theme "Catppuccin Mocha"
Set TypingSpeed 30ms

Hide
Type "export PS1='$ '"
Enter
Type "unset NO_COLOR; export CLICOLOR_FORCE=1"
Enter
Type "clear"
Enter
Show

Type "zig build run"
Enter
Sleep 7s
