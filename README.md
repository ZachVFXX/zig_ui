# ZUI – Under Construction

A Zig UI library that do to much, built for personal projects.

Made possible by using [Raylib](https://github.com/raysan5/raylib.git) for rendering and input handling and [Clay](https://github.com/nicbarker/clay) (using this [bindings](https://github.com/johan0A/clay-zig-bindings.git)) for layout computation.

Using **Zig 0.16.0**

## Features

Currently available:

* Column
* Row
* Scroll
* Button
* Slider
* Text
* Image

Widgets are created using `app.X`.

## Installation to test demo (WIP)

```bash
git clone https://github.com/ZachVFXX/zig_ui.git
cd zig_ui/
zig build test
```


## Installation to your project

```bash
zig fetch --save git+https://github.com/ZachVFXX/zig_ui.git
```


## Example

```zig
pub fn main(init: std.process.Init) !void {
    var app = try zu.App.init(init.arena.allocator(), "Widget test", 720, 720, .{});
    defer app.uninit();

    const font_data = @embedFile("assets/Roboto-Regular.ttf");
    try app.loadFont(font_data, 0, 20);
    
    while (!app.is_closing()) {
        app.update(); // Clear internal arena and state 
        
        // Track any key press
        for (app.events.items) |ev| {
            switch (ev) {
                .key_pressed => |k| {
                    // ...
                },
                else => {},
            }
        }

        app.beginLayout();
        
        const button = app.Button(.ID("Click"), .{}, .{});
        
        const root = app.Row(.ID("root"), .{
            .sizing = .grow,
            .padding = .{ .top = 16, .bottom = 16, .left = 16, .right = 16 },
            .color = .{ .role = .surface },
        }, .{
            // Other widgets
            button,
        });
        
        if (button.clicked()) {
            // Do something here
        }

        app.endLayout(root);
        try app.render();
    }
}
```

## Custom Widgets

Custom widgets can be created using Clay and other widgets by defining a struct with parameters and a render function:

```zig
pub fn render(ptr: *anyopaque, w: Widget, children: []const Widget) void
```

Children can be ignored, or rendered manually:

```zig
for (children) |child| child.render();
```

This allows forwarding rendering to child widgets.

## Contributing

Explore `src/widgets` to understand how widgets are implemented, the structure is straightforward.

Contributions are welcome through feature suggestions or issues.
AI-generated pull requests are not accepted (AI can be used for writing messages if needed).

Be precise. Be responsible. Be kind.
