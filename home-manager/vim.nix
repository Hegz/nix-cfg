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
                  '';
    #plugins = [ pkgs.vimPlugins.cmp-copilot ];
    settings = {
      background = "dark";
      copyindent = true;
      number = true;
      shiftwidth = 4;
      tabstop = 4;
    };
  };
}
