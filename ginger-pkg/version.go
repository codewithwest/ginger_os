package main

import (
	"strconv"
	"strings"
)

// compareVersions compares two dotted version strings numerically:
// "1.10.0" > "1.9.0", "2.0" > "1.99", equal on identical parts.
// Returns -1, 0, or 1. Non-numeric parts fall back to lexicographic compare.
func compareVersions(a, b string) int {
	pa, pb := strings.Split(a, "."), strings.Split(b, ".")
	n := len(pa)
	if len(pb) > n {
		n = len(pb)
	}
	for i := 0; i < n; i++ {
		var av, bv string
		if i < len(pa) {
			av = pa[i]
		}
		if i < len(pb) {
			bv = pb[i]
		}
		an, aerr := strconv.Atoi(av)
		bn, berr := strconv.Atoi(bv)
		switch {
		case aerr == nil && berr == nil:
			if an < bn {
				return -1
			}
			if an > bn {
				return 1
			}
		default:
			if av < bv {
				return -1
			}
			if av > bv {
				return 1
			}
		}
	}
	return 0
}
