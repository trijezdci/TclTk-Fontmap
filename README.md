# TclTk-Fontmap

## A Tcl/Tk Fontmap Generator

This library provides:
- a ps font name generator for regular, italic, bold and bold-italic styles
- a ps font map generator for use with Tcl/Tk's canvas postscript command

### Postscript Font Name Generator

Tcl/Tk  derives  postscript font names  as follows:  For regular style fonts
the  font family name  is used as the  font name,  for other styles a suffix
denoting the style  is appended  to the  font family namme.  The suffixe are
"-Italic",  "-Bold"  and "-BoldItalic  for  slanted,  bold  and slanted-bold
styles respectively.  This scheme works for the majority of fonts,  but some
fonts use a different naming convention.  In some cases no hyphen is used to
delimit the font family from the style suffix.  In some cases an alternative
suffix is used, such as 'Oblique' instead of 'Italic' for the slanted styles
or  'Regular' instead of  no suffix  for the  regular style.  As a result, a
postscript renderer or postscript printer  may or may not find the requested
font and substitute it for another font.

The postscript font name generator  generates post script font names using a
a  suffix dictionary  for  font families known  to use an alternative naming
convention or alternative style suffixes.

`proc ::fontmap::font_name_list_for {font_family}`

> returns a list with the font names for the regular, slanted, bold and
> slanted-bold style fonts of font-family.  A font name of 'nil' denotes
> an unavailable font for the respective style.

 Example:
```
  import ::fontmap::font_name_list_for
  ...
  set font_name_list [font_name_list_for "DejaVuSans"]
```

### Postscript Font Map Generator

The Tcl/Tk canvas postscript command  accepts a fontmap option through which
the font names in the postscript output can be controlled.  A font name of a
canvas text object for which an entry exists in the font map  is replaced in
the postscript output with the replacement given in the font map.

Unfortunately, it is  NOT possible  to have a font map entry that covers all
pitches of a given font.  One entry is required for each pitch used.

The postscript font map generator  must therefore be passed a list with font
families and their pitches to be entered into the font map.  If no such list
is passed, a default list is used instead.  The default list is comprised of
the font families Times, Courier and Helvetica, and pitches 8, 9, 10, 12, 14
and 15 for each family.  Two public functions are provided:

`proc ::fontmap::is_mapped_font {font_map font_spec}`

> returns 1 if the passed font-spec is mapped in font-map , otherwise 0.

`proc ::fontmap::font_map_for {font_families_and_pitches_list}`

> returns a custom font map, initialised from the list of font families
> and pitches passed or the default font list if no list is passed.

 Example:
```
  import ::fontmap::font_map_for
  ...
  .c postscript\
    -fontmap [font_map_for {FreeSans 12 14} {FreeSerif 12 14} {FreeMono 10}]\
    -file sample.ps
```

\[END OF FILE\]
