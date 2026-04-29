{ inputs, outputs, lib, config, pkgs, ... }:
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
      set statusline+=%#warningmsg#
      set statusline+=%{SyntasticStatuslineFlag()}
      set statusline+=%*

      let g:syntastic_always_populate_loc_list = 1
      let g:syntastic_auto_loc_list = 1
      let g:syntastic_check_on_open = 1
      let g:syntastic_check_on_wq = 0

      let g:llama_config.endpoint = 'http://embiggen.taild7a71.ts.net:8012/infill'
      let g:llama_config.model = 'coder'
      let g:llama_config.ssl_verify = 0  " Tailscale often uses HTTP, disable SSL check if unsure
      let g:llama_config.timeout = 30000  " 30 seconds timeout (Tailscale can have latency)
      " Enable LSP/Plugin logging
      let g:llama_config.log_level = "debug"
      " Or enable specific file logging
      let g:llama_config.log_file = "/tmp/lama_vim.log"
    '';
    plugins = with pkgs.vimPlugins; [ 
      #cmp-copilot 
      syntastic 
      fugitive 
      llama-vim
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
