const std = @import("std");
pub const clay = @import("zclay");
const renderer = @import("raylib.zig");
const ray = renderer.ray;

const builtin = @import("builtin");
pub const ColorRole = enum {
    transparent,
    surface,
    surface_raised,
    surface_overlay,
    primary,
    primary_hover,
    primary_active,
    text,
    text_dim,
    text_disabled,
    scrollbar_track,
    scrollbar_thumb,
    scrollbar_hover,
};

pub const Color = union(enum) {
    rgba: clay.Color,
    role: ColorRole,

    pub fn resolve(self: Color, palette: Palette) clay.Color {
        return switch (self) {
            .rgba => |c| c,
            .role => |r| palette.fromRole(r),
        };
    }
};

pub const Palette = struct {
    // Surfaces/background layers
    surface: clay.Color = .{ 20, 20, 20, 255 },
    surface_raised: clay.Color = .{ 30, 30, 30, 255 },
    surface_overlay: clay.Color = .{ 40, 40, 40, 255 },

    // Interactive
    primary: clay.Color = .{ 100, 149, 237, 255 },
    primary_hover: clay.Color = .{ 120, 169, 255, 255 },
    primary_active: clay.Color = .{ 70, 110, 200, 255 },

    // Text
    text: clay.Color = .{ 255, 255, 255, 255 },
    text_dim: clay.Color = .{ 180, 180, 180, 255 },
    text_disabled: clay.Color = .{ 100, 100, 100, 255 },

    // Scrollbar
    scrollbar_track: clay.Color = .{ 40, 40, 40, 255 },
    scrollbar_thumb: clay.Color = .{ 140, 140, 140, 255 },
    scrollbar_hover: clay.Color = .{ 180, 180, 180, 255 },

    pub fn fromRole(self: Palette, role: ColorRole) clay.Color {
        return switch (role) {
            .transparent => .{ 0, 0, 0, 0 },
            .surface => self.surface,
            .surface_raised => self.surface_raised,
            .surface_overlay => self.surface_overlay,
            .primary => self.primary,
            .primary_hover => self.primary_hover,
            .primary_active => self.primary_active,
            .text => self.text,
            .text_dim => self.text_dim,
            .text_disabled => self.text_disabled,
            .scrollbar_track => self.scrollbar_track,
            .scrollbar_thumb => self.scrollbar_thumb,
            .scrollbar_hover => self.scrollbar_hover,
        };
    }
};

pub const RowData = struct {
    color: Color = .{ .role = .transparent },
    gap: u16 = 8,
    padding: clay.Padding = .{},
    corner_radius: f32 = 0,
    direction: clay.LayoutDirection = .left_to_right,
    sizing: clay.Sizing = .grow,
    child_alignment: clay.ChildAlignment = .{},
};

pub const ColumnData = struct {
    color: Color = .{ .role = .transparent },
    gap: u16 = 8,
    padding: clay.Padding = .{},
    corner_radius: f32 = 0,
    direction: clay.LayoutDirection = .top_to_bottom,
    sizing: clay.Sizing = .grow,
    child_alignment: clay.ChildAlignment = .{},
};

pub const TextData = struct {
    frame: RowData = .{ .sizing = .fit },
    text: []const u8 = "",
    font_id: u16 = 0,
    font_size: u16 = 16,
    wrap: bool = true,
    color: Color = .{ .role = .text },
};

pub const ScrollData = struct {
    frame: RowData = .{},
    color: Color = .{ .role = .transparent },
    vertical: bool = true,
    horizontal: bool = true,
    gap: u16 = 4,
};

pub const ButtonData = struct {
    frame: RowData = .{},
    bg_color: Color = .{ .role = .primary },
    hover_color: Color = .{ .role = .primary_hover },
    click_color: Color = .{ .role = .primary_active },
};

pub const ImageData = struct {
    frame: RowData = .{ .sizing = .fit },
    texture: ?*const ray.Texture2D = null,
};

pub const SliderData = struct {
    frame: RowData = .{ .sizing = .{ .w = .growMinMax(.{ .min = 0, .max = 200 }), .h = .fixed(16) } },
    value: u32,
    step: u32 = 1,
    max: u32 = 100,
    ctx: *anyopaque = null,
    on_change: ?*const fn (*anyopaque, u32) void = null,
};

pub const Widget = union(enum) {
    column: ColumnData,
    row: RowData,
    text: TextData,
    scroll: ScrollData,
    button: ButtonData,
    image: ImageData,
    slider: SliderData,

    fn render(self: Widget, node: Node, children: []const Node) void {
        switch (self) {
            .row => |d| renderRow(node, d, children),
            .column => |d| renderColumn(node, d, children),
            .text => |d| renderText(node, d),
            .scroll => |d| renderScroll(node, d, children),
            .button => |d| renderButton(node, d, children),
            .image => |d| renderImage(node, d),
            .slider => |d| renderSlider(node, d),
        }
    }
};

pub const MouseEvent = enum {
    hovered,
    mouse_pressed,
    mouse_released,
    none,
};

pub const Interaction = struct {
    hot: ?clay.ElementId = null, // hovered this frame
    active: ?clay.ElementId = null, // currently pressed
};

pub const Node = struct {
    id: clay.ElementId,
    widget: Widget,
    children: []const Node = &.{},
    app: *App,

    pub fn getMouseEvent(node: *const Node) MouseEvent {
        return node.app.interact(node.id);
    }
};

fn renderSlider(node: Node, d: SliderData) void {
    const max_v: f32 = @max(1.0, @as(f32, @floatFromInt(d.max)));

    var display_t: f32 = @as(f32, @floatFromInt(d.value)) / max_v;
    var fill_color = node.app.palette.fromRole(.primary);

    const track_data = clay.getElementData(node.id);
    const slider_w: f32 = if (track_data.found) track_data.bounding_box.width else 0;

    if (track_data.found) {
        const ev = node.app.interactImpl(node.id, true);

        switch (ev) {
            .hovered => fill_color = node.app.palette.fromRole(.primary_hover),
            .mouse_pressed => fill_color = node.app.palette.fromRole(.primary_active),
            else => {},
        }

        if (ev == .mouse_pressed or ev == .mouse_released) {
            const mouse_x = ray.GetMousePosition().x;
            var t = (mouse_x - track_data.bounding_box.x) / slider_w;
            t = @max(0.0, @min(1.0, t));
            display_t = t;

            if (ev == .mouse_released) {
                var new_val: f32 = t * max_v;
                if (d.step > 1) {
                    const step_f: f32 = @floatFromInt(d.step);
                    new_val = @round(new_val / step_f) * step_f;
                }
                if (d.on_change) |cb| {
                    cb(d.ctx, @intFromFloat(new_val));
                }
            }
        }
    }

    clay.UI()(.{
        .id = node.id,
        .layout = .{
            .direction = .left_to_right,
            .sizing = d.frame.sizing,
            .padding = d.frame.padding,
        },
        .background_color = node.app.palette.fromRole(.scrollbar_track),
    })({
        clay.UI()(.{
            .layout = .{ .sizing = .{ .w = .fixed(display_t * slider_w), .h = .grow } },
            .background_color = fill_color,
        })({});
    });
}

fn renderImage(node: Node, d: ImageData) void {
    const tex = d.texture orelse return;
    clay.UI()(.{
        .id = node.id,
        .image = .{ .image_data = tex },
        .layout = .{
            .direction = d.frame.direction,
            .sizing = d.frame.sizing,
            .child_gap = d.frame.gap,
            .padding = d.frame.padding,
            .child_alignment = d.frame.child_alignment,
        },
        .background_color = d.frame.color.resolve(node.app.palette),
        .corner_radius = .all(d.frame.corner_radius),
    })({});
}

fn renderRow(node: Node, d: RowData, children: []const Node) void {
    clay.UI()(.{
        .id = node.id,
        .layout = .{
            .direction = d.direction,
            .sizing = d.sizing,
            .child_gap = d.gap,
            .padding = d.padding,
            .child_alignment = d.child_alignment,
        },
        .background_color = d.color.resolve(node.app.palette),
        .corner_radius = .all(d.corner_radius),
    })({
        for (children) |child| createClayElement(child);
    });
}

fn renderColumn(node: Node, d: ColumnData, children: []const Node) void {
    clay.UI()(.{
        .id = node.id,
        .layout = .{
            .direction = d.direction,
            .sizing = d.sizing,
            .child_gap = d.gap,
            .padding = d.padding,
            .child_alignment = d.child_alignment,
        },
        .background_color = d.color.resolve(node.app.palette),
        .corner_radius = .all(d.corner_radius),
    })({
        for (children) |child| createClayElement(child);
    });
}

fn renderText(node: Node, d: TextData) void {
    if (d.text.len == 0 or d.text.len > std.math.maxInt(i32)) return;

    clay.UI()(.{
        .layout = .{
            .direction = d.frame.direction,
            .sizing = d.frame.sizing,
            .child_gap = d.frame.gap,
            .padding = d.frame.padding,
            .child_alignment = d.frame.child_alignment,
        },
        .background_color = d.frame.color.resolve(node.app.palette),
        .corner_radius = .all(d.frame.corner_radius),
    })({
        clay.text(d.text, .{
            .font_id = d.font_id,
            .font_size = d.font_size,
            .color = d.color.resolve(node.app.palette),
            .wrap_mode = if (d.wrap) .words else .none,
        });
    });
}

fn renderButton(node: Node, d: ButtonData, children: []const Node) void {
    const state = node.getMouseEvent();

    var row_data = d.frame;

    row_data.color = d.bg_color;

    switch (state) {
        .hovered => row_data.color = d.hover_color,
        .mouse_pressed => row_data.color = d.click_color,
        .mouse_released => row_data.color = d.hover_color,
        else => {},
    }

    renderRow(node, row_data, children);
}

fn renderScroll(node: Node, d: ScrollData, children: []const Node) void {
    const content_eid = clay.ElementId.fromSrc(@src());
    const track_eid = clay.ElementId.fromSrcI(@src(), 1);
    const thumb_eid = clay.ElementId.fromSrcI(@src(), 2);

    const sc = clay.getScrollContainerData(content_eid);

    // Input
    if (sc.found) {
        const ch = sc.scroll_container_dimensions.h;
        const ct = sc.content_dimensions.h;
        if (ct > ch) {
            const max_scroll = ct - ch;
            const cur_y = sc.scroll_position.*.y;
            if (node.app.interact(thumb_eid) == .mouse_pressed) {
                const scale = ct / ch;
                sc.scroll_position.*.y = @max(-max_scroll, @min(0.0, cur_y - ray.GetMouseDelta().y * scale));
            }
            if (node.app.interact(track_eid) == .mouse_released) {
                const td = clay.getElementData(track_eid);
                if (td.found) {
                    const thumb_h = @max(20.0, ch * (ch / ct));
                    const rel_y = ray.GetMousePosition().y - td.bounding_box.y;
                    const new_t = @max(0.0, @min(1.0, (rel_y - thumb_h * 0.5) / (ch - thumb_h)));
                    sc.scroll_position.*.y = -new_t * max_scroll;
                }
            }
        }
    }

    // Layout
    clay.UI()(.{
        .id = node.id,
        .layout = .{ .direction = .left_to_right, .sizing = d.frame.sizing },
        .background_color = d.color.resolve(node.app.palette),
    })({
        clay.UI()(.{
            .id = content_eid,
            .layout = .{
                .direction = .top_to_bottom,
                .sizing = .grow,
                .child_gap = d.gap,
            },
            .clip = .{
                .vertical = d.vertical,
                .horizontal = d.horizontal,
                .child_offset = if (sc.found) sc.scroll_position.* else .{ .x = 0, .y = 0 },
            },
        })({
            for (children) |child| createClayElement(child);
        });

        // Scrollbar
        if (sc.found) {
            const ch = sc.scroll_container_dimensions.h;
            const ct = sc.content_dimensions.h;
            if (ct > ch) {
                const max_scroll = ct - ch;
                const t = @max(0.0, @min(1.0, -sc.scroll_position.*.y / max_scroll));
                const thumb_h = @max(20.0, ch * (ch / ct));
                const thumb_y = t * (ch - thumb_h);

                clay.UI()(.{
                    .id = track_eid,
                    .layout = .{
                        .direction = .top_to_bottom,
                        .sizing = .{ .w = .fixed(8), .h = .grow },
                    },
                    .background_color = d.color.resolve(node.app.palette),
                    .corner_radius = .all(4),
                })({
                    clay.UI()(.{
                        .layout = .{ .sizing = .{ .w = .grow, .h = .fixed(thumb_y) } },
                    })({});

                    createClayElement(node.app.Button(
                        thumb_eid,
                        ButtonData{
                            .bg_color = .{ .role = .scrollbar_thumb },
                            .click_color = .{ .role = .scrollbar_track },
                            .hover_color = .{ .role = .scrollbar_hover },
                            .frame = .{
                                .sizing = .{
                                    .w = .grow,
                                    .h = .fixed(thumb_h),
                                },
                            },
                        },
                        .{},
                    ));
                });
            }
        }
    });
}

fn createClayElement(node: Node) void {
    node.widget.render(node, node.children);
}

export fn printClayError(errors: clay.ErrorData) void {
    const s = errors.error_text;
    const slice = s.chars[0..@intCast(s.length)];
    std.debug.print("CLAY ERROR: {s}\n", .{slice});
}

pub const App = struct {
    title: [:0]const u8,
    width: i32,
    height: i32,
    alloc: std.mem.Allocator,
    frame_arena: std.heap.ArenaAllocator,
    memory: []u8,
    render_commands: ?[]clay.RenderCommand,
    interaction: Interaction,
    palette: Palette,

    pub fn init(
        alloc: std.mem.Allocator,
        title: []const u8,
        width: i32,
        height: i32,
        palette: Palette,
    ) !App {
        const c_path = alloc.dupeSentinel(u8, title, 0) catch unreachable;
        ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
        ray.InitWindow(width, height, c_path);
        ray.InitAudioDevice();
        ray.SetTargetFPS(60); // FIXME: no vsync because it cause audio stutter idk why
        const min_memory_size: u32 = clay.minMemorySize();
        const memory = try alloc.alloc(u8, min_memory_size);
        const arena: clay.Arena = .init(memory);
        _ = clay.initialize(arena, .{ .h = @floatFromInt(height), .w = @floatFromInt(width) }, .{ .error_handler_function = printClayError, .user_data = null });

        clay.setMeasureTextFunction(void, {}, renderer.measureText);

        return .{
            .title = c_path,
            .width = width,
            .height = height,
            .alloc = alloc,
            .memory = memory,
            .render_commands = null,
            .frame_arena = .init(alloc),
            .interaction = .{},
            .palette = palette,
        };
    }

    pub fn loadFont(self: *App, file_data: []const u8, font_id: u16, font_size: i32) !void {
        _ = self;
        const ptr: [*c]const u8 = @ptrCast(file_data.ptr);
        const ext: [*c]const u8 = ".ttf";

        const font = ray.LoadFontFromMemory(
            ext,
            ptr,
            @intCast(file_data.len),
            font_size * 2,
            null,
            0,
        );

        renderer.raylib_fonts[font_id] = font;
        ray.SetTextureFilter(font.texture, ray.TEXTURE_FILTER_BILINEAR);
    }

    pub fn interactImpl(self: *App, id: clay.ElementId, release_anywhere: bool) MouseEvent {
        const is_hovered = clay.pointerOver(id);
        const pressed = ray.IsMouseButtonPressed(ray.MOUSE_LEFT_BUTTON);
        const down = ray.IsMouseButtonDown(ray.MOUSE_LEFT_BUTTON);
        const released = ray.IsMouseButtonReleased(ray.MOUSE_LEFT_BUTTON);

        if (is_hovered) self.interaction.hot = id;

        if (pressed and is_hovered and self.interaction.active == null) {
            self.interaction.active = id;
            return .mouse_pressed;
        }

        if (self.interaction.active) |active_id| {
            if (active_id.id == id.id) {
                if (down) return .mouse_pressed;
                if (released) {
                    self.interaction.active = null;
                    return if (release_anywhere or is_hovered) .mouse_released else .none;
                }
            }
        }

        if (is_hovered) return .hovered;
        return .none;
    }

    pub fn interact(self: *App, id: clay.ElementId) MouseEvent {
        return self.interactImpl(id, false);
    }

    pub fn is_closing(self: *App) bool {
        _ = self;
        return ray.WindowShouldClose();
    }

    pub fn update(self: *App) void {
        if (ray.IsWindowResized()) {
            self.width = ray.GetRenderWidth();
            self.height = ray.GetRenderHeight();
            clay.setLayoutDimensions(.{ .w = @floatFromInt(self.width), .h = @floatFromInt(self.height) });
        }
        clay.setPointerState(
            .{
                .x = ray.GetMousePosition().x,
                .y = ray.GetMousePosition().y,
            },
            ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT),
        );
        clay.updateScrollContainers(false, .{
            .x = ray.GetMouseWheelMoveV().x,
            .y = ray.GetMouseWheelMoveV().y,
        }, ray.GetFrameTime());

        if (comptime builtin.mode == .Debug) {
            if (ray.IsKeyPressed(ray.KEY_H)) {
                clay.setDebugModeEnabled(!clay.isDebugModeEnabled());
            }
        }
    }

    pub fn beginLayout(self: *App) void {
        _ = self.frame_arena.reset(.retain_capacity);
        self.interaction.hot = null;
        clay.beginLayout();
    }

    pub fn endLayout(self: *App, node: Node) void {
        createClayElement(node);
        self.render_commands = clay.endLayout();
    }

    pub fn render(self: *App) !void {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.WHITE);
        if (self.render_commands) |cmds| {
            try renderer.clayRaylibRender(cmds, self.alloc);
        }
        if (comptime builtin.mode == .Debug) ray.DrawFPS(0, 0);
    }

    fn dupe(self: *App, children: anytype) []const Node {
        const T = @TypeOf(children);
        if (@typeInfo(T) == .pointer) {
            const p = @typeInfo(T).pointer;
            if (p.size == .slice and p.child == Node) {
                const s = self.frame_arena.allocator().alloc(Node, children.len) catch @panic("OOM");
                @memcpy(s, children);
                return s;
            }
        }
        const fields = std.meta.fields(T);
        const s = self.frame_arena.allocator().alloc(Node, fields.len) catch @panic("OOM");
        inline for (fields, 0..) |_, i| s[i] = children[i];
        return s;
    }

    pub fn Row(self: *App, id: clay.ElementId, cfg: RowData, children: anytype) Node {
        return .{ .app = self, .id = id, .widget = .{ .row = cfg }, .children = self.dupe(children) };
    }

    pub fn Column(self: *App, id: clay.ElementId, cfg: ColumnData, children: anytype) Node {
        return .{ .app = self, .id = id, .widget = .{ .column = cfg }, .children = self.dupe(children) };
    }

    pub fn Text(self: *App, id: clay.ElementId, cfg: TextData) Node {
        return .{ .app = self, .id = id, .widget = .{ .text = cfg } };
    }

    pub fn Scroll(self: *App, id: clay.ElementId, cfg: ScrollData, children: anytype) Node {
        return .{ .app = self, .id = id, .widget = .{ .scroll = cfg }, .children = self.dupe(children) };
    }

    pub fn Button(self: *App, id: clay.ElementId, cfg: ButtonData, children: anytype) Node {
        return .{ .app = self, .id = id, .widget = .{ .button = cfg }, .children = self.dupe(children) };
    }

    pub fn Image(self: *App, id: clay.ElementId, cfg: ImageData) Node {
        return .{ .app = self, .id = id, .widget = .{ .image = cfg } };
    }

    pub fn Slider(self: *App, id: clay.ElementId, cfg: SliderData) Node {
        return .{ .app = self, .id = id, .widget = .{ .slider = cfg } };
    }

    pub fn uninit(self: *App) void {
        self.alloc.free(self.title);
        self.frame_arena.deinit();
        self.alloc.free(self.memory);
        ray.CloseWindow();
        ray.CloseAudioDevice();
    }
};
