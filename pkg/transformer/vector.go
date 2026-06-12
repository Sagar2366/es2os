package transformer

// TransformDenseVector converts an ES dense_vector field to OS knn_vector.
// Returns the transformed field mapping and a Change record.
func TransformDenseVector(fieldName string, dims int, similarity string) (map[string]interface{}, Change) {
	// Map similarity types
	spaceType := mapSimilarity(similarity)

	newField := map[string]interface{}{
		"type":      "knn_vector",
		"dimension": dims,
		"method": map[string]interface{}{
			"name":       "hnsw",
			"space_type": spaceType,
			"engine":     "nmslib",
			"parameters": map[string]interface{}{
				"ef_construction": 512,
				"m":               16,
			},
		},
	}

	before := formatBefore(dims, similarity)
	after := formatAfter(dims, spaceType)

	change := Change{
		FieldPath:   fieldName,
		Description: "dense_vector → knn_vector (type, structure, engine)",
		Before:      before,
		After:       after,
	}

	return newField, change
}

func mapSimilarity(similarity string) string {
	switch similarity {
	case "cosine":
		return "cosinesimil"
	case "dot_product":
		return "innerproduct"
	case "l2_norm", "":
		return "l2"
	default:
		return "l2"
	}
}

func formatBefore(dims int, similarity string) string {
	if similarity == "" {
		similarity = "l2_norm"
	}
	return `type: dense_vector, dims: ` + itoa(dims) + `, similarity: ` + similarity
}

func formatAfter(dims int, spaceType string) string {
	return `type: knn_vector, dimension: ` + itoa(dims) + `, method.space_type: ` + spaceType + `, engine: nmslib`
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	s := ""
	for n > 0 {
		s = string(rune('0'+n%10)) + s
		n /= 10
	}
	return s
}
