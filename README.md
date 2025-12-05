# 🎨 Aseprite Color Reducer

![Aseprite](https://img.shields.io/badge/Aseprite-FFFFFF?style=for-the-badge&logo=Aseprite&logoColor=#7D929E)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

**Iterative Cluster Palette Simplification for Pixel Art**

This Lua script for **Aseprite** implements a palette reduction algorithm that repeatedly identifies and merges the two closest colors in the RGB space (using **Euclidean distance**) until an exact, user-defined color count is reached. It's a powerful tool for *pixel art* requiring strict control over the final color count.

---

## ⚠️ Critical Safety Warning

**SAVE YOUR WORK BEFORE RUNNING THIS SCRIPT!**

> 🚨 **CRASH RISK:** This script performs intensive calculations on your sprite's pixels. 
> **Large sprites (4K+) or images with thousands of colors may cause Aseprite to freeze or crash.**
> 
> ### **BEFORE RUNNING:**
> 1. **Save your work** (`Ctrl+S` / `Cmd+S`)
> 2. **Duplicate your sprite** (File > Save As)
> 3. **Test on a small copy first**

---

## 🚀 Installation and Usage

### 1. Installation

1. Download `color_reducer.lua`
2. In Aseprite: **File → Scripts → Open Scripts Folder**
3. Copy the `.lua` file into the folder
4. **File → Scripts → Rescan Scripts**

### 2. Usage

1. **Open** your sprite or animation in Aseprite
2. **Show/Hide layers** as needed (only visible layers will be processed)
3. **File → Scripts → Color Reducer**
4. **Enter target color count** (e.g., `32`)
5. Click **"Simplify"** and wait for processing

---

## ⚙️ How It Works

### **Algorithm: Hierarchical Color Clustering**
1. **Extract** all colors from visible layers
2. **Calculate** Euclidean distance between all color pairs
3. **Merge** the two closest colors (weighted average)
4. **Repeat** until target color count is reached
5. **Remap** all pixels to the new palette

### **Performance Considerations**
- **Time Complexity:** O(n²) per iteration
- **Best for:** Palettes < 1000 colors
- **Memory usage:** High for large sprites

### **Color Mode Handling**
- **RGB Mode:** Processed directly
- **Indexed Mode:** Automatically converted to RGB
  *Note: Original palette indexes will be lost*

---

## 🎯 Use Cases

### **Cleaning AI-Generated Art**
> AI tools often create color noise with slightly varying hues. This script reduces them to clean, consistent colors.

**Before:** 450 colors with noise  
**After:** 32 clean colors  
**Result:** Ready for pixel art editing

### **Game Asset Optimization**
> Reduce sprite colors to match platform limitations (GameBoy: 4 colors, NES: 64 colors, etc.)

### **Art Style Consistency**
> Force all frames in an animation to use the exact same color palette

---

## ✅ Future Improvements Checklist

The following features are not currently implemented and are considered *future features*:

* [ ] **Undo Guarantee (`Ctrl+Z`)**
    *  Ensure that the use of `app.transaction` reliably groups and allows undoing all changes.
* [ ] **Selection Support (`M` Tool)**
    * Allow the script to act **only** on pixels within the active selection, instead of the entire sprite.
* [ ] **$O(N^2)$ Algorithm Optimization**
    * Improve the efficiency of the nearest pair search loop (the slowest part) to reduce processing time for large palettes.
* [ ] **Dithering Option**
    * Integrate a dithering algorithm (e.g., Floyd-Steinberg) to smooth color transitions after reduction.
* [ ] **Preset palettes**
    * Option to reassign simplified colors to an external fixed palette (e.g., DB32, GameBoy).

---

## 🛠️ Development

### **Requirements**
- Aseprite v1.2.40 or higher

### Testing

Test with various image types:

- Small sprites (64x64)
- Large images (1024x1024)
- Animations with multiple frames
- Different color depths

## Contributing
- Fork the repository
- Create a feature branch
- Test your changes 
- Submit a pull request

## 📄 License

This script is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## ❤️ Support

If this script helped you, consider:
- ⭐ Starring this repository
- 🐛 Reporting issues
- 💡 Suggesting features

**Created by:** [@deveduar](https://github.com/deveduar)

# 🎨 Pixel Lab Animation Importer for Aseprite

This Lua script for **Aseprite** automates the import of animation sequences and their metadata directly from a **Pixel Lab** JSON export file.

The script creates a new `Sprite` in Aseprite, imports the individual PNG frames, and generates the corresponding **Animation Tags** for immediate use in your project.

## 💡 Designed for Pixel Lab Exports

This tool is specifically developed to process the `metadata.json` structure generated when exporting character assets from the **Pixel Lab** tool. It ensures stable and correct parsing of the animation structure, paths, and frame data.

## 🌟 Features

- **Pixel Lab Compatibility:** Built to read the standard JSON structure output by Pixel Lab, including `rotations` and named `animations`.
    
- **Bulk Import:** Loads multiple animations and static poses (rotations) in a single run.
    
- **Animation Tags (`Tags`):** Automatically creates Aseprite Tags based on the animation name and direction (e.g., `picking-up_east`, `Idle_Static_south`).
    
- **Robust JSON Decoder:** Uses a Lua JSON decoder to handle complex metadata files within the constrained Aseprite environment, avoiding the common "index nil value" errors.
    
---

## 🚀 How to Use

### 1. File Preparation

Ensure your project structure matches the relative paths in your `metadata.json` file. The script expects the JSON file to be in the parent directory of the image folders (`rotations`, `animations`).

```
/your_character_project
|-- metadata.json
|-- /rotations
|   |-- south.png
|   |-- north.png
|-- /animations
    |-- /picking-up
        |-- /east
            |-- frame_000.png
            |-- frame_001.png
            |-- ...
```

### 2. Script Installation

1. Save the Lua script code as **`pixel-lab-impoter-json.lua`**.
2. Place the file in Aseprite's scripts folder.
3. Restart Aseprite.
    

### 3. Execution

1. In Aseprite, go to `File` > `Scripts` and select **`pixel-lab-impoter-json.lua`**.
2. A dialog will appear. Click the file selection button and choose your **`metadata.json`** file.
3. Click **`Import`**.

The script will create a new **Sprite** with the correct dimensions, all frames imported, and all animations set up as Aseprite Tags.

---

## 💾 Expected `metadata.json` Structure

The script reads the following primary objects from the Pixel Lab export:

### 1. Character Size and Name (`character`)

Used to initialize the Aseprite Sprite dimensions and initial filename.

JSON

```
{
  "character": {
    "name": "Character_Name",
    "size": {
      "width": 48,
      "height": 48
    }
  },
// ...
```

### 2. Frame Definitions (`frames`)

This object dictates which images to import and how to name the animation tags.

|**JSON Key**|**Content Type**|**Resulting Tag Naming Convention**|
|---|---|---|
|`rotations`|Single image path per direction.|`Idle_Static_{direction}` (e.g., `Idle_Static_south`)|
|`animations`|Array of image paths per direction.|`{animation_name}_{direction}` (e.g., `picking-up_east`)|

JSON

```
  "frames": {
    "rotations": {
      "south": "rotations/south.png", 
      "west": "rotations/west.png"
    },
    "animations": {
      "picking-up": { 
        "east": [ 
          "animations/picking-up/east/frame_000.png",
          "animations/picking-up/east/frame_001.png"
        ],
        "west": [
          // ... list of paths
        ]
      }
    }
  }
}
```

> **Note:** Although Pixel Lab exports may contain `keypoints` data, the current version of this script **ignores** those fields and focuses solely on importing the frames and tags.