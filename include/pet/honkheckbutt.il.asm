//////////////////////////////////////////////////////////////////////////////////////
// CityXen - https://linktr.ee/cityxen
//////////////////////////////////////////////////////////////////////////////////////
// Deadline's Commodore PET Assembly Language Library:
// HonkHeckButt — Button/Input Mapping
// Target: Commodore PET 4032 (BASIC 4.0, MOS 6502)
//
// The PET has no joystick ports.  HonkHeckButt maps the five game-controller
// button colors to keyboard keys so game code using BUTTON_* constants works
// without modification.
//
// Default keyboard layout:
//   RED    = Z     GREEN  = X     YELLOW = C
//   BLUE   = V     WHITE  = SPACE
//
// Change these .const values to remap.
//////////////////////////////////////////////////////////////////////////////////////

#importonce

// Button key codes (keyboard mapping for PET)
.const BUTTON_RED    = KEY_Z
.const BUTTON_GREEN  = KEY_X
.const BUTTON_YELLOW = KEY_C
.const BUTTON_BLUE   = KEY_V
.const BUTTON_WHITE  = KEY_SPACE

// j1_* alias constants — point to input.il.asm's state bytes
// These let code reference J1_B_RED etc. the same as C64 code.
.const J1_B_RED    = j1_left
.const J1_B_GREEN  = j1_up
.const J1_B_YELLOW = j1_down
.const J1_B_BLUE   = j1_right
.const J1_B_WHITE  = j1_button

// Action masks (reused naming from C64 HHB; no user-port lights on PET)
.const MASK_POW       = BUTTON_WHITE
.const MASK_MISS      = BUTTON_RED
.const MASK_GAME_OVER = BUTTON_WHITE
