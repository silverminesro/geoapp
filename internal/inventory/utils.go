package inventory

import (
	"fmt"
	"strings"
)

// GenerateImageURL creates the image_url for frontend
func GenerateImageURL(itemType string, props map[string]interface{}) string {
	base := "https://cdn.geoanomaly.com/"
	switch itemType {
	case "artifact":
		rarity, _ := props["rarity"].(string)
		typ, _ := props["type"].(string)
		return fmt.Sprintf("%sartifacts/%s_%s.png", base, strings.ToLower(typ), strings.ToLower(rarity))
	case "gear":
		typ, _ := props["type"].(string)
		level := "1"
		if l, ok := props["level"]; ok {
			level = fmt.Sprintf("%v", l)
		}
		return fmt.Sprintf("%sgear/%s_%s.png", base, strings.ToLower(typ), level)
	default:
		return base + "default.png"
	}
}

func GenerateIconKey(itemType string, props map[string]interface{}) string {
	switch itemType {
	case "artifact":
		rarity, _ := props["rarity"].(string)
		typ, _ := props["type"].(string)
		return fmt.Sprintf("%s_%s", strings.ToLower(typ), strings.ToLower(rarity))
	case "gear":
		typ, _ := props["type"].(string)
		level := "1"
		if l, ok := props["level"]; ok {
			level = fmt.Sprintf("%v", l)
		}
		return fmt.Sprintf("%s_%s", strings.ToLower(typ), level)
	default:
		return "default"
	}
}
