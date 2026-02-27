extends RefCounted
class_name MapData

## Stores theme configuration for a procedural arena

var map_name := "Unknown"
var map_description := ""
var arena_size := 44.0
var wall_height := 6.0

# Sky colors
var sky_top := Color(0.05, 0.05, 0.15)
var sky_horizon := Color(0.15, 0.08, 0.25)
var ground_bottom := Color(0.02, 0.02, 0.05)
var ground_horizon := Color(0.15, 0.08, 0.25)

# Lighting
var ambient_color := Color(0.4, 0.35, 0.5)
var ambient_energy := 0.3
var sun_color := Color(0.7, 0.75, 1.0)
var accent_color := Color(0.0, 0.8, 1.0)

# Fog
var fog_color := Color(0.12, 0.08, 0.18)
var fog_density := 0.005

# Materials
var floor_color := Color(0.12, 0.11, 0.13)
var wall_color := Color(0.08, 0.08, 0.1)
var cover_color := Color(0.18, 0.17, 0.2)
var glow_color := Color(0.0, 0.6, 1.0)
var glow_energy := 3.0

# Hazards
var has_lava := false
var has_ice := false
var has_void := false
var has_walls := true

# Post-processing
var tonemap_exposure := 1.1
var glow_intensity := 0.4
var volumetric_fog_density := 0.01
var ssr_enabled := true

# Preview color (for map selection UI)
var preview_color := Color(0.0, 0.8, 1.0)


static func neon_nexus() -> MapData:
	var m := MapData.new()
	m.map_name = "NEON NEXUS"
	m.map_description = "Dark sci-fi arena with neon glow"
	m.preview_color = Color(0.0, 0.8, 1.0)
	m.tonemap_exposure = 1.1
	m.glow_intensity = 0.5
	m.volumetric_fog_density = 0.008
	m.ssr_enabled = true
	return m


static func lava_foundry() -> MapData:
	var m := MapData.new()
	m.map_name = "LAVA FOUNDRY"
	m.map_description = "Volcanic arena with deadly lava pits"
	m.sky_top = Color(0.15, 0.02, 0.0)
	m.sky_horizon = Color(0.3, 0.1, 0.0)
	m.ground_bottom = Color(0.05, 0.01, 0.0)
	m.ground_horizon = Color(0.3, 0.1, 0.0)
	m.ambient_color = Color(0.5, 0.25, 0.1)
	m.sun_color = Color(1.0, 0.5, 0.2)
	m.accent_color = Color(1.0, 0.3, 0.0)
	m.fog_color = Color(0.2, 0.05, 0.0)
	m.fog_density = 0.008
	m.floor_color = Color(0.1, 0.06, 0.04)
	m.wall_color = Color(0.12, 0.05, 0.02)
	m.cover_color = Color(0.2, 0.1, 0.05)
	m.glow_color = Color(1.0, 0.3, 0.0)
	m.glow_energy = 4.0
	m.has_lava = true
	m.preview_color = Color(1.0, 0.3, 0.0)
	m.tonemap_exposure = 1.2
	m.glow_intensity = 0.6
	m.volumetric_fog_density = 0.015
	m.ssr_enabled = false
	return m


static func frozen_outpost() -> MapData:
	var m := MapData.new()
	m.map_name = "FROZEN OUTPOST"
	m.map_description = "Icy terrain with slippery ground"
	m.arena_size = 36.0
	m.sky_top = Color(0.1, 0.15, 0.25)
	m.sky_horizon = Color(0.4, 0.5, 0.6)
	m.ground_bottom = Color(0.1, 0.15, 0.2)
	m.ground_horizon = Color(0.4, 0.5, 0.6)
	m.ambient_color = Color(0.5, 0.6, 0.8)
	m.ambient_energy = 0.4
	m.sun_color = Color(0.7, 0.8, 1.0)
	m.accent_color = Color(0.3, 0.6, 1.0)
	m.fog_color = Color(0.5, 0.55, 0.65)
	m.fog_density = 0.01
	m.floor_color = Color(0.6, 0.65, 0.7)
	m.wall_color = Color(0.4, 0.45, 0.55)
	m.cover_color = Color(0.5, 0.55, 0.6)
	m.glow_color = Color(0.3, 0.6, 1.0)
	m.glow_energy = 2.5
	m.has_ice = true
	m.preview_color = Color(0.3, 0.6, 1.0)
	m.tonemap_exposure = 1.0
	m.glow_intensity = 0.3
	m.volumetric_fog_density = 0.02
	m.ssr_enabled = true
	return m


static func void_station() -> MapData:
	var m := MapData.new()
	m.map_name = "VOID STATION"
	m.map_description = "Floating platforms over the void"
	m.sky_top = Color(0.02, 0.0, 0.08)
	m.sky_horizon = Color(0.1, 0.0, 0.2)
	m.ground_bottom = Color(0.0, 0.0, 0.0)
	m.ground_horizon = Color(0.1, 0.0, 0.2)
	m.ambient_color = Color(0.3, 0.1, 0.5)
	m.ambient_energy = 0.2
	m.sun_color = Color(0.6, 0.3, 1.0)
	m.accent_color = Color(0.8, 0.0, 1.0)
	m.fog_color = Color(0.05, 0.0, 0.1)
	m.fog_density = 0.003
	m.floor_color = Color(0.08, 0.04, 0.12)
	m.wall_color = Color(0.06, 0.02, 0.1)
	m.cover_color = Color(0.12, 0.06, 0.18)
	m.glow_color = Color(0.8, 0.0, 1.0)
	m.glow_energy = 4.0
	m.has_void = true
	m.has_walls = false
	m.preview_color = Color(0.8, 0.0, 1.0)
	m.tonemap_exposure = 0.9
	m.glow_intensity = 0.5
	m.volumetric_fog_density = 0.005
	m.ssr_enabled = true
	return m


static func get_all_maps() -> Array[MapData]:
	return [neon_nexus(), lava_foundry(), frozen_outpost(), void_station()]
