" LICENSE: GPLv3 or later
" AUTHOR: zsugabubus
let s:bufnr = 0 " Buffer number that preview is displayed for.
let s:changenr = 0 " changenr() of this buffer.
let s:tree = {} " lnum -> { parent lnum | 0 }
let s:bottom = 0 " First shown line in the preview (the bottom one).
let s:nw = 0 " Width of number column (not includes the space).
let s:sw = 0 " Width of sign column.
let s:ts = 0 " Size of a tab.
let s:ww = 0 " Width of preview window.

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
	if a:0 ># 0
		let [s:nw, s:sw, s:ts, s:ww] = [0, 0, 0, 0]
	endif

	let lnum = line('.')
	let w0 = line('w0')

	let changenr = changenr()
	let bufnr = bufnr()

	if s:bufnr ==# bufnr && s:changenr ==# changenr && s:ts ==# &ts
		let fromlnum = lnum
		if has_key(s:tree, fromlnum)
			while fromlnum >=# w0
				let fromlnum = s:tree[fromlnum]
			endwhile
			if fromlnum ==# s:bottom
				return
			endif
		endif
	else
		let s:tree = {}
		let s:bottom = 0
	endif

	let s:changenr = changenr
	let s:bufnr = bufnr

	let s:ts = &ts

	let view = winsaveview()
	let timeout = get(g:, 'paperplane_timeout', 10)

	call cursor(0, 1)
	let fromlnum = lnum
	if !has_key(s:tree, fromlnum) && searchpos('\v\C^\s*\zs\w(.*[^:])?$', 'Wc')[0] !=# 0
		" Current line may changed because of the search.
		let fromlnum = line('.')
		let indent = virtcol('.')
		let first_tolnum = 0
		let maylabel = 1

		while indent ># 1
			let [tolnum, tocol] = searchpos('\v\C^\s*%<'.indent.'v\zs\w'.(maylabel ? '' : '%(\k+\s*:\s*$)@!'), 'Wb', 0, timeout)
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

			if maylabel && match(getline('.'), '\v\C^\s*\k+\s*:\s*$') !=# -1
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
		while fromlnum ># 0
			let fromlnum = s:tree[fromlnum]
			let plnum += 1
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
			call setbufvar(bufnr, '&statusline', printf('%%#Folded#%*s%*d %%#Normal#', sw, '', nw, w0 - currbottom - 1))
		else
			call setbufvar(bufnr, '&statusline', printf('%%#Folded#%*s%%#Normal#', sw, ''))
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
			" Replace leading tabs with spaces.
			let [line, white, text; _] = matchlist(getline(fromlnum), '\v^(\s*)(.*)$')
			let pline = repeat(' ', strdisplaywidth(white)).text

			let from = 1 + sw
			if nw ># 0
				call setbufline(bufnr, plnum, printf('%*s%*d %s', sw, '', nw, (&relativenumber ? abs(lnum - fromlnum) : fromlnum), pline))
				call matchaddpos('LineNr', [[plnum, from, nw + 1]], 10, -1, {'window': pwinid})
				let from += nw + 1
			else
				call setbufline(bufnr, plnum, printf('%*s%s', sw, '', pline))
			endif

			if fromlnum <=# s:bottom
				" Compare with previous nw and sw. If any changed lines have moved
				" horizontally.
				if nw ==# 0 || !&relativenumber
					" Do not even have to update line numbers
					break
				endif
			else
				let end = min([len(line), ww])

				let count = 0
				let prevhl = 'Normal'
				let leading_white = 1
				let vcoldiff = 0
				for col in range(1, end + 1)
					let hlgroup = synIDattr(synIDtrans(synID(fromlnum, col, 1)), 'name')
					if hlgroup ==# prevhl && col <# end
						let count += 1
					else
						if !empty(prevhl)
							call matchaddpos(prevhl, [[plnum, from, count]], 0, -1, {'window': pwinid})
						endif
						let prevhl = hlgroup
						let from += count
						let count = 1
					endif
					if leading_white
						if line[col - 1] ==# "\t"
							let tw = &tabstop - ((col - 1 + vcoldiff) % &tabstop) - 1
							let count += tw
							let vcoldiff += tw
						elseif line[col - 1] !~# '\s'
							let leading_white = 0
						endif
					endif
				endfor
			endif

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
