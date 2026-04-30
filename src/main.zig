const std = @import("std");
const zu = @import("zig_ui.zig");

pub fn print_value(_: *anyopaque, v: u32) void {
    std.debug.print("{any}", v);
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var app = try zu.App.init(arena, "test", 800, 600, .{});
    defer app.uninit();

    while (!app.is_closing()) {
        app.update();
        app.Slider(.ID("test"), .{ .on_change = print_value });
        try app.render();
    }
}
