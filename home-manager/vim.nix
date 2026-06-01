{ inputs, outputs, lib, config, pkgs, secrets, ... }:
# Vim configuration options
{
  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      set nocompatible
      filetype plugin indent on
      syntax on
      noremap <space> za
      set foldmethod=indent
      set foldlevel=99
      if has("autocmd")
        autocmd BufReadPost * if line("'\"") > 0 && line ("'\"") <= line("$") | exe "normal g'\"" | endif
      endif
      "set statusline+=%#warningmsg#
      "set statusline+=%{SyntasticStatuslineFlag()}
      "set statusline+=%*

      "let g:syntastic_always_populate_loc_list = 1
      "let g:syntastic_auto_loc_list = 1
      "let g:syntastic_check_on_open = 1
      "let g:syntastic_check_on_wq = 0

	  " llama.vim - initialise after plugins are loaded
	  function! SetupLlama()
		if exists('g:llama_config') && type(g:llama_config) == v:t_dict
		  " already initialised by plugin, just set our values
		else
		  let g:llama_config = {}
		endif
        let g:llama_config.endpoint      = 'http://${secrets.llama.host}:${secrets.llama.port}/infill'
        let g:llama_config.endpoint_inst = 'http://${secrets.llama.host}:${secrets.llama.port}/completion' 
		let g:llama_config.model         = 'fim-coder'
		let g:llama_config.n_prefix      = 256
	  	let g:llama_config.n_suffix      = 64
		let g:llama_config.n_predict     = 128
		let g:llama_config.auto_fim      = v:true
		let g:llama_config.show_info     = 1
		let g:llama_config.t_max_prompt_ms  = 500
		let g:llama_config.t_max_predict_ms = 3000
		let g:llama_config.log_level     = 'debug'
		let g:llama_config.log_file      = '/tmp/llama_vim.log'
	  endfunction

	  autocmd VimEnter * call SetupLlama()
      colorscheme dracula
    '';
    plugins = with pkgs.vimPlugins; [ 
      # syntastic 
      # fugitive 
      llama-vim
      dracula-vim
      gruvbox
    ];
    settings = {
      background = "dark";
      copyindent = true;
      number = true;
      shiftwidth = 4;
      tabstop = 4;
    };
  };
}
