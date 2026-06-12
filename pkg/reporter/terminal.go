package reporter

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/fatih/color"
	"github.com/sutekar/es2os/pkg/analyzer"
	"github.com/sutekar/es2os/pkg/scanner"
	"github.com/sutekar/es2os/pkg/transformer"
)

// Terminal renders the full report to stdout with colors.
func Terminal(w io.Writer, scan *scanner.ScanResult, analysis *analyzer.AnalysisResult, transform *transformer.TransformResult) {
	green := color.New(color.FgGreen, color.Bold)
	yellow := color.New(color.FgYellow)
	red := color.New(color.FgRed, color.Bold)
	cyan := color.New(color.FgCyan)
	bold := color.New(color.Bold)
	dim := color.New(color.FgHiBlack)

	// Header
	fmt.Fprintln(w)
	cyan.Fprintln(w, "╔══════════════════════════════════════════════════════════════╗")
	cyan.Fprintln(w, "║      es2os — Elasticsearch → OpenSearch Analyzer            ║")
	cyan.Fprintln(w, "╚══════════════════════════════════════════════════════════════╝")
	fmt.Fprintln(w)
	fmt.Fprintf(w, "  Source: ")
	yellow.Fprintf(w, "Elasticsearch %s", scan.SourceVersion)
	fmt.Fprintf(w, "    Target: ")
	green.Fprintf(w, "OpenSearch %s\n", scan.TargetVersion)
	fmt.Fprintln(w)

	// Scan section
	bold.Fprintln(w, "━━━ SCAN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Fprintf(w, "  Indices: %d    Fields: %d", len(scan.Indices), scan.TotalFields)

	// Count custom analyzers
	analyzerCount := 0
	for _, idx := range scan.Indices {
		if _, ok := idx.Settings["analysis"]; ok {
			analyzerCount++
		}
	}
	if analyzerCount > 0 {
		fmt.Fprintf(w, "    Custom analyzers: %d", analyzerCount)
	}
	fmt.Fprintln(w)
	fmt.Fprintln(w)

	// Findings section
	bold.Fprintln(w, "━━━ FINDINGS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Fprintln(w)

	// Group findings by index
	byIndex := groupByIndex(analysis.Findings)

	// Sort index names for consistent output
	indexNames := make([]string, 0, len(byIndex))
	for name := range byIndex {
		indexNames = append(indexNames, name)
	}
	sort.Strings(indexNames)

	for _, indexName := range indexNames {
		findings := byIndex[indexName]
		fmt.Fprintf(w, "  ")
		bold.Fprintln(w, indexName)

		for _, f := range findings {
			fmt.Fprintf(w, "  ")
			switch f.Severity {
			case analyzer.SeverityCritical:
				red.Fprintf(w, "❌ [%s]", f.RuleID)
			case analyzer.SeverityWarning:
				yellow.Fprintf(w, "⚠️  [%s]", f.RuleID)
			case analyzer.SeverityInfo:
				dim.Fprintf(w, "ℹ️  [%s]", f.RuleID)
			}
			fmt.Fprintf(w, " %s", f.Title)
			if f.FieldName != "" {
				dim.Fprintf(w, " (field: %s)", f.FieldName)
			}
			fmt.Fprintln(w)

			// Show action
			fmt.Fprintf(w, "     ")
			if f.AutoFix {
				green.Fprintf(w, "✅ Auto-fixable")
			} else {
				yellow.Fprintf(w, "→ %s", f.Action)
			}
			fmt.Fprintln(w)
		}
		fmt.Fprintln(w)
	}

	// Clean indices
	if len(analysis.CleanIndices) > 0 {
		fmt.Fprintf(w, "  ")
		green.Fprintf(w, "%s", strings.Join(analysis.CleanIndices, ", "))
		fmt.Fprintln(w)
		fmt.Fprintf(w, "  ")
		green.Fprintln(w, "✅ Clean — no issues")
		fmt.Fprintln(w)
	}

	// Transform preview section
	if transform != nil && transform.Summary.TotalChanges > 0 {
		fmt.Fprintln(w)
		bold.Fprintln(w, "━━━ TRANSFORM PREVIEW ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		fmt.Fprintln(w)

		for indexName, ti := range transform.Indices {
			if ti.Skipped || len(ti.Changes) == 0 {
				continue
			}
			for _, change := range ti.Changes {
				fmt.Fprintf(w, "  ")
				bold.Fprintf(w, "%s.%s:\n", indexName, change.FieldPath)

				// Show before/after as diff
				beforeParts := strings.Split(change.Before, ", ")
				afterParts := strings.Split(change.After, ", ")

				maxLen := len(beforeParts)
				if len(afterParts) > maxLen {
					maxLen = len(afterParts)
				}

				for i := 0; i < maxLen; i++ {
					before := ""
					after := ""
					if i < len(beforeParts) {
						before = beforeParts[i]
					}
					if i < len(afterParts) {
						after = afterParts[i]
					}

					if before != "" {
						red.Fprintf(w, "  - %-28s", before)
					} else {
						fmt.Fprintf(w, "  %-30s", "")
					}
					if after != "" {
						green.Fprintf(w, " + %s", after)
					}
					fmt.Fprintln(w)
				}
				fmt.Fprintln(w)
			}
		}
	}

	// Summary section
	fmt.Fprintln(w)
	bold.Fprintln(w, "━━━ SUMMARY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Fprintln(w)

	totalIndices := len(scan.Indices)
	cleanCount := len(analysis.CleanIndices)
	cleanPct := 0
	if totalIndices > 0 {
		cleanPct = cleanCount * 100 / totalIndices
	}

	fmt.Fprintf(w, "  ")
	green.Fprintf(w, "✅ Clean:    %d/%d (%d%%)", cleanCount, totalIndices, cleanPct)
	fmt.Fprintf(w, "     Auto-fixable: %d\n", analysis.AutoFixable)

	fmt.Fprintf(w, "  ")
	yellow.Fprintf(w, "⚠️  Warning:  %d", analysis.WarningCount)
	fmt.Fprintf(w, "            Manual:       %d\n", analysis.ManualRequired)

	fmt.Fprintf(w, "  ")
	red.Fprintf(w, "❌ Critical: %d", analysis.CriticalCount)

	// Readiness indicator
	fmt.Fprintf(w, "            Readiness: ")
	if analysis.CriticalCount == 0 && analysis.WarningCount == 0 {
		green.Fprintf(w, "✅ READY")
	} else if analysis.CriticalCount == 0 {
		yellow.Fprintf(w, "⚠️  PARTIAL")
	} else {
		red.Fprintf(w, "❌ NOT READY")
	}
	fmt.Fprintln(w)
	fmt.Fprintln(w)

	// Footer
	dim.Fprintln(w, "  Run 'es2os transform' to generate OpenSearch-compatible mappings.")
	dim.Fprintln(w, "  Run 'es2os report -o html' to generate a shareable HTML report.")
	fmt.Fprintln(w)
}

func groupByIndex(findings []analyzer.Finding) map[string][]analyzer.Finding {
	grouped := make(map[string][]analyzer.Finding)
	for _, f := range findings {
		grouped[f.IndexName] = append(grouped[f.IndexName], f)
	}
	return grouped
}
