package analyzer

import "github.com/sutekar/es2os/pkg/scanner"

// Analyze runs all rules against all indices in the scan result.
func Analyze(scan *scanner.ScanResult) *AnalysisResult {
	result := &AnalysisResult{
		SourceVersion: scan.SourceVersion,
		TargetVersion: scan.TargetVersion,
		TotalIndices:  len(scan.Indices),
	}

	rules := AllRules()

	for indexName, indexInfo := range scan.Indices {
		info := indexInfo // copy for pointer
		indexHasFindings := false

		for _, rule := range rules {
			findings := rule.Check(indexName, &info)
			for _, f := range findings {
				result.Findings = append(result.Findings, f)
				indexHasFindings = true

				switch f.Severity {
				case SeverityCritical:
					result.CriticalCount++
				case SeverityWarning:
					result.WarningCount++
				case SeverityInfo:
					result.InfoCount++
				}

				if f.AutoFix {
					result.AutoFixable++
				} else {
					result.ManualRequired++
				}
			}
		}

		if !indexHasFindings {
			result.CleanIndices = append(result.CleanIndices, indexName)
		}
	}

	result.TotalFindings = len(result.Findings)
	return result
}
