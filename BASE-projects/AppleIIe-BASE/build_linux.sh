echo "##############################################################################"
echo "Building PROGRAM"
vasm6502 main.asm -c02 -chklabels -nocase -Fvasm=1 -DBuildAP2=1 -Fbin -o "PROGRAM" # -L listing.txt
if [ $? -eq 0 ]; then
    echo "##############################################################################"
    echo "Build OK, creating PROGRAM.DSK"
    rm PROGRAM.DSK
    cp BLANK.DSK PROGRAM.DSK
    a2in b.0c00 PROGRAM.DSK PROGRAM PROGRAM
    a2ls PROGRAM.DSK
    echo "##############################################################################"
    echo "Running Apple ][e Emulator with PROGRAM.DSK"
    applewin PROGRAM.DSK
else
    echo "Error in asm file"
fi

