// Test using claude code

const std = @import("std");
const zu = @import("zig_ui");
const clay = zu.clay;
const ray = zu.raylib;

// ── State ─────────────────────────────────────────────────────────────────────

const State = struct {
    // button
    btn_click_count: u32 = 0,
    btn_last_event: []const u8 = "none",

    // sliders
    slider_a: u32 = 50,
    slider_b: u32 = 20,

    // scroll
    scroll_item_count: u32 = 8,

    // keyboard
    last_key: i32 = 0,

    // toggle
    toggle_on: bool = false,

    // log
    log: [8][]const u8 = .{"---"} ** 8,
    log_idx: usize = 0,

    fn push_log(self: *State, msg: []const u8) void {
        self.log[self.log_idx % self.log.len] = msg;
        self.log_idx += 1;
    }
};

// ── Section header ────────────────────────────────────────────────────────────

fn section(app: *zu.App, label: []const u8, base: u32, children: anytype) zu.Widget {
    return app.Column(clay.ElementId.IDI("sec", base), .{
        .sizing = .{ .w = .grow, .h = .fit },
        .gap = 8,
        .padding = .{ .top = 12, .bottom = 12, .left = 12, .right = 12 },
        .color = .{ .role = .surface_raised },
        .corner_radius = 8,
    }, .{
        app.Row(clay.ElementId.IDI("sec_hdr", base), .{
            .sizing = .{ .w = .grow, .h = .fit },
            .padding = .{ .bottom = 6 },
        }, .{
            app.Text(clay.ElementId.IDI("sec_hdr_txt", base), .{
                .text = label,
                .font_size = 13,
                .color = .{ .role = .text_dim },
                .wrap = false,
            }),
        }),
        app.Column(clay.ElementId.IDI("sec_body", base), .{
            .sizing = .{ .w = .grow, .h = .fit },
            .gap = 8,
        }, children),
    });
}

fn label_row(app: *zu.App, text: []const u8, base: u32, value_widget: zu.Widget) zu.Widget {
    return app.Row(clay.ElementId.IDI("lbl_row", base), .{
        .sizing = .{ .w = .grow, .h = .fit },
        .child_alignment = .{ .y = .center },
        .gap = 12,
    }, .{
        app.Text(clay.ElementId.IDI("lbl_txt", base), .{
            .text = text,
            .font_size = 13,
            .color = .{ .role = .text_dim },
            .wrap = false,
        }),
        value_widget,
    });
}

// ── Format helpers (comptime buffers via frame arena) ─────────────────────────

fn fmt(app: *zu.App, comptime f: []const u8, args: anytype) []const u8 {
    const buf = app.frame_arena.allocator().alloc(u8, 128) catch return "?";
    return std.fmt.bufPrint(buf, f, args) catch "?";
}

// ── Build UI ──────────────────────────────────────────────────────────────────

fn buildUI(app: *zu.App, state: *State) *zu.ScrollWidget {

    // ── 1. Button section ─────────────────────────────────────────────────────
    const btn = app.Button(clay.ElementId.ID("test_btn"), .{
        .frame = .{
            .sizing = .fit,
            .padding = .{ .top = 8, .bottom = 8, .left = 16, .right = 16 },
            .corner_radius = 6,
        },
    }, .{
        app.Text(clay.ElementId.ID("test_btn_txt"), .{
            .text = "Click me",
            .font_size = 14,
        }),
    });
    const toggle_btn = app.Button(clay.ElementId.ID("test_toggle"), .{
        .bg_color = if (state.toggle_on) zu.Color{ .rgba = .{ 80, 180, 100, 255 } } else zu.Color{ .role = .primary },
        .hover_color = .{ .role = .primary_hover },
        .click_color = .{ .role = .primary_active },
        .frame = .{
            .sizing = .fit,
            .padding = .{ .top = 8, .bottom = 8, .left = 16, .right = 16 },
            .corner_radius = 6,
        },
    }, .{
        app.Text(clay.ElementId.ID("test_toggle_txt"), .{
            .text = if (state.toggle_on) "ON" else "OFF",
            .font_size = 14,
        }),
    });

    if (btn.clicked()) {
        state.btn_click_count += 1;
        state.btn_last_event = "clicked";
        state.push_log("button: clicked");
    }
    if (btn.hovered()) {
        state.btn_last_event = "hovered";
    }
    if (toggle_btn.clicked()) {
        state.toggle_on = !state.toggle_on;
        state.push_log(if (state.toggle_on) "toggle: ON" else "toggle: OFF");
    }

    const btn_section = section(app, "Button & Toggle", 100, .{
        app.Row(clay.ElementId.ID("btn_row"), .{
            .sizing = .{ .w = .grow, .h = .fit },
            .gap = 10,
            .child_alignment = .{ .y = .center },
        }, .{
            btn.widget,
            toggle_btn.widget,
        }),
        label_row(
            app,
            "clicks:",
            101,
            app.Text(clay.ElementId.ID("btn_count"), .{
                .text = fmt(app, "{d}", .{state.btn_click_count}),
                .font_size = 14,
            }),
        ),
        label_row(
            app,
            "last event:",
            102,
            app.Text(clay.ElementId.ID("btn_event"), .{
                .text = state.btn_last_event,
                .font_size = 14,
            }),
        ),
    });

    // ── 2. Slider section ─────────────────────────────────────────────────────
    const slider_a = app.Slider(clay.ElementId.ID("slider_a"), .{
        .value = state.slider_a,
        .max = 100,
        .frame = .{ .sizing = .{ .w = .grow, .h = .fixed(14) } },
    });
    const slider_b = app.Slider(clay.ElementId.ID("slider_b"), .{
        .value = state.slider_b,
        .max = 255,
        .step = 5,
        .frame = .{ .sizing = .{ .w = .grow, .h = .fixed(14) } },
    });

    if (slider_a.changed()) |v| {
        state.slider_a = v;
        state.push_log(fmt(app, "slider A: {d}", .{v}));
    }
    if (slider_b.changed()) |v| {
        state.slider_b = v;
        state.push_log(fmt(app, "slider B: {d}", .{v}));
    }

    const slider_section = section(app, "Sliders", 200, .{
        label_row(app, fmt(app, "A  {d}/100", .{state.slider_a}), 201, slider_a.widget),
        label_row(app, fmt(app, "B  {d}/255 (step 5)", .{state.slider_b}), 202, slider_b.widget),
    });

    // ── 3. Text & wrapping section ────────────────────────────────────────────
    const text_section = section(app, "Text", 300, .{
        app.Text(clay.ElementId.ID("txt_nowrap"), .{
            .text = "No wrap: The quick brown fox jumps over the lazy dog",
            .font_size = 14,
            .wrap = false,
            .color = .{ .role = .text },
        }),
        app.Text(clay.ElementId.ID("txt_wrap"), .{
            .text = "Wrap: The quick brown fox jumps over the lazy dog and keeps going until it wraps around",
            .font_size = 14,
            .wrap = true,
            .color = .{ .role = .text },
        }),
        app.Text(clay.ElementId.ID("txt_dim"), .{
            .text = "Dim text — secondary info",
            .font_size = 12,
            .color = .{ .role = .text_dim },
        }),
        app.Text(clay.ElementId.ID("txt_disabled"), .{
            .text = "Disabled text",
            .font_size = 12,
            .color = .{ .role = .text_disabled },
        }),
    });

    // ── 4. Scroll section ─────────────────────────────────────────────────────
    const add_btn = app.Button(clay.ElementId.ID("scroll_add"), .{
        .frame = .{ .sizing = .fit, .padding = .{ .top = 4, .bottom = 4, .left = 12, .right = 12 }, .corner_radius = 4 },
    }, .{
        app.Text(clay.ElementId.ID("scroll_add_txt"), .{ .text = "+ item", .font_size = 12 }),
    });
    const rem_btn = app.Button(clay.ElementId.ID("scroll_rem"), .{
        .bg_color = .{ .rgba = .{ 180, 60, 60, 255 } },
        .hover_color = .{ .rgba = .{ 210, 80, 80, 255 } },
        .click_color = .{ .rgba = .{ 140, 40, 40, 255 } },
        .frame = .{ .sizing = .fit, .padding = .{ .top = 4, .bottom = 4, .left = 12, .right = 12 }, .corner_radius = 4 },
    }, .{
        app.Text(clay.ElementId.ID("scroll_rem_txt"), .{ .text = "- item", .font_size = 12 }),
    });

    if (add_btn.clicked()) {
        state.scroll_item_count +|= 1;
        state.push_log(fmt(app, "scroll items: {d}", .{state.scroll_item_count}));
    }
    if (rem_btn.clicked() and state.scroll_item_count > 0) {
        state.scroll_item_count -= 1;
    }

    const scroll_items = app.frame_arena.allocator().alloc(zu.Widget, state.scroll_item_count) catch @panic("OOM");
    for (0..state.scroll_item_count) |i| {
        scroll_items[i] = app.Row(clay.ElementId.IDI("scroll_item", @intCast(i)), .{
            .sizing = .{ .w = .grow, .h = .fit },
            .padding = .{ .top = 6, .bottom = 6, .left = 8, .right = 8 },
            .corner_radius = 4,
            .color = .{ .role = .surface_overlay },
        }, .{
            app.Text(clay.ElementId.IDI("scroll_item_txt", @intCast(i)), .{
                .text = fmt(app, "Item {d}", .{i + 1}),
                .font_size = 13,
            }),
        });
    }

    const scroll_widget = app.Scroll(clay.ElementId.ID("test_scroll"), .{
        .frame = .{ .sizing = .{ .w = .grow, .h = .fixed(160) } },
        .vertical = true,
        .horizontal = false,
        .gap = 6,
    }, scroll_items);

    const scroll_section = section(app, "Scroll", 400, .{
        app.Row(clay.ElementId.ID("scroll_controls"), .{
            .sizing = .{ .w = .grow, .h = .fit },
            .gap = 8,
            .child_alignment = .{ .y = .center },
        }, .{
            add_btn.widget,
            rem_btn.widget,
            app.Text(clay.ElementId.ID("scroll_count"), .{
                .text = fmt(app, "{d} items", .{state.scroll_item_count}),
                .font_size = 13,
                .color = .{ .role = .text_dim },
            }),
        }),
        scroll_widget,
    });

    // ── 5. Keyboard section ───────────────────────────────────────────────────
    const kb_section = section(app, "Keyboard — press any key", 500, .{
        label_row(
            app,
            "last key code:",
            501,
            app.Text(clay.ElementId.ID("kb_key"), .{
                .text = fmt(app, "{d}", .{state.last_key}),
                .font_size = 14,
            }),
        ),
        label_row(
            app,
            "space pressed:",
            502,
            app.Text(clay.ElementId.ID("kb_space"), .{
                .text = if (app.keyPressed(ray.KEY_SPACE)) "YES" else "no",
                .font_size = 14,
                .color = if (app.keyPressed(ray.KEY_SPACE)) zu.Color{ .rgba = .{ 80, 200, 100, 255 } } else zu.Color{ .role = .text_dim },
            }),
        ),
    });

    // ── 6. Event log ──────────────────────────────────────────────────────────
    const log_items = app.frame_arena.allocator().alloc(zu.Widget, state.log.len) catch @panic("OOM");
    const start = if (state.log_idx >= state.log.len) state.log_idx - state.log.len else 0;
    for (0..state.log.len) |i| {
        const entry = state.log[(start + i) % state.log.len];
        log_items[i] = app.Text(clay.ElementId.IDI("log_entry", @intCast(i)), .{
            .text = entry,
            .font_size = 12,
            .color = .{ .role = .text_dim },
            .wrap = false,
        });
    }

    const log_section = section(app, "Event log", 600, .{
        app.Scroll(clay.ElementId.ID("log_scroll"), .{
            .frame = .{ .sizing = .{ .w = .grow, .h = .fixed(120) } },
            .vertical = true,
            .horizontal = false,
            .gap = 4,
        }, log_items),
    });

    // ── Root ──────────────────────────────────────────────────────────────────
    return app.Scroll(clay.ElementId.ID("root_scroll"), .{}, .{
        btn_section,
        slider_section,
        text_section,
        scroll_section,
        kb_section,
        log_section,
    });
}

// ── Main ──────────────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    var app = try zu.App.init(init.arena.allocator(), "Widget test", 720, 720, .{});
    defer app.uninit();

    const font_data = @embedFile("assets/Roboto-Regular.ttf");
    try app.loadFont(font_data, 0, 20);

    var state = State{};

    while (!app.is_closing()) {
        app.update();

        // track any key press
        for (app.events.items) |ev| {
            switch (ev) {
                .key_pressed => |k| {
                    state.last_key = k;
                    state.push_log(std.fmt.allocPrint(
                        app.frame_arena.allocator(),
                        "key pressed: {d}",
                        .{k},
                    ) catch "key pressed");
                },
                else => {},
            }
        }

        app.beginLayout();

        const root = app.Row(clay.ElementId.ID("root"), .{
            .sizing = .grow,
            .padding = .{ .top = 16, .bottom = 16, .left = 16, .right = 16 },
            .color = .{ .role = .surface },
        }, .{
            buildUI(&app, &state),
        });

        app.endLayout(root);
        try app.render();
    }
}
