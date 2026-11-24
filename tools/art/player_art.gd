extends RefCounted
## Hand-pixelled base frames for the player character (16x24 each).
## Walk/idle frames are derived from these by the generator (leg lifts and
## a 1px body bob), so editing a facing here updates all its animations.
##
## Legend:
##  o outline   h/H straw hat (light/shade)   r ribbon
##  k/K hair    s/S skin   e eyes   c blush
##  w/W blouse  b/B overalls (recoloured in-game by the outfit shader)
##  t boots     . transparent

const WIDTH := 16
const HEIGHT := 24

const DOWN: Array[String] = [
	"................",
	".....oooooo.....",
	"....ohhhhhho....",
	"...ohhhhhhhho...",
	"..oHHrrrrrrHHo..",
	".oohhhhhhhhhhoo.",
	"ohhhhhhhhhhhhhho",
	".ooKkkkkkkkkKoo.",
	"...okssssssko...",
	"...oksessesko...",
	"...okcsssscko...",
	"...okKsSSsKko...",
	"...okKossoKko...",
	"..okwwwwwwwwko..",
	"..owbwwwwwwbwo..",
	".oswbbbbbbbbwso.",
	".osWbbbrbbbbWso.",
	".ossbbbbbbbbsso.",
	"..oobbbbbbbboo..",
	"...obbbBBbbbo...",
	"...obbBooBbbo...",
	"...oBBo..oBBo...",
	"...otto..otto...",
	"...oooo..oooo...",
]

const UP: Array[String] = [
	"................",
	".....oooooo.....",
	"....ohhhhhho....",
	"...ohhhhhhhho...",
	"..oHHHHHHHHHHo..",
	".oohhhhhhhhhhoo.",
	"ohhhhhhhhhhhhhho",
	".ooKkkkkkkkkKoo.",
	"...okkkkkkkko...",
	"...okkkKKkkko...",
	"...okkkkkkkko...",
	"...oKkkkkkkKo...",
	"...okKkkkkKko...",
	"..okwkkkkkkwko..",
	"..owbwkrrkwbwo..",
	".oswbbbbbbbbwso.",
	".osWbbbbbbbbWso.",
	".ossbbbbbbbbsso.",
	"..oobbbbbbbboo..",
	"...obbbBBbbbo...",
	"...obbBooBbbo...",
	"...oBBo..oBBo...",
	"...otto..otto...",
	"...oooo..oooo...",
]

const RIGHT: Array[String] = [
	"................",
	"....oooooo......",
	"...ohhhhhhoo....",
	"..ohhhhhhhhho...",
	"..oHHHHrrrrHo...",
	".oohhhhhhhhhhoo.",
	"ohhhhhhhhhhhhhho",
	".ooKkkkkkkkKooo.",
	"...okkkkssssso..",
	"...okkkkssseso..",
	"...okkkksscsso..",
	"...okKkkssssSo..",
	"...okKkoSsso....",
	"....okkwwwwwo...",
	"....okwbwwwo....",
	"....owbbbbbso...",
	"....oWbbrbbso...",
	"....obbbbbsso...",
	"....obbbbbbo....",
	"....obbBBbbo....",
	"....obBoobbo....",
	"....oBBooBBo....",
	"....ottooottoo..",
	"....oooo.oooo...",
]
