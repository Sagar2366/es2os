package transformer

import (
	"github.com/sutekar/es2os/pkg/analyzer"
	"github.com/sutekar/es2os/pkg/scanner"
)

// Transform generates OpenSearch-compatible mappings from ES mappings + analysis findings.
func Transform(scan *scanner.ScanResult, analysis *analyzer.AnalysisResult) *TransformResult {
	result := &TransformResult{
		Indices: make(map[string]TransformedIndex),
	}

	for indexName, indexInfo := range scan.Indices {
		// Skip multi-type indices (manual only)
		if indexInfo.Mappings.IsMultiType {
			result.Indices[indexName] = TransformedIndex{
				Name:       indexName,
				Skipped:    true,
				SkipReason: "Multi-type index requires manual splitting",
			}
			result.Summary.IndicesSkipped++
			continue
		}

		transformed := transformIndex(indexName, &indexInfo)
		if len(transformed.Changes) == 0 {
			result.Summary.IndicesClean++
		} else {
			result.Summary.IndicesTransformed++
			result.Summary.TotalChanges += len(transformed.Changes)
		}
		result.Indices[indexName] = transformed
	}

	return result
}

func transformIndex(name string, info *scanner.IndexInfo) TransformedIndex {
	ti := TransformedIndex{
		Name:       name,
		NewMapping: make(map[string]interface{}),
	}

	// Transform properties (fields)
	newProps := transformProperties(info.Mappings.Properties, "", &ti.Changes)
	ti.NewMapping["properties"] = newProps

	// Transform settings
	newSettings, settingsChanges := TransformSettings(info.Settings)
	ti.Changes = append(ti.Changes, settingsChanges...)
	if len(newSettings) > 0 {
		ti.NewMapping["settings"] = map[string]interface{}{
			"index": newSettings,
		}
	}

	// Preserve _source if present
	if info.Mappings.Source != nil {
		ti.NewMapping["_source"] = info.Mappings.Source
	}

	return ti
}

func transformProperties(props map[string]scanner.FieldMapping, prefix string, changes *[]Change) map[string]interface{} {
	result := make(map[string]interface{})

	for name, field := range props {
		fullPath := name
		if prefix != "" {
			fullPath = prefix + "." + name
		}

		switch field.Type {
		case "dense_vector":
			newField, change := TransformDenseVector(fullPath, field.Dims, field.Similarity)
			result[name] = newField
			*changes = append(*changes, change)

		default:
			// Preserve the field as-is, but recurse into nested properties
			fieldMap := make(map[string]interface{})
			if field.Type != "" {
				fieldMap["type"] = field.Type
			}
			if field.Analyzer != "" {
				fieldMap["analyzer"] = field.Analyzer
			}
			if field.SearchAnalyzer != "" {
				fieldMap["search_analyzer"] = field.SearchAnalyzer
			}
			if field.Properties != nil {
				fieldMap["properties"] = transformProperties(field.Properties, fullPath, changes)
			}
			// Copy any extra raw fields we didn't explicitly model
			for k, v := range field.Raw {
				if k != "type" && k != "analyzer" && k != "search_analyzer" && k != "properties" {
					fieldMap[k] = v
				}
			}
			result[name] = fieldMap
		}
	}

	return result
}
