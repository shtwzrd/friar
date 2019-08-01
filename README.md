# friar

_Fennel Repl In Awesome Repl_

## What?
Interact with your running AwesomeWM session from inside Emacs,
using [Fennel](https://fennel-lang.org), a lua-based Lisp.

Interested in using Fennel for writing your own AwesomeWM configuration?
Check the `starter-kit` included in this repo.
It contains an `rc.lua` that bootstraps loading the provided `config.fnl` file,
which is a line-for-line translation of the default AwesomeWM configuration.

## Installation
Via `use-package` with `straight.el`:

```
(use-package friar 
  :straight (:host github :repo "warreq/friar" :branch "master"
	     :files (:defaults "*.lua" "*.fnl")))
```

## Usage

`M-x friar` and he's ready to serve you.

## Troubleshooting

### I can't connect to AwesomeWM (D-Bus error)

Try slapping this into your `.xinitrc` to ensure you have a `DBUS_SESSION_BUS_ADDRESS`,
which Emacs needs in order to connect to your D-Bus. 
```
if test -z "$DBUS_SESSION_BUS_ADDRESS" ; then
  eval `dbus-launch --sh-syntax --exit-with-session`
fi
```
