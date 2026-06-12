package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	filePath      string
	clusterURL    string
	clusterUser   string
	clusterPass   string
	sourceVersion string
	targetVersion string
	outputFormat  string
	noColor       bool
	verbose       bool
)

var rootCmd = &cobra.Command{
	Use:   "es2os",
	Short: "Elasticsearch to OpenSearch mapping analyzer and transformer",
	Long: `es2os analyzes Elasticsearch index mappings and identifies incompatibilities
with OpenSearch. It generates transformed, OpenSearch-compatible mappings
and provides a detailed compatibility report.

Inspired by the OpenSearch Migration Assistant — this tool helps you
understand what needs to change BEFORE you migrate.`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&filePath, "file", "f", "", "Path to ES mapping JSON file")
	rootCmd.PersistentFlags().StringVarP(&clusterURL, "cluster", "c", "", "Elasticsearch cluster URL (e.g., https://localhost:9200)")
	rootCmd.PersistentFlags().StringVar(&clusterUser, "user", "", "Cluster username for basic auth")
	rootCmd.PersistentFlags().StringVar(&clusterPass, "password", "", "Cluster password for basic auth")
	rootCmd.PersistentFlags().StringVar(&sourceVersion, "source-version", "7.17", "Source Elasticsearch version")
	rootCmd.PersistentFlags().StringVar(&targetVersion, "target-version", "2.19", "Target OpenSearch version")
	rootCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "terminal", "Output format: terminal | html | json")
	rootCmd.PersistentFlags().BoolVar(&noColor, "no-color", false, "Disable colored output")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output")
}
