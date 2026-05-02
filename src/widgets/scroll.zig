const Widget = @import("../app.zig").Widget;
const RowWidget = @import("row.zig").RowWidget;
const ButtonWidget = @import("button.zig").ButtonWidget;
const std = @import("std");
const Color = @import("../color.zig").Color;
const clay = @import("zclay");
const renderer = @import("../raylib.zig");
const ray = renderer.ray;

pub const ScrollWidget = struct {
    widget: Widget = undefined,
    frame: RowWidget = .{},
    color: Color = .{ .role = .transparent },
    vertical: bool = true,
    horizontal: bool = true,
    gap: u16 = 4,

    pub fn render(ptr: *anyopaque, w: Widget, children: []const Widget) void {
        const self: *ScrollWidget = @ptrCast(@alignCast(ptr));

        const content_eid = clay.ElementId.fromSrcI(@src(), w.id.id);
        const track_eid = clay.ElementId.fromSrcI(@src(), w.id.id + 1);
        const thumb_eid = clay.ElementId.fromSrcI(@src(), w.id.id + 2);

        const sc = clay.getScrollContainerData(content_eid);

        // Input
        if (sc.found) {
            const ch = sc.scroll_container_dimensions.h;
            const ct = sc.content_dimensions.h;
            if (ct > ch) {
                const max_scroll = ct - ch;
                const cur_y = sc.scroll_position.*.y;
                const thumb_h = @max(20.0, ch * (ch / ct));

                if (w.app.interactImpl(thumb_eid, true) == .mouse_pressed) {
                    const scale = ct / ch;
                    sc.scroll_position.*.y = @max(-max_scroll, @min(0.0, cur_y - ray.GetMouseDelta().y * scale));
                }

                if (w.app.interactImpl(track_eid, false) == .mouse_released) {
                    const td = clay.getElementData(track_eid);
                    if (td.found) {
                        const rel_y = ray.GetMousePosition().y - td.bounding_box.y;
                        const new_t = std.math.clamp(
                            (rel_y - thumb_h * 0.5) / (ch - thumb_h),
                            0.0,
                            1.0,
                        );
                        sc.scroll_position.*.y = -new_t * max_scroll;
                    }
                }
            }
        }

        // Layout
        clay.UI()(.{
            .id = w.id,
            .layout = .{ .direction = .left_to_right, .sizing = self.frame.sizing },
            .background_color = self.color.resolve(w.app.palette),
        })({
            // content area
            clay.UI()(.{
                .id = content_eid,
                .layout = .{
                    .direction = .top_to_bottom,
                    .sizing = .grow,
                    .child_gap = self.gap,
                },
                .clip = .{
                    .vertical = self.vertical,
                    .horizontal = self.horizontal,
                    .child_offset = if (sc.found) sc.scroll_position.* else .{ .x = 0, .y = 0 },
                },
            })({
                for (children) |child| child.render();
            });

            // scrollbar
            if (sc.found) {
                const ch = sc.scroll_container_dimensions.h;
                const ct = sc.content_dimensions.h;
                if (ct > ch) {
                    const max_scroll = ct - ch;
                    const t = std.math.clamp(-sc.scroll_position.*.y / max_scroll, 0.0, 1.0);
                    const thumb_h = @max(20.0, ch * (ch / ct));
                    // clamp so thumb never overflows track
                    const thumb_y = @min(t * (ch - thumb_h), ch - thumb_h);

                    clay.UI()(.{
                        .id = track_eid,
                        .layout = .{
                            .direction = .top_to_bottom,
                            .sizing = .{ .w = .fixed(8), .h = .grow },
                        },
                        .background_color = w.app.palette.fromRole(.scrollbar_track),
                    })({
                        // spacer
                        clay.UI()(.{
                            .layout = .{ .sizing = .{ .w = .grow, .h = .fixed(thumb_y) } },
                        })({});

                        // thumb
                        const thumb = w.app.Button(thumb_eid, .{
                            .bg_color = .{ .role = .scrollbar_thumb },
                            .hover_color = .{ .role = .scrollbar_hover },
                            .click_color = .{ .role = .scrollbar_track },
                            .frame = .{
                                .sizing = .{ .w = .grow, .h = .fixed(thumb_h) },
                            },
                        }, .{});
                        thumb.widget.render();
                    });
                }
            }
        });
    }

    // how far down (0.0 to 1.0) the view currently is
    //pub fn scrollT(self: *ScrollWidget) f32 {
    //    _ = self;
    //    const content_eid = clay.ElementId.fromSrc(@src());
    //    const sc = clay.getScrollContainerData(content_eid);
    //    if (!sc.found) return 0.0;
    //    const ch = sc.scroll_container_dimensions.h;
    //    const ct = sc.content_dimensions.h;
    //    if (ct <= ch) return 0.0;
    //    return @max(0.0, @min(1.0, -sc.scroll_position.*.y / (ct - ch)));
    //}
};
