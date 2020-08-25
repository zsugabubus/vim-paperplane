" LICENSE: GPLv3 or later
" AUTHOR: zsugabubus
let s:bufnr = 0 " Buffer number that preview is displayed for.
let s:winnr = 0 " Window number that preview is displayed for.
let s:changenr = 0 " changenr() of this buffer.
let s:tree = {} " lnum -> { parent lnum | 0 }
let s:bottom = 0 " First shown line in the preview (the bottom one).
let s:nw = 0 " Width of number column (not includes the space).
let s:sw = 0 " Width of sign column.
let s:ts = 0 " Size of a tab.
let s:ww = 0 " Width of preview window.

let s:colnumfmt = '%%#Folded#%*s%*d %%#Normal#'
let s:colfmt = '%%#Folded#%*s%%#Normal#'

" Is paperline buffer shown?
function! paperplane#isactive() abort
	return bufnr('vim-paperplane://') !=# -1
endfunction

" Update buffer if shown.
function! paperplane#update(...) abort
	if paperplane#isactive()
		noautocmd call call('paperplane#_update', a:000)
	endif
endfunction

" Force update. This one will create buffer if does not exist.
function! paperplane#_update(...) abort
	" On option update reset everything.
	if a:0 ># 0
		let [s:nw, s:sw, s:ts, s:ww] = [0, 0, 0, 0]
	endif

	let lnum = line('.')
	let w0 = line('w0')

	let changenr = changenr()
	let bufnr = bufnr()
	let winnr = winnr()

	if s:winnr !=# winnr && s:bottom ># 0
		silent! pclose
		let s:bottom = 0
	endif
	if s:bufnr ==# bufnr && s:changenr ==# changenr && s:ts ==# &ts
		if s:winnr ==# winnr
			let fromlnum = lnum
			if has_key(s:tree, fromlnum)
				while fromlnum >=# w0
					let fromlnum = s:tree[fromlnum]
				endwhile
				if fromlnum ==# s:bottom
					" Redraw just line numbers.
					if s:nw ># 0
						let bufnr = bufnr('vim-paperplane://')
						call setbufvar(bufnr, '&statusline', printf(s:colnumfmt, s:sw, '', s:nw, w0 - s:bottom - 1))
						" Update relative line numbers.
						if &relativenumber
							let plnum = 0
							while fromlnum ># 0
								let fromlnum = s:tree[fromlnum]
								let plnum += 1
							endwhile

							let fromlnum = s:bottom
							while fromlnum ># 0
								let newline = printf('%*s%*d%s', s:sw, '', s:nw, abs(lnum - fromlnum), getbufline(bufnr, plnum)[0][s:sw + s:nw:])
								call setbufline(bufnr, plnum, newline)

								let fromlnum = s:tree[fromlnum]
								let plnum -= 1
							endwhile
						endif
					endif

					return
				endif
			endif
		endif
	else
		let s:tree = {}
		let s:bottom = 0
	endif

	let s:changenr = changenr
	let s:bufnr = bufnr
	let s:winnr = winnr

	let s:ts = &ts

	let view = winsaveview()
	let timeout = get(g:, 'paperplane_timeout', 10)

	call cursor(0, 1)
	let [anypat, nolabelpat] = get(b:, 'paperplane_patterns', g:paperplane_patterns)
	let fromlnum = lnum
	if !has_key(s:tree, fromlnum) && searchpos('\v\C^\s*\zs'.nolabelpat, 'Wc')[0] !=# 0
		" Current line may changed because of the search.
		let fromlnum = line('.')
		let indent = virtcol('.')
		let first_tolnum = 0
		let maylabel = 1

		while indent ># 1
			let [tolnum, tocol] = searchpos('\v\C^\s*%<'.indent.'v\zs'.(maylabel ? anypat : nolabelpat), 'Wb', 0, timeout)
			if tolnum ==# 0
				break
			endif

			let iscomment = synIDattr(synIDtrans(synID(tolnum, tocol, 1)), 'name') =~? '\mcomment|string'
			if iscomment
				continue
			endif

			" Set parent indent for original line because search() may jumped off
			" that at the beginning.
			if first_tolnum ==# 0
				let first_tolnum = tolnum
			endif
			" Build the tree.
			let s:tree[fromlnum] = tolnum
			let fromlnum = tolnum
			" We already know the next indent.  We can exit now.
			if has_key(s:tree, fromlnum)
				break
			endif

			if maylabel && match(getline('.'), '\v\C^\s*'.nolabelpat) ==# -1
				let maylabel = 0
			else
				let indent = virtcol('.')
				let maylabel = 1
			endif
		endwhile
		" Only set if untouched, otherwise it may cause a two-long loop: First
		" search from start line -> inner search back to start line (that already
		" points to this line).
		if !has_key(s:tree, lnum)
			" ...plus avoid infinite loops.
			let s:tree[lnum] = lnum !=# first_tolnum ? first_tolnum : 0
		endif
	endif
	" Terminate the branch of the tree.
	if !has_key(s:tree, fromlnum)
		let s:tree[fromlnum] = 0
	endif

	" Go up on the tree until we reach an off-screen line.
	let fromlnum = lnum
	while fromlnum >=# w0
		let fromlnum = s:tree[fromlnum]
	endwhile
	let currbottom = fromlnum
	if fromlnum ==# 0
		silent! pclose
	else
		let oldmode = mode()

		silent! wincmd P
		if !&previewwindow || bufname() !=# 'vim-paperplane://'
			let bufnr = bufnr('vim-paperplane://', 1)
			above pedit vim-paperplane://

			call setbufvar(bufnr, '&bufhidden', 'unload')
			call setbufvar(bufnr, '&buflisted', 0)
			call setbufvar(bufnr, '&buftype', 'nofile')
			call setbufvar(bufnr, '&cursorline', 0)
			call setbufvar(bufnr, '&tabstop', &tabstop)
			call setbufvar(bufnr, '&list', 0)
			call setbufvar(bufnr, '&number', 0)
			call setbufvar(bufnr, '&number', 0)
			call setbufvar(bufnr, '&relativenumber', 0)
			call setbufvar(bufnr, '&signcolumn', 'no')
			call setbufvar(bufnr, '&swapfile', 0)
			call setbufvar(bufnr, '&syntax', 0)
			call setbufvar(bufnr, '&undolevels', -1)
			call setbufvar(bufnr, '&wrap', 0)
			silent! wincmd P
		else
			let bufnr = bufnr()
		endif

		" Size increased. Reset highlights now.
		if s:bottom <# currbottom
			let s:bottom = 0 " Needed for below to indicate that all rows must be reset.
			call clearmatches()
		endif

		" Find height of the tree. Go until we reach the root.
		let plnum = 0
		let nlines = line('$')
		while fromlnum ># 0
			let fromlnum = s:tree[fromlnum]
			let plnum += 1
			" `setline()` will not work on non-existent lines.
			if plnum >=# nlines
				call append(plnum, '')
			endif
		endwhile
		execute 'resize' plnum

		let pwinid = winnr()
		wincmd p

		if &number || &relativenumber
			let nw = max([&numberwidth - 1, float2nr(ceil(log10(line('$'))))])
		else
			let nw = 0
		endif

		let oldve = &ve
		let oldcole = &cole
		set ve=all
		set cole=0
		let sw = wincol() - virtcol('.') - (nw ># 0 ? nw + 1 : 0)
		let &ve = oldve
		let &cole = oldcole

		if nw ># 0
			call setbufvar(bufnr, '&statusline', printf(s:colnumfmt, sw, '', nw, w0 - currbottom - 1))
		else
			call setbufvar(bufnr, '&statusline', printf(s:colfmt, sw, ''))
		endif
		let ww = winwidth(pwinid)

		" If any option changed, every line must be reset.
		if nw !=# s:nw || sw !=# s:sw || ww !=# s:ww
			let s:bottom = 0 " Reset
			wincmd P
			call clearmatches()
			wincmd p
		endif

		let fromlnum = currbottom
		while fromlnum ># 0
			if fromlnum <=# s:bottom
				" Compare with previous nw and sw. If any changed lines have moved
				" horizontally.
				if nw ==# 0 || !&relativenumber
					" Do not even have to update line numbers
					break
				endif
			endif

			let line = getline(fromlnum)

			if sw > 0
				call matchaddpos('SignColumn', [[plnum, 1, sw]], 10, -1, {'window': pwinid})
			endif
			if nw ># 0
				call matchaddpos('LineNr', [[plnum, 1 + sw, nw + 1]], 10, -1, {'window': pwinid})
				let pline = printf('%*s%*d ', sw, '', nw, (&relativenumber ? abs(lnum - fromlnum) : fromlnum))
			else
				let pline = printf('%*s', sw, '')
			endif

			let [_, tabx, taby, tabz; _] = matchlist((&list ? &listchars.',tab:' : 'tab:  '), '\v%(^|,)tab:([^,]?)([^,]?)([^,]?)')
			let [_, space; _] = matchlist((&list ? &listchars : '').',space: ', '\v%(^|,)space:([^,])')

			let from = strlen(pline)
			let prevhl = ''
			let col = 1
			let vcol = 0
			while line !=# '' && vcol <# ww
				let chr = strcharpart(line, 0, 1)
				let line = strcharpart(line, 1)
				let width = strdisplaywidth(chr, vcol)
				let vcol += width
				let to = strlen(pline)
				if chr ==# "\t"
					if tabx ==# ''
						let hlgroup = 'SpecialKey'
						let pline .= '^I'
					else
						let hlgroup = 'NonText'
						let pline .= tabx.repeat(taby, width - 1 - strlen(tabz)).(width >=# 2 ? tabz : '')
					end
				elseif chr ==# ' '
					let hlgroup = 'NonText'
					let pline .= space
				else
					let hlgroup = synIDattr(synIDtrans(synID(fromlnum, col, 1)), 'name')
					let pline .= chr
				endif
				let col += strlen(chr)
				if prevhl !=# hlgroup
					call matchaddpos(prevhl, [[plnum, from + 1, to - from]], 0, -1, {'window': pwinid})
					let prevhl = hlgroup
					let from = to
				endif
			endwhile
			let to = strlen(pline)
			call matchaddpos(prevhl, [[plnum, from + 1, to - from]], 0, -1, {'window': pwinid})
			if line ==# ''
				let from = to
				let [_, eol; _] = matchlist((&list ? &listchars : '').',eol: ', '\v%(^|,)eol:([^,])')
				let pline .= eol
				let to = strlen(pline)
				call matchaddpos('NonText', [[plnum, from + 1, to - from]], 0, -1, {'window': pwinid})
			endif

			call setbufline(bufnr, plnum, pline)

			let fromlnum = s:tree[fromlnum]
			let plnum -= 1
		endwhile

		let s:nw = nw
		let s:sw = sw
		let s:ww = ww

		if oldmode ==? 'v' || oldmode ==# "\<C-V>"
			normal! gv
		endif
	endif
	let s:bottom = currbottom
	call winrestview(view)
endfunction
