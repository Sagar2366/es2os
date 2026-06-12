package transformer

// DeprecatedSettings lists settings that should be removed during transformation.
var DeprecatedSettings = map[string]string{
	"mapper.dynamic":       "Removed in OpenSearch. Dynamic mapping is controlled at mapping level.",
	"soft_deletes.enabled": "Always enabled in OpenSearch. Setting is unnecessary.",
	"merge.policy":         "OpenSearch uses optimized merge defaults.",
	"merge.scheduler":      "OpenSearch uses optimized merge defaults.",
}

// TransformSettings removes deprecated settings and returns changes.
func TransformSettings(settings map[string]interface{}) (map[string]interface{}, []Change) {
	newSettings := make(map[string]interface{})
	var changes []Change

	for key, value := range settings {
		if reason, deprecated := DeprecatedSettings[key]; deprecated {
			changes = append(changes, Change{
				FieldPath:   "settings.index." + key,
				Description: "Removed: " + reason,
				Before:      key + " = " + formatValue(value),
				After:       "(removed)",
			})
			continue
		}
		newSettings[key] = value
	}

	return newSettings, changes
}

func formatValue(v interface{}) string {
	switch val := v.(type) {
	case string:
		return val
	case bool:
		if val {
			return "true"
		}
		return "false"
	case float64:
		return itoa(int(val))
	default:
		return "(complex)"
	}
}
