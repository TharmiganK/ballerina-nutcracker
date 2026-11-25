// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

package corpus

import (
	"os"
	"path/filepath"
	"sort"
	"testing"
)

// testBalStdlibTests runs `bal test` on every embedded stdlib package that
// ships a tests/ directory (lib/stdlibs/<org>/<name>/<version>/<platform>/tests),
// failing when any of its Ballerina tests fail. Each package is copied into a
// sandbox first so the run's target/ never lands in the source tree.
func testBalStdlibTests(t *testing.T, cli *balCLI) {
	for _, rel := range findStdlibPackagesWithTests(t, cli.repoRoot) {
		t.Run(filepath.ToSlash(rel), func(t *testing.T) {
			t.Parallel()
			sandbox := filepath.Join(t.TempDir(), filepath.Base(rel))
			copyDir(t, filepath.Join(cli.repoRoot, "lib", "stdlibs", rel), sandbox)
			stdout, stderr, exitCode := runCLICommand(t, cli.relBin, cli.repoRoot, cli.coverDir, "test", sandbox)
			if exitCode != 0 {
				t.Fatalf("bal test exited with %d\nstdout:\n%s\nstderr:\n%s", exitCode, stdout, stderr)
			}
		})
	}
}

// findStdlibPackagesWithTests returns, relative to lib/stdlibs, the platform
// directories of stdlib packages that contain a tests/ directory.
func findStdlibPackagesWithTests(t *testing.T, repoRoot string) []string {
	t.Helper()
	stdlibsRoot := filepath.Join(repoRoot, "lib", "stdlibs")
	matches, err := filepath.Glob(filepath.Join(stdlibsRoot, "*", "*", "*", "*", "tests"))
	if err != nil {
		t.Fatalf("failed to glob stdlib tests: %v", err)
	}
	var pkgs []string
	for _, testsDir := range matches {
		if info, err := os.Stat(testsDir); err != nil || !info.IsDir() {
			continue
		}
		rel, err := filepath.Rel(stdlibsRoot, filepath.Dir(testsDir))
		if err != nil {
			t.Fatalf("failed to relativize %s: %v", testsDir, err)
		}
		pkgs = append(pkgs, rel)
	}
	sort.Strings(pkgs)
	if len(pkgs) == 0 {
		t.Fatalf("no stdlib packages with a tests/ directory found under %s", stdlibsRoot)
	}
	return pkgs
}
