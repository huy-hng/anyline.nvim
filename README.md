# anyline.nvim
Indentation Lines with Animations for Neovim

Thought about naming this animeline.nvim but that might have been a little to cringe

> **Warning**
> Highly experimental.
> Only tested in neovide and neovim inside terminal
> Currently no options available, but will change shortly

### Showcase
https://user-images.githubusercontent.com/33007237/221636629-bd10a0aa-f302-40f8-9d34-e0f12cd7c44b.mp4

Note: cursor animation comes from [Neovide](https://neovide.dev/)

### Installation
Use the package manager of your choice
```lua
require('lazy').setup({
    {
        'huy-hng/anyline.nvim',
        dependencies = { 'nvim-treesitter/nvim-treesitter' }
    },
})
```
### Usage
```lua
require('anyline').setup()
```

# TODOS
- [ ] add user opts to setup function
