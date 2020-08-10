function! context#line#make(number, indent, text) abort
    return context#line#make_highlight(a:number, '', a:indent, a:text, '')
endfunction

function! context#line#make_trimmed(number, indent, text) abort
    let trimmed_text = context#line#trim(a:text)
    return {
                \ 'number':         a:number,
                \ 'number_char':    '',
                \ 'indent':         a:indent,
                \ 'indent_chars':   len(a:text) - len(trimmed_text),
                \ 'text':           trimmed_text,
                \ 'highlight':      '',
                \ }
endfunction

function! context#line#make_highlight(number, number_char, indent, text, highlight) abort
    return {
                \ 'number':         a:number,
                \ 'number_char':    a:number_char,
                \ 'indent':         a:indent,
                \ 'indent_chars':   a:indent,
                \ 'text':           a:text,
                \ 'highlight':      a:highlight,
                \ }
endfunction

let s:nil_line = context#line#make(0, 0, '')

" find line downwards (from given line) which isn't empty
function! context#line#get_base_line(line) abort
    let current_line = a:line
    while 1
        let indent = g:context.Indent(current_line)
        if indent < 0 " invalid line
            return s:nil_line
        endif

        let text = getline(current_line)
        if context#line#should_skip(text)
            let current_line += 1
            continue
        endif

        return context#line#make(current_line, indent, text)
    endwhile
endfunction

" returns list of [line, [highlights]]
" where each highlight is [hl, col, width]
function! context#line#display(winid, join_parts) abort
    let col = 1 " TODO: can we infer this from len(text) or something?
    let text = ''
    let highlights = []
    let part0 = a:join_parts[0]

    let c = getwinvar(a:winid, 'context')

    " NOTE: we use non breaking spaces for padding in order to not show
    " 'listchars' in the sign and number columns

    " sign column
    let width = c.sign_width
    if width > 0
        let part = repeat(' ', width)
        let width = len(part)
        call add(highlights, ['SignColumn', col, width])
        let text .= part
        let col += width
    endif

    " number column
    let width = c.number_width
    if width > 0
        if part0.number_char != ''
            " NOTE: we use a non breaking space here because number_char can
            " be border_char
            let part = repeat(part0.number_char, width-1) . ' '
        else
            if &relativenumber
                let n = c.cursor_line - part0.number
            elseif &number
                let n = part0.number
            endif
            " let part = printf('%*d ', width - 1, n)
            let part = repeat(' ', width-len(n)-1) . n . ' '
        endif

        let width = len(part)
        call add(highlights, ['LineNr', col, width])
        let text .= part
        let col += width
    endif

    " indent
    " TODO: use `space` to fake tab listchars?
    " let [_, space, text; _] = matchlist(part0.text, '\v^(\s*)(.*)$')
    if part0.indent > 0
        let part = repeat(' ', part0.indent)
        let width = len(part)
        " NOTE: this highlight wouldn't be necessary for popup, but is added
        " to make it easier to assemble the statusline for preview
        call add(highlights, ['Normal', col, width])
        let text .= part
        let col += width
    endif

    " text
    let prev_hl = ''
    for j in range(0, len(a:join_parts)-1)
        let join_part = a:join_parts[j]
        let text .= join_part.text

        " " highlight individual join parts for debugging
        " let width = len(join_part.text)
        " let hl = j % 2 == 0 ? 'Search' : 'IncSearch'
        " call add(highlights, [hl, col, width])
        " let col += width

        let width = 0

        if join_part.highlight != ''
            let width = len(join_part.text)
            call add(highlights, [join_part.highlight, col, width])
            let col += width
            let width = 1
            continue
        endif

        for line_col in range(1+join_part.indent_chars, join_part.indent_chars + len(join_part.text)+1) " TODO: only up to windowwidth
            let hlgroup = synIDattr(synIDtrans(synID(join_part.number, line_col, 1)), 'name')

            if hlgroup == prev_hl " TODO: add col < end condition?
                let width += 1
                continue
            endif

            if prev_hl != ''
                call add(highlights, [prev_hl, col, width])
            endif

            let prev_hl = hlgroup
            let col += width
            let width = 1
        endfor
        let col += width-1
    endfor

    return [text, highlights]
endfunction

" TODO: make this an s: function? only used in here
function! context#line#trim(string) abort
    return substitute(a:string, '^\s*', '', '')
endfunction

function! context#line#should_extend(line) abort
    return a:line =~ g:context.regex_extend
endfunction

function! context#line#should_skip(line) abort
    return a:line =~ g:context.regex_skip
endfunction

function! context#line#should_join(line) abort
    if g:context.max_join_parts < 1
        return 0
    endif

    return a:line =~ g:context.regex_join
endfunction
