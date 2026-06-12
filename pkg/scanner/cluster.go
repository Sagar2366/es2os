package scanner

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// ScanCluster connects to a live Elasticsearch cluster and reads mappings + settings.
// Usage: es2os report --cluster https://localhost:9200
// Optional: --user elastic --password changeme
func ScanCluster(clusterURL, username, password, targetVersion string) (*ScanResult, error) {
	client := &http.Client{Timeout: 30 * time.Second}

	// 1. Detect cluster version
	version, err := getClusterVersion(client, clusterURL, username, password)
	if err != nil {
		return nil, fmt.Errorf("connecting to cluster: %w", err)
	}

	// 2. Get all index mappings
	mappingsData, err := clusterGet(client, clusterURL+"/_mapping", username, password)
	if err != nil {
		return nil, fmt.Errorf("fetching mappings: %w", err)
	}

	// 3. Get all index settings
	settingsData, err := clusterGet(client, clusterURL+"/_settings", username, password)
	if err != nil {
		return nil, fmt.Errorf("fetching settings: %w", err)
	}

	// 4. Parse into ScanResult
	result := &ScanResult{
		SourceVersion: version,
		TargetVersion: targetVersion,
		Indices:       make(map[string]IndexInfo),
	}

	// Parse mappings: {"index_name": {"mappings": {...}}, ...}
	var rawMappings map[string]json.RawMessage
	if err := json.Unmarshal(mappingsData, &rawMappings); err != nil {
		return nil, fmt.Errorf("parsing mappings response: %w", err)
	}

	// Parse settings: {"index_name": {"settings": {"index": {...}}}, ...}
	var rawSettings map[string]json.RawMessage
	if err := json.Unmarshal(settingsData, &rawSettings); err != nil {
		return nil, fmt.Errorf("parsing settings response: %w", err)
	}

	for indexName, mappingData := range rawMappings {
		// Skip system indices
		if len(indexName) > 0 && indexName[0] == '.' {
			continue
		}

		idx := IndexInfo{
			Name:     indexName,
			Settings: make(map[string]interface{}),
		}

		// Parse mapping for this index
		var indexMapping struct {
			Mappings json.RawMessage `json:"mappings"`
		}
		if err := json.Unmarshal(mappingData, &indexMapping); err == nil && indexMapping.Mappings != nil {
			idx.Mappings = parseMappings(indexMapping.Mappings)
		}

		// Parse settings for this index
		if settingData, ok := rawSettings[indexName]; ok {
			var indexSettings struct {
				Settings struct {
					Index map[string]interface{} `json:"index"`
				} `json:"settings"`
			}
			if err := json.Unmarshal(settingData, &indexSettings); err == nil {
				idx.Settings = flattenSettings(indexSettings.Settings.Index)
			}
		}

		result.Indices[indexName] = idx
	}

	// Count total fields
	for _, idx := range result.Indices {
		result.TotalFields += countFields(idx.Mappings.Properties)
		for _, t := range idx.Mappings.Types {
			result.TotalFields += countFields(t.Properties)
		}
	}

	return result, nil
}

func getClusterVersion(client *http.Client, url, user, pass string) (string, error) {
	data, err := clusterGet(client, url, user, pass)
	if err != nil {
		return "", err
	}

	var info struct {
		Version struct {
			Number       string `json:"number"`
			Distribution string `json:"distribution"`
		} `json:"version"`
		ClusterName string `json:"cluster_name"`
	}
	if err := json.Unmarshal(data, &info); err != nil {
		return "", fmt.Errorf("parsing cluster info: %w", err)
	}

	if info.Version.Distribution == "opensearch" {
		return "OpenSearch " + info.Version.Number, nil
	}
	return info.Version.Number, nil
}

func clusterGet(client *http.Client, url, user, pass string) ([]byte, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	if user != "" {
		req.SetBasicAuth(user, pass)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body[:min(200, len(body))]))
	}

	return io.ReadAll(resp.Body)
}

// flattenSettings removes nested "index" key prefixes from settings map.
// ES returns: {"index": {"number_of_shards": "3", "provided_name": "...", "creation_date": "..."}}
// We want just the relevant settings without internal ones.
func flattenSettings(settings map[string]interface{}) map[string]interface{} {
	result := make(map[string]interface{})
	// Skip internal/read-only settings
	skip := map[string]bool{
		"creation_date":          true,
		"uuid":                   true,
		"provided_name":          true,
		"version":               true,
		"routing":               true,
		"number_of_routing_shards": true,
	}

	for key, value := range settings {
		if skip[key] {
			continue
		}
		// Recursively flatten nested maps (e.g., "lifecycle": {"name": "..."} → "lifecycle.name": "...")
		if nested, ok := value.(map[string]interface{}); ok {
			for subKey, subVal := range nested {
				result[key+"."+subKey] = subVal
			}
		} else {
			result[key] = value
		}
	}
	return result
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
