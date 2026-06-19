const std = @import("std");
pub const ray = @cImport({
    @cInclude("raylib.h");
});
const cl = @import("zclay");
const math = std.math;
const hb = @import("harfbuzz");

pub fn clayColorToRaylibColor(color: cl.Color) ray.Color {
    return ray.Color{
        .r = @trunc(color[0]),
        .g = @trunc(color[1]),
        .b = @trunc(color[2]),
        .a = @trunc(color[3]),
    };
}

pub var raylib_fonts: [10]?ray.Font = @splat(null);

const SUBPIXEL_BITS: i32 = 6;
const SUBPIXEL_SCALE: i32 = 1 << SUBPIXEL_BITS; // 64, like FreeType's 26.6

pub const HbFontSlot = struct {
    font: *hb.c.hb_font_t,
    /// true if the face has color glyphs (COLR/CPAL/CBDT/sbix/SVG) -> use
    /// hb_raster_paint_*, otherwise use hb_raster_draw_* (outline coverage).
    is_color: bool,
};

pub var hb_font_slots: [10]?HbFontSlot = @splat(null);

pub fn loadHarfbuzzFont(font_id: usize, file_data: []const u8, font_size: i32) !void {
    const blob = hb.c.hb_blob_create(
        file_data.ptr,
        @intCast(file_data.len),
        hb.c.HB_MEMORY_MODE_READONLY,
        null,
        null,
    ) orelse return error.FontLoadFailed;
    std.debug.print("VERSION {s}\n", .{hb.versionString()});

    const face = hb.c.hb_face_create(blob, 0) orelse return error.FontLoadFailed;

    const font = hb.c.hb_font_create(face) orelse return error.FontLoadFailed;
    hb.c.hb_font_set_scale(font, font_size * SUBPIXEL_SCALE, font_size * SUBPIXEL_SCALE);

    const is_color = hb.c.hb_ot_color_has_paint(face) != 0 or
        hb.c.hb_ot_color_has_layers(face) != 0 or
        hb.c.hb_ot_color_has_png(face) != 0;

    hb_font_slots[font_id] = .{ .font = font, .is_color = is_color };
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
                const text =
                    config.string_contents.chars[0..@intCast(config.string_contents.length)];

                const slot = hb_font_slots[config.font_id] orelse continue;

                const font_size: i32 = @intCast(config.font_size);

                hb.c.hb_font_set_scale(
                    slot.font,
                    font_size * SUBPIXEL_SCALE,
                    font_size * SUBPIXEL_SCALE,
                );

                //------------------------
                // Shape
                //------------------------

                const buf = hb.c.hb_buffer_create();
                defer hb.c.hb_buffer_destroy(buf);

                hb.c.hb_buffer_add_utf8(
                    buf,
                    text.ptr,
                    @intCast(text.len),
                    0,
                    @intCast(text.len),
                );

                hb.c.hb_buffer_guess_segment_properties(buf);

                hb.c.hb_shape(
                    slot.font,
                    buf,
                    null,
                    0,
                );

                const len = hb.c.hb_buffer_get_length(buf);

                if (len == 0)
                    continue;

                const info =
                    hb.c.hb_buffer_get_glyph_infos(buf, null);

                const pos =
                    hb.c.hb_buffer_get_glyph_positions(buf, null);

                //---------------------------------
                // Compute text extents
                //---------------------------------

                var width: f32 = 0;

                for (0..len) |i| {
                    width += @as(
                        f32,
                        @floatFromInt(pos[i].x_advance),
                    );
                }

                var h_ext: hb.c.hb_font_extents_t = undefined;

                _ = hb.c.hb_font_get_h_extents(
                    slot.font,
                    &h_ext,
                );

                const ascender: i32 = @divTrunc(h_ext.ascender, SUBPIXEL_SCALE);
                const descender: i32 = @divTrunc((-h_ext.descender), SUBPIXEL_SCALE);

                const height =
                    @as(f32, @floatFromInt(
                        ascender + descender,
                    ));

                var ext: hb.c.hb_raster_extents_t = .{
                    .x_origin = 0,
                    .y_origin = 0,
                    .width = @intFromFloat(@ceil(width / SUBPIXEL_SCALE)),
                    .height = @intFromFloat(@ceil(height)),
                    .stride = @intFromFloat(@ceil(width / SUBPIXEL_SCALE)),
                };

                //---------------------------------
                // Rasterizer
                //---------------------------------

                const img = blk: {
                    if (slot.is_color) {
                        const p =
                            hb.c.hb_raster_paint_create_or_fail() orelse continue;

                        defer hb.c.hb_raster_paint_destroy(p);

                        var pen_x: f32 = 0;
                        var pen_y: f32 = 0;

                        for (0..len) |i| {
                            const gx =
                                pen_x +
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].x_offset),
                                );

                            const gy =
                                pen_y +
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].y_offset),
                                );

                            hb.c.hb_raster_paint_set_extents(
                                p,
                                &ext,
                            );

                            hb.c.hb_raster_paint_set_scale_factor(p, SUBPIXEL_SCALE, SUBPIXEL_SCALE);
                            hb.c.hb_raster_paint_set_transform(
                                p,
                                1,
                                0,
                                0,
                                1,
                                gx,
                                gy,
                            );

                            hb.c.hb_raster_paint_glyph(
                                p,
                                slot.font,
                                info[i].codepoint,
                            );

                            pen_x +=
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].x_advance),
                                );

                            pen_y +=
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].y_advance),
                                );
                        }

                        break :blk hb.c.hb_raster_paint_render(p);
                    } else {
                        const d =
                            hb.c.hb_raster_draw_create_or_fail() orelse continue;

                        defer hb.c.hb_raster_draw_destroy(d);

                        var pen_x: f32 = 0;
                        var pen_y: f32 = 0;

                        for (0..len) |i| {
                            const gx =
                                pen_x +
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].x_offset),
                                );

                            const gy =
                                pen_y +
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].y_offset),
                                );

                            hb.c.hb_raster_draw_set_extents(
                                d,
                                &ext,
                            );

                            hb.c.hb_raster_draw_set_scale_factor(d, SUBPIXEL_SCALE, SUBPIXEL_SCALE);

                            hb.c.hb_raster_draw_set_transform(
                                d,
                                1,
                                0,
                                0,
                                1,
                                gx,
                                gy,
                            );

                            hb.c.hb_raster_draw_glyph(
                                d,
                                slot.font,
                                info[i].codepoint,
                            );

                            pen_x +=
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].x_advance),
                                );

                            pen_y +=
                                @as(
                                    f32,
                                    @floatFromInt(pos[i].y_advance),
                                );
                        }

                        break :blk hb.c.hb_raster_draw_render(d);
                    }
                };

                const raster = img orelse continue;
                defer hb.c.hb_raster_image_destroy(raster);

                //---------------------------------
                // Raylib
                //---------------------------------

                const src =
                    hb.c.hb_raster_image_get_buffer(raster) orelse continue;

                const format =
                    hb.c.hb_raster_image_get_format(raster);

                hb.c.hb_raster_image_get_extents(
                    raster,
                    &ext,
                );

                const count =
                    @as(usize, ext.width) *
                    @as(usize, ext.height);

                const copy = try arena.allocator().alloc(
                    u8,
                    count * 4,
                );
                if (format == hb.c.HB_RASTER_FORMAT_A8) {
                    for (0..count) |i| {
                        const a = src[i];

                        copy[i * 4 + 0] = 255;
                        copy[i * 4 + 1] = 255;
                        copy[i * 4 + 2] = 255;
                        copy[i * 4 + 3] = a;
                    }
                } else {
                    for (0..count) |i| {
                        copy[i * 4 + 0] = src[i * 4 + 2];
                        copy[i * 4 + 1] = src[i * 4 + 1];
                        copy[i * 4 + 2] = src[i * 4 + 0];
                        copy[i * 4 + 3] = src[i * 4 + 3];
                    }
                }

                const row_size = @as(usize, ext.width) * 4;

                var tmp = try arena.allocator().alloc(u8, copy.len);

                for (0..ext.height) |y| {
                    const src_y = ext.height - 1 - y;

                    @memcpy(
                        tmp[y * row_size .. (y + 1) * row_size],
                        copy[src_y * row_size .. (src_y + 1) * row_size],
                    );
                }

                @memcpy(copy, tmp);

                const img_ray = ray.Image{
                    .data = copy.ptr,
                    .width = @intCast(ext.width),
                    .height = @intCast(ext.height),
                    .mipmaps = 1,
                    .format = ray.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
                };

                const tex =
                    ray.LoadTextureFromImage(img_ray);

                ray.DrawTextureV(
                    tex,
                    .{
                        .x = bounding_box.x + @as(f32, @floatFromInt(ext.x_origin)),
                        .y = bounding_box.y + @as(f32, @floatFromInt(ext.y_origin)),
                    },
                    clayColorToRaylibColor(
                        config.text_color,
                    ),
                );
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

pub fn measureText(clay_text: []const u8, config: *cl.TextElementConfig, _: void) cl.Dimensions {
    const font_size: i32 = @intCast(config.font_size);

    const slot = hb_font_slots[config.font_id] orelse {
        const count =
            std.unicode.utf8CountCodepoints(clay_text) catch clay_text.len;

        return .{
            .w = @as(f32, @floatFromInt(count)) *
                @as(f32, @floatFromInt(font_size)) * 0.6,
            .h = @floatFromInt(font_size),
        };
    };

    // IMPORTANT:
    // use the same scale as rendering
    hb.c.hb_font_set_scale(
        slot.font,
        font_size * SUBPIXEL_SCALE,
        font_size * SUBPIXEL_SCALE,
    );

    var max_width: f32 = 0;
    var line_count: usize = 0;

    var lines = std.mem.splitScalar(
        u8,
        clay_text,
        '\n',
    );

    while (lines.next()) |line| {
        line_count += 1;

        const buf = hb.c.hb_buffer_create();
        defer hb.c.hb_buffer_destroy(buf);

        hb.c.hb_buffer_add_utf8(
            buf,
            line.ptr,
            @intCast(line.len),
            0,
            @intCast(line.len),
        );

        hb.c.hb_buffer_guess_segment_properties(buf);

        hb.c.hb_shape(
            slot.font,
            buf,
            null,
            0,
        );

        const len = hb.c.hb_buffer_get_length(buf);

        if (len == 0)
            continue;

        const pos = hb.c.hb_buffer_get_glyph_positions(
            buf,
            null,
        );

        var width: f32 = 0;

        for (0..len) |i| {
            width += @as(
                f32,
                @floatFromInt(pos[i].x_advance),
            ) / SUBPIXEL_SCALE;
        }

        if (width > max_width)
            max_width = width;
    }

    if (line_count == 0)
        line_count = 1;

    const line_height =
        if (config.line_height > 0)
            @as(f32, @floatFromInt(config.line_height))
        else
            @as(f32, @floatFromInt(font_size));

    return .{
        .w = max_width,
        .h = line_height * @as(f32, @floatFromInt(line_count)),
    };
}
