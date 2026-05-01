const Widget = @import("../app.zig").Widget;
const RowWidget = @import("row.zig").RowWidget;
const Color = @import("../color.zig").Color;
const clay = @import("zclay");
const std = @import("std");

pub const TextWidget = struct {
    frame: RowWidget = .{ .sizing = .fit },
    text: []const u8 = "",
    font_id: u16 = 0,
    font_size: u16 = 16,
    wrap: bool = true,
    color: Color = .{ .role = .text },

    pub fn render(ptr: *anyopaque, w: Widget, _: []const Widget) void {
        const self: *TextWidget = @ptrCast(@alignCast(ptr));
        if (self.text.len == 0 or self.text.len > std.math.maxInt(i32)) return;
        clay.UI()(.{
            .id = w.id,
            .layout = .{
                .direction = self.frame.direction,
                .sizing = self.frame.sizing,
                .child_gap = self.frame.gap,
                .padding = self.frame.padding,
                .child_alignment = self.frame.child_alignment,
            },
            .background_color = self.frame.color.resolve(w.app.palette),
            .corner_radius = .all(self.frame.corner_radius),
        })({
            clay.text(self.text, .{
                .font_id = self.font_id,
                .font_size = self.font_size,
                .color = self.color.resolve(w.app.palette),
                .wrap_mode = if (self.wrap) .words else .none,
            });
        });
    }
};
