$env:ORACLE_HOME="e:\oracle\product\11.2.0\client_1"
$env:TNS_ADMIN="${env:ORACLE_HOME}\network\admin"
$env:PATH+=";%{env:ORACLE_HOME}\bin"
$env:PATH="e:\psoft\status\ruby21\bin;"+$env:PATH

cd e:\psoft\status\ps-availability

ruby .\psavailability.rb 