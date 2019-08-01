;; Standard awesome library
(local gears (require "gears"))
(local awful (require "awful"))
(require "awful.autofocus")
;; Widget and layout library
(local wibox (require "wibox"))
;; Theme handling library
(local beautiful (require "beautiful"))
;; Notification library
(local naughty (require "naughty"))
(local menubar (require "menubar"))
;; Enable hotkeys help widget for VIM and other apps
;; when client with a matching name is opened:
(local hotkeys_popup (require "awful.hotkeys_popup"))
(require "awful.hotkeys_popup.keys")

;; Error handling
;; Check if awesome encountered an error during startup and fell back to
;; another config (This code will only ever execute for the fallback config)
(when awesome.startup_errors
  (naughty.notify {:preset naughty.config.presets.critical
                   :title "Oops, there were errors during startup!"
                   :text awesome.startup_errors}))

;; Handle runtime errors after startup
(do
  (var in_error false)
  (awesome.connect_signal "debug::error" (fn [err]
                                           ;; Make sure we don't go into an endless error loop
                                           (when (not in_error)
                                             (set in_error true)
                                             (naughty.notify {:preset naughty.config.presets.critical
                                                              :title "Oops, an error happened!"
                                                              :text (tostring err)})
                                             (set in_error false)))))

;; Variable definitions
;; Themes define colours, icons, font and wallpapers.
(beautiful.init (.. (gears.filesystem.get_themes_dir) "default/theme.lua"))

;; This is used later as the default terminal and editor to run.
(var terminal "xterm")
(var editor (or (os.getenv "EDITOR") "nano"))
(var editor_cmd (.. terminal " -e " editor))

;; Default modkey.
;; Usually, Mod4 is the key with a logo between Control and Alt.
;; If you do not like this or do not have such a key,
;; I suggest you to remap Mod4 to another key using xmodmap or other tools.
;; However, you can use another modifier like Mod1, but it may interact with others.
(var modkey "Mod4")

;; Table of layouts to cover with awful.layout.inc, order matters.
(set awful.layout.layouts [
                           awful.layout.suit.floating
                           awful.layout.suit.tile
                           awful.layout.suit.tile.left
                           awful.layout.suit.tile.bottom
                           awful.layout.suit.tile.top
                           awful.layout.suit.fair
                           awful.layout.suit.fair.horizontal
                           awful.layout.suit.spiral
                           awful.layout.suit.spiral.dwindle
                           awful.layout.suit.max
                           awful.layout.suit.max.fullscreen
                           awful.layout.suit.magnifier
                           awful.layout.suit.corner.nw
                           ;; awful.layout.suit.corner.ne
                           ;; awful.layout.suit.corner.sw
                           ;; awful.layout.suit.corner.se
                           ])

;; Menu
;; Create a launcher widget and a main menu
(global myawesomemenu [ 
                       [ "hotkeys" (fn [] (hotkeys_popup.show_help nil (awful.screen.focused))) ]
                       [ "manual" (.. terminal " -e man awesome") ]
                       [ "edit config" (.. editor_cmd " " awesome.conffile) ]
                       [ "restart" awesome.restart ]
                       [ "quit" (fn [] (awesome.quit)) ]])

(global mymainmenu (awful.menu {:items [
                                        [ "awesome" myawesomemenu beautiful.awesome_icon ]
                                        [ "open terminal" terminal ]]}))

(global mylauncher (awful.widget.launcher {:image beautiful.awesome_icon
                                           :menu mymainmenu }))

;; Menubar configuration
(set menubar.utils.terminal terminal) ;; Set the terminal for applications that require it

;; Keyboard map indicator and switcher
(global mykeyboardlayout (awful.widget.keyboardlayout))

;; Wibar
;; Create a textclock widget
(global mytextclock (wibox.widget.textclock))

;; Create a wibox for each screen and add it
(local taglist_buttons
       (gears.table.join
        (awful.button [] 1 (fn [t] (: t :view_only)))
        (awful.button [ modkey ] 1 (fn [t] (when client.focus (: client.focus :move_to_tag t))))
        (awful.button [] 3 awful.tag.viewtoggle)
        (awful.button [ modkey ] 3 (fn [t] (when client.focus (: client.focus :toggle_tag t))))
        (awful.button [] 4 (fn [t] (awful.tag.viewnext t.screen)))
        (awful.button [] 5 (fn [t] (awful.tag.viewprev t.screen)))))

(local tasklist_buttons
       (gears.table.join
        (awful.button [] 1 (fn [c]
                             (if (= c client.focus)
                                 (set c.minimized true)
                                 (: c :emit_signal
                                    "request::activate"
                                    "tasklist"
                                    {:raise true}
                                    ))))
        (awful.button [] 3 (fn [] (awful.menu.client_list {:theme {:width 250 }})))
        (awful.button [] 4 (fn [] (awful.client.focus.byidx 1)))
        (awful.button [] 5 (fn [] (awful.client.focus.byidx -1)))))

(fn set_wallpaper [s]
  ;; Wallpaper
  (when beautiful.wallpaper
    (var wallpaper beautiful.wallpaper)
    ;; If wallpaper is a function, call it with the screen
    (when (= (type wallpaper) "function")
      (set wallpaper (wallpaper s)))
    (gears.wallpaper.maximized wallpaper s true)))

;; Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
(screen.connect_signal "property::geometry" set_wallpaper)

(awful.screen.connect_for_each_screen
 (fn [s]
   ;; Wallpaper
   (set_wallpaper s)

   ;; Each screen has its own tag table.
   (awful.tag [ "1" "2" "3" "4" "5" "6" "7" "8" "9" ] s (. awful.layout.layouts 1))

   ;; Create a promptbox for each screen
   (set s.mypromptbox (awful.widget.prompt))
   ;; Create an imagebox widget which will contain an icon indicating which layout we're using.
   ;; We need one layoutbox per screen.
   (set s.mylayoutbox (awful.widget.layoutbox s))
   (: s.mylayoutbox :buttons (gears.table.join
                              (awful.button [] 1 (fn [] (awful.layout.inc 1 s awful.layout.layouts)))
                              (awful.button [] 3 (fn [] (awful.layout.inc -1 s)))
                              (awful.button [] 4 (fn [] (awful.layout.inc 1 s)))
                              (awful.button [] 5 (fn [] (awful.layout.inc -1 s)))))
   ;; Create a taglist widget
   (set s.mytaglist (awful.widget.taglist {
                                           :screen s
                                           :filter awful.widget.taglist.filter.all
                                           :buttons taglist_buttons
                                           }))

   ;; Create a tasklist widget
   (set s.mytasklist (awful.widget.tasklist {
                                             :screen s
                                             :filter awful.widget.tasklist.filter.currenttags
                                             :buttons tasklist_buttons
                                             }))

   ;; Create the wibox
   (set s.mywibox (awful.wibar { :position "top" :screen s }))

   ;; Add widgets to the wibox
   (: s.mywibox :setup {
                        :layout wibox.layout.align.horizontal
                        1 { ;; Left widgets
                           :layout wibox.layout.fixed.horizontal
                           1 mylauncher
                           2 s.mytaglist
                           3 s.mypromptbox
                           }
                        2 s.mytasklist ;; Middle widget
                        3 { ;; Right widgets
                           :layout wibox.layout.fixed.horizontal
                           1 mykeyboardlayout
                           2 (wibox.widget.systray)
                           3 mytextclock
                           4 s.mylayoutbox
                           }
                        })))


;; Mouse bindings
(root.buttons (gears.table.join
               (awful.button [ ] 3 (fn [] (: mymainmenu :toggle)))
               (awful.button [ ] 4 awful.tag.viewnext)
               (awful.button [ ] 5 awful.tag.viewprev)))

;; key bindings
(global globalkeys
      (gears.table.join
       (awful.key [ modkey ] "s" hotkeys_popup.show_help
                  { :description "show help" :group "awesome"})
       (awful.key [ modkey ] "Left" awful.tag.viewprev
                  {:description "view previous" :group "tag"})
       (awful.key [ modkey ] "Right" awful.tag.viewnext
                  {:description "view next" :group "tag"})
       (awful.key [ modkey ] "Escape" awful.tag.history.restore
                  {:description "go back" :group "tag"})
       (awful.key [ modkey ] "j" (fn [] (awful.client.focus.byidx 1))
                  {:description "focus next by index" :group "client"})
       (awful.key [ modkey ] "k" (fn [] (awful.client.focus.byidx -1))
                  {:description "focus previous by index" :group "client"})
       (awful.key [ modkey ] "w" (fn [] (: mymainmenu :show))
                  {:description "show main menu" :group "awesome"})

       ;; Layout manipulation
       (awful.key [ modkey "Shift" ] "j" (fn [] (awful.client.swap.byidx 1))
                  {:description "swap with next client by index" :group "client"})
       (awful.key [ modkey "Shift" ], "k" (fn [] (awful.client.swap.byidx  -1))
                  {:description "swap with previous client by index" :group "client"})
       (awful.key [ modkey "Control" ] "j" (fn [] (awful.screen.focus_relative 1))
                  {:description "focus the next screen" :group "screen"})
       (awful.key [ modkey "Control" ] "k" (fn [] (awful.screen.focus_relative -1))
                  {:description "focus the previous screen" :group "screen"})
       (awful.key [ modkey ] "u" awful.client.urgent.jumpto
                  {:description "jump to urgent client" :group "client"})
       (awful.key [ modkey ] "Tab" (fn []
                                     (awful.client.focus.history.previous)
                                     (when client.focus (: client.focus :raise)))
                  {:description "go back" :group "client"})

       ;; Standard program
       (awful.key [ modkey ] "Return" (fn [] (awful.spawn terminal))
                  {:description "open a terminal" :group "launcher"})
       (awful.key [ modkey "Control" ] "r" awesome.restart
                  {:description "reload awesome" :group "awesome"})
       (awful.key [ modkey "Shift" ] "q" awesome.quit
                  {:description "quit awesome" :group "awesome"})
       (awful.key [ modkey ] "l" (fn [] (awful.tag.incmwfact 0.05))
                  {:description "increase master width factor" :group "layout"})
       (awful.key [ modkey ] "h" (fn [] (awful.tag.incmwfact -0.05))
                  {:description "decrease master width factor" :group "layout"})
       (awful.key [ modkey "Shift" ] "h" (fn [] (awful.tag.incnmaster 1 nil true))
                  {:description "increase the number of master clients" :group "layout"})
       (awful.key [ modkey "Shift" ] "l" (fn [] (awful.tag.incnmaster -1 nil true))
                  {:description "decrease the number of master clients" :group "layout"})
       (awful.key [ modkey "Control" ] "h" (fn [] (awful.tag.incncol 1 nil true))
                  {:description "increase the number of columns" :group "layout"})
       (awful.key [ modkey "Control" ] "l" (fn [] (awful.tag.incncol -1 nil true))
                  {:description "decrease the number of columns" :group "layout"})
       (awful.key [ modkey ] "space" (fn [] (awful.layout.inc 1))
                  {:description "select next" :group "layout"})
       (awful.key [ modkey "Shift" ] "space" (fn [] (awful.layout.inc -1))
                  {:description "select previous" :group "layout"})
       (awful.key [ modkey "Control" ] "n" (fn []
                                             (local c (awful.client.restore))
                                             (when c ;; Focus restored client
                                               (: c :emit_signal "request::activate" "key.unminimize" {:raise true})))
                  {:description "restore minimized" :group "client"})

       ;; Prompt
       (awful.key [ modkey ] "r" (fn [] (: (. (awful.screen.focused) :mypromptbox) :run))
                  {:description "run prompt" :group "launcher"})

       (awful.key [ modkey ] "x" (fn []
                                   (let [fscr (awful.screen.focused)]
                                     (awful.prompt.run {
                                                        :prompt       "Run Lua code: "
                                                        :textbox      fscr.mypromptbox.widget
                                                        :exe_callback awful.util.eval
                                                        :history_path (.. (awful.util.get_cache_dir) "/history_eval")
                                                        })))
                  {:description "lua execute prompt" :group "awesome"})
       ;; Menubar
       (awful.key [ modkey ] "p" (fn [] (menubar.show))
                  {:description "show the menubar" :group "launcher"})))

(global clientkeys
        (gears.table.join
         (awful.key [ modkey ] "f" (fn [c] (set c.fullscreen (not c.fullscreen)) (: c :raise))
                    {:description "toggle fullscreen" :group "client"})
         (awful.key [ modkey "Shift" ] "c" (fn [c] (: c :kill))
                    {:description "close" :group "client"})
         (awful.key [ modkey "Control" ] "space" awful.client.floating.toggle
                    {:description "toggle floating" :group "client"})
         (awful.key [ modkey "Control" ] "Return" (fn [c] (: c :swap (awful.client.getmaster)))
                    {:description "move to master" :group "client"})
         (awful.key [ modkey ] "o" (fn [c] (: c :move_to_screen))
                    {:description "move to screen" :group "client"})
         (awful.key [ modkey ] "t"(fn [c] (set c.ontop (not c.ontop)))
                    {:description "toggle keep on top" :group "client"})
         (awful.key [ modkey ] "n" (fn [c]
                                     ;; The client currently has the input focus, so it cannot be
                                     ;; minimized, since minimized clients can't have the focus.
                                     (set c.minimized true))
                    {:description "minimize" :group "client"}),
         (awful.key [ modkey ] "m" (fn [c] (set c.maximized (not c.maximized)) (: c :raise))
                    {:description "(un)maximize" :group "client"}),
         (awful.key [ modkey "Control" ] "m" (fn [c] (set c.maximized_vertical (not c.maximized_vertical)) (: c :raise))
                    {:description "(un)maximize vertically" :group "client"}),
         (awful.key [modkey "Shift" ] "m" (fn [c] (set c.maximized_horizontal (not c.maximized_horizontal)) (: c :raise))
                    {:description "(un)maximize horizontally" :group "client"})))

;; Bind all key numbers to tags.
;; Be careful: we use keycodes to make it work on any keyboard layout.
;; This should map on the top row of your keyboard, usually 1 to 9.
(for [i 1 9]
  (global globalkeys
          (gears.table.join
           globalkeys
           ;; View tag only.
           (awful.key [ modkey ] (.. "#" (+ i 9))
                      (fn []
                        (let [screen (awful.screen.focused)
                              tag    (. screen.tags i)]
                          (when tag
                            (: tag :view_only))))
                      {:description (.. "view tag #" i) :group "tag"})
           ;; Toggle tag display
           (awful.key [ modkey "Control" ] (.. "#" (+ i 9))
                      (fn []
                        (let [screen (awful.screen.focused)
                              tag    (. screen.tags i)]
                          (when tag
                            (awful.tag.viewtoggle))))
                      {:description (.. "toggle tag #" i) :group "tag"})
           ;; Move client to tag
           (awful.key [ modkey, "Shift" ] (.. "#"  (+ i 9))
                      (fn []
                        (when client.focus
                          (let [tag (. client.focus.screen.tags i)]
                            (when tag
                              (: client.focus :move_to_tag tag)))))
                      {:description (.. "move focused client to tag #" i) :group "tag"})
           ;; Toggle tag on focused client.
           (awful.key [ modkey "Control" "Shift" ] (.. "#" (+ i 9))
                      (fn []
                        (when client.focus
                          (let [tag (. client.focus.screen.tags i)]
                            (when tag
                              (: client.focus :toggle_tag tag)))))
                      {:description (.. "toggle focused client on tag #" i) :group "tag"}))))

(global clientbuttons
        (gears.table.join
         (awful.button [] 1 (fn [c] (: c :emit_signal "request::activate" "mouse_click" {:raise true})))
         (awful.button [ modkey ] 1 (fn [c]
                                      (: c :emit_signal "request::activate" "mouse_click" {:raise true})
                                      (awful.mouse.client.move c)))
         (awful.button [ modkey ] 3 (fn [c]
                                      (: c :emit_signal "request::activate" "mouse_click" {:raise true})
                                      (awful.mouse.client.resize c)))))
;; Set keys
(root.keys globalkeys)

;; Rules
;; Rules to apply to new clients (through the "manage" signal)
(set awful.rules.rules
     [
      ;; All clients will match this rule.
      {
       :rule { }
       :properties { :border_width beautiful.border_width
                    :border_color beautiful.border_normal
                    :focus awful.client.focus.filter
                    :raise true
                    :keys clientkeys
                    :buttons clientbuttons
                    :screen awful.screen.preferred
                    :placement (+ awful.placement.no_overlap awful.placement.no_offscreen)
                    }
       }

      ;; Floating clients.
      {
       :rule_any {
                  :instance [
                             "DTA" ;; Firefox addon DownThemAll.
                             "copyq" ;; Includes session name in class.
                             "pinentry"
                             ] 
                  :class [
                          "Arandr"
                          "Blueman-manager"
                          "Gpick"
                          "Kruler"
                          "MessageWin" ;; kalarm.
                          "Sxiv"
                          "Tor Browser" ;; Needs a fixed window size to avoid fingerprinting by screen size.
                          "Wpa_gui"
                          "veromix"
                          "xtightvncviewer"
                          ]
                  ;; Note that the name property shown in xprop might be set slightly after creation of the client
                  ;; and the name shown there might not match defined rules here.
                  :name [
                         "Event Tester"  ;; xev
                         ]
                  :role [
                         "AlarmWindow" ;; Thunderbird's calendar.
                         "ConfigManager" ;; Thunderbird's about:config.
                         "pop-up" ;; e.g. Google Chrome's (detached) Developer Tools.
                         ]
                  }
       :properties {:floating true }}

      ;; Add titlebars to normal clients and dialogs
      {
       :rule_any {:type [ "normal", "dialog" ] }
       :properties {:titlebars_enabled true }
       }

      ;; Set Firefox to always map on the tag named "2" on screen 1.
      ;; { :rule { :class "Firefox" }
      ;;   :properties { :screen 1 :tag "2" } }
      ])

;; Signals
;; Signal function to execute when a new client appears.
(client.connect_signal
 "manage"
 (fn [c]
   ;; Set the windows at the slave,
   ;; i.e. put it at the end of others instead of setting it master.
   ;; (when (not awesome.startup) (awful.client.setslave c))

   (when (and awesome.startup
              (not c.size_hints.user_position)
              (not c.size_hints.program_position))
     ;; Prevent clients from being unreachable after screen count changes.
     (awful.placement.no_offscreen c))))

;; Add a titlebar if titlebars_enabled is set to true in the rules.
(client.connect_signal
 "request::titlebars"
 (fn [c]
   ;; buttons for the titlebar
   (let [buttons (gears.table.join
                  (awful.button [] 1 (fn []
                                       (: c :emit_signal "request::activate" "titlebar" {:raise true})
                                       (awful.mouse.client.move c)))
                  (awful.button [] 3 (fn []
                                       (: c :emit_signal "request::activate" "titlebar" {:raise true})
                                       (awful.mouse.client.resize c))))
         titlebar (awful.titlebar c)]
     (: titlebar :setup {
                         1 { ;; Left
                            1 (awful.titlebar.widget.iconwidget c)
                            :buttons buttons
                            :layout wibox.layout.fixed.horizontal
                            }
                         2 { ;; Middle
                            1 { ;; Title
                               :align "center"
                               :widget (awful.titlebar.widget.titlewidget c)
                               }
                            :buttons buttons
                            :layout wibox.layout.flex.horizontal
                            }
                         3 { ;; Right
                            1 (awful.titlebar.widget.floatingbutton  c)
                            2 (awful.titlebar.widget.maximizedbutton c)
                            3 (awful.titlebar.widget.stickybutton    c)
                            4 (awful.titlebar.widget.ontopbutton     c)
                            5 (awful.titlebar.widget.closebutton     c)
                            :layout (wibox.layout.fixed.horizontal)
                            }
                         :layout wibox.layout.align.horizontal
                         }))))

;; Enable sloppy focus, so that focus follows mouse.
(client.connect_signal "mouse::enter"
                       (fn [c]
                         (: c :emit_signal "request::activate"  "mouse_enter" {:raise false})))

(client.connect_signal "focus" (fn [c] (set c.border_color beautiful.border_focus)))
(client.connect_signal "unfocus" (fn [c] (set c.border_color beautiful.border_normal)))
