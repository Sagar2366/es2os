package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/sutekar/es2os/pkg/analyzer"
	"github.com/sutekar/es2os/pkg/transformer"
)

var outputFile string

var transformCmd = &cobra.Command{
	Use:   "transform",
	Short: "Generate OpenSearch-compatible mappings",
	Long:  "Transforms ES mappings to OpenSearch format, applying all auto-fixable rules.",
	RunE: func(cmd *cobra.Command, args []string) error {
		scan, err := runScan()
		if err != nil {
			return fmt.Errorf("scan failed: %w", err)
		}

		analysis := analyzer.Analyze(scan)
		result := transformer.Transform(scan, analysis)

		output, err := json.MarshalIndent(result, "", "  ")
		if err != nil {
			return fmt.Errorf("marshaling output: %w", err)
		}

		if outputFile != "" {
			if err := os.WriteFile(outputFile, output, 0644); err != nil {
				return fmt.Errorf("writing file: %w", err)
			}
			fmt.Fprintf(os.Stderr, "Transformed mappings written to %s\n", outputFile)
		} else {
			fmt.Fprintln(os.Stdout, string(output))
		}

		return nil
	},
}

func init() {
	transformCmd.Flags().StringVar(&outputFile, "output-file", "", "Write output to file instead of stdout")
	rootCmd.AddCommand(transformCmd)
}
