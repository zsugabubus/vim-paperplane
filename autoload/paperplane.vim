" LICENSE: GPLv3 or later
" AUTHOR: zsugabubus
function! paperplane#isactive() abort
	return bufnr('vim-paperplane://') !=# -1
endfunction

function! paperplane#update() abort
	if paperplane#isactive()
		noautocmd call paperplane#_update()
	endif
endfunction

function! paperplane#_update() abort
	let view = winsaveview()
	let curlnum = line('.')
	let from = line('.') - 1
	let iter = []

	" let wl = winline()
	let w0 = line('w0')
	let timeout = get(b:, 'paperplane_timeout', 10)
	" let type = get(g:, 'paperplane_type', 'preview')

	call cursor(0, 1)
	if searchpos('\v\C^\s*\zs\S(.*[^:])?$', 'Wc', 0, timeout)[0] !=# 0
		let indent = virtcol('.')
		let maylabel = 1

		while 1
			let [tolnum, tocol] = searchpos('\v\C^\s*%<'.indent.'v\zs\S'.(maylabel ? '.*\w' : '.*\w.*[^:]\s*$'), 'Wb', 0, timeout)
			if tolnum ==# 0
				break
			endif

			let iscomment = synIDattr(synIDtrans(synID(tolnum, tocol, 1)), 'name') =~? '\mcomment|string'
			if iscomment
				continue
			endif

			if tolnum <# w0 - 1
				call add(iter, tolnum)
			endif
			" if tolnum + 1 <# from
			" 	call add(iter, [from, tolnum + 1])
			" endif
			let from = tolnum - 1

			if maylabel && match(getline('.'), '\m\C:\s*$') !=# -1
				let maylabel = 0
			else
				let indent = virtcol('.')
				let maylabel = 1
			endif
		endwhile
	endif

	if empty(iter)
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
		execute 'resize' len(iter)

		call clearmatches()
		let pwinid = winnr()
		wincmd p

		let nw = max([&numberwidth - 1, float2nr(ceil(log10(line('$'))))])
		let sw = wincol() - virtcol('.') - (nw + 1)
		call setbufvar(bufnr, '&statusline', printf('%%#SignColumn#%*s%%#Folded#%*d %%#Normal#', sw, '', nw, w0 - (iter[0] + 1)))
		let plnum = 0
		let lnum = from

		for lnum in reverse(iter)
			let plnum += 1
			" Replace leading tabs with spaces.
			let [line, white, text; _] = matchlist(getline(lnum), '\v(^\s*)(.*)$')
			let pline = repeat(' ', strdisplaywidth(white)).text

			let from = 1 + sw
			if &number || &relativenumber
				call setbufline(bufnr, plnum, printf('%*s%*d %s', sw, '', nw, (&relativenumber ? abs(curlnum - lnum) : lnum), pline))
				call matchaddpos('LineNr', [[plnum, from, nw + 1]], 10, -1, {'window': pwinid})
				let from += nw
			else
				call setbufline(bufnr, plnum, pline)
			end

			let end = min([len(line), winwidth(pwinid)])

			let count = 0
			let prevhl = 'Normal'
			let indent = 1
			let vcoldiff = 0
			for col in range(0, end + 1)
				let hlgroup = synIDattr(synIDtrans(synID(lnum, col, 1)), 'name')
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
				if indent
					if line[col] ==# "\t"
						let tw = &ts - ((col + vcoldiff) % &ts) - 1
						let count += tw
						let vcoldiff += tw
					elseif line[col] !~# '\s'
						let ident = 0
					endif
				endif
			endfor
		endfor

		if oldmode ==? 'v' || oldmode ==# "\<C-V>"
			normal! gv
		endif
	endif

	" if !empty(iter)
	" 	setlocal foldmethod=manual
	" 	let oldmode = mode()
  "
	" 	silent! normal! 1GVGzD
  "
	" 	let view.topline = from + 1
	" 	let diffs = [copy(iter)]
	" 	while 1
	" 		call winrestview(view)
	" 		if empty(iter)
	" 			break
	" 		endif
  "
	" 		execute 'normal!' iter[-1][1].'Gzf'.iter[-1][0].'G'
	" 		call winrestview(view)
  "
	" 		if view.topline >=# line('w0')
  "
	" 			let wl2 = winline()
  "
	" 			let diff = wl2 - wl + (line('w0') - view.topline)
	" 			call add(diffs, string({'len': iter[-1][0] - iter[-1][1],'wldiff': diff.'/'.(iter[-1][0] - iter[-1][1]), 'iter': iter[-1], 'lnum': line('.')}))
  "
	" 			execute 'normal!' iter[-1][1].'Gzd'.(iter[-1][0] + diff >=# iter[-1][1] ? iter[-1][1].'Gzf'.(iter[-1][0] + diff).'G' : '')
  "
	" 			break
	" 		else
	" 			call add(diffs, 'nw0: '.line('w0').'^'.view.topline)
	" 		endif
  "
	" 		unlet iter[-1]
	" 	endwhile
  "
	" 	\" echom string(diffs)
	" 	if oldmode ==? 'v' || oldmode ==# \"\<C-V>\"
	" 		normal! gv
	" 	endif
	" endif

	call winrestview(view)
endfunction
