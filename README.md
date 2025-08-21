# GuideLime Vanilla

A comprehensive World of Warcraft Classic (1.12) addon that provides an enhanced guide system with automatic quest tracking, TomTom integration, and smart UI management.

## 🌟 Features

### 📚 Smart Guide System
- **Dynamic Step Management**: Automatically tracks completed and active quest steps
- **Checkbox Interface**: Visual progress tracking with clickable checkboxes
- **Step Highlighting**: Active steps are highlighted with a distinctive color scheme
- **Auto-scrolling**: Automatically scrolls to show the current active step

### 🗺️ TomTom Integration
- **Automatic Waypoints**: Creates TomTom waypoints for quest objectives
- **Smart Coordinate Selection**: Automatically selects the most relevant coordinates based on step type
- **Multi-part Quest Support**: Handles complex quests with multiple objectives
- **Zone-aware Navigation**: Prioritizes coordinates within the quest's zone

### 🎯 Quest Tracking
- **Automatic Progress**: Automatically checks off completed quest steps
- **Quest State Persistence**: Saves progress between sessions
- **Real-time Updates**: Updates automatically when quests are accepted or completed
- **Quest Abandonment Handling**: Properly manages quest state when quests are abandoned

### 🎨 Enhanced User Interface
- **Modern Design**: Clean, organized interface with consistent styling
- **Icon Integration**: Clickable icons for special actions (e.g., Hearthstone usage)
- **Responsive Layout**: Adapts to different content lengths and screen sizes
- **Color-coded Steps**: Visual distinction between different step types

### 🔧 Technical Features
- **Lua 5.0 Compatibility**: Fully compatible with WoW Classic 1.12
- **Efficient Memory Management**: Optimized for performance
- **Modular Architecture**: Clean separation of concerns
- **Error Handling**: Robust error handling and fallbacks

## 📦 Installation

### Prerequisites
- World of Warcraft Classic (1.12)
- Optional: [TomTom TWOW](https://github.com/laytya/TomTom-TWOW) for waypoint functionality

### Installation Steps
1. Download the addon files
2. Extract to your `World of Warcraft/Interface/AddOns/` directory
3. Ensure the folder name matches the addon name
4. Restart World of Warcraft

## 🚀 Usage

### Basic Guide Navigation
1. **Load a Guide**: Select a guide from the dropdown menu
2. **Follow Steps**: Complete quests and objectives as listed
3. **Track Progress**: Checkboxes automatically update as you progress
4. **Navigate**: Use the auto-scrolling feature to stay on track

### TomTom Integration
- **Automatic Waypoints**: Waypoints are created automatically for quest objectives
- **Manual Control**: Use TomTom's built-in controls to manage waypoints
- **Zone Awareness**: Coordinates are prioritized based on quest zone

### Quest Management
- **Accept Quests**: Steps automatically check off when quests are accepted
- **Complete Objectives**: Progress is tracked in real-time
- **Abandon Quests**: Properly handles quest abandonment and state updates

## 🎮 Supported Step Types

### Quest Steps
- **ACCEPT**: Quest acceptance steps with NPC coordinates
- **TURNIN**: Quest completion steps with turn-in NPC coordinates
- **COMPLETE**: Objective completion steps with target coordinates
- **OBJECTIVE**: General objective steps

### Utility Steps
- **REPAIR**: Equipment repair steps
- **VENDOR**: Vendor interaction steps
- **HEARTHSTONE**: Hearthstone usage steps (clickable icon)

### Special Steps
- **Multi-line Steps**: Steps with multiple objectives or instructions

## ⚙️ Configuration

### Settings
The addon automatically saves your progress and preferences:
- **Step State**: Tracks which steps are completed
- **Current Step**: Remembers your current position in guides
- **Quest Progress**: Maintains quest acceptance and completion states

### Customization
- **Colors**: Step highlighting colors can be modified in the code
- **Spacing**: UI element spacing is configurable
- **Icons**: Custom icons can be added for special actions

## 🔍 Technical Details

### Architecture
- **Core Module**: Main addon functionality and initialization
- **Guide Parser**: Parses guide text and extracts step information
- **Guide Writer**: Renders the UI and manages user interactions
- **Quest Tracker**: Monitors quest state changes
- **TomTom Integration**: Handles waypoint creation and management
- **Database Tools**: Manages coordinate and quest data

### Dependencies
- **Ace2**: Core framework for addon management
- **TomTom TWOW**: Optional dependency for waypoint functionality

### File Structure
```
GuideLimeVanilla/
├── Core.lua                 # Main addon initialization
├── Settings.lua             # Settings and saved variables management
├── Guides/
│   ├── GuideLibrary.lua     # Guide loading and management
│   ├── GuideParser.lua      # Guide text parsing
│   ├── GuideWriter.lua      # UI rendering and management
│   ├── TomTomIntegration.lua # TomTom waypoint integration
│   └── Events/
│       └── Quests.lua       # Quest event handling
├── Helpers/
│   ├── DBTools.lua          # Database query functions
│   └── Helpers.lua          # Utility functions
└── DB/                      # Quest and coordinate databases
    ├── units.lua            # NPC coordinates
    ├── objects.lua          # Object coordinates
    ├── quests.lua           # Quest information
    ├── zones.lua            # Zone data
    └── items.lua            # Item information
```

## 🐛 Troubleshooting

### Common Issues
1. **TomTom Not Working**: Ensure TomTom TWOW is installed and enabled
2. **Guides Not Loading**: Check that all files are in the correct directory
3. **Progress Not Saving**: Verify that the addon has permission to save variables

### Debug Commands
- `/reload`: Reloads the UI and addon state
- Check chat for any error messages or debug information

## 🤝 Contributing

### Development
- **Code Style**: Follow existing code patterns and conventions
- **Testing**: Test changes thoroughly in WoW Classic 1.12
- **Documentation**: Update this README for any new features

### Reporting Issues
- **Bug Reports**: Include steps to reproduce and any error messages
- **Feature Requests**: Describe the desired functionality clearly
- **Compatibility Issues**: Specify WoW version and other addons

## 📄 License

This addon is provided as-is for educational and entertainment purposes. Use at your own risk.

## 🙏 Acknowledgments

- **Original GuideLime**: For the foundation and inspiration
- **WoW Classic Community**: For testing and feedback
- **Shagu**: For the databases (Quests, Items, Units, ...)
- **LaYT**: For the spells database, and TomTom TWOW !

## 📞 Support

For support, bug reports, or feature requests:
- Check the troubleshooting section above
- Review the code for any obvious issues
- Test with a clean addon installation

---

**Happy questing! 🎯✨**
