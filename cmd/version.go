package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var (
	appVersion  = "dev"
	appBuildTime = "unknown"
)

func SetVersionInfo(version, buildTime string) {
	appVersion = version
	appBuildTime = buildTime
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("es2os %s (built %s)\n", appVersion, appBuildTime)
		fmt.Println("Elasticsearch → OpenSearch mapping analyzer")
		fmt.Println("https://github.com/sutekar/es2os")
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
