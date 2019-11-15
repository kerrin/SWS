rm -f Test/Logs/debug0.log ;rm -f Test/Logs/debug5.log ;rm -f Test/Logs/debug9.log ; cp -p Test/Logs/EmptyLogs/*.log Test/Logs/ ; perl Test/TestLog.pm
echo D0; cat Test/Logs/debug0.log ; echo D5 ; cat Test/Logs/debug5.log ; echo D9 ; cat Test/Logs/debug9.log ; echo EV ; cat Test/Logs/event.log ; echo ER ; cat Test/Logs/error.log
