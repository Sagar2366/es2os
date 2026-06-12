package cmd

import (
	"fmt"
	"os"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
	"github.com/sutekar/es2os/pkg/scanner"
)

var scanCmd = &cobra.Command{
	Use:   "scan",
	Short: "Scan Elasticsearch mappings and display inventory",
	Long:  "Reads ES mapping JSON from a file and displays what was found.",
	RunE: func(cmd *cobra.Command, args []string) error {
		result, err := runScan()
		if err != nil {
			return fmt.Errorf("scan failed: %w", err)
		}

		bold := color.New(color.Bold)
		green := color.New(color.FgGreen)
		cyan := color.New(color.FgCyan)

		fmt.Fprintln(os.Stdout)
		cyan.Fprintln(os.Stdout, "  es2os scan")
		fmt.Fprintln(os.Stdout)
		fmt.Fprintf(os.Stdout, "  Source: Elasticsearch %s\n", result.SourceVersion)
		fmt.Fprintf(os.Stdout, "  Target: OpenSearch %s\n", result.TargetVersion)
		fmt.Fprintln(os.Stdout)

		bold.Fprintf(os.Stdout, "  Indices found: %d\n", len(result.Indices))
		fmt.Fprintf(os.Stdout, "  Total fields:  %d\n", result.TotalFields)
		fmt.Fprintln(os.Stdout)

		for name, idx := range result.Indices {
			fieldCount := countIndexFields(&idx)
			marker := "  "
			if idx.Mappings.IsMultiType {
				marker = "⚠️"
			}
			green.Fprintf(os.Stdout, "  %s %s", marker, name)
			fmt.Fprintf(os.Stdout, " (%d fields)\n", fieldCount)
		}
		fmt.Fprintln(os.Stdout)

		return nil
	},
}

func countIndexFields(idx *scanner.IndexInfo) int {
	count := 0
	for _, f := range idx.Mappings.Properties {
		count++
		if f.Properties != nil {
			count += countNested(f.Properties)
		}
	}
	for _, t := range idx.Mappings.Types {
		for _, f := range t.Properties {
			count++
			if f.Properties != nil {
				count += countNested(f.Properties)
			}
		}
	}
	return count
}

func countNested(props map[string]scanner.FieldMapping) int {
	count := 0
	for _, f := range props {
		count++
		if f.Properties != nil {
			count += countNested(f.Properties)
		}
	}
	return count
}

func init() {
	rootCmd.AddCommand(scanCmd)
}
