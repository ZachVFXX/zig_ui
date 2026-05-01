const Widget = @import("../app.zig").Widget;
const Color = @import("../color.zig").Color;
const clay = @import("zclay");

pub const RowWidget = struct {
    color: Color = .{ .role = .transparent },
    gap: u16 = 8,
    padding: clay.Padding = .{},
    corner_radius: f32 = 0,
    direction: clay.LayoutDirection = .left_to_right,
    sizing: clay.Sizing = .grow,
    child_alignment: clay.ChildAlignment = .{},

    pub fn render(ptr: *anyopaque, w: Widget, children: []const Widget) void {
        const self: *RowWidget = @ptrCast(@alignCast(ptr));
        clay.UI()(.{
            .id = w.id,
            .layout = .{
                .direction = self.direction,
                .sizing = self.sizing,
                .child_gap = self.gap,
                .padding = self.padding,
                .child_alignment = self.child_alignment,
            },
            .background_color = self.color.resolve(w.app.palette),
            .corner_radius = .all(self.corner_radius),
        })({
            for (children) |child| child.render();
        });
    }
};
