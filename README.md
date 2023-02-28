# anyline.nvim
Indentation Lines with Animations for Neovim

Thought about naming this animeline.nvim but that might have been a little to cringe
This is my first attempt at creating neovim plugins and more importantly, my quest on creating useless plugins.

> **Warning**  
> Highly experimental.  
> Only tested in neovide and neovim inside terminal  
> Super buggy  


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
        config = true,
        event = 'VeryLazy',
    },
})
```
### Usage
```lua
require('anyline').setup()
```
Or just put `config = true` in lazy as shown above.  
Lazy loading should work. I use `event = 'VeryLazy'` as shown above.

### Config
```lua
{
    -- visual stuff
    indent_char = '▏', -- character to use for the line
    highlight = 'Comment', -- color of non active indentatino lines
    context_highlight = 'ModeMsg', -- color of the context under the cursor

    -- animation stuff / fine tuning
    debounce_time = 30, -- how responsive to make to make the cursor movements (in ms, very low debounce time is kinda janky at the moment)
    fps = 30, -- changes how many steps are used to transition from one color to another
    fade_duration = 200, -- color fade speed (only used when lines_per_second is 0)
    length_acceleration = 0.05, -- increase animation speed depending on how long the context is

    lines_per_second = 50, -- how many lines/seconds to show
    trail_length = 10, -- how long the trail / fade transition should be

    -- other stuff
    priority = 19, -- extmark priority
    priority_context = 20,
    ft_ignore = {
        'NvimTree',
        'TelescopePrompt',
        'alpha',
    },
}
```

# TODOS
- [X] add user opts to setup function
- [ ] nice api for animation, so anyone can create dope looking animations
