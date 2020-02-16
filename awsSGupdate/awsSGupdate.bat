SETLOCAL
@echo off
SET mypath=%~dp0
set PATH=%PATH%;"C:\Program Files\Amazon\AWSCLI\";"C:\Program Files (x86)\PuTTY\";"C:\MyApps\gnuwin32\bin"
set GROUPID=  PUT YOUR DYNAMIC SECURITY GROUP ID HERE
rem aws ec2 create-security-group --group-name dynamic_ips --vpc-id vpc-81a519e5 --description "Dynamic Ip Address"
set /p MYIP=<%mypath%\MYIP_NODELETE.txt
aws ec2 revoke-security-group-ingress --group-id %GROUPID% --protocol tcp --port 0-65535 --cidr %MYIP%/24
wget -qO %mypath%\MYIP_NODELETE.txt http://ipinfo.io/ip
set /p MYIP=<%mypath%\MYIP_NODELETE.txt
aws ec2 authorize-security-group-ingress --group-id %GROUPID% --protocol tcp --port 0-65535 --cidr %MYIP%/24
rem cat %mypath%\MYIP_NODELETE.txt
pause
