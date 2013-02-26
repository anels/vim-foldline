let g:FoldLine_Enable = 1
let g:FoldLine_MaxFoldTextLength = 40
let g:FoldLine_Trial = '...'

function FoldLine_truncate(text) " {{{
  let text = a:text
  if (strlen(text) > g:FoldLine_MaxFoldTextLength)
    let text = strpart(text, 0, g:FoldLine_MaxFoldTextLength)
    let text = strpart(text, 0, strridx(line, " "))
    let text = text . g:FoldLine_Trial
  endif
  return text
endfunction " }}}

" Returns a copy of the string, with leading and trailing whitespace omitted.
function FoldLine_trim(text) " {{{
  let text = substitute(a:text, '^\s*\(.\{-}\)\s*$', '\1', '')
  return text
endfunction " }}}

" General Fold Line {{{
function FoldLine_general(...)
    " use the argument for display if possible, otherwise the current line {{{
    if a:0 > 0
        let line = a:1
    else
        let line = getline(v:foldstart)
    endif
    " }}}
    " remove the marker that caused this fold from the display {{{
    let foldmarkers = split(&foldmarker, ',')
    let line = substitute(line, '\V' . foldmarkers[0] . '\%(\d\+\)\?', ' ', '')
    " }}}
    " remove comments that vim knows about {{{
    let comment = split(&commentstring, '%s')
    if comment[0] != ''
        let comment_begin = comment[0]
        let comment_end = ''
        if len(comment) > 1
            let comment_end = comment[1]
        end
        let pattern = '\V' . comment_begin . '\s\*' . comment_end . '\s\*\$'
        if line =~ pattern
            let line = substitute(line, pattern, ' ', '')
        else
            let line = substitute(line, '.*\V' . comment_begin, ' ', '')
            if comment_end != ''
                let line = substitute(line, '\V' . comment_end, ' ', '')
            endif
        endif
    endif
    " }}}
    let line = FoldLine_trim(line)
    if(strlen(line) == 0)
      let line = getline(v:foldstart + 1)
      let line = FoldLine_trim(line)
    endif
    " Truncate text if it exceeds the maximal length {{{
    let line = FoldLine_truncate(line)
    " }}}
    " align everything, and pad the end of the display with - {{{
    let alignment = &columns - 18 - v:foldlevel
    let line = strpart(printf('%-' . alignment . 's', line), 0, alignment)
    let line = substitute(line, '\%( \)\@<= \%( *$\)\@=', '-', 'g')
    " }}}
    " format the line count {{{
    let cnt = printf('%12s', '(' . (v:foldend - v:foldstart + 1) . ' lines)')
    " }}}
    return '+-' . cnt . " >> " . line . v:folddashes . ' '
endfunction
" }}}

if exists("g:FoldLine_Enable")
  if g:FoldLine_Enable
    set foldtext=FoldLine_general()
  endif
endif
