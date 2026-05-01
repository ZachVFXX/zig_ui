pub const clay = @import("zclay");

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
