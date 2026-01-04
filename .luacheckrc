std = "lua51"
globals = { "vim" }
max_line_length = 80
codes = true

files["tests/**/*.lua"] = {
	globals = { "describe", "it", "assert", "before_each", "after_each" },
}

include_files = {
	"lua/",
	"ftplugin/",
	"plugin/",
	"tests/",
}

exclude_files = {
	"tests/fixtures/",
	".luacheckrc",
}

unused_args = true
unused_secondaries = true
self = false
