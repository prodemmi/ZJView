const std = @import("std");

// Large buffer for processing big JSON files
var json_buffer: [1000 * 1024 * 1024]u8 = undefined; // 10MB buffer
var json_length: usize = 0;

// Result buffer for keys/values
var result_buffer: [1024 * 1024]u8 = undefined; // 1MB for results
var result_length: usize = 0;

// Statistics
var stats: struct {
    total_keys: usize = 0,
    total_objects: usize = 0,
    total_arrays: usize = 0,
    max_depth: usize = 0,
    file_size: usize = 0,
} = .{};

// Error messages
const ERROR_INVALID_JSON = "INVALID_JSON";
const ERROR_BUFFER_OVERFLOW = "BUFFER_OVERFLOW";
const ERROR_EMPTY_INPUT = "EMPTY_INPUT";

// Memory management functions
pub export fn get_json_buffer() callconv(.C) [*]u8 {
    return &json_buffer;
}

pub export fn get_json_buffer_size() callconv(.C) usize {
    return json_buffer.len;
}

pub export fn set_json_length(len: usize) callconv(.C) void {
    json_length = @min(len, json_buffer.len);
}

pub export fn get_result_buffer() callconv(.C) [*]const u8 {
    return &result_buffer;
}

pub export fn get_result_length() callconv(.C) usize {
    return result_length;
}

// Main processing function
pub export fn process_json() callconv(.C) i32 {
    if (json_length == 0) return -1; // Empty input

    // Reset stats
    stats = .{};
    result_length = 0;

    const input = json_buffer[0..json_length];
    stats.file_size = json_length;

    // Validate JSON structure
    if (!validateJSON(input)) return -2; // Invalid JSON

    // Process the JSON
    var depth: usize = 0;
    var i: usize = 0;

    while (i < input.len) {
        switch (input[i]) {
            '{' => {
                stats.total_objects += 1;
                depth += 1;
                stats.max_depth = @max(stats.max_depth, depth);
            },
            '}' => {
                if (depth > 0) depth -= 1;
            },
            '[' => {
                stats.total_arrays += 1;
                depth += 1;
                stats.max_depth = @max(stats.max_depth, depth);
            },
            ']' => {
                if (depth > 0) depth -= 1;
            },
            '"' => {
                // Check if this is a key
                if (isKey(input, i)) {
                    stats.total_keys += 1;
                    extractKey(input, i);
                }
                // Skip to end of string
                i = skipString(input, i);
                continue;
            },
            else => {},
        }
        i += 1;
    }

    return 0; // Success
}

// Extract all keys from JSON
pub export fn extract_all_keys() callconv(.C) usize {
    if (json_length == 0) return 0;

    const input = json_buffer[0..json_length];
    result_length = 0;

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '"') {
            if (isKey(input, i)) {
                extractKey(input, i);
            }
            i = skipString(input, i);
        } else {
            i += 1;
        }
    }

    return result_length;
}

// Get specific key value
pub export fn get_key_value(key_ptr: [*]const u8, key_len: usize) callconv(.C) usize {
    if (json_length == 0) return 0;

    const input = json_buffer[0..json_length];
    const search_key = key_ptr[0..key_len];
    result_length = 0;

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '"') {
            if (isKey(input, i)) {
                const key_start = i + 1;
                const key_end = findStringEnd(input, i);

                if (key_end > key_start) {
                    const current_key = input[key_start..key_end];
                    if (std.mem.eql(u8, current_key, search_key)) {
                        // Found the key, now get its value
                        const value_start = findValueStart(input, key_end + 1);
                        if (value_start < input.len) {
                            extractValue(input, value_start);
                            return result_length;
                        }
                    }
                }
                i = key_end;
            } else {
                i = skipString(input, i);
            }
        } else {
            i += 1;
        }
    }

    return 0;
}

// Statistics functions
pub export fn get_total_keys() callconv(.C) usize {
    return stats.total_keys;
}

pub export fn get_total_objects() callconv(.C) usize {
    return stats.total_objects;
}

pub export fn get_total_arrays() callconv(.C) usize {
    return stats.total_arrays;
}

pub export fn get_max_depth() callconv(.C) usize {
    return stats.max_depth;
}

pub export fn get_file_size() callconv(.C) usize {
    return stats.file_size;
}

// Helper functions
fn validateJSON(input: []const u8) bool {
    if (input.len == 0) return false;

    // Skip whitespace
    var i: usize = 0;
    while (i < input.len and isWhitespace(input[i])) i += 1;

    return i < input.len and (input[i] == '{' or input[i] == '[');
}

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

fn isKey(input: []const u8, pos: usize) bool {
    if (pos >= input.len) return false;

    const string_end = findStringEnd(input, pos);
    if (string_end >= input.len) return false;

    // Skip whitespace after string
    var i = string_end + 1;
    while (i < input.len and isWhitespace(input[i])) i += 1;

    return i < input.len and input[i] == ':';
}

fn findStringEnd(input: []const u8, start: usize) usize {
    var i = start + 1;
    while (i < input.len) {
        if (input[i] == '"') return i;
        if (input[i] == '\\' and i + 1 < input.len) {
            i += 2; // Skip escape sequence
        } else {
            i += 1;
        }
    }
    return input.len;
}

fn skipString(input: []const u8, start: usize) usize {
    return findStringEnd(input, start);
}

fn extractKey(input: []const u8, pos: usize) void {
    const key_start = pos + 1;
    const key_end = findStringEnd(input, pos);

    if (key_end > key_start) {
        const key = input[key_start..key_end];
        if (result_length + key.len + 1 < result_buffer.len) {
            @memcpy(result_buffer[result_length .. result_length + key.len], key);
            result_buffer[result_length + key.len] = '\n';
            result_length += key.len + 1;
        }
    }
}

fn findValueStart(input: []const u8, start: usize) usize {
    var i = start;
    // Skip whitespace and colon
    while (i < input.len and (isWhitespace(input[i]) or input[i] == ':')) i += 1;
    return i;
}

fn extractValue(input: []const u8, start: usize) void {
    if (start >= input.len) return;

    var end = start;
    var depth: i32 = 0;
    var in_string = false;

    while (end < input.len) {
        const c = input[end];

        if (in_string) {
            if (c == '"' and (end == 0 or input[end - 1] != '\\')) {
                in_string = false;
            }
        } else {
            switch (c) {
                '"' => in_string = true,
                '{', '[' => depth += 1,
                '}', ']' => {
                    depth -= 1;
                    if (depth < 0) break;
                },
                ',' => if (depth == 0) break,
                else => {},
            }
        }
        end += 1;
    }

    const value = input[start..end];
    if (result_length + value.len < result_buffer.len) {
        @memcpy(result_buffer[result_length .. result_length + value.len], value);
        result_length += value.len;
    }
}
