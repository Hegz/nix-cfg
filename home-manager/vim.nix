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
                  '';
    plugins = [ pkgs.vimPlugins.cmp-copilot pkgs.vimPlugins.syntastic pkgs.vimPlugins.fugitive ];
    settings = {
      background = "dark";
      copyindent = true;
      number = true;
      shiftwidth = 4;
      tabstop = 4;
    };
  };
}
