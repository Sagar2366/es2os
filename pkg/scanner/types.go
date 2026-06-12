package scanner

// ScanResult holds the parsed Elasticsearch cluster/file data.
type ScanResult struct {
	SourceVersion string               `json:"source_version"`
	TargetVersion string               `json:"target_version"`
	Indices       map[string]IndexInfo `json:"indices"`
	TotalFields   int                  `json:"total_fields"`
}

// IndexInfo holds mapping and settings for a single index.
type IndexInfo struct {
	Name     string                 `json:"name"`
	Mappings IndexMappings          `json:"mappings"`
	Settings map[string]interface{} `json:"settings"`
	Aliases  map[string]interface{} `json:"aliases,omitempty"`
}

// IndexMappings represents the mappings section of an index.
type IndexMappings struct {
	// Properties is the field definitions (normal single-type index)
	Properties map[string]FieldMapping `json:"properties,omitempty"`
	// Types holds multiple type mappings (ES 5.x multi-type index)
	Types map[string]TypeMapping `json:"types,omitempty"`
	// Source holds _source config
	Source *SourceConfig `json:"_source,omitempty"`
	// Meta holds _meta config
	Meta map[string]interface{} `json:"_meta,omitempty"`
	// IsMultiType indicates this index has ES 5.x style multiple types
	IsMultiType bool `json:"is_multi_type"`
}

// TypeMapping represents a single type within a multi-type index.
type TypeMapping struct {
	Properties map[string]FieldMapping `json:"properties"`
}

// FieldMapping represents a single field's mapping definition.
type FieldMapping struct {
	Type       string                 `json:"type,omitempty"`
	Properties map[string]FieldMapping `json:"properties,omitempty"` // nested/object fields

	// dense_vector specific fields
	Dims       int    `json:"dims,omitempty"`
	Index      *bool  `json:"index,omitempty"`
	Similarity string `json:"similarity,omitempty"`

	// text/keyword analyzer fields
	Analyzer       string `json:"analyzer,omitempty"`
	SearchAnalyzer string `json:"search_analyzer,omitempty"`

	// All raw data for fields we don't explicitly model
	Raw map[string]interface{} `json:"-"`
}

// SourceConfig holds _source settings.
type SourceConfig struct {
	Enabled *bool `json:"enabled,omitempty"`
}
