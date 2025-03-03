import fs from "fs";
import { KarabinerRules } from "./types";
import { createHyperSubLayers, app, app_new, open, execute } from "./utils";

const rules: KarabinerRules[] = [
  // Disabling
  {
  "description": "Disable Command + H",
  "manipulators": [
    {
      "from": {
        "key_code": "h",
        "modifiers": {
          "mandatory": ["command"]
        }
      },
      "to": [],
      "type": "basic"
    }
  ]
},






  // // This is used as a homerow app shortcut
  // {
  //   description: "right_control -> homerow 2",
  //   manipulators: [
  //     {
  //       from: {
  //         key_code: "right_control",
  //       },
  //       to: [
  //         {
  //           key_code: "right_control",
  //         },
  //       ],
  //       to_if_alone: [
  //         {
  //           key_code: "spacebar",
  //           modifiers: ["left_command", "left_option"],
  //         },
  //       ],
  //       type: "basic",
  //     },
  //   ],
  // },

  // // This is used as a homerow app shortcut
  // {
  //   description: "right_option -> homerow 3",
  //   manipulators: [
  //     {
  //       from: {
  //         key_code: "right_option",
  //       },
  //       to: [
  //         {
  //           key_code: "right_option",
  //         },
  //       ],
  //       to_if_alone: [
  //         {
  //           key_code: "delete_or_backspace",
  //           modifiers: ["left_command", "left_option"],
  //         },
  //       ],
  //       type: "basic",
  //     },
  //   ],
  // },

  // I couldn't get this work with the magic mouse because it only detects button1 in the karabiner event viewer
  // You need to enable pro mode in karabiner for the work with the apple mouse
  // It works with the logitech mouse tough
  // {
  //   description: "Simultaneous Left and Right Click to Cmd+Shift+S",
  //   manipulators: [
  //     {
  //       type: "basic",
  //       parameters: {
  //         "basic.simultaneous_threshold_milliseconds": 500
  //       },
  //       from: {
  //         simultaneous: [
  //           { "pointing_button": "button1" },
  //           { "pointing_button": "button2" }
  //         ],
  //         simultaneous_options: {
  //           detect_key_down_uninterruptedly: true,
  //           key_down_order: "strict",
  //           key_up_order: "strict",
  //           key_up_when: "all"
  //         }
  //       },
  //       to: [
  //         {
  //           key_code: "s",
  //           modifiers: ["left_command", "left_shift"]
  //         },
  //       ],
  //     },
  //   ],
  // },

  ...createHyperSubLayers({
    // All the following combinations require the "hyper" key as well
    i: execute("osascript ~/.config/bin/mac_arc_new_instance.applescript"),
    t: app("Telegram"),
    // return_or_enter: execute("osascript ~/.config/bin/mac_kitty_new_instance.applescript"),
    return_or_enter: execute("open -n -a kitty"),
    f: execute("open -n -a Finer"),
    c:execute("osascript ~/.config/bin/mac_dissmiss_notify.applescript"),
    y: execute("~/.config/yabai/yabai_restart.sh")
    // https://youtu.be/MCbEPylDEWU

    // r = "Raycast"
    // r: {
    //   j: open("raycast://extensions/lardissone/raindrop-io/search"),
    //   k: open("raycast://extensions/mblode/google-search/index"),
    //   l: open("raycast://extensions/raycast/navigation/switch-windows"),
    //   quote: open("raycast://extensions/mathieudutour/wolfram-alpha/index"),
    //   u: open("raycast://extensions/raycast/apple-reminders/create-reminder"),
    //   i: open("raycast://extensions/raycast/apple-reminders/my-reminders"),
    //   o: open("raycast://extensions/raycast/github/search-repositories"),
    //   p: open("raycast://extensions/nhojb/brew/search"),
    //   e: open(
    //     "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"
    //   ),
    // },

    // s = "System" or "Service"

    // u: {
    //   // Restart yabai
    //   o: {
    //     to: [
    //       {
    //         // shell_command: `/opt/homebrew/bin/yabai --restart-service`,
    //         shell_command: `~/github/dotfiles-latest/yabai/yabai_restart.sh`,
    //       },
    //     ],
    //   },
    //   // Dismiss notifications on macos
    //   k: open(
    //     "btt://execute_assigned_actions_for_trigger/?uuid=92B63395-5930-463A-9301-57BA344D6981"
    //   ),
    //   // Restart Ghostty
    //   g: open(
    //     "btt://execute_assigned_actions_for_trigger/?uuid=DAB53833-E0D1-4FF6-A411-3B02E3C55153"
    //   ),
    //   // w: {
    //   //   to: [
    //   //     {
    //   //       shell_command: `export PATH="/opt/homebrew/bin:$PATH" && yabai -m window --toggle study`,
    //   //     },
    //   //   ],
    //   // },
    //   // s: {
    //   //   to: [
    //   //     {
    //   //       shell_command: `export PATH="/opt/homebrew/bin:$PATH" && yabai -m window --toggle spotify`,
    //   //     },
    //   //   ],
    //   // },
    // },

    // c = "colorscheme selector"
    // c: {
    //   // execute the colorscheme selector script
    //   n: open(
    //     "btt://execute_assigned_actions_for_trigger/?uuid=6793CE15-C70A-43E7-ADA9-479DF1539A39"
    //   ),
    // },

    // For betterTouchTool
    // d: {
    //   // Terminal select last command
    //   j: open(
    //     "btt://execute_assigned_actions_for_trigger/?uuid=5A708885-4D65-465C-B87A-996BA6C23B86"
    //   ),
    //   // Paste alacritty text and go down
    //   k: open(
    //     "btt://execute_assigned_actions_for_trigger/?uuid=5AF2559D-E6C9-4665-8D06-2CAF35B1AB07"
    //   ),
    //   // Paste alacritty text and go up
    //   l: open(
    //     // This one is working great
    //     // paste alacritty go up LESS DELAY
    //     "btt://execute_assigned_actions_for_trigger/?uuid=E46BB0D5-F67F-46D5-850C-197337EB26E3"
    //   ),
    //   // Reboot router
    //   u: open(
    //     "btt://execute_assigned_actions_for_trigger/?uuid=EA461EE0-4C15-4113-93B6-07C12086FF1F"
    //   ),
    //   // Test ping
    //   hyphen: open(
    //     "btt://execute_assigned_actions_for_trigger/?uuid=EADC365D-0747-4E8F-ACB6-79564FEF1410"
    //   ),
    // },
    //
    // // shift+arrows to select stuff
    // v: {
    //   h: {
    //     to: [{ key_code: "left_arrow", modifiers: ["left_shift"] }],
    //   },
    //   j: {
    //     to: [{ key_code: "down_arrow", modifiers: ["left_shift"] }],
    //   },
    //   k: {
    //     to: [{ key_code: "up_arrow", modifiers: ["left_shift"] }],
    //   },
    //   l: {
    //     to: [{ key_code: "right_arrow", modifiers: ["left_shift"] }],
    //   },
    //   y: {
    //     to: [
    //       { key_code: "left_arrow", modifiers: ["left_shift", "left_option"] },
    //     ],
    //   },
    //   u: {
    //     to: [
    //       { key_code: "down_arrow", modifiers: ["left_shift", "left_option"] },
    //     ],
    //   },
    //   i: {
    //     to: [
    //       { key_code: "up_arrow", modifiers: ["left_shift", "left_option"] },
    //     ],
    //   },
    //   o: {
    //     to: [
    //       { key_code: "right_arrow", modifiers: ["left_shift", "left_option"] },
    //     ],
    //   },
    //   // // Magicmove via homerow.app
    //   // m: {
    //   //   to: [{ key_code: "f", modifiers: ["right_control"] }],
    //   // },
    //   // // Scroll mode via homerow.app
    //   // s: {
    //   //   to: [{ key_code: "j", modifiers: ["right_control"] }],
    //   // },
    // },

    // left_command: {
    //   // Change MX Vertical mouse to mac mini
    //   4: {
    //     to: [
    //       {
    //         shell_command: `~/github/dotfiles-latest/hidapitester/hidapitester --vidpid 046D:B020 --usagePage 0xFF43 --usage 0x0202 --open --length 20 --send-output 0x11,0x00,0x0C,0x1C,0x00`,
    //       },
    //     ],
    //   },
    //   // Change MX Vertical  mouse to macbook pro
    //   5: {
    //     to: [
    //       {
    //         shell_command: `~/github/dotfiles-latest/hidapitester/hidapitester --vidpid 046D:B020 --usagePage 0xFF43 --usage 0x0202 --open --length 20 --send-output 0x11,0x00,0x0C,0x1C,0x01`,
    //       },
    //     ],
    //   },
    //   // Pull github repos
    //   // I tried with the number 6 instead of "J" but didn't work, seems to have been a
    //   // conflict maybe with another app
    //   j: {
    //     to: [
    //       {
    //         shell_command: `~/github/scripts/macos/mac/360-pullGitRepos.sh`,
    //       },
    //     ],
    //   },
    // },

    // // copy, paste and other stuff
    // g: {
    //   // // I use this for fzf
    //   // r: {
    //   //   to: [{ key_code: "r", modifiers: ["left_control"] }],
    //   // },
    //   // t: {
    //   //   to: [{ key_code: "t", modifiers: ["left_control"] }],
    //   // },
    //   // Slack go to all unreads
    //   a: {
    //     to: [{ key_code: "a", modifiers: ["left_command", "left_shift"] }],
    //   },
    //   h: {
    //     to: [{ key_code: "delete_or_backspace" }],
    //   },
    //   l: {
    //     to: [{ key_code: "delete_forward" }],
    //   },
    //   // Switch between windows of same app, normally cmd+~
    //   spacebar: {
    //     to: [
    //       { key_code: "grave_accent_and_tilde", modifiers: ["left_command"] },
    //     ],
    //   },
    // },

    // // 'e' for extra tools
    // e: {
    //   // To edit the contents of an excel cell
    //   u: {
    //     to: [{ key_code: "f2" }],
    //   },
    //   // Focus outline in obsidian
    //   o: {
    //     to: [{ key_code: "x", modifiers: ["left_command", "left_shift"] }],
    //   },
    //   // Increase LG TV volume
    //   k: {
    //     to: [
    //       {
    //         shell_command: `~/opt/lgtv/bin/python3 ~/opt/lgtv/bin/lgtv MyTV volumeUp ssl`,
    //       },
    //     ],
    //   },
    //   // Decrease LG TV volume
    //   j: {
    //     to: [
    //       {
    //         shell_command: `~/opt/lgtv/bin/python3 ~/opt/lgtv/bin/lgtv MyTV volumeDown ssl`,
    //       },
    //     ],
    //   },
    // },

    // ALWAYS LEAVE THE ONES WITHOUT ANY SUBLAYERS AT THE BOTTOM
    // Vim nagivation
    // h: {
    //   to: [{ key_code: "left_arrow" }],
    // },
    // j: {
    //   to: [{ key_code: "down_arrow" }],
    // },
    // k: {
    //   to: [{ key_code: "up_arrow" }],
    // },
    // l: {
    //   to: [{ key_code: "right_arrow" }],
    // },
    // Map hyper+f to ctrl+b for tmux
    // f: {
    //   to: [{ key_code: "b", modifiers: ["left_control"] }],
    // },
    // copy, paste and other stuff
    // y: {
    //   // Switch between windows of same app, normally cmd+~
    //   to: [{ key_code: "tab", modifiers: ["left_command"] }],
    // },
    // 6: {
    //   // Switch between windows of same app, normally cmd+~
    //   to: [{ key_code: "grave_accent_and_tilde", modifiers: ["left_command"] }],
    // },
  }),
];

fs.writeFileSync(
  "karabiner.json",
  JSON.stringify(
    {
      global: {
        show_in_menu_bar: false,
      },
      profiles: [
        {
          complex_modifications: {
            rules,
          },
          fn_function_keys: [
            {
              from: { key_code: "f6" },
              to: [{ consumer_key_code: "rewind" }],
            },
            {
              from: { key_code: "f7" },
              to: [{ consumer_key_code: "play_or_pause" }],
            },
            {
              from: { key_code: "f8" },
              to: [{ consumer_key_code: "fast_forward" }],
            },
            {
              from: { key_code: "f9" },
              to: [{ consumer_key_code: "volume_decrement" }],
            },
            {
              from: { key_code: "f10" },
              to: [{ consumer_key_code: "volume_increment" }],
            },
            {
              from: { key_code: "f11" },
              to: [{ key_code: "f11" }],
            },
            {
              from: { key_code: "f12" },
              to: [{ key_code: "f12" }],
            },
          ],
          name: "Default",
          selected: true,
          virtual_hid_keyboard: { keyboard_type_v2: "ansi" },
        },
      ],
    },
    null,
    2
  )
);
