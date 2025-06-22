![cover](https://github.com/user-attachments/assets/e2d5d86d-3376-46a6-a265-9be218021b14)

<p align="center">
  <a href="https://ko-fi.com/syakhisk" target="_blank"> <img src="https://ko-fi.com/img/githubbutton_sm.svg"/> </a>
</p>

# Reading Ruler Plugin for KOReader

**Reading Ruler** is a KOReader plugin that adds a movable underline (ruler) to help readers focus on specific text lines, ideal for guided reading or improving focus.

## Features

This plugin simply introduce a customizable underline that can be moved up or down to guide your reading.

### Navigation Options

- **Tap Mode**: Tap to move the ruler to the next line, swipe up to move it up. (Swipe down is unused)
- **Swipe Navigation**: Use swipe gestures to move the ruler to the next or previous line of text.
- **Custom Gestures**: Configure custom gestures to navigate through the text, such as tapping corners or edges of the screen.

### Tap-to-Move Mode

Skipped a couple of lines without moving the ruler? No problem, you can quickly reposition the ruler by tapping on the desired line.


To get to this mode, you can tap the ruler (the ruler will turn into dashed line) and then tap on the desired line to move the ruler there.

<img width="896" alt="tap-to-move-demo" src="https://github.com/user-attachments/assets/0b22e6fe-46ae-4f1c-82ad-01cdeca7cd70" />

### Ruler Customization

- **Thickness**: Adjust the thickness of the ruler to suit your reading preferences.
- **Intensity** (Opacity): Set the opacity of the ruler to make it more or less prominent.

### Automatic Page Navigation

Automatically navigate to the next or previous page when reaching the end of the current page:

- If the ruler is at the top of the page, navigating up will navigate to the previous page and put the ruler at the bottom of the page,
- and if it is at the bottom, swiping down will navigate to the next page and put the ruler at the top of the page.

## Preview

<table>
   <tr>
      <td>
         <img src="https://github.com/user-attachments/assets/66661951-c5b5-4d9c-9c4c-c1817570c885">
      </td>
      <td>
         <img src="https://github.com/user-attachments/assets/cc785f42-c1ba-490d-9d4b-7643aa8bb291">
      </td>
      <td>
         <img src="https://github.com/user-attachments/assets/22dce65c-4285-4dd8-a49e-25855838a3ac">
      </td>
   </tr>
</table>

## Installation

1. Go to the [releases page](https://github.com/Syakhisk/readingruler.koplugin/releases).
2. Download the `readingruler.koplugin.zip` file from the latest release.
3. Extract and copy the `readingruler.koplugin` folder into the `plugins` directory of your KOReader installation.
4. Restart KOReader to load the plugin.

## Known Issues

### Two Columns Mode

Some features of this plugin may not work as expected in two columns mode, this may be fixed in the future:

- Swipe navigation on page start/end will not move to next/previous page.
- The ruler may jump further than expected if the left and right columns texts are not aligned.

### Line-skipping

If the last line in the paragraphs is short, the plugin may skip one line ahead. This is due to the way that KOreader determine lines visible in the page.

## Contributions
I am open to feature requests to improve the plugin. Issues or Pull requests are welcomed!

## Laundry List

TODO:

- [ ] Support two columns
- [ ] Support continuous/scroll view mode

DONE:

- [x] Update screenshots in readme and add demo
- [x] Add option to use:
  - [x] Swipe mode
  - [x] Tap mode
  - [x] Disable default gestures (create event for navigation)
- [x] Customize line thickness / width
- [x] Ignore screen edges for swipe mode

## Shout-outs

- https://github.com/koreader/contrib
- https://github.com/Billiam/hardcoverapp.koplugin
