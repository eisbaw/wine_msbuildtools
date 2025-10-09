REM Change the current directory to the path of this .bat file
cd /d "%~dp0"

echo "Downloading + Installing Visual Studio BuildTools"
REM See options at https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019
vs_buildtools.exe ^
  --passive ^
  --norestart ^
  --wait ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.19041
REM  --includeRecommended ^
REM  --includeOptional
