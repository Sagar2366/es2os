package analyzer

import "github.com/sutekar/es2os/pkg/scanner"

// Severity levels for findings.
type Severity int

const (
	SeverityInfo     Severity = iota // Informational
	SeverityWarning                  // Manual review recommended
	SeverityCritical                 // Will break if not addressed
)

func (s Severity) String() string {
	switch s {
	case SeverityInfo:
		return "INFO"
	case SeverityWarning:
		return "WARNING"
	case SeverityCritical:
		return "CRITICAL"
	default:
		return "UNKNOWN"
	}
}

func (s Severity) Icon() string {
	switch s {
	case SeverityInfo:
		return "ℹ️ "
	case SeverityWarning:
		return "⚠️ "
	case SeverityCritical:
		return "❌"
	default:
		return "?"
	}
}

// Category of the finding.
type Category string

const (
	CategoryMapping    Category = "Mapping"
	CategorySettings   Category = "Settings"
	CategoryAnalyzer   Category = "Analyzer"
	CategoryLifecycle  Category = "Lifecycle"
	CategoryDataStream Category = "DataStream"
)

// Finding represents a single compatibility issue found during analysis.
type Finding struct {
	IndexName   string   `json:"index_name"`
	FieldName   string   `json:"field_name,omitempty"`
	RuleID      string   `json:"rule_id"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Severity    Severity `json:"severity"`
	Category    Category `json:"category"`
	AutoFix     bool     `json:"auto_fix"`
	Action      string   `json:"action"`
}

// AnalysisResult is the output of running all rules against all indices.
type AnalysisResult struct {
	SourceVersion  string    `json:"source_version"`
	TargetVersion  string    `json:"target_version"`
	TotalIndices   int       `json:"total_indices"`
	TotalFindings  int       `json:"total_findings"`
	CriticalCount  int       `json:"critical_count"`
	WarningCount   int       `json:"warning_count"`
	InfoCount      int       `json:"info_count"`
	AutoFixable    int       `json:"auto_fixable"`
	ManualRequired int       `json:"manual_required"`
	Findings       []Finding `json:"findings"`
	CleanIndices   []string  `json:"clean_indices"`
}

// Rule defines a single analysis check.
type Rule struct {
	ID       string
	Title    string
	Category Category
	Check    func(indexName string, info *scanner.IndexInfo) []Finding
}
