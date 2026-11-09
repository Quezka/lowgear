class_name Icons
extends RefCounted
## Material Symbols (Google, Apache 2.0, assets/icons/MaterialSymbols-LICENSE.txt), white,
## rendered sharp at the size asked for and tinted by the caller.

static var _cache: Dictionary = {}


static func tex(icon_name: String, size := 64) -> Texture2D:
	var key := "%s@%d" % [icon_name, size]
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D
	var path := "res://assets/icons/%s.svg" % icon_name
	if ResourceLoader.exists(path):
		var img := (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## A TextureRect showing an icon, for rows of icon + text.
static func rect(icon_name: String, size := 28, tint := Color("#fff8f0")) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(icon_name, size * 2)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
