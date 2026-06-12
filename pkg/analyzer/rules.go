package analyzer

import (
	"fmt"
	"strings"

	"github.com/sutekar/es2os/pkg/scanner"
)

// AllRules returns the complete set of analysis rules.
func AllRules() []Rule {
	return []Rule{
		ruleVEC001(),
		ruleVEC002(),
		ruleTYP001(),
		ruleSRC001(),
		ruleSET001(),
		ruleSET002(),
		ruleSET003(),
		ruleANZ001(),
		ruleANZ002(),
		ruleANZ003(),
		ruleILM001(),
		ruleDST001(),
	}
}

// VEC001: dense_vector requires knn_vector transformation
func ruleVEC001() Rule {
	return Rule{
		ID:       "VEC001",
		Title:    "dense_vector → knn_vector transformation",
		Category: CategoryMapping,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			var findings []Finding
			checkFieldsForDenseVector(indexName, info.Mappings.Properties, "", &findings)
			for _, t := range info.Mappings.Types {
				checkFieldsForDenseVector(indexName, t.Properties, "", &findings)
			}
			return findings
		},
	}
}

func checkFieldsForDenseVector(indexName string, props map[string]scanner.FieldMapping, prefix string, findings *[]Finding) {
	for name, field := range props {
		fullName := name
		if prefix != "" {
			fullName = prefix + "." + name
		}
		if field.Type == "dense_vector" {
			sim := field.Similarity
			if sim == "" {
				sim = "l2_norm"
			}
			*findings = append(*findings, Finding{
				IndexName:   indexName,
				FieldName:   fullName,
				RuleID:      "VEC001",
				Title:       "dense_vector → knn_vector transformation needed",
				Description: fmt.Sprintf("Field %q is type dense_vector (dims=%d, similarity=%s). OpenSearch uses knn_vector with different structure.", fullName, field.Dims, sim),
				Severity:    SeverityCritical,
				Category:    CategoryMapping,
				AutoFix:     true,
				Action:      "es2os will transform: dims→dimension, similarity→method.space_type, add engine config",
			})
		}
		if field.Properties != nil {
			checkFieldsForDenseVector(indexName, field.Properties, fullName, findings)
		}
	}
}

// VEC002: Index-level knn settings (v3.3.1 bug)
func ruleVEC002() Rule {
	return Rule{
		ID:       "VEC002",
		Title:    "Index-level knn setting",
		Category: CategorySettings,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			var findings []Finding
			for key := range info.Settings {
				if key == "knn" || strings.HasPrefix(key, "knn.") {
					findings = append(findings, Finding{
						IndexName:   indexName,
						RuleID:      "VEC002",
						Title:       "Index-level knn setting detected",
						Description: fmt.Sprintf("Setting index.%s found. Migration Assistant v3.3.1 fixed an infinite create-index retry loop caused by this setting.", key),
						Severity:    SeverityWarning,
						Category:    CategorySettings,
						AutoFix:     true,
						Action:      "Ensure Migration Assistant >= v3.3.1. Setting will be preserved but may need adjustment.",
					})
					break // one finding per index is enough
				}
			}
			return findings
		},
	}
}

// TYP001: Multi-type index detected
func ruleTYP001() Rule {
	return Rule{
		ID:       "TYP001",
		Title:    "Multi-type index",
		Category: CategoryMapping,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			if !info.Mappings.IsMultiType {
				return nil
			}
			typeNames := make([]string, 0, len(info.Mappings.Types))
			for t := range info.Mappings.Types {
				typeNames = append(typeNames, t)
			}
			return []Finding{{
				IndexName:   indexName,
				RuleID:      "TYP001",
				Title:       "Multi-type index detected",
				Description: fmt.Sprintf("Index has %d types: [%s]. OpenSearch does not support multiple types per index.", len(typeNames), strings.Join(typeNames, ", ")),
				Severity:    SeverityCritical,
				Category:    CategoryMapping,
				AutoFix:     false,
				Action:      "Split into separate indices or flatten. Queries using _type filter must be rewritten.",
			}}
		},
	}
}

// SRC001: _source disabled
func ruleSRC001() Rule {
	return Rule{
		ID:       "SRC001",
		Title:    "_source disabled index",
		Category: CategoryMapping,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			if info.Mappings.Source == nil {
				return nil
			}
			if info.Mappings.Source.Enabled != nil && !*info.Mappings.Source.Enabled {
				return []Finding{{
					IndexName:   indexName,
					RuleID:      "SRC001",
					Title:       "_source disabled — empty documents risk",
					Description: "Index has _source disabled. Before Migration Assistant v3.1.0, this silently produces EMPTY documents.",
					Severity:    SeverityWarning,
					Category:    CategoryMapping,
					AutoFix:     false,
					Action:      "Ensure Migration Assistant >= v3.1.0 which reconstructs _source from stored fields.",
				}}
			}
			return nil
		},
	}
}

// SET001: Deprecated index.mapper.dynamic
func ruleSET001() Rule {
	return Rule{
		ID:       "SET001",
		Title:    "Deprecated setting: mapper.dynamic",
		Category: CategorySettings,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			if _, ok := info.Settings["mapper.dynamic"]; ok {
				return []Finding{{
					IndexName:   indexName,
					RuleID:      "SET001",
					Title:       "Deprecated setting: index.mapper.dynamic",
					Description: "Setting index.mapper.dynamic is removed in OpenSearch. Dynamic mapping is controlled at the mapping level.",
					Severity:    SeverityWarning,
					Category:    CategorySettings,
					AutoFix:     true,
					Action:      "Setting will be removed during transformation.",
				}}
			}
			return nil
		},
	}
}

// SET002: Deprecated merge.policy settings
func ruleSET002() Rule {
	return Rule{
		ID:       "SET002",
		Title:    "Changed setting: merge.policy",
		Category: CategorySettings,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			for key := range info.Settings {
				if strings.HasPrefix(key, "merge.policy") || strings.HasPrefix(key, "merge.scheduler") {
					return []Finding{{
						IndexName:   indexName,
						RuleID:      "SET002",
						Title:       "Changed merge policy settings",
						Description: fmt.Sprintf("Setting index.%s may behave differently in OpenSearch.", key),
						Severity:    SeverityInfo,
						Category:    CategorySettings,
						AutoFix:     true,
						Action:      "Setting will be removed. OpenSearch uses optimized defaults.",
					}}
				}
			}
			return nil
		},
	}
}

// SET003: soft_deletes.enabled (always enabled in OS)
func ruleSET003() Rule {
	return Rule{
		ID:       "SET003",
		Title:    "Unnecessary setting: soft_deletes.enabled",
		Category: CategorySettings,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			if _, ok := info.Settings["soft_deletes.enabled"]; ok {
				return []Finding{{
					IndexName:   indexName,
					RuleID:      "SET003",
					Title:       "Unnecessary setting: index.soft_deletes.enabled",
					Description: "Soft deletes are always enabled in OpenSearch. This setting is ignored.",
					Severity:    SeverityWarning,
					Category:    CategorySettings,
					AutoFix:     true,
					Action:      "Setting will be removed during transformation.",
				}}
			}
			return nil
		},
	}
}

// ANZ001: ICU analyzer plugin
func ruleANZ001() Rule {
	return Rule{
		ID:       "ANZ001",
		Title:    "ICU analyzer plugin",
		Category: CategoryAnalyzer,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			if hasAnalysisReference(info, "icu_tokenizer", "icu_folding", "icu_collation", "icu_normalizer") {
				return []Finding{{
					IndexName:   indexName,
					RuleID:      "ANZ001",
					Title:       "ICU analyzer plugin detected",
					Description: "Index uses ICU analysis components (icu_tokenizer, icu_folding, etc.).",
					Severity:    SeverityWarning,
					Category:    CategoryAnalyzer,
					AutoFix:     false,
					Action:      "Verify analysis-icu plugin is installed on target OpenSearch cluster.",
				}}
			}
			return nil
		},
	}
}

// ANZ002: Kuromoji analyzer plugin
func ruleANZ002() Rule {
	return Rule{
		ID:       "ANZ002",
		Title:    "Kuromoji analyzer plugin",
		Category: CategoryAnalyzer,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			if hasAnalysisReference(info, "kuromoji_tokenizer", "kuromoji_baseform", "kuromoji_stemmer", "kuromoji_number") {
				return []Finding{{
					IndexName:   indexName,
					RuleID:      "ANZ002",
					Title:       "Kuromoji analyzer plugin detected",
					Description: "Index uses Kuromoji analysis components for Japanese text.",
					Severity:    SeverityWarning,
					Category:    CategoryAnalyzer,
					AutoFix:     false,
					Action:      "Verify analysis-kuromoji plugin is installed on target OpenSearch cluster.",
				}}
			}
			return nil
		},
	}
}

// ANZ003: Generic custom analysis plugin
func ruleANZ003() Rule {
	return Rule{
		ID:       "ANZ003",
		Title:    "Custom analysis configuration",
		Category: CategoryAnalyzer,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			analysis, ok := info.Settings["analysis"]
			if !ok {
				return nil
			}
			// If we get here and ANZ001/ANZ002 didn't match, it's a generic custom analyzer
			analysisMap, ok := analysis.(map[string]interface{})
			if !ok {
				return nil
			}
			if _, hasAnalyzers := analysisMap["analyzer"]; hasAnalyzers {
				// Only report if ICU and Kuromoji haven't already flagged this
				if !hasAnalysisReference(info, "icu_tokenizer", "icu_folding") &&
					!hasAnalysisReference(info, "kuromoji_tokenizer", "kuromoji_baseform") {
					return []Finding{{
						IndexName:   indexName,
						RuleID:      "ANZ003",
						Title:       "Custom analysis configuration detected",
						Description: "Index has custom analyzer definitions. Verify plugins and token filters are available on target.",
						Severity:    SeverityInfo,
						Category:    CategoryAnalyzer,
						AutoFix:     false,
						Action:      "Review custom analyzers and verify equivalent plugins exist for OpenSearch.",
					}}
				}
			}
			return nil
		},
	}
}

// ILM001: ILM policy detected
func ruleILM001() Rule {
	return Rule{
		ID:       "ILM001",
		Title:    "ILM lifecycle policy",
		Category: CategoryLifecycle,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			if _, ok := info.Settings["lifecycle.name"]; ok {
				return []Finding{{
					IndexName:   indexName,
					RuleID:      "ILM001",
					Title:       "ILM policy detected — manual ISM conversion required",
					Description: "Index is managed by an ILM policy. OpenSearch uses ISM (Index State Management) with different syntax.",
					Severity:    SeverityCritical,
					Category:    CategoryLifecycle,
					AutoFix:     false,
					Action:      "Manually convert ILM policy to OpenSearch ISM policy. Not automatically migrated.",
				}}
			}
			return nil
		},
	}
}

// DST001: Data stream detected
func ruleDST001() Rule {
	return Rule{
		ID:       "DST001",
		Title:    "Data stream index pattern",
		Category: CategoryDataStream,
		Check: func(indexName string, info *scanner.IndexInfo) []Finding {
			// Data streams use backing indices like .ds-logs-2024.01.01-000001
			if strings.HasPrefix(indexName, ".ds-") || strings.Contains(indexName, "data_stream") {
				return []Finding{{
					IndexName:   indexName,
					RuleID:      "DST001",
					Title:       "Data stream backing index detected",
					Description: "This appears to be a data stream backing index. Data streams are not automatically migrated.",
					Severity:    SeverityCritical,
					Category:    CategoryDataStream,
					AutoFix:     false,
					Action:      "Recreate data stream manually on target. Backing index naming conventions may differ.",
				}}
			}
			return nil
		},
	}
}

// hasAnalysisReference checks if the index settings reference any of the given analysis components.
func hasAnalysisReference(info *scanner.IndexInfo, components ...string) bool {
	analysis, ok := info.Settings["analysis"]
	if !ok {
		return false
	}
	// Marshal back to string for simple substring search
	analysisStr := fmt.Sprintf("%v", analysis)
	for _, comp := range components {
		if strings.Contains(analysisStr, comp) {
			return true
		}
	}

	// Also check field-level analyzers in mappings
	for _, field := range info.Mappings.Properties {
		for _, comp := range components {
			if strings.Contains(field.Analyzer, comp) || strings.Contains(field.SearchAnalyzer, comp) {
				return true
			}
		}
	}
	return false
}
