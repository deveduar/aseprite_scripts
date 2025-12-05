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