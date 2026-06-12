package cmd

import (
	"fmt"

	"github.com/sutekar/es2os/pkg/scanner"
)

// runScan is a helper used by all commands to get a ScanResult from either file or cluster.
func runScan() (*scanner.ScanResult, error) {
	if filePath != "" && clusterURL != "" {
		return nil, fmt.Errorf("specify either --file or --cluster, not both")
	}

	if filePath != "" {
		return scanner.ScanFile(filePath, sourceVersion, targetVersion)
	}

	if clusterURL != "" {
		return scanner.ScanCluster(clusterURL, clusterUser, clusterPass, targetVersion)
	}

	return nil, fmt.Errorf("either --file (-f) or --cluster (-c) is required")
}
