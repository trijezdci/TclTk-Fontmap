#!/usr/bin/wish
# ****************************************************************************
# Tcl/Tk Fontmap Library (C) 2018 B.Kowarsch, released under MIT license.
# ****************************************************************************
# This library provides:
#
# - a ps font name generator for regular, italic, bold and bold-italic styles
# - a ps font map generator for use with Tcl/Tk's canvas postscript command
#
#
# Postscript font name generator
#
# Tcl/Tk  derives  postscript font names  as follows:  For regular style fonts
# the  font family name  is used as the  font name,  for other styles a suffix
# denoting the style  is appended  to the  font family namme.  The suffixe are
# "-Italic",  "-Bold"  and "-BoldItalic  for  slanted,  bold  and slanted-bold
# styles respectively.  This scheme works for the majority of fonts,  but some
# fonts use a different naming convention.  In some cases no hyphen is used to
# delimit the font family from the style suffix.  In some cases an alternative
# suffix is used, such as 'Oblique' instead of 'Italic' for the slanted styles
# or  'Regular' instead of  no suffix  for the  regular style.  As a result, a
# postscript renderer or postscript printer  may or may not find the requested
# font and substitute it for another font.
#
# The postscript font name generator  generates post script font names using a
# a  suffix dictionary  for  font families known  to use an alternative naming
# convention or alternative style suffixes.
#
# (1) function ::fontmap::font_name_list_for ( font-family )
#     returns a list with the font names for the regular, slanted, bold and
#     slanted-bold style fonts of font-family.  A font name of 'nil' denotes
#     an unavailable font for the respective style.
#
# Example:
#
#   import ::fontmap::font_name_list_for
#   ...
#   set font_name_list [font_name_list_for "DejaVuSans"]
#
#
# Postscript font map generator
#
# The Tcl/Tk canvas postscript command  accepts a fontmap option through which
# the font names in the postscript output can be controlled.  A font name of a
# canvas text object for which an entry exists in the font map  is replaced in
# the postscript output with the replacement given in the font map.
#
# Unfortunately, it is  NOT possible  to have a font map entry that covers all
# pitches of a given font.  One entry is required for each pitch used.
#
# The postscript font map generator  must therefore be passed a list with font
# families and their pitches to be entered into the font map.  If no such list
# is passed, a default list is used instead.  The default list is comprised of
# the font families Times, Courier and Helvetica, and pitches 8, 9, 10, 12, 14
# and 15 for each family.  Two public functions are provided:
#
# (2) function ::fontmap::is_mapped_font ( font-map font-spec )
#     returns 0 if the passed font-spec is mapped in font-map , otherwise 1.
#
# (3) function ::fontmap::font_map_for ( font-families-and-pitches-list )
#     returns a custom font map, initialised from the list of font families
#     and pitches passed or the default font list if no list is passed.
#
# Example:
#
#   import ::fontmap::font_map_for
#   ...
#   canvas postscript -fontmap\
#     [font_map_for {FreeSans 12 14} {FreeSerif 12 14} {FreeMono 10}]
#
# ****************************************************************************

namespace eval ::fontmap {

# ----------------------------------------------------------------------------
# EXPORT
# ----------------------------------------------------------------------------
# Public functions and procedures.
#
namespace export font_name_list_for is_mapped_font font_map_for

# ----------------------------------------------------------------------------
# PRIVATE VAR DEBUG : ORD OF CARDINAL;
# ----------------------------------------------------------------------------
# Debugging flag. Value of 0 indicates FALSE, 1 indicates TRUE.
#
variable DEBUG 0


# ----------------------------------------------------------------------------
# PRIVATE CONST regular = 0; slanted = 1; boldface = 2; slanted_boldface = 3;
# ----------------------------------------------------------------------------
# Enumerated font style values, used as indices in lists encoding font styles.
#
variable regular 0
variable slanted 1
variable boldface 2
variable slanted_boldface 3


# ----------------------------------------------------------------------------
# PRIVATE CONST default_suffixes = {"", "-Italic", "-Bold", "-BoldItalic"};
# ----------------------------------------------------------------------------
# Default postscript font style suffix strings in the format:
# {regular-suffix slanted-suffix bold-suffix slanted-bold-suffix}
#
variable default_suffixes {"" "-Italic" "-Bold" "-BoldItalic"}


# ----------------------------------------------------------------------------
# PRIVATE CONST known_irregulars =
#   { LIST OF { font_family : LIST 1 OF String; styles : LIST 4 OF String } };
# ----------------------------------------------------------------------------
# List of known irregular postscript font style suffixes, in the format:
# {family} {regular-suffix slanted-suffix bold-suffix slanted-bold-suffix}
# Empty string denotes no suffix, nil denotes unavailable style.
#
variable known_irregulars {
  {DejaVuSans}      {"" "-Oblique" "-Bold" "-BoldOblique"}
  {DejaVuSansMono}  {"" "-Oblique" "-Bold" "-BoldOblique"}
  {FreeSans}        {"" "Oblique" "Bold" "BoldOblique"}
  {FreeSerif}       {"" "Italic" "Bold" "BoldItalic"}
  {FreeMono}        {"" "Oblique" "Bold" "BoldOblique"}
  {NotoSans}        {"-Regular" "-Italic" "-Bold" "-BoldItalic"}
  {NotoSerif}       {"-Regular" "-Italic" "-Bold" "-BoldItalic"}
  {NotoMono}        {"-Regular" nil nil nil}
  {UbuntuMono}      {"-Regular" "-Italic" "-Bold" "-BoldItalic"}
  {UbuntuCondensed} {"-Regular" nil nil nil}
}; # end known_irregulars


# ----------------------------------------------------------------------------
# PRIVATE CONST default_fonts =
#   { LIST OF { font_family : String; pitches : LIST >0 OF CARDINAL } };
# ----------------------------------------------------------------------------
# Default font list, used by function font_map_for if no arguments are passed.
#
variable default_fonts {
  {Times 8 9 10 12 14 15}
  {Courier 8 9 10 12 14 15}
  {Helvetica 8 9 10 12 14 15}
}; # end default_fonts


# ----------------------------------------------------------------------------
# PRIVATE VAR initialized_default_font_map : ORD OF CARDINAL;
# ----------------------------------------------------------------------------
# Initialisation status flag. Value of 0 indicates FALSE, 1 indicates TRUE.
#
variable initialized_default_font_map 0


# ----------------------------------------------------------------------------
# PRIVATE VAR default_font_map : ARRAY OF {
#   key : LIST 1 OF { font_family : String; pitch : CARDINAL;
#     OPTIONAL style1 : String; OPTIONAL style2 : String };
#   value : LIST 1 OF { ps_name : String; pitch : CARDINAL } };
# ----------------------------------------------------------------------------
# Font map to be returned by function font_map_for if no arguments are passed.
# Initialised by function font_map_for the first time it is to be returned.
#
variable default_font_map;

}; # end ::fontmap


# ----------------------------------------------------------------------------
# PRIVATE FUNCTION tk_spelling_for ( font_family : String ) : String;
# ----------------------------------------------------------------------------
# Returns string with the internal TCL/TK spelling for given font family.
#

proc ::fontmap::tk_spelling_for {font_family} {
  set tk_spelling ""
  set font_spec [list $font_family 10]
  set font_actual [font actual $font_spec]
  set tk_font_family [lindex $font_actual 1]

  foreach word $tk_font_family {
    append tk_spelling [string totitle $word]
  }; # end foreach

  return $tk_spelling
} ;# end ::fontmap::tk_spelling_for


# ----------------------------------------------------------------------------
# PRIVATE FUNCTION ps_spelling_for ( font_family : String ) : String;
# ----------------------------------------------------------------------------
# Returns string with the postscript spelling for given font family.
#
proc ::fontmap::ps_spelling_for {font_family} {
  set ps_spelling ""
  set font_spec [list $font_family 10]
  set font_actual [font actual $font_spec]
  set ps_font_family [lindex $font_actual 1]

  foreach word $ps_font_family {
    append ps_spelling $word
  }; # end foreach

  return $ps_spelling
}; # end ::fontmap::ps_spelling_for


# ----------------------------------------------------------------------------
# PRIVATE FUNCTION suffix_list_for
#   ( font_family : String ) : LIST 4 OF String;
# ----------------------------------------------------------------------------
# Returns list of postscript font style suffixes for given font family.
#
proc ::fontmap::suffix_list_for {font_family} {

  variable default_suffixes
  variable known_irregulars

  # check if font family is listed in known irregulars
  set index [lsearch $known_irregulars $font_family]

  # if it is irregular, return its suffix list
  if {$index>0} {
    return [lindex $known_irregulars [expr $index+1]]

  # if it is regular, return the default suffix list
  } else {
    return $default_suffixes
  }; # end if
}; # end ::fontmap::suffix_list_for


# ----------------------------------------------------------------------------
# PUBLIC FUNCTION font_name_list_for
#   ( font_family : String ) : LIST 4 OF String;
# ----------------------------------------------------------------------------
# Returns list of postscript font names for given font family.
#
proc ::fontmap::font_name_list_for {font_family} {

  # get font style suffixes for font family
  set suffix_list [suffix_list_for $font_family]

  # init font name list
  set font_name_list {}

  # build font name from family and suffix for each style
  # and append it to the font name list

  # for every font style ...
  foreach suffix $suffix_list {

    # build font name from family and suffix
    if {$suffix!="nil"} {
      set font_name "$font_family$suffix"

    # or nil if font style is unavailable
    } else {
      set font_name nil
    }; # end if

    # append the result to the font name list
    lappend font_name_list $font_name
  }; # end foreach

  # return the font name list
  return $font_name_list
}; # end ::fontmap::font_name_list_for


# ----------------------------------------------------------------------------
# PRIVATE PROCEDURE add_entry
#   ( font_map : ARRAY; tk_name : String;
#     pitch : CARDINAL; styles : LIST OF String; ps_name : String );
# ----------------------------------------------------------------------------
#
proc add_entry {font_map tk_name pitch styles ps_name} {
  upvar $font_map fmap

  # add font map entry of the form
  # {{tk_name pitch {styles}} {ps_name pitch}}
  array set fmap [list [list $tk_name $pitch $styles] [list $ps_name $pitch]]
}; # end add_entry


# ----------------------------------------------------------------------------
# PUBLIC FUNCTION font_map_for
#   ( req_font_list : LIST OF
#       { font_family : String; pitches : LIST >0 OF CARDINAL } ) : ARRAY;
# ----------------------------------------------------------------------------
# Returns a font map for all available styles of given font families for their
# given pitches, using  spell dictionary  and  irregular style suffixes  where
# necessary.  If  no argument  or  an empty list is passed,  default font list
# default_fonts is used as a default argument instead.
#
# The structure of the returned font map is:
#
# ARRAY OF {
#   key : LIST 1 OF { font_family : String; pitch : CARDINAL;
#     OPTIONAL style1 : String; OPTIONAL style2 : String };
#   value : LIST 1 OF { ps_name : String; pitch : CARDINAL }
# };
#
# where (1) both style1 and style2 are omitted,
# or (2) style1 is "italic" and style2 is omitted,
# or (3) style1 is "bold" and style2 is omitted,
# or (4) style1 is "bold" and style2 is "italic".
#
proc ::fontmap::font_map_for {req_font_list} {
  variable DEBUG

  # enumerated font style values
  variable regular
  variable slanted
  variable boldface
  variable slanted_boldface

  # defaults
  variable default_fonts
  variable default_font_map
  variable initialized_default_font_map

  # return default font map if no argument passed
  if {[llength $req_font_list]==0} {
    if {!$initialized_default_font_map} {
      set default_font_map [font_map_for $default_fonts]
      set initialized_default_font_map 1
    }; # end if
    return $default_font_map
  }; # end if

  # new empty font map
  array set font_map {}

  # for every font requested ...
  foreach req_font $req_font_list {

    # get font family and pitches
    set req_family [lindex $req_font 0]
    set pitch_list [lrange $req_font 1 end]

    # get tk and ps spellings of font family
    set tk_family [tk_spelling_for $req_family]
    set ps_family [ps_spelling_for $req_family]

    # two entries needed if spellings don't match
    set needs_double_entry [expr {"$tk_family" ne "$ps_family"}]

    # get postscript font names for font family
    set font_name_list [font_name_list_for $ps_family]

    # add font map entries for font names in all listed pitches
    foreach pitch $pitch_list {

      # add fontmap entry or entriesfor regular face, if available
      # example {Foosans 10} {FooSans 10}
      set font_name [lindex $font_name_list $regular]
      if {"$font_name" ne "nil"} {
        add_entry font_map $tk_family $pitch {} $font_name
        if {$needs_double_entry} {
          add_entry font_map $ps_family $pitch {} $font_name
        }; # end if
      }; # end if

      # add fontmap entry or entries for slanted face
      # example {Foosans 10 italic} {FooSans-Italic 10}
      set font_name [lindex $font_name_list $slanted]
      if {"$font_name" ne "nil"} {
        add_entry font_map $tk_family $pitch italic $font_name
        if {$needs_double_entry} {
          add_entry font_map $ps_family $pitch italic $font_name
        }; # end if
      }; # end if

      # add fontmap entry or entries for bold face
      # example {Foosans 10 bold} {FooSans-Bold 10}
      set font_name [lindex $font_name_list $boldface]
      if {"$font_name" ne "nil"} {
        add_entry font_map $tk_family $pitch bold $font_name
        if {$needs_double_entry} {
          add_entry font_map $ps_family $pitch bold $font_name
        }; # end if
     }; # end if

      # add fontmap entry or entries for slanted bold face
      # example {Foosans 10 bold italic} {FooSans-BoldItalic 10}
      set font_name [lindex $font_name_list $slanted_boldface]
      if {"$font_name" ne "nil"} {
        add_entry font_map $tk_family $pitch {bold italic} $font_name
        if {$needs_double_entry} {
          add_entry font_map $ps_family $pitch {bold italic} $font_name
        }; # end if
      }; # end if

    }; # end foreach
  }; # end foreach

  #set DEBUG 1
  if {$DEBUG} {
    set elem_count [array size font_map]
    puts "font_map has $elem_count entries"
    parray font_map
  }; # end if

  # return result
  return [array get font_map]
}; # end ::fontmap::font_map_for


# ----------------------------------------------------------------------------
# PUBLIC FUNCTION is_mapped_font
#   ( font_map : ARRAY;
#     font_spec : LIST 1 OF { font_family : String; pitch : CARDINAL;
#     OPTIONAL style1 : String; OPTIONAL style2 : String } ) : ORD OF BOOLEAN;
# ----------------------------------------------------------------------------
# Returns  ORD(TRUE) = 1  if the given font spec  is present in the given font
# map, otherwise returns ORD(FALSE) = 0.
#
proc ::fontmap::is_mapped_font {font_map font_spec} {
  return {[llength [array get font_map $font_spec]]!=0}
}; # end ::fontmap::is_mapped_font


# ****************************************************************************
# Test harness below -- Not part of the library
# ****************************************************************************

# ============================================================================
# Namespace page -- text output to canvas
# ============================================================================
#
namespace eval ::page {
  namespace export init set_font write_string writeln write_ps_file
  variable .c
  variable font_size 10; # default
  variable font_family Helvetica; # default
  variable fonts_used {}
  variable x_pos
  variable y_pos
}; # end ::page


# ----------------------------------------------------------------------------
# Initialise namespace page
# ----------------------------------------------------------------------------
#
proc ::page::init {width height} {
  variable .c
  variable default_font
  variable x_pos
  variable y_pos

  canvas .c -width $width -height $height; pack .c
  set x_pos [expr $width/2]
  set y_pos 20
}; # end ::page::init


# ----------------------------------------------------------------------------
# Set font family and pitch for page output
# ----------------------------------------------------------------------------
#
proc ::page::set_font {family size} {
  variable font_size
  variable font_family

  set font_size $size
  set font_family $family
}; # end ::page::set_font_spec


# ----------------------------------------------------------------------------
# Add font family and pitch to list of used fonts and pitches
# ----------------------------------------------------------------------------
#
proc ::page::add_font_and_pitch {font_family pitch} {
  variable fonts_used

  # search used fonts for font family entry
  set index 0
  set family_and_pitches {}
  foreach entry $fonts_used {
    if {$font_family==[lindex $entry 0]} {
      set family_and_pitches $entry
      break
    }; # end if
    incr index
  }; # end foreach

  # append new entry if not found
  if {[llength $family_and_pitches]==0} {
    lappend fonts_used [list $font_family $pitch]

  # replace existing entry adding pitch if found
  } else {
    # search for pitch in existing entry
    set pitch_list [lrange $family_and_pitches 1 end]

    # if pitch is not in list,
    if {[lsearch $pitch_list $pitch]<0} {
      # append pitch
      lappend pitch_list $pitch
      # sort appended pitch list
      set pitch_list [lsort -integer $pitch_list]
      # replace old pitch list in entry with new list
      set family_and_pitches [linsert $pitch_list 0 $font_family]
      # replace old entry in fonts used with new entry
      set fonts_used [lreplace $fonts_used $index $index $family_and_pitches]
    }; # end if
  }; # end if
}; # end ::page::add_font_and_pitch


# ----------------------------------------------------------------------------
# Write string to page
# ----------------------------------------------------------------------------
#
proc ::page::write_string {style_list string} {
  variable .c
  variable font_family
  variable font_size
  variable x_pos
  variable y_pos

  set font_spec [list $font_family $font_size]
  lappend font_spec $style_list

  # add font and pitch to list of used fonts, if not already in list
  add_font_and_pitch $font_family $font_size

  # write text to canvas, advance y and update display
  .c create text $x_pos $y_pos -font $font_spec -text $string
  set y_pos [expr $y_pos+$font_size+10]
  update
}; # end ::page::write_string


# ----------------------------------------------------------------------------
# Write EOL to page
# ----------------------------------------------------------------------------
#
proc ::page::writeln {} {
  variable font_size
  variable y_pos

  set y_pos [expr $y_pos+$font_size+10]
}; # end ::page::writeln


# ----------------------------------------------------------------------------
# Write page to postscript file
# ----------------------------------------------------------------------------
#
proc ::page::write_ps_file {filename} {
  namespace import ::fontmap::font_map_for
  variable .c
  variable fonts_used

  array set font_map [font_map_for $fonts_used]

  .c postscript -fontmap font_map -file $filename
}; # end ::page::write_ps_file


# ---------------------------------------------------------------------------
# Fonts to be tested
# ---------------------------------------------------------------------------
#
set font_size 18
set font_list {DejaVuSans FreeSans LiberationSans NotoSans Ubuntu}
set sample_text "ABC abc 123"

namespace import ::page::init
namespace import ::page::set_font
namespace import ::page::writeln
namespace import ::page::write_string
namespace import ::page::write_ps_file

init 250 685

foreach font_family $font_list {
  set_font $font_family $font_size
  write_string {} $sample_text
  write_string italic $sample_text
  write_string bold $sample_text
  write_string {bold italic} $sample_text
  writeln
}; # end foreach

write_ps_file sample.ps

# EOF
