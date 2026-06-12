package transformer

// TransformResult holds all transformation outputs.
type TransformResult struct {
	Indices map[string]TransformedIndex `json:"indices"`
	Summary TransformSummary           `json:"summary"`
}

// TransformedIndex contains original and new mappings for one index.
type TransformedIndex struct {
	Name       string                 `json:"name"`
	NewMapping map[string]interface{} `json:"new_mapping"`
	Changes    []Change               `json:"changes"`
	Skipped    bool                   `json:"skipped,omitempty"` // true if manual-only
	SkipReason string                 `json:"skip_reason,omitempty"`
}

// Change describes a single field-level transformation.
type Change struct {
	FieldPath   string `json:"field_path"`
	Description string `json:"description"`
	Before      string `json:"before"`
	After       string `json:"after"`
}

// TransformSummary provides high-level stats.
type TransformSummary struct {
	IndicesTransformed int `json:"indices_transformed"`
	IndicesSkipped     int `json:"indices_skipped"`
	IndicesClean       int `json:"indices_clean"`
	TotalChanges       int `json:"total_changes"`
}
