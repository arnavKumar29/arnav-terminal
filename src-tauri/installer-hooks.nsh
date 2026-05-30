; "Open in arnavterminal" shell verbs for folders, folder backgrounds, and drives.
; HKCU matches installer currentUser scope. %V = clicked path.
; NoWorkingDirectory keeps Explorer from overriding %V (System32 on Drive).

!macro NSIS_HOOK_POSTINSTALL
  WriteRegStr HKCU "Software\Classes\Directory\shell\OpenInarnavterminal" "" "Open in arnavterminal"
  WriteRegStr HKCU "Software\Classes\Directory\shell\OpenInarnavterminal" "Icon" '"$INSTDIR\arnavterminal.exe",0'
  WriteRegStr HKCU "Software\Classes\Directory\shell\OpenInarnavterminal" "NoWorkingDirectory" ""
  WriteRegStr HKCU "Software\Classes\Directory\shell\OpenInarnavterminal\command" "" '"$INSTDIR\arnavterminal.exe" "%V"'

  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\OpenInarnavterminal" "" "Open in arnavterminal"
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\OpenInarnavterminal" "Icon" '"$INSTDIR\arnavterminal.exe",0'
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\OpenInarnavterminal" "NoWorkingDirectory" ""
  WriteRegStr HKCU "Software\Classes\Directory\Background\shell\OpenInarnavterminal\command" "" '"$INSTDIR\arnavterminal.exe" "%V"'

  WriteRegStr HKCU "Software\Classes\Drive\shell\OpenInarnavterminal" "" "Open in arnavterminal"
  WriteRegStr HKCU "Software\Classes\Drive\shell\OpenInarnavterminal" "Icon" '"$INSTDIR\arnavterminal.exe",0'
  WriteRegStr HKCU "Software\Classes\Drive\shell\OpenInarnavterminal" "NoWorkingDirectory" ""
  WriteRegStr HKCU "Software\Classes\Drive\shell\OpenInarnavterminal\command" "" '"$INSTDIR\arnavterminal.exe" "%V"'
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  DeleteRegKey HKCU "Software\Classes\Directory\shell\OpenInarnavterminal"
  DeleteRegKey HKCU "Software\Classes\Directory\Background\shell\OpenInarnavterminal"
  DeleteRegKey HKCU "Software\Classes\Drive\shell\OpenInarnavterminal"
!macroend
