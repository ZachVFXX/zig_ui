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
    last_ch: f32 = 0.0,
    last_ct: f32 = 0.0,

    pub fn render(ptr: *anyopaque, w: Widget, children: []const Widget) void {
        const self: *ScrollWidget = @ptrCast(@alignCast(ptr));

        const content_eid = clay.ElementId.fromSrcI(@src(), w.id.id);
        const track_eid = clay.ElementId.fromSrcI(@src(), w.id.id + 1);
        const thumb_eid = clay.ElementId.fromSrcI(@src(), w.id.id + 2);

        const sc = clay.getScrollContainerData(content_eid);

        var scroll_y: f32 = 0.0;

        if (sc.found) {
            const ch = sc.scroll_container_dimensions.h;
            const ct = sc.content_dimensions.h;
            const max_scroll = @max(0.0, ct - ch);

            const resized = (ch != self.last_ch) or (ct != self.last_ct);

            if (resized) {
                const old_max = @max(0.0, self.last_ct - self.last_ch);

                var t: f32 = 0.0;
                if (old_max > 0.0) {
                    t = std.math.clamp(-sc.scroll_position.*.y / old_max, 0.0, 1.0);
                }

                sc.scroll_position.*.y = -t * max_scroll;
            }

            // Clamp final (toujours safe)
            sc.scroll_position.*.y = std.math.clamp(sc.scroll_position.*.y, -max_scroll, 0.0);
            scroll_y = sc.scroll_position.*.y;

            // Update cache
            self.last_ch = ch;
            self.last_ct = ct;

            if (ct > ch) {
                const thumb_h = @floor(@max(20.0, ch * (ch / ct)));

                if (w.app.interactImpl(thumb_eid, true) == .mouse_pressed) {
                    const scale = ct / ch;
                    const new_y = scroll_y - ray.GetMouseDelta().y * scale;
                    sc.scroll_position.*.y = std.math.clamp(new_y, -max_scroll, 0.0);
                    scroll_y = sc.scroll_position.*.y;
                }

                if (w.app.interactImpl(track_eid, false) == .mouse_released) {
                    const td = clay.getElementData(track_eid);
                    if (td.found) {
                        const rel_y = ray.GetMousePosition().y - td.bounding_box.y;
                        const available = @max(1.0, ch - thumb_h);
                        const new_t = std.math.clamp(
                            (rel_y - thumb_h * 0.5) / available,
                            0.0,
                            1.0,
                        );
                        sc.scroll_position.*.y = -new_t * max_scroll;
                        scroll_y = sc.scroll_position.*.y;
                    }
                }
            }
        }

        clay.UI()(.{
            .id = w.id,
            .layout = .{ .direction = .left_to_right, .sizing = self.frame.sizing },
            .background_color = self.color.resolve(w.app.palette),
        })({
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
                    .child_offset = .{ .x = 0, .y = scroll_y },
                },
            })({
                for (children) |child| child.render();
            });

            if (sc.found) {
                const ch = sc.scroll_container_dimensions.h;
                const ct = sc.content_dimensions.h;
                if (ct > ch) {
                    const max_scroll = ct - ch;
                    const t = std.math.clamp(-scroll_y / max_scroll, 0.0, 1.0);

                    const ch_i: u32 = @intFromFloat(@floor(ch));
                    const thumb_h_i: u32 = @max(20, @as(u32, @intFromFloat(@floor(ch * (ch / ct)))));
                    const available_i: u32 = if (ch_i > thumb_h_i) ch_i - thumb_h_i else 0;
                    const thumb_y_i: u32 = @min(
                        @as(u32, @intFromFloat(@floor(t * @as(f32, @floatFromInt(available_i))))),
                        available_i,
                    );

                    clay.UI()(.{
                        .id = track_eid,
                        .layout = .{
                            .direction = .top_to_bottom,
                            .sizing = .{ .w = .fixed(8), .h = .grow },
                        },
                        .background_color = w.app.palette.fromRole(.scrollbar_track),
                    })({
                        clay.UI()(.{
                            .layout = .{ .sizing = .{ .w = .grow, .h = .fixed(@floatFromInt(thumb_y_i)) } },
                        })({});

                        const thumb = w.app.Button(thumb_eid, .{
                            .bg_color = .{ .role = .scrollbar_thumb },
                            .hover_color = .{ .role = .scrollbar_hover },
                            .click_color = .{ .role = .scrollbar_track },
                            .frame = .{ .sizing = .{ .w = .grow, .h = .fixed(@floatFromInt(thumb_h_i)) } },
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
