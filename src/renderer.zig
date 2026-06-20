const std = @import("std");
const ray = @import("raylib.zig").rl;
const cl = @import("zclay");
const math = std.math;
const Harfbuzz = @import("harbuzz.zig");

pub fn clayColorToRaylibColor(color: cl.Color) ray.Color {
    return ray.Color{
        .r = @trunc(color[0]),
        .g = @trunc(color[1]),
        .b = @trunc(color[2]),
        .a = @trunc(color[3]),
    };
}

pub fn clayRaylibRender(render_commands: []cl.RenderCommand, gpa: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    for (render_commands) |render_command| {
        defer _ = arena.reset(.retain_capacity);

        const bounding_box = render_command.bounding_box;
        switch (render_command.command_type) {
            .none => {},
            .text => {
                const config = render_command.render_data.text;
                const text = config.string_contents.chars[0..@intCast(config.string_contents.length)];
                try Harfbuzz.draw_text(gpa, text, config.font_id, config.font_size, clayColorToRaylibColor(config.text_color), bounding_box);
            },
            .image => {
                const config = render_command.render_data.image;
                var tint = config.background_color;
                if (std.mem.eql(f32, &tint, &.{ 0, 0, 0, 0 })) {
                    tint = .{ 255, 255, 255, 255 };
                }

                const image_texture: *const ray.Texture2D = @ptrCast(@alignCast(config.image_data));
                ray.DrawTextureEx(
                    image_texture.*,
                    ray.Vector2{ .x = bounding_box.x, .y = bounding_box.y },
                    0,
                    bounding_box.width / @as(f32, @floatFromInt(image_texture.width)),
                    clayColorToRaylibColor(tint),
                );
            },
            .scissor_start => {
                ray.BeginScissorMode(
                    @round(bounding_box.x),
                    @round(bounding_box.y),
                    @round(bounding_box.width),
                    @round(bounding_box.height),
                );
            },
            .scissor_end => ray.EndScissorMode(),
            .rectangle => {
                const config = render_command.render_data.rectangle;
                if (config.corner_radius.top_left > 0) {
                    const radius: f32 = (config.corner_radius.top_left * 2) / @min(bounding_box.width, bounding_box.height);
                    ray.DrawRectangleRounded(
                        ray.Rectangle{
                            .x = bounding_box.x,
                            .y = bounding_box.y,
                            .width = bounding_box.width,
                            .height = bounding_box.height,
                        },
                        radius,
                        8,
                        clayColorToRaylibColor(config.background_color),
                    );
                } else {
                    ray.DrawRectangle(
                        @trunc(bounding_box.x),
                        @trunc(bounding_box.y),
                        @trunc(bounding_box.width),
                        @trunc(bounding_box.height),
                        clayColorToRaylibColor(config.background_color),
                    );
                }
            },
            .border => {
                const config = render_command.render_data.border;
                const color = clayColorToRaylibColor(config.color);
                const bb = bounding_box;
                const corners = config.corner_radius;

                const drawRect = struct {
                    fn draw(x: f32, y: f32, w: f32, h: f32, c: ray.Color) void {
                        ray.DrawRectangle(@round(x), @round(y), @round(w), @round(h), c);
                    }
                }.draw;

                drawRect(
                    bb.x,
                    bb.y + corners.top_left,
                    @floatFromInt(config.width.left),
                    bb.height - corners.top_left - corners.bottom_left,
                    color,
                );

                drawRect(
                    bb.x + bb.width - @as(f32, @floatFromInt(config.width.right)),
                    bb.y + corners.top_right,
                    @floatFromInt(config.width.right),
                    bb.height - corners.top_right - corners.bottom_right,
                    color,
                );

                drawRect(
                    bb.x + corners.top_left,
                    bb.y,
                    bb.width - corners.top_left - corners.top_right,
                    @floatFromInt(config.width.top),
                    color,
                );

                drawRect(
                    bb.x + corners.bottom_left,
                    bb.y + bb.height - @as(f32, @floatFromInt(config.width.bottom)),
                    bb.width - corners.bottom_left - corners.bottom_right,
                    @floatFromInt(config.width.bottom),
                    color,
                );

                const drawCorner = struct {
                    fn draw(center: ray.Vector2, innerRadius: f32, outerRadius: f32, startAngle: f32, endAngle: f32, c: ray.Color) void {
                        if (outerRadius <= 0) return;
                        ray.DrawRing(center, @round(innerRadius), @round(outerRadius), startAngle, endAngle, 10, c);
                    }
                }.draw;

                drawCorner(
                    ray.Vector2{ .x = @round(bb.x + corners.top_left), .y = @round(bb.y + corners.top_left) },
                    corners.top_left - @as(f32, @floatFromInt(config.width.top)),
                    corners.top_left,
                    180,
                    270,
                    color,
                );

                drawCorner(
                    ray.Vector2{ .x = @round(bb.x + bb.width - corners.top_right), .y = @round(bb.y + corners.top_right) },
                    corners.top_right - @as(f32, @floatFromInt(config.width.top)),
                    corners.top_right,
                    270,
                    360,
                    color,
                );

                drawCorner(
                    ray.Vector2{ .x = @round(bb.x + corners.bottom_left), .y = @round(bb.y + bb.height - corners.bottom_left) },
                    corners.bottom_left - @as(f32, @floatFromInt(config.width.bottom)),
                    corners.bottom_left,
                    90,
                    180,
                    color,
                );

                drawCorner(
                    ray.Vector2{ .x = @round(bb.x + bb.width - corners.bottom_right), .y = @round(bb.y + bb.height - corners.bottom_right) },
                    corners.bottom_right - @as(f32, @floatFromInt(config.width.bottom)),
                    corners.bottom_right,
                    0.1,
                    90,
                    color,
                );
            },
            .custom => {
                // Implement custom element rendering here
            },
        }
    }
}

pub const measureText = Harfbuzz.measureText;
pub const loadFont = Harfbuzz.loadFont;
