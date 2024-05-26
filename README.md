# stage-editor.lua
This is an old project of mine. I intended to finish it, but I didn't. Oops.

This small behemoth of a script is a WYSIWYG stage editor for
[Psych Engine](https://github.com/ShadowMario/FNF-PsychEngine), but because of
the poor Lua support in the engine, it also includes a small de/serializer and
input handler. These parts should be fairly easy to rip out for your own use if
you find it useful.

![stage-editor.lua](images/1.png)

## Usage
**This section may be incomplete!**

First, place the script in `/mods/stages` along with a JSON file with the same
name. Then, in your chart, set the stage to `stage-editor` and add an empty
`editor` difficulty. To enter the editor, start the song on this difficulty.

The stage won't be very interesting until you add objects to it. This can't be
done in the editor itself, so you'll have to write the file that records stages
by hand. See the Deserializer section for more information on how to format the
file.

The file should be created in `/mods/stages/stage-editor`. The file must have
the same name as your song *with no file extension* in order to be found. This
allows many songs to use the same `stage-editor` stage and have their own unique
stages.

Here is an example you can start with:

```text
tag=splayer2;image=x;x position=n0;y position=n0;character overlap=btrue;
tag=splayer1;image=x;x position=n1000;y position=n0;character overlap=btrue;
tag=sgirlfriend;image=x;x position=n500;y position=n0;character overlap=btrue;
tag=sExample Object;image=sexample-image;x position=n0;y position=n200;x scroll factor=n0.5;y scroll factor=n0.5;x scale=n1;y scale=n1;antialiasing=btrue;animated=bfalse;fps=x;character overlap=bfalse;
```

Not all keys may be required. The `player1`, `player2`, and `girlfriend` tags
are special and will always map to `boyfriend`, `dad`, and `gf` in-game
respectively. These characters aren't actually objects, so they have special
behavior, and although `stage-editor.lua` does make an effort to abstract these
differences away, some properties of these character objects may be noticeably
broken.

Animated sprites are supported, and will animate in the editor. The FPS can't
be changed in the editor, so you'll need to change it in this file directly.

The default keys look like this:

| Key       | Function               | Description                                                               |
|-----------|------------------------|---------------------------------------------------------------------------|
| ESCAPE    | pause                  | Press twice quickly to exit the editor. Remember to save your work!       |
| F1        | help                   | Hold this key and press another key to get a description of its function. |
| F10       | save                   | Saves the stage to the file that it was opened from.                      |
| BACKSLASH | toggle antialiasing    | Toggles the state of antialiasing between `true` and `false`.             |
| Q         | select previous object | Selects the previous object for editor function.                          |
| E         | select next object     | Selects the next object for editor function.                              |
| J         | camera step X          | Move the camera left by 50 units.                                         |
| L         | camera step X          | Move the camera right by 50 units.                                        |
| I         | camera step Y          | Move the camera up by 50 units.                                           |
| K         | camera step Y          | Move the camera down by 50 units.                                         |
| SEMICOLON | reset camera X         | Reset the camera's X position to default.                                 |
| SEMICOLON | reset camera Y         | Reset the camera's Y position to default.                                 |
| A         | object step X          | Move the selected object left by 50 units.                                |
| D         | object step X          | Move the selected object right by 50 units.                               |
| W         | object step Y          | Move the selected object up by 50 units.                                  |
| S         | object step Y          | Move the selected object down by 50 units.                                |
| Z         | speed modifier         | Modify the unit change by a factor of 0.1.                                |
| X         | speed modifier         | Modify the unit change by a factor of 0.5.                                |
| C         | speed modifier         | Modify the unit change by a factor of 2.0.                                |
| V         | speed modifier         | Modify the unit change by a factor of 5.0.                                |
| B         | speed modifier         | Modify the unit change by a factor of 10.0.                               |

These keys can be modified freely by changing the `events.bound` table, which is
found near the top of `stage-editor.lua` for convenience.

Also, the mouse has the following bindings:

| Button       | Function            | Description                                                  |
|--------------|---------------------|--------------------------------------------------------------|
| mouse1 (LMB) | mouse_move          | Move the selected object using the cursor.                   |
| mouse2 (RMB) | mouse_scale         | Scale the selected object using the cursor.                  |
| mouse3 (MMB) | mouse_scroll_factor | Adjust the selected object's scroll factor using the cursor. |

These can be swapped around, but there are no other functions to bind.

In order to play your stage, save it, then exit the editor and enter your song
in any other difficulty. The global `editor` variable will be disabled, which
also disables nearly everything outside of initializing the stage. The normal
editor keys won't do anything, and in fact the input handler will never run.

## Deserializer
The deserializer is very simple. It reads tables as `key=value` pairs separated
by newlines. Pairs are separated by the `;` character. These special characters
can all be escaped by preceeding them with the `\` character.

The serializer can serialize the types `string`, `number`, `boolean`, and `nil`.
The type of a value is *always* indicated by the very first character in the
value. For example, in the pair `foo=sHello World`, the `s` character indicates
that the value is a string.

The escape character can be used to serialize characters that normally have
special meanings to the deserializer. For example, in the pair
`bar=sHello;World!`, the `;` character will be interpreted as a separator, and
the value of `bar` will be `Hello` while `World!` begins a key. However, in
the pair `baz=sHello\;World!`, the `;` character follows an escape character
`\` and is treated as any other character, making the value of `baz` equal to
`Hello;World!`.

The types are:

- string: `s`
- number: `n`
- boolean: `b`
- nil: `x`

The set value of a boolean can be indicated by either `1` or `true`, with any
other value indicating unset. The value of a `nil` is ignored.