set ORACLE_HOME=e:\oracle\product\11.2.0\client_1
set TNS_ADMIN=%ORACLE_HOME%\network\admin
set PATH=%ORACLE_HOME%\bin;%PATH%
set PATH=e:\psoft\status\ruby21\bin;%PATH%

e:

cd \

cd psoft\status

ruby ps92availability.rb 