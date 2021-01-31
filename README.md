# 🌆🅲🅸🆃🆈🆇🅴🅽☯️ 8 & 16 bit hijinx and programming!

# Retro Dev Tool Box

Toolchains to create software for retro consoles and vintage computers via scripted support with the goal to accellerate retro software development.

The simplistic 2 step nature of the system will compile the source, take the compiled binary and place it into the appropriate disk image for that system. It will then open the disk image in the appropriate emulator.

* 1 Edit the source
* 2 Run the build script

#### But, this is already done. There's so many things out there that do this.
While it is true that tools exist already that accomplish certain tasks, not all of these tools operate the same way. Some do not support creation of native disk images, much less have built in support for storing or extracting files from said disk images. The goal of this project is for the scripting do all that heavy lifting for you and to behave in a uniform fashion. KickAssembler does create image files, and it even executes the emulator and loads in the file. This is the behavior we're going for but not just for Commodore machines. For instance, KickAssembler does not have built in support for creating Atari or Apple IIe disk images. There are command line tools included that solve this problem and to unify everything, we have created the system in such a manner that all you have to do is:
* Copy BASE project to new project
* Go to BASE project
* execute build script

##### Current support
* Linux (debian flavors)
* Windows 10
##### Planned support
* Raspberry Pi
* MacOS

These tools and scripts were developed using the  github.com/cityxen/APMs repo.

We've tried to include as many things as possible that you could need while also leaving out larger things to try and minimize the overhead.

## Notes:
So far the following compile and run in respective emulator by running one script.

|Character|Machine|Toolchain|Disk Manager|Emulator|
|---|---|---|---|---|
|Clicky|Commodore 64|KickAssembler|KickAssembler|VICE (x64)|
|Victoria|Commodore VIC-20|KickAssembler|KickAssembler|VICE (xVIC)|
|Fido|Commodore PET|KickAssembler|KickAssembler|VICE (xPET)|
|Pokey |      Atari 800 XL |       MADS   |     atr     |        Altirra64|
|Apollol  |   Apple IIe  |         VASM6502 |       a2tools* |       AppleWin|
| Amy    |     Amiga   |            AMOS Pro2**  |   N/A  |           WinUAE|
|---|---|---|---|---|

````

    *  - Can't get a2tools to work under windows, maybe someone can help with this
    ** - Amy will be getting overhauled to 68k assembly at some point

````

## Instructions:

Install the Retro Dev Tools repository

```

git clone https://github.com/cityxen/retro-dev-tools

```

### Windows

Add Retro Dev Tools bin-win folder to your environment path. Example: https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/

Alternatively, you can type it on the command line

```

set PATH=%PATH%;X:\path\to\retro-dev-tools\bin-win\

```

Restart Computer

### Linux

Add Retro Dev Tools bin-linux folder to your environment path.

```

echo "export PATH=$PATH:/path/to/retro-dev-lib/bin-linux" >> ~/.bashrc

```

Restart Computer

### Dependecy check

You will need to ensure you have the following software installed.
In Linux, the script install.sh will handle these for you, provided you are using a debian based linux with the apt package manager.

|Dependecy|System|How To Get|
|---|---|---|
|vice|linux|sudo apt install vice|
|java|windows|download and install java|
|java|linux|sudo apt install openjdk-11-jre-headless|
|python|windows|download and install python|
|python|linux|windows:sudo apt install python|
|wine|linux|sudo apt install wine|
|cc65|linux|sudo apt install cc65 # Note: This is not a dependency, just including it here for your health|

## After Installation

Now you have the power of the Retro Dev Tools at your disposal.

#### Step 1
Copy the BASE project folder for the target machine to a new folder of your choice. We recommend that you create a new folder somewhere called my_projects_folder. Note: This will be scripted in the future to allow for something like the following

```

cd my_projects_folder
rdt -t c64 mynewc64project

```

```

cd my_projects_folder
rdt -t appleiie My_New_AppleIIe_Project

```

and so forth...

#### Step 2
Edit your asm file
    
#### Step 3
Execute build script. If you have everything installed properly, it should compile your program, place it into a disk file, and then run that disk file in the appropriate emulator.

##### Windows

```

cd project_folder
Build.bat

```

##### Linux

```

cd project_folder
./build_linux.sh

```



More to come,
Deadline
