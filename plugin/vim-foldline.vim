" let g:FoldLine_Enable = 1
let g:FoldLine_MaxFoldTextLength = 40
let g:FoldLine_Trial = '...'

" Base {{{
function Foldtext_base(...)
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
    " remove any remaining leading or trailing whitespace {{{
    let line = substitute(line, '^\s*\(.\{-}\)\s*$', '\1', '')
    " }}}
    " remove text if it exceeds the maximal length {{{
    if (strlen(line) > g:FoldLine_MaxFoldTextLength)
      let line = strpart(line, 0, g:FoldLine_MaxFoldTextLength)
      let line = strpart(line, 0, strridx(line, " "))
      let line = line . g:FoldLine_Trial
    endif
    " }}}
    " align everything, and pad the end of the display with - {{{
    let alignment = &columns - 18 - v:foldlevel
    let line = strpart(printf('%-' . alignment . 's', line), 0, alignment)
    let line = substitute(line, '\%( \)\@<= \%( *$\)\@=', '-', 'g')
    " }}}
    " format the line count {{{
    let cnt = printf('%13s', '(' . (v:foldend - v:foldstart + 1) . ' lines) ')
    " }}}
    return '+-' . cnt . ">> " . line . v:folddashes . ' '
endfunction
" }}}
" Latex {{{
let s:latex_types = {'thm': 'Theorem', 'cor':  'Corollary',
                   \ 'lem': 'Lemma',   'defn': 'Definition'}
function s:lower_letter(i) " {{{
    return tolower(s:upper_letter(a:i))
endfunction " }}}
function s:roman_numeral(i) " {{{
    let numeral = ''
    let chars = 'ivxlcdm'
    let i = a:i
    for base in [0, 2, 4]
        let c1 = strpart(chars, base, 1)
        let c5 = strpart(chars, base + 1, 1)
        let c10 = strpart(chars, base + 2, 1)
        let digit = i % 10
        if digit == 1
            let numeral = c1 . numeral
        elseif digit == 2
            let numeral = c1 . c1 . numeral
        elseif digit == 3
            let numeral = c1 . c1 . c1 . numeral
        elseif digit == 4
            let numeral = c1 . c5 . numeral
        elseif digit == 5
            let numeral = c5 . numeral
        elseif digit == 6
            let numeral = c5 . c1 . numeral
        elseif digit == 7
            let numeral = c5 . c1 . c1 . numeral
        elseif digit == 8
            let numeral = c5 . c1 . c1 . c1 . numeral
        elseif digit == 9
            let numeral = c1 . c10 . numeral
        endif
        let i = i / 10
        if i == 0
            break
        end
    endfor

    return repeat('m', i) . numeral
endfunction " }}}
function s:upper_letter(i) " {{{
    if a:i <= 26
        return nr2char(char2nr('A') + a:i - 1)
    else
        return 'ERROR'
    endif
endfunction " }}}
function s:enumeration(depth, index) " {{{
    if a:depth == 0
        return a:index + 1
    elseif a:depth == 1
        return '(' . s:lower_letter(a:index + 1) . ')'
    elseif a:depth == 2
        return s:roman_numeral(a:index + 1)
    elseif a:depth == 3
        return s:upper_letter(a:index + 1)
    else
        return 'Error: invalid depth'
    endif
endfunction " }}}
function Foldtext_latex() " {{{
    let line = getline(v:foldstart)
    " format theorems/etc nicely {{{
    let matches = matchlist(line, '\\begin{\([^}]*\)}')
    if !empty(matches) && has_key(s:latex_types, matches[1])
        let type = s:latex_types[matches[1]]
        let label = ''
        let linenum = v:foldstart - 1
        while linenum <= v:foldend
            let linenum += 1
            let line = getline(linenum)
            let matches = matchlist(line, '\\label{\([^}]*\)}')
            if !empty(matches)
                let label = matches[1]
                break
            endif
        endwhile
        if label != ''
            let label = ": " . label
        endif
        return Foldtext_base(type . label)
    endif
    " }}}
    " format list items nicely {{{
    " XXX: nesting different types of lists doesn't give quite the correct
    " result - an enumerate inside an itemize inside an enumerate should use
    " (a), but here it will go back to using 1.
    if line =~ '\\item'
        let item_name = []
        let item_depth = 0
        let nesting = 0
        let type = ''
        for linenum in range(v:foldstart, 0, -1)
            let line = getline(linenum)
            if line =~ '\\item'
                if nesting == 0
                    let label = matchstr(line, '\\item\[\zs[^]]*\ze\]')
                    if len(item_name) == item_depth
                        if label != ''
                            let item_name += [label]
                        else
                            let item_name += [0]
                        endif
                    else
                        if type(item_name[item_depth]) == type(0) && label == ''
                            let item_name[item_depth] += 1
                        endif
                    endif
                endif
            elseif line =~ '\\begin{document}'
                break
            elseif line =~ '\\begin'
                if nesting > 0
                    let nesting -= 1
                else
                    let new_type = matchstr(line, '\\begin{\zs[^}]*\ze}')
                    if type == ''
                        let type = new_type
                    elseif type != new_type
                        let item_name = item_name[0:-2]
                        break
                    endif
                    let item_depth += 1
                endif
            elseif line =~ '\\end'
                let nesting += 1
            endif
        endfor
        " XXX: vim crashes if i just reverse the actual list
        " should be fixed in patch 7.1.287
        "let item_name = reverse(item_name)
        let item_name = reverse(deepcopy(item_name))
        for i in range(len(item_name))
            if type(item_name[i]) != type('')
                let item_name[i] = s:enumeration(i, item_name[i])
            endif
        endfor
        let type = toupper(strpart(type, 0, 1)) . strpart(type, 1)
        let line = type . ': ' . join(item_name, '.')
        return Foldtext_base(line)
    endif
    " }}}
    return Foldtext_base(line)
endfunction " }}}
" }}}
" C++ {{{
function Foldtext_cpp()
    let line = getline(v:foldstart)
    " strip out // comments {{{
    let block_open = stridx(line, '/*')
    let line_open = stridx(line, '//')
    if block_open == -1 || line_open < block_open
        return Foldtext_base(substitute(line, '//', ' ', ''))
    endif
    " }}}
    return Foldtext_base(line)
endfunction
" }}}

set foldtext=Foldtext_base()

if exists("g:FoldLine_enable") && g:FoldLine_enable
    set foldtext=Foldtext_base()
endif
if exists("g:Foldtext_tex_enable") && g:Foldtext_tex_enable
    autocmd FileType tex  setlocal foldtext=Foldtext_latex()
endif
if exists("g:Foldtext_cpp_enable") && g:Foldtext_cpp_enable
    autocmd FileType cpp  setlocal foldtext=Foldtext_cpp()
endif
