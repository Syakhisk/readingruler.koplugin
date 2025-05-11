![cover](https://github.com/user-attachments/assets/e2d5d86d-3376-46a6-a265-9be218021b14)

# Reading Ruler Plugin for KOReader

The **Reading Ruler** plugin is a tool designed to enhance the reading experience on KOReader by providing a movable horizontal line that helps readers focus on specific lines of text. This is especially useful for individuals who prefer guided reading or have difficulty maintaining focus while reading.

## Features

- **Movable Horizontal Line**: A customizable line that can be moved up or down to guide your reading.
- **Tap-to-Move Mode**: Quickly reposition the ruler by tapping on the desired location.
- **Swipe Navigation**: Use swipe gestures to move the ruler to the next or previous line of text.
- **Automatic Page Navigation**: Automatically navigate to the next or previous page when reaching the end of the current page.
- **Reset Position**: Easily reset the ruler to its default position.

## Preview

<table>
   <tr>
      <td>
         <img src="https://github.com/user-attachments/assets/66661951-c5b5-4d9c-9c4c-c1817570c885">
      </td>
      <td>
         <img src="https://github.com/user-attachments/assets/2695732c-c366-489e-af21-fa4b278fdf7c">
      </td>
      <td>
         <img src="https://github.com/user-attachments/assets/22dce65c-4285-4dd8-a49e-25855838a3ac">
      </td>
   </tr>
</table>

## How It Works

1. **Enable the Plugin**: Activate the Reading Ruler from the main menu.
2. **Move the Ruler**:

   - Swipe up or down to navigate between lines.
   - Use tap-to-move mode to reposition the ruler by tap/hold the ruler and then tap on the desired location.
   - Use custom gestures

## Installation

1. Download this repository
2. Rename the folder to `readingruler.koplugin` (remove `-master` from the folder name).
3. Copy the `readingruler.koplugin` folder into the `plugins` directory of your KOReader installation.
4. Restart KOReader to load the plugin.

## Known Issues

### Two Columns Mode

Some features of this plugin may not work as expected in two columns mode, this may be fixed in the future:

- Swipe navigation on page start/end will not move to next/previous page.
- The ruler may jump further than expected if the left and right columns texts are not aligned.

## Contributions

I have been using this plugin myself, and as of now, I don't need any additional features. However, I am open to feature requests to improve the plugin. Pull requests are also welcomed!

## Possible improvements

TODO:

- [ ] Support two columns
- [ ] Support continuous/scroll view mode

DONE:

- [x] Add option to use:
  - [x] Swipe mode
  - [x] Tap mode
  - [x] Disable default gestures (create event for navigation)
- [x] Customize line thickness / width
- [x] Ignore screen edges for swipe mode
