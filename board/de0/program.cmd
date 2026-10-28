set "QUARTUS_BIN=C:\Tools\altera\13.1\quartus\bin"
set "PROGRAMMER_CABLE=1"
set "SOF_FILE=top.sof"

cd prj

"%QUARTUS_BIN%\quartus_pgm.exe" ^
    -c "%PROGRAMMER_CABLE%" ^
    -m JTAG ^
    -o "p;%SOF_FILE%"
    
cd ..