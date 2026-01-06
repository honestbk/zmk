# Building ZMK Firmware for Corne Keyboard

## 🔹 Command

```bash
west build -s app/ -p -d build/corne_left -b nice_nano_v2 -- -DSHIELD=corne_left -DZMK_CONFIG=/workspaces/zmk/zmk-config/config
```

---

### 🔹 Parts Explained

#### `west build`

- `west` is Zephyr’s meta-tool to manage projects, building, flashing, etc.
- `build` tells `west` to run CMake/Ninja to configure and build the firmware.

---

#### `-s app/`

- **Source directory** for the application (`app/`).
- This is where `CMakeLists.txt` of your ZMK application is located.
- Often `app/` is the entry point in ZMK setups.

---

#### `-p`

- Stands for **pristine build**.
- Cleans the build directory before building (like a fresh build).
- Useful when switching boards, shields, or configs.

---

#### `-d build/corne_left`

- **Build directory**.
- Here it will place all build files in `build/corne_left/`.
- Keeps builds for different keyboards/shields separate (e.g., `corne_left`, `corne_right`).

---

#### `-b nice_nano_v2`

- **Board name** (Zephyr board definition).
- Here: `nice_nano_v2`, the MCU used in your keyboard.

---

#### `--`

- Separator: everything after `--` goes directly to CMake (extra `-D` definitions).

---

#### `-DSHIELD=corne_left`

- A **CMake variable**.
- Tells Zephyr/ZMK which **shield** to use (`corne_left`).
- A _shield_ is usually the keyboard layout/PCB definition (matrix, keys, etc.).

---

#### `-DZMK_CONFIG=/workspaces/zmk/zmk-config/config`

- Another **CMake variable**.
- Points to your **custom ZMK config directory**.
- In this case, `/workspaces/zmk/zmk-config/config` contains keymap files (`keymap.keymap`, `conf`, overlays, etc.).
