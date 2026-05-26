#!/usr/bin/python3
# -*- coding: utf-8 -*-
import os
import os.path
from os import path
import argparse
import platform
from datetime import datetime 
from shutil import copyfile

print()
print("\x1b[1;33;40m"+"░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█")
print()
print("\x1b[0;32;40m"+"     Retro Dev Tools KickAssembler Config File Generator")
print("\x1b[0;32;40m"+"      by Deadline / CityXen 2021 https://linktr.ee/cityxen ")
print("\x1b[1;30;40m"+"                                                          ")
print("\x1b[3;33;40m"+"                █▀▀ █ ▀█▀ █▄█ ▀▄▀ █▀▀ █▄░█  ")
print("\x1b[3;33;40m"+"                █▄▄ █ ░█░ ░█░ █░█ ██▄ █░▀█  ")
print("\x1b[3;30;40m"+"                                                          ")
print("\x1b[0;35;40m"+"              8 & 16 bit hijinx and programming!          ")
print("\x1b[1;30;40m"+"                                                          ")
print("\x1b[1;33;40m"+"░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█")


######################################################################################
# Set up some default variables

# current date and time
now = datetime.now()
timestamp = datetime.timestamp(now)

OS_DETECTED         = platform.platform()
if "Windows" in OS_DETECTED:
    OS_DETECTED = "WINDOWS"
if "Linux" in OS_DETECTED:
    OS_DETECTED = "LINUX"

ORIG_PATH           = os.getcwd()
NEW_KICKASS_CONFIG  = "KickAss_AutoGen.cfg"
SCRIPT_PATH         = os.path.dirname(os.path.realpath(__file__))
RETRO_DEV_PATH      = SCRIPT_PATH.replace("\\bin-win","").replace("\\bin-linux","").replace("\\bin-pi","")
KICKASS_PATH        = RETRO_DEV_PATH+os.path.sep+"dev-tools"+os.path.sep+"commodore64"+os.path.sep+"KickAssembler"
KICKASS_CONFIG      = KICKASS_PATH+os.path.sep+"KickAss.cfg"
EMULATOR_PATH       = RETRO_DEV_PATH+os.path.sep
C64_INCLUDE_PATH    = RETRO_DEV_PATH+os.path.sep+"include"+os.path.sep+"commodore"

VICE_PATH           = "/usr/bin"
if OS_DETECTED=="WINDOWS":
    VICE_PATH=RETRO_DEV_PATH+os.path.sep+"emulators"+os.path.sep+"vice"+os.path.sep+"bin"
    
target              = "Default"
emulator            = "Default"
symbolfile          = "Off"
showmem             = "Off"
libdir              = "Off"
odir                = "Off"

######################################################################################
# Parse arguments
ap=argparse.ArgumentParser()
ap.add_argument("-t", "--target",required=False,help="Target Machine: (C64,C128,PET,VIC20,DTV)")
ap.add_argument("-e", "--emulator",required=False,help="Emulator: (Set emulator path and bin; ie: E:\\vice\\x64.exe")
ap.add_argument("-s", "--symbolfile",required=False,help="Specify symbolfile")
ap.add_argument("-m", "--showmem",required=False,help="Show memory output")
ap.add_argument("-l", "--libdir", required=False,help="Specify library dir")
ap.add_argument("-o", "--odir", required=False,help="Specify output dir")

args=vars(ap.parse_args())
if(args["target"]):
    target=args["target"]
if(args["emulator"]):
    emulator=args["emulator"]
if(args["symbolfile"]):
    symbolfile = args["symbolfile"]
if(args["showmem"]):
    showmem = args["showmem"]
if(args["libdir"]):
    libdir = args["libdir"]
if(args["odir"]):
    odir = args["odir"]

if target=="Default":
    target="C64"

if target=="C64":
    if emulator=="Default":
        if OS_DETECTED=="WINDOWS":
            emulator=VICE_PATH+os.path.sep+"x64sc.exe"
        if OS_DETECTED=="LINUX":
            emulator=VICE_PATH+os.path.set+"x64"

if target=="C128":
    if emulator=="Default":
        if OS_DETECTED=="WINDOWS":
            emulator=VICE_PATH+os.path.sep+"x128.exe"
        if OS_DETECTED=="LINUX":
            emulator=VICE_PATH+os.path.set+"x128"

if target=="VIC20":
    if emulator=="Default":
        if OS_DETECTED=="WINDOWS":
            emulator=VICE_PATH+os.path.sep+"xvic.exe"
        if OS_DETECTED=="LINUX":
            emulator=VICE_PATH+os.path.set+"xvic"

if target=="PET":
    if emulator=="Default":
        if OS_DETECTED=="WINDOWS":
            emulator=VICE_PATH+os.path.sep+"xpet.exe"
        if OS_DETECTED=="LINUX":
            emulator=VICE_PATH+os.path.set+"xpet"

if target=="DTV":
    if emulator=="Default":
        if OS_DETECTED=="WINDOWS":
            emulator=VICE_PATH+os.path.sep+"x64dtv.exe"
        if OS_DETECTED=="LINUX":
            emulator=VICE_PATH+os.path.set+"x64dtv"

if libdir=="RETRO_DEV_LIB":
    libdir=C64_INCLUDE_PATH

print("\x1b[0;37;40m")
print("Current Path      :"+ORIG_PATH)
print("Retro Dev Tools   :"+RETRO_DEV_PATH)
print("Commodore Include :"+C64_INCLUDE_PATH)
print("Script Path       :"+SCRIPT_PATH)
print("Operating System  :"+OS_DETECTED)
print("Vice Path         :"+VICE_PATH)
print("KickAss Path      :"+KICKASS_PATH)
print("KickAss Flags     :")
print("         target   :"+target)
print("       execute    :"+emulator)
print("    symbolfile    :"+symbolfile)
print("       showmem    :"+showmem)
print("        libdir    :"+libdir)
print("          odir    :"+odir)
print("\x1b[0;37;40m")
print("\x1b[1;33;40m"+"░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█░█")
print("\x1b[0;37;40m")

#############################################################################################################
## Backup current KickAss.cfg
if(path.exists(KICKASS_CONFIG)):
    copyfile(KICKASS_CONFIG,KICKASS_CONFIG+".RTD_BACKUP")

#############################################################################################################
## Write new KickAss.cfg

kout = open(NEW_KICKASS_CONFIG,"w")
kout.write("#########################################################################\n")
kout.write("## KickAss File Auto Generated by Retro Dev Tools by Deadline / CityXen #\n")
kout.write("## Download Retro Dev Tools from our github: https://github.com/cityxen #\n")
kout.write("## https://linktr.ee/cityxen                                            #\n")
kout.write("#########################################################################\n")
if showmem!="Off":
    kout.write("-showmem\n")
if symbolfile!="Off":
    kout.write("-symbolfile\n")
if libdir!="Off":
    kout.write("-libdir \""+libdir+"\" \n")
if odir!="Off":
    kout.write("-odir \""+odir+"\" \n")
if emulator!="Off":
    kout.write("-execute \""+emulator+"\" \n")
kout.close()

#############################################################################################################
## Write over KickAss.cfg in KickAss folder
copyfile(NEW_KICKASS_CONFIG,KICKASS_CONFIG)
