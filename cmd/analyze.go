package cmd

import (
	"fmt"
	"os"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
	"github.com/sutekar/es2os/pkg/analyzer"
)

var analyzeCmd = &cobra.Command{
	Use:   "analyze",
	Short: "Analyze ES mappings for OpenSearch compatibility issues",
	Long:  "Runs all compatibility rules against scanned mappings and reports findings.",
	RunE: func(cmd *cobra.Command, args []string) error {
		scan, err := runScan()
		if err != nil {
			return fmt.Errorf("scan failed: %w", err)
		}

		result := analyzer.Analyze(scan)

		green := color.New(color.FgGreen)
		yellow := color.New(color.FgYellow)
		red := color.New(color.FgRed, color.Bold)
		dim := color.New(color.FgHiBlack)

		fmt.Fprintln(os.Stdout)
		fmt.Fprintf(os.Stdout, "  Analyzed %d indices → %d findings\n\n", result.TotalIndices, result.TotalFindings)

		for _, f := range result.Findings {
			switch f.Severity {
			case analyzer.SeverityCritical:
				red.Fprintf(os.Stdout, "  ❌ [%s]", f.RuleID)
			case analyzer.SeverityWarning:
				yellow.Fprintf(os.Stdout, "  ⚠️  [%s]", f.RuleID)
			case analyzer.SeverityInfo:
				dim.Fprintf(os.Stdout, "  ℹ️  [%s]", f.RuleID)
			}
			fmt.Fprintf(os.Stdout, " %s → %s\n", f.IndexName, f.Title)
		}

		if len(result.CleanIndices) > 0 {
			fmt.Fprintln(os.Stdout)
			green.Fprintf(os.Stdout, "  ✅ Clean: ")
			for i, name := range result.CleanIndices {
				if i > 0 {
					fmt.Fprint(os.Stdout, ", ")
				}
				fmt.Fprint(os.Stdout, name)
			}
			fmt.Fprintln(os.Stdout)
		}
		fmt.Fprintln(os.Stdout)

		return nil
	},
}

func init() {
	rootCmd.AddCommand(analyzeCmd)
}
