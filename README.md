# 🎨 Aseprite Color Reducer

**High-Speed Palette Quantization using the Median-Cut Algorithm**

This Lua script for **Aseprite** implements the **Median-Cut algorithm**, an industry-standard technique for generating an optimal palette in the shortest time possible. It achieves fast and high-quality color reduction, even for large sprites with thousands of unique colors.

---

## ⚠️ Critical Safety Notice

**SAVE YOUR WORK BEFORE RUNNING THIS SCRIPT!**

> 🚀 **PERFORMANCE IMPROVED:** The algorithm has been optimized from $O(N^2)$ to **$O(N \log K)$**. This drastically reduces the risk of Aseprite freezing or crashing with large images. However, as a standard precaution:
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
5. Click **"Generate Palette"** and wait for processing

---

## ⚙️ How It Works

### **Algorithm: Median-Cut Quantization**

This method uses a spatial approximation to find the representative colors, avoiding the computationally expensive "all-pairs" comparison that slows down clustering algorithms.

1. **Extract** all unique colors from visible layers.
2. **Identify** a **bounding box** containing all colors in the 3D RGB space.
3. **Split** the box into two smaller boxes by cutting it at the median of its **longest color axis** (R, G, or B).
4. **Repeat** the splitting process recursively until the exact target color count ($K$) is reached.
5. **Final Color:** The final color for each box is the average of all colors contained within it.
6. **Remap** all pixels to the nearest color in the final palette.

### **Performance Metrics**

- **Time Complexity:** **$O(N \log K)$**
    - $N$: Number of unique initial pixels/colors.
    - $K$: Number of target colors (e.g., 16, 32).
    - _Result:_ Performance is **near-linear** and extremely fast, even with $10,000+$ unique colors.
- **Best for:** **All palette sizes, including large, high-color images** where speed is critical.
- **Memory usage:** Moderate, due to caching of unique colors.

### **Color Mode Handling**

- **RGB Mode:** Processed directly
- Indexed Mode: Automatically converted to RGB
    Note: Original palette indexes will be lost

---

## 🎯 Use Cases

### **Cleaning AI-Generated Art**

> AI tools often create color noise with slightly varying hues. This script reduces them to clean, consistent colors.

Before: 450 colors with noise  
After: 32 clean colors  
Result: Ready for pixel art editing

### **Game Asset Optimization**

> Reduce sprite colors to match platform limitations (GameBoy: 4 colors, NES: 64 colors, etc.)

### **Art Style Consistency**

> Force all frames in an animation to use the exact same color palette

---

## ✅ Future Improvements Checklist

The following features are not currently implemented and are considered _future features_:

- [ ] **Undo Guarantee (`Ctrl+Z`)**
    - Ensure that the use of `app.transaction` reliably groups and allows undoing all changes.
- [ ] **Selection Support (`M` Tool)**
    - Allow the script to act **only** on pixels within the active selection, instead of the entire sprite.
- [ ] **Dithering Option**
    - Integrate a dithering algorithm (e.g., Floyd-Steinberg) to smooth color transitions after reduction.
- [ ] **Preset Palettes**
    
    - Option to reassign simplified colors to an external fixed palette (e.g., DB32, GameBoy).

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

This script is licensed under the MIT License. See [LICENSE](https://www.google.com/search?q=LICENSE) for details.

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
>

# Auto Resize by Block Matrix (C++ Module)

Aseprite script that instantly resizes sprites using the native C++ engine for maximum speed and performance.

## 📋 Requirements

- Aseprite v1.2.40 or higher
- Script extension enabled

## 📥 Installation

1. Download the `auto_resize_by_block_matrix_C_Module.lua` file
2. In Aseprite, go to **File → Scripts → Open Scripts Folder**
3. Copy the file into the opened folder
4. Restart Aseprite or rescan scripts (**File → Scripts → Rescan Scripts Folder**)

## 🎯 Usage

1. Open a sprite in Aseprite
2. Go to **File → Scripts → Auto Resize by Block Matrix (C++ Module)**
3. Enter a **Division Factor**:
   - **2** = Reduce to 50% (half the original size)
   - **4** = Reduce to 25% (quarter of the size)
   - **1.5** = Reduce to 66.6%
4. The script will show the new size in real-time
5. Click **"INSTANT RESIZE"** to apply

## 🔧 How It Works

This script uses Aseprite's internal `app.command.SpriteSize` command (written in C++) to resize the entire sprite at once, including all layers and frames.

### Technical Parameters:
- **Scaling method**: `bilinear` interpolation
- **Origin position**: `Top-Left` corner
- **Aspect ratio**: Locked (`lockRatio = true`)
- **Scope**: Entire sprite (all frames and layers)

## ⚠️ Limitations

- Only allows reduction (factor > 1)
- Factor must be a number greater than 1
- Prevents resizing to 0x0 pixels
- Result is rounded down (floor)

## 💡 Tips

- For extreme reductions (e.g., 16x to 1x), consider applying multiple progressive reductions
- The bilinear method is ideal for pixel art that needs controlled anti-aliasing
- Always work on a copy of your original file

## 📄 License

This script is distributed under the MIT License. You can freely modify and distribute it.

## 🐛 Troubleshooting

If you encounter issues:
1. Verify that a sprite is active
2. Ensure you're using a numeric factor greater than 1
3. Check that your Aseprite version is compatible (v1.2.40+)

---

**Note**: This script is perfect for workflows requiring frequent asset resizing, such as tileset preparation, multiple icon creation, or sprite optimization for different resolutions.