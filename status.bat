set ORACLE_HOME=e:\oracle\product\11.2.0\client_1
set TNS_ADMIN=%ORACLE_HOME%\network\admin
set PATH=%ORACLE_HOME%\bin;%PATH%
set PATH=e:\ruby22-x64\bin;%PATH%

e:

cd \

cd psoft\status

ruby ps92availability.rb 

xcopy status.html e:\psoft\HR92DMO\webserv\hr92dmo\applications\peoplesoft\PORTAL.war\ /y