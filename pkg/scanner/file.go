package scanner

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

// ScanFile reads Elasticsearch mappings from a JSON file.
// Supports two formats:
//  1. Multi-index: {"index_name": {"mappings": {...}, "settings": {...}}, ...}
//  2. Single-index: {"mappings": {...}, "settings": {...}}
func ScanFile(path, sourceVersion, targetVersion string) (*ScanResult, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading file: %w", err)
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parsing JSON: %w", err)
	}

	result := &ScanResult{
		SourceVersion: sourceVersion,
		TargetVersion: targetVersion,
		Indices:       make(map[string]IndexInfo),
	}

	// Detect format: if top-level has "mappings" key, it's single-index
	if _, hasMappings := raw["mappings"]; hasMappings {
		idx, err := parseIndex("unnamed", data)
		if err != nil {
			return nil, err
		}
		result.Indices["unnamed"] = idx
	} else {
		// Multi-index format
		for name, indexData := range raw {
			// Skip special keys
			if strings.HasPrefix(name, "_") {
				continue
			}
			idx, err := parseIndex(name, indexData)
			if err != nil {
				return nil, fmt.Errorf("parsing index %q: %w", name, err)
			}
			result.Indices[name] = idx
		}
	}

	// Count total fields
	for _, idx := range result.Indices {
		result.TotalFields += countFields(idx.Mappings.Properties)
		for _, t := range idx.Mappings.Types {
			result.TotalFields += countFields(t.Properties)
		}
	}

	return result, nil
}

func parseIndex(name string, data []byte) (IndexInfo, error) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return IndexInfo{}, err
	}

	idx := IndexInfo{
		Name:     name,
		Settings: make(map[string]interface{}),
	}

	// Parse settings
	if settingsData, ok := raw["settings"]; ok {
		var settings map[string]interface{}
		if err := json.Unmarshal(settingsData, &settings); err == nil {
			// Flatten "index" sub-key if present
			if indexSettings, ok := settings["index"].(map[string]interface{}); ok {
				idx.Settings = indexSettings
			} else {
				idx.Settings = settings
			}
		}
	}

	// Parse aliases
	if aliasData, ok := raw["aliases"]; ok {
		json.Unmarshal(aliasData, &idx.Aliases)
	}

	// Parse mappings
	if mappingsData, ok := raw["mappings"]; ok {
		idx.Mappings = parseMappings(mappingsData)
	}

	return idx, nil
}

func parseMappings(data []byte) IndexMappings {
	mappings := IndexMappings{}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return mappings
	}

	// Check for _source
	if sourceData, ok := raw["_source"]; ok {
		var sc SourceConfig
		if err := json.Unmarshal(sourceData, &sc); err == nil {
			mappings.Source = &sc
		}
	}

	// Check for _meta
	if metaData, ok := raw["_meta"]; ok {
		json.Unmarshal(metaData, &mappings.Meta)
	}

	// Check for properties (single-type index)
	if propsData, ok := raw["properties"]; ok {
		mappings.Properties = parseProperties(propsData)
		return mappings
	}

	// If no "properties" at top level, check for multi-type format
	// In multi-type, each key (other than _source, _meta) is a type name containing {"properties": {...}}
	mappings.Types = make(map[string]TypeMapping)
	for key, typeData := range raw {
		if strings.HasPrefix(key, "_") {
			continue
		}

		var typeRaw map[string]json.RawMessage
		if err := json.Unmarshal(typeData, &typeRaw); err != nil {
			continue
		}

		if propsData, ok := typeRaw["properties"]; ok {
			mappings.Types[key] = TypeMapping{
				Properties: parseProperties(propsData),
			}
			mappings.IsMultiType = true
		}
	}

	return mappings
}

func parseProperties(data []byte) map[string]FieldMapping {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil
	}

	fields := make(map[string]FieldMapping)
	for name, fieldData := range raw {
		fields[name] = parseField(fieldData)
	}
	return fields
}

func parseField(data []byte) FieldMapping {
	var field FieldMapping

	// First unmarshal into raw map to capture everything
	var raw map[string]interface{}
	json.Unmarshal(data, &raw)
	field.Raw = raw

	// Extract known fields
	if t, ok := raw["type"].(string); ok {
		field.Type = t
	}
	if d, ok := raw["dims"].(float64); ok {
		field.Dims = int(d)
	}
	if s, ok := raw["similarity"].(string); ok {
		field.Similarity = s
	}
	if a, ok := raw["analyzer"].(string); ok {
		field.Analyzer = a
	}
	if sa, ok := raw["search_analyzer"].(string); ok {
		field.SearchAnalyzer = sa
	}
	if idx, ok := raw["index"].(bool); ok {
		field.Index = &idx
	}

	// Parse nested properties (object/nested types)
	if propsRaw, ok := raw["properties"]; ok {
		propsJSON, _ := json.Marshal(propsRaw)
		field.Properties = parseProperties(propsJSON)
	}

	return field
}

func countFields(props map[string]FieldMapping) int {
	count := 0
	for _, f := range props {
		count++
		if f.Properties != nil {
			count += countFields(f.Properties)
		}
	}
	return count
}
