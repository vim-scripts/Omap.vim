" File: Omap.vim
" Author: Ben Collerson
" Version: 1.0
" Last Modified: 23 Mar 2005
" License: General Public License version 2 or later.
"          http://www.gnu.org/copyleft/gpl.html
"-------------------------------------------------------------------------------

if exists("loaded_Omap")
  finish
endif
let loaded_Omap = 1

" stores a list of the keys used to differentiate Omaps
let s:Omap_keys = ''

"-------------------------------------------------------------------------------
" DotCommand 
" This section provides a generic method to enable mapped commands to be
" repeated using the dot (.) repeat command.
" This should eventually be in its own separate file.
"
" The ideas here are borrowed from the yankring.vim plugin written
" by David Fishburn
" See: http://www.vim.org/scripts/script.php?script_id=1234
" This code is reused under the terms of the GPL version 2.
" License: http://www.gnu.org/copyleft/gpl.html

" DotCommandClear() - initialises/resets dotcommand variables             " {{{
function! s:DotCommandClear()
    let s:dc_operation        = ''
    let s:dc_prev_reg_unnamed = ''
    let s:dc_prev_reg_small   = ''
    let s:dc_prev_reg_insert  = ''
    let s:dc_prev_vis_lstart  = 0
    let s:dc_prev_vis_lend    = 0
    let s:dc_prev_vis_cstart  = 0
    let s:dc_prev_vis_cend    = 0
endf                                                                      " }}}

" DotCommandSet(operation) - Sets the keysequence to repeat               " {{{
" for the next press of the dot (.) repeat command. 
function! s:DotCommandSet(operation) 
    let s:dc_operation        = a:operation
    let s:dc_prev_reg_unnamed = getreg('"')
    let s:dc_prev_reg_small   = getreg('-')
    let s:dc_prev_reg_insert  = getreg('.')
    let s:dc_prev_vis_lstart  = line("'<")
    let s:dc_prev_vis_lend    = line("'>")
    let s:dc_prev_vis_cstart  = col("'<")
    let s:dc_prev_vis_cend    = col("'>")
endf                                                                      " }}}

" DotCommandRepeat() - Repeats a previous command if there                " {{{
" has been no change in a set of registers/settings, otherwise
" it will do a "normal! ." command.
" This is a simple and clever solution, credit goes to David Fishburn. ;-)
function! s:DotCommandRepeat()
  if s:dc_prev_reg_unnamed     == getreg('"') &&
        \ s:dc_prev_reg_small  == getreg('-') &&
        \ s:dc_prev_reg_insert == getreg('.') &&
        \ s:dc_prev_vis_lstart == line("'<") &&
        \ s:dc_prev_vis_lend   == line("'>") &&
        \ s:dc_prev_vis_cstart == col("'<") &&
        \ s:dc_prev_vis_cend   == col("'>") &&
        \ s:dc_operation       != ''

    exec 'normal '.s:dc_operation
    call s:DotCommandSet(s:dc_operation)
    
  else " repeat normally!
    exec "normal! ."
  endif
endf                                                                      " }}}

" DotCommand initialisation, commands, and mappings                       " {{{
command -nargs=1 DotCommandSet :call <sid>DotCommandSet(<args>)
command -nargs=0 DotCommandClear :call <sid>DotCommandClear()

map <silent> <plug>DotCommandRepeat :call <sid>DotCommandRepeat()<cr>
map <silent> <plug>DotCommandClear :call <sid>DotCommandClear()<cr>

"map <silent> <leader>. <plug>DotCommandClear
map <silent> . <plug>DotCommandRepeat

" initialise dot command
call s:DotCommandClear()
                                                                          " }}}

"-------------------------------------------------------------------------------
" The following two functions are originally from :help eval-examples
" I assume they are by Bram Moolenaar
"
" These functions are used to encode a key sequence into a string of hex
" digits. This hex string can then be put into identifiers relating to the
" Omap using the foo{bar} notation. This system will be replaced using the 
" dictionary type once Vim 7 is released.

" The function Nr2Hex() returns the Hex string of a number.               " {{{
function! s:Nr2Hex(nr)
  let n = a:nr
  let r = ""
  while n
    let r = '0123456789ABCDEF'[n % 16] . r
    let n = n / 16
  endwhile
  return r
endf                                                                      " }}}

" The function String2Hex() converts each character in a string to a two  " {{{
" character Hex string.
" BEC 10/03/2005 - added a leading '0' to single hex digits
function! s:String2Hex(str)
  let out = ''
  let ix = 0
  while ix < strlen(a:str)
    let hex = s:Nr2Hex(char2nr(a:str[ix]))
    let hex = strlen(hex) < 2 ? '0' . hex : hex
    let out = out . hex
    let ix = ix + 1
  endwhile
  return out
endf                                                                      " }}}

"-------------------------------------------------------------------------------
" These two functions are based on functions taken from the foo.vim collection
" of functions written by Benji Fisher.
" The original foo.vim file is availiable at 
" URL: http://www.vim.org/script.php?script_id=72
"
" My various modifications are noted below. - BJC

" Getchar() - get a character - return a string                           " {{{
" The built-in getchar() function! returns a Number for an 8-bit character,
" and a String for any other character.  This version always returns a 
" String.
" BJC 08/03/2005 - added support for timeout option 
" BJC 22/03/2005 - commented out the timeout stuff - wasn't working like I
"                  thought it should
" TODO: fix timeout stuff
function! s:Getchar()
"  if &timeout
"    let time = 0
"    while time <= &timeoutlen
"      let c = getchar(0)
"      if !(s:IsZero(c))
"        break
"      endif
"      let time = time + 100
"      sleep 100m
"    endw
"  else
    let c = getchar()
"  endif
  if c != 0
    let c = nr2char(c)
  endif
  return c
endf                                                                      " }}}

" GetMotion() - Get a sequence of characters that describe a motion.      " {{{
" BJC 08/03/2005 - added support for some more obscure motions (like g'x)
" BJC 08/03/2005 - now returns the value 0 if it times out
" BJC 12/03/2005 - modified to return a "normalised" motion of the
"                  form: visualmode [count] motion 
" BJC 22/03/2005 - changes the shape of the cursor to indicate simulated
"                  operator pending mode.
" BJC 23/03/2005 - line motion is now last motion checked for
" TODO: support user defined omaps/vmaps
function! s:GetMotion(lhs)
  let cnt = v:count1 
  let visual = 'v'
  let motion = '' 

  let _guicursor = &guicursor
  let &guicursor = substitute(&guicursor,'o:\([^,]*\),','n:\1','')
  let c = s:Getchar()
  if s:IsZero(c) || c == "\<esc>"
    let &guicursor = _guicursor
    return 0
  endif

  " Capture any sequence of digits (a count) and visual modifiers.
  " :help o_v
  " Note: this loop starts with an if statement because ``0 is actually 
  " a motion not a count.
  while c =~ "[1-9vV\<C-V>]"
    if c =~ "[1-9]"
      let newcnt = c
      let c = s:Getchar()
      if s:IsZero(c) || c == "\<esc>"
        let &guicursor = _guicursor
        return 0
      endif
      while c =~ "[[:digit:]]"
        let newcnt = (newcnt * 10) + c
        let c = s:Getchar()
        if s:IsZero(c) || c == "\<esc>"
          let &guicursor = _guicursor
          return 0
        endif
      endwhile
      let cnt = cnt * newcnt
    endif

    if c =~ "[vV\<C-V>]"
      visual = c
      let c = s:Getchar()
      if s:IsZero(c) || c == "\<esc>"
        let &guicursor = _guicursor
        return 0
      endif
    endif
  endwhile


  " Most motions are a single character, but some two-character motions start
  " with 'g'.  For example,
  " :help gj
  if c ==# "g"
    let motion = motion . c
    let c = s:Getchar()
    if s:IsZero(c) || c == "\<esc>"
      let &guicursor = _guicursor
      return 0
    endif
    " check for g's three character motions
    if c =~ "['`]"
      let motion = motion . c
      let c = s:Getchar()
      if s:IsZero(c) || c == "\<esc>"
        let &guicursor = _guicursor
        return 0
      endif
      let motion = motion . c
    endif

  " Text objects start with 'a' or 'i'.  :help text-objects
  " Jump to a mark with "'" or "`".  :help 'a
  " added [ and ] motions
  " also added t,f,T,and F motions
  elseif c =~ "[ai'`\\[\\]tfTF]"
    let motion = motion . c
    let c = s:Getchar()
    if s:IsZero(c) || c == "\<esc>"
      let &guicursor = _guicursor
      return 0
    endif
    let motion = motion . c

  elseif c ==# 'w'
    " motion w means e
    let motion = motion . 'e'

  elseif c ==# 'W'
    " motion W mens E
    let motion = motion . 'E'

  " In some contexts, eg. ``yy'', a particular character counts as a motion.
  " Repeat last character for whole line motion.
  elseif a:lhs != '' && c ==# a:lhs[strlen(a:lhs)-1]
    " special motion like that in yy 
    let cnt = cnt - 1
    let motion = cnt < 1 ? '' : 'j'
    let cnt = cnt < 1 ? 1 : cnt
    let visual = 'V'

"  repeat the operator for a line motion -- doesn't currently work
"  elseif a:lhs != '' && c ==# a:lhs[0]
"    let ix = 1
"    while ix < strlen(a:lhs)
"      let c = s:Getchar()
"      if s:IsZero(c) || c == "\<esc>" || c !=# a:lhs[ix]
"        let &guicursor = _guicursor
"        return 0
"      endif
"      let ix = ix + 1
"    endw
"    let cnt = cnt - 1
"    let motion = cnt < 1 ? '' : 'j'
"    let cnt = cnt < 1 ? 1 : cnt
"    let visual = 'V'

  else
    " single character motion...
    let motion = motion . c
  endif

  let &guicursor = _guicursor
  return visual.(cnt>1 ? cnt : '').motion
endf                                                                      " }}}

"-------------------------------------------------------------------------------
" I wrote this stuff from scratch

" IsZero() - returns true if argument is a number that is zero            " {{{
function! s:IsZero(num)
  return type(a:num) == 0 && a:num == 0
endf                                                                      " }}}

" IsLinewise(): returns 1 if motion should be considered linewise,        " {{{
"               0 otherwise 
function! s:IsLinewise(motion)
  if a:motion =~ '\v^\d*('
        \ .'[\[\]]{2}'
        \ .'|ap|ip|gg'
        \ ."|\<c-end>"
        \ ."|\<c-home>"
        \ ."|\<down>"
        \ ."|\<up>"
        \ .'|[-GjkLM+_'
        \ ."\<c-n>\<c-p>\<c-j>\<c-m>\<nl>\<cr>]"
        \ .')$'
    return 1
  endif
  return 0
endf                                                                      " }}}

" DoOmap(): executes an operator mapping                                  " {{{
function! s:DoOmap(lhs) range

  let cnt = v:count1
  let key = s:String2Hex(a:lhs)

  if !exists('s:Omaps'.key.'lhs')
    " error no Omap for this key
    return 1
  endif

  let cmd = s:Omaps{key}{'rhs'}

  let motion = s:GetMotion(a:lhs)
  if s:IsZero(motion)
    " timed out
    return 0
  endif

  let _whichwrap = &whichwrap
  set whichwrap=

  if motion !~ "^[ \t]*$"
      execute 'normal ' . motion
      execute 'normal ' . a:lhs
  endif


  if s:Omaps{key}startinsert == 1
    if col(".") == 1
      startinsert
    elseif col(".") < (col("$") - 1)
      normal! l
      startinsert
    else
      startinsert!
    endif
  endif

  let &whichwrap = _whichwrap 

  DotCommandSet motion.a:lhs

endf                                                                     " }}}

" AddOmap() - Adds an operator                                           " {{{
function! s:AddOmap(...)
  if a:0 == 1
    return s:PrintOmap()
  elseif a:0 == 2
    return s:PrintOmap(a:2)
  endif

  let remap = a:1

  let startinsert = 0
  let lhs = ''
  let options = ''
  let rhs = ''
  let i = 2
  while i <= a:0

    if a:{i} =~ '<\%(buffer\|silent\|script\|unique\)>' 
      let options = (options == '') ? a:{i} : options.' '.a:{i}

    " experimental option to simulate behavior of |c| command -- finishes
    " command in insert mode, but currently won't work properly with the
    " dotcommand stuff.
    elseif a:{i} =~ '<startinsert>'  
      let startinsert = 1

    elseif lhs == ''
      let lhs = a:{i}
    else 
      let rhs = (rhs == '') ? a:{i} : rhs.' '.a:{i}
    endif

    let i = i + 1
  endw

  let lhs = substitute(lhs,'\c<leader>', (exists('mapleader') ? 'mapleader' : '\\'), 'g')

  let key = s:String2Hex(lhs)

  " remove any existing Omapping
  call s:RemoveOmap(lhs)

  let s:Omap_keys = (s:Omap_keys == '') ? key.',' : s:Omap_keys.key.',' 

  let s:Omaps{key}lhs = lhs
  let s:Omaps{key}rhs = rhs
  let s:Omaps{key}buffer = (options =~ '<buffer>' ? 1 : 0)
  let s:Omaps{key}silent = (options =~ '<silent>' ? 1 : 0)
  let s:Omaps{key}script = (options =~ '<script>' ? 1 : 0)
  let s:Omaps{key}unique = (options =~ '<unique>' ? 1 : 0)
  let s:Omaps{key}startinsert = startinsert

  exe 'n' . (!remap ? 'nore' : '') . 'map ' . options . ' ' . lhs . " :call <sid>DoOmap('".lhs."')<cr>"
  if lhs != rhs
    " in case you overload a builtin operator
    exe 'v' . (!remap ? 'nore' : '') . 'map ' . options . ' ' . lhs . ' ' . rhs
  endif
endf                                                                      " }}}

" PrintOmap() - prints an Omap in the same format (mostly)                " {{{
"               as the :map command
function! s:PrintOmap(...)
  let prefix = (a:0 > 0) ? s:String2Hex(a:1) : ''
  " print all
  if strlen(s:Omap_keys) == 0
    return 0
  endif
  let key = matchstr(s:Omap_keys,'^\x*')
  if key == ''
    return 0
  endif
  let i = 1
  while 1
    if key =~ '^'.prefix.'\x*'
      echo 'O  '.s:Omaps{key}{'lhs'}." \t\t ".s:Omaps{key}{'rhs'}
    endif
    let key = matchstr(s:Omap_keys,'^\%(\x*,\)\{'.i.'}\zs\x*')
    if key == ''
      return 0
    endif
    let i = i + 1
  endw
endf                                                                      " }}}

" RemoveOmap() - removes specified Omap                                   " {{{
function! s:RemoveOmap(lhs)
  let key = s:String2Hex(a:lhs)

  if !exists('s:Omaps'.key.'lhs')
    return 1
  endif

  let s:Omap_keys = substitute(s:Omap_keys,key.',','','')

  unlet s:Omaps{key}lhs 
  unlet s:Omaps{key}rhs
  unlet s:Omaps{key}buffer
  unlet s:Omaps{key}silent
  unlet s:Omaps{key}script
  unlet s:Omaps{key}unique
  unlet s:Omaps{key}startinsert

  try
    exe "nunmap ".a:lhs
  catch /E31/
  endtry

  try
    exe "vunmap ".a:lhs
  catch /E31/
  endtry
endf                                                                      " }}}

" RemoveAllOmaps() - removes all defined Omaps                            " {{{
function! s:RemoveAllOmaps()
  if strlen(s:Omap_keys) == 0
    return 0
  endif
  while 1
    let key = matchstr(s:Omap_keys,'^\x*')
    if key == ''
      return 0
    endif
    call s:RemoveOmap(s:Omaps{key}{'lhs'})
  endw
endf                                                                      " }}}

" OmapBuiltins() - overloads the standard builtin operators with Omaps    " {{{
" * used for testing *
function! s:OmapBuiltins() "
  Onoremap <silent> <startinsert> c c
  Onoremap <silent> d d
  Onoremap <silent> y y
  if &tildeop
    Onoremap <silent> char> ~ ~
  endif
  Onoremap <silent> g~ g~
  Onoremap <silent> gu gu
  Onoremap <silent> gU gU
  Onoremap <silent> ! !
  Onoremap <silent> = =
  Onoremap <silent> gq gq
  Onoremap <silent> g? g?
  Onoremap <silent> > >
  Onoremap <silent> < <
  Onoremap <silent> zf zf
endf                                                                      " }}}

" OmapDump() - prints out all Omaps                                       " {{{
function! s:OmapDump() 
  echo "keys: ".s:Omap_keys
  let key = matchstr(s:Omap_keys,'^\x*')
  if key == ''
    return 0
  endif
  let i = 1
  while 1
    echo '---- '.key
    echo '   lhs       : '.s:Omaps{key}lhs 
    echo '   rhs       : '.s:Omaps{key}rhs
    echo '   buffer    : '.s:Omaps{key}buffer
    echo '   silent    : '.s:Omaps{key}silent
    echo '   script    : '.s:Omaps{key}script
    echo '   unique    : '.s:Omaps{key}unique
    let key = matchstr(s:Omap_keys,'^\%(\x*,\)\{'.i.'}\zs\x*')
    if key == ''
      return 0
    endif
    let i = i + 1
  endw
endf                                                                      " }}}

" Commands - the commands are defined here                                " {{{
command! -nargs=* Omap :call <sid>AddOmap(1,<f-args>)
command! -nargs=* Onoremap :call <sid>AddOmap(0,<f-args>)
command! -nargs=1 Ounmap :call <sid>RemoveOmap(<f-args>)
command! -nargs=0 Omapclear :call <sid>RemoveAllOmaps()

" testing:
command! -nargs=0 OmapBuiltins :call <sid>OmapBuiltins()
command! -nargs=0 OmapDump :call <sid>OmapDump()
                                                                          " }}}

" vim:ft=vim:sw=2:fdm=marker:ff=unix
