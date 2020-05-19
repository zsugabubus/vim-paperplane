" LICENSE: GPLv3 or later
" AUTHOR: zsugabubus
silent! nnoremap <unique><silent> <C-W>Z :above pedit vim-paperplane://<CR>
if get(g:, 'paperplane_doscrollmappings', 0) !=# 0
	if has('nvim')
		silent! nnoremap <unique><silent> <C-E> <C-E><Cmd>call paperplane#update()<CR>
		silent! nnoremap <unique><silent> <C-Y> <C-Y><Cmd>call paperplane#update()<CR>
		silent! vnoremap <unique><silent> <C-E> <C-E><Cmd>call paperplane#update()<CR>
		silent! vnoremap <unique><silent> <C-Y> <C-Y><Cmd>call paperplane#update()<CR>
	else
		silent! nnoremap <unique><silent> <C-E> <C-E>:call paperplane#update()<CR>
		silent! nnoremap <unique><silent> <C-Y> <C-Y>:call paperplane#update()<CR>
		silent! vnoremap <unique><silent> <C-E> <C-E>:<C-U>call paperplane#update()<CR>gv
		silent! vnoremap <unique><silent> <C-Y> <C-Y>:<C-U>call paperplane#update()<CR>gv
	endif
endif

" Keep it undocumented for a while.
augroup vim_paperplane_patterns
	autocmd!
	let g:paperplane_patterns = ['\w', '\w%(\k*\s*:\s*$)@!']
	autocmd FileType c,cpp let b:paperplane_patterns = get(b:, 'paperplane_patterns', ['\w', '\w.*[^:]\s*$'])
augroup END

function! s:idle()
	augroup vim_paperplane
		autocmd!
		autocmd BufAdd vim-paperplane:// noautocmd call s:active()
	augroup END
endfunction

function! s:active()
	execute bufnr('vim-paperplane://').'bwipeout'
	call paperplane#_update()
	augroup vim_paperplane
		autocmd!
		autocmd CursorMoved,CursorHold * noautocmd call paperplane#_update()
		autocmd VimResized * noautocmd call paperplane#_update(1)
		autocmd OptionSet number,relativenumber,numberwidth,signcolumn,tabstop noautocmd call paperplane#_update(1)
		autocmd BufUnload vim-paperplane:// call s:idle()
	augroup END
endfunction

call s:idle()
