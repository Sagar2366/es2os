package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/sutekar/es2os/pkg/analyzer"
	"github.com/sutekar/es2os/pkg/reporter"
	"github.com/sutekar/es2os/pkg/transformer"
)

var htmlFile string

var reportCmd = &cobra.Command{
	Use:   "report",
	Short: "Run full analysis pipeline and display report",
	Long: `Runs scan → analyze → transform → report in one command.
This is the primary demo command that shows everything at once.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Run full pipeline
		scan, err := runScan()
		if err != nil {
			return fmt.Errorf("scan failed: %w", err)
		}

		analysis := analyzer.Analyze(scan)
		transform := transformer.Transform(scan, analysis)

		// Output based on format
		switch outputFormat {
		case "html":
			w := os.Stdout
			if htmlFile != "" {
				f, err := os.Create(htmlFile)
				if err != nil {
					return fmt.Errorf("creating html file: %w", err)
				}
				defer f.Close()
				w = f
			}
			if err := reporter.HTMLReport(w, scan, analysis, transform); err != nil {
				return fmt.Errorf("generating HTML report: %w", err)
			}
			if htmlFile != "" {
				fmt.Fprintf(os.Stderr, "HTML report written to %s\n", htmlFile)
			}

		case "terminal", "":
			reporter.Terminal(os.Stdout, scan, analysis, transform)

		default:
			return fmt.Errorf("unknown output format: %s (use terminal or html)", outputFormat)
		}

		return nil
	},
}

func init() {
	reportCmd.Flags().StringVar(&htmlFile, "html-file", "", "Write HTML report to file")
	rootCmd.AddCommand(reportCmd)
}
