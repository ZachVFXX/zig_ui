const std = @import("std");
pub const clay = @import("zclay");
const renderer = @import("raylib.zig");
const ray = renderer.ray;
const Color = @import("color.zig").Color;
const Palette = @import("color.zig").Palette;
const builtin = @import("builtin");
const RowWidget = @import("widgets/row.zig").RowWidget;
const ColumnWidget = @import("widgets/column.zig").ColumnWidget;
const ScrollWidget = @import("widgets/scroll.zig").ScrollWidget;
const ButtonWidget = @import("widgets/button.zig").ButtonWidget;
const ImageWidget = @import("widgets/image.zig").ImageWidget;
const TextWidget = @import("widgets/text.zig").TextWidget;
const SliderWidget = @import("widgets/slider.zig").SliderWidget;

pub const Widget = struct {
    id: clay.ElementId,
    children: []const Widget = &.{},
    app: *App,
    data: *anyopaque,
    renderFn: *const fn (*anyopaque, Widget, []const Widget) void,

    pub fn render(self: Widget) void {
        self.renderFn(self.data, self, self.children);
    }
};

pub const Event = union(enum) {
    hovered: clay.ElementId,
    pressed: clay.ElementId,
    released: clay.ElementId,
    slider_changed: struct { id: clay.ElementId, value: u32 },
    key_pressed: i32,
    key_released: i32,
};

const Interaction = struct {
    hot: ?clay.ElementId = null,
    active: ?clay.ElementId = null,
};

export fn printClayError(errors: clay.ErrorData) void {
    const s = errors.error_text;
    std.debug.print("CLAY ERROR: {s}\n", .{s.chars[0..@intCast(s.length)]});
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
    events: std.ArrayListUnmanaged(Event),

    pub fn init(alloc: std.mem.Allocator, title: []const u8, width: i32, height: i32, palette: Palette) !App {
        const c_path = try alloc.dupeSentinel(u8, title, 0);
        ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
        ray.InitWindow(width, height, c_path);
        ray.InitAudioDevice();
        ray.SetTargetFPS(60);
        const memory = try alloc.alloc(u8, clay.minMemorySize());
        _ = clay.initialize(.init(memory), .{ .h = @floatFromInt(height), .w = @floatFromInt(width) }, .{ .error_handler_function = printClayError, .user_data = null });
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
            .events = .empty,
        };
    }

    pub fn loadFont(self: *App, file_data: []const u8, font_id: u16, font_size: i32) !void {
        _ = self;
        const font = ray.LoadFontFromMemory(".ttf", @ptrCast(file_data.ptr), @intCast(file_data.len), font_size * 2, null, 0);
        renderer.raylib_fonts[font_id] = font;
        ray.SetTextureFilter(font.texture, ray.TEXTURE_FILTER_BILINEAR);
    }

    pub fn interactImpl(self: *App, id: clay.ElementId, release_anywhere: bool) enum { mouse_hovered, mouse_pressed, mouse_released, none } {
        const is_hovered = clay.pointerOver(id);
        const pressed = ray.IsMouseButtonPressed(ray.MOUSE_LEFT_BUTTON);
        const down = ray.IsMouseButtonDown(ray.MOUSE_LEFT_BUTTON);
        const released = ray.IsMouseButtonReleased(ray.MOUSE_LEFT_BUTTON);

        if (is_hovered) {
            self.interaction.hot = id;
            self.events.append(self.alloc, .{ .hovered = id }) catch {};
        }

        if (pressed and is_hovered and self.interaction.active == null) {
            self.interaction.active = id;
            self.events.append(self.alloc, .{ .pressed = id }) catch {};
            return .mouse_pressed;
        }

        if (self.interaction.active) |active_id| {
            if (active_id.id == id.id) {
                if (down) {
                    self.events.append(self.alloc, .{ .pressed = id }) catch {};
                    return .mouse_pressed;
                }
                if (released) {
                    self.interaction.active = null;
                    if (release_anywhere or is_hovered) {
                        self.events.append(self.alloc, .{ .released = id }) catch {};
                        return .mouse_released;
                    }
                    return .none;
                }
            }
        }

        if (is_hovered) return .mouse_hovered;
        return .none;
    }

    pub fn keyPressed(self: *App, key: anytype) bool {
        const keycode: i32 = switch (@TypeOf(key)) {
            u8, comptime_int => @intCast(key),
            i32 => key,
            c_int => @intCast(key),
            else => @compileError("key must be a char or i32"),
        };
        for (self.events.items) |ev| {
            switch (ev) {
                .key_pressed => |k| if (k == keycode) return true,
                else => {},
            }
        }
        return false;
    }

    pub fn is_closing(_: *App) bool {
        return ray.WindowShouldClose();
    }

    pub fn update(self: *App) void {
        if (ray.IsWindowResized()) {
            self.width = ray.GetRenderWidth();
            self.height = ray.GetRenderHeight();
            clay.setLayoutDimensions(.{ .w = @floatFromInt(self.width), .h = @floatFromInt(self.height) });
        }
        clay.setPointerState(.{ .x = ray.GetMousePosition().x, .y = ray.GetMousePosition().y }, ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT));
        clay.updateScrollContainers(false, .{ .x = ray.GetMouseWheelMoveV().x, .y = ray.GetMouseWheelMoveV().y }, ray.GetFrameTime());

        // key events
        var key = ray.GetKeyPressed();
        while (key != 0) : (key = ray.GetKeyPressed()) {
            self.events.append(self.alloc, .{ .key_pressed = key }) catch {};
        }

        if (comptime builtin.mode == .Debug) {
            if (ray.IsKeyPressed(ray.KEY_H))
                clay.setDebugModeEnabled(!clay.isDebugModeEnabled());
        }
    }

    pub fn beginLayout(self: *App) void {
        _ = self.frame_arena.reset(.retain_capacity);
        self.events.clearRetainingCapacity();
        self.interaction.hot = null;
        clay.beginLayout();
    }

    pub fn endLayout(self: *App, root: anytype) void {
        toWidget(root).render();
        self.render_commands = clay.endLayout();
    }

    pub fn render(self: *App) !void {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.WHITE);
        if (self.render_commands) |cmds| try renderer.clayRaylibRender(cmds, self.alloc);
        if (comptime builtin.mode == .Debug) ray.DrawFPS(0, 0);
    }

    fn alloc_widget(self: *App, comptime T: type, cfg: T) *T {
        const data = self.frame_arena.allocator().create(T) catch @panic("OOM");
        data.* = cfg;
        return data;
    }

    fn toWidget(child: anytype) Widget {
        const T = @TypeOf(child);

        if (T == Widget) return child;
        if (@typeInfo(T) == .pointer) {
            const Child = @typeInfo(T).pointer.child;
            if (@hasField(Child, "widget")) return child.widget;
        }
        if (@hasField(T, "widget")) return child.widget;
        @compileError("expected Widget or a type with a .widget field, got " ++ @typeName(T));
    }

    fn dupe(self: *App, children: anytype) []const Widget {
        const T = @TypeOf(children);

        // handle []Widget and []const Widget slices
        if (@typeInfo(T) == .pointer) {
            const p = @typeInfo(T).pointer;
            if (p.size == .slice) {
                const s = self.frame_arena.allocator().alloc(Widget, children.len) catch @panic("OOM");
                for (children, 0..) |c, i| s[i] = toWidget(c);
                return s;
            }
        }

        // handle tuples / anonymous structs
        const fields = std.meta.fields(T);
        const s = self.frame_arena.allocator().alloc(Widget, fields.len) catch @panic("OOM");
        inline for (fields, 0..) |_, i| s[i] = toWidget(children[i]);
        return s;
    }

    pub fn Row(self: *App, id: clay.ElementId, cfg: RowWidget, children: anytype) Widget {
        const data = self.alloc_widget(RowWidget, cfg);
        return .{ .id = id, .app = self, .data = data, .renderFn = RowWidget.render, .children = self.dupe(children) };
    }

    pub fn Column(self: *App, id: clay.ElementId, cfg: ColumnWidget, children: anytype) Widget {
        const data = self.alloc_widget(ColumnWidget, cfg);
        return .{ .id = id, .app = self, .data = data, .renderFn = ColumnWidget.render, .children = self.dupe(children) };
    }

    pub fn Text(self: *App, id: clay.ElementId, cfg: TextWidget) Widget {
        const data = self.alloc_widget(TextWidget, cfg);
        return .{ .id = id, .app = self, .data = data, .renderFn = TextWidget.render };
    }

    pub fn Image(self: *App, id: clay.ElementId, cfg: ImageWidget) Widget {
        const data = self.alloc_widget(ImageWidget, cfg);
        return .{ .id = id, .app = self, .data = data, .renderFn = ImageWidget.render };
    }

    pub fn Button(self: *App, id: clay.ElementId, cfg: ButtonWidget, children: anytype) *ButtonWidget {
        const data = self.alloc_widget(ButtonWidget, cfg);
        data.widget = .{ .id = id, .app = self, .data = data, .renderFn = ButtonWidget.render, .children = self.dupe(children) };
        return data;
    }

    pub fn Slider(self: *App, id: clay.ElementId, cfg: SliderWidget) *SliderWidget {
        const data = self.alloc_widget(SliderWidget, cfg);
        data.widget = .{ .id = id, .app = self, .data = data, .renderFn = SliderWidget.render };
        return data;
    }

    pub fn Scroll(self: *App, id: clay.ElementId, cfg: ScrollWidget, children: anytype) *ScrollWidget {
        const data = self.alloc_widget(ScrollWidget, cfg);
        data.widget = .{ .id = id, .app = self, .data = data, .renderFn = ScrollWidget.render, .children = self.dupe(children) };
        return data;
    }

    pub fn uninit(self: *App) void {
        self.alloc.free(self.title);
        self.frame_arena.deinit();
        self.events.deinit(self.alloc);
        self.alloc.free(self.memory);
        ray.CloseWindow();
        ray.CloseAudioDevice();
    }
};
