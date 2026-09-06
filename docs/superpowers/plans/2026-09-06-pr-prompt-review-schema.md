# PR Prompt Review: Schema Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Declare, in the `schema` module, every wire type and Village route the pull request prompt attachment feature needs, bump the three specification versions, freeze the retired ones, and queue the release so peasant and village can re-pin.

**Architecture:** All changes are additive. A new optional `Command` field on `TurnDetail` carries skill invocations onto the published wire. A `PromptDigest` domain type is the shared projection both Village and fairtrade will render. Village-side DTOs and seven routes are declared through the existing reflected-operation table so the generated OpenAPI, the TypeScript package, and every fixture gate stay in lockstep. Versions bump first so every later regeneration writes the new artifact names and the released 0.14.0 and 0.9.0 documents stay byte-frozen.

**Tech Stack:** Go 1.26, `github.com/swaggest/jsonschema-go` v0.3.79, `github.com/swaggest/openapi-go` v0.2.60, `gopkg.in/yaml.v3`, the module's `testcase` corpus package, pnpm 11.24.0 with the pinned Hey API Zod and `openapi-typescript` generators.

**Spec:** `docs/superpowers/specs/2026-09-06-pr-prompt-review-design.md` (in the polyrepo). Sections "Data and contract changes / schema", "The digest", and "Attachment state machine" are the source for every type below.

## Global Constraints

Copied from the schema repository's `AGENTS.md`, `TESTING.md`, and `CONTRIBUTING.md`, and from the workspace guide:

- Work in a per-branch worktree under `polyrepo/schema/`, never by switching branches inside `schema/develop`. Branch name: `schema-feat--pr-prompt-attachment-contract`.
- Test cases live in `testdata/*.yaml` corpora loaded through `testcase.LoadCorpus`, never as inline case tables. Deletion protection uses required-name manifests, not bare counts.
- Every Go test run uses the race detector: `go test -race ./...`.
- Never hand-edit a file under `generated/` or `typescript/src/internal/generated/`. After any Go type or route change run `make schema` and commit the byte-identical output.
- Spec versions bump, never mutate. A retired version is registered in `cmd/schema-gen/testdata/retired_specs.yaml` with the sha256 of its committed bytes in the same change that bumps the live constant.
- `go.mod` gains no new direct requirement. The leaf audit fails otherwise.
- Prose and comments use ASCII hyphens, straight quotes, and three dots. No em-dashes, no smart quotes, no ellipsis glyph.
- No internal task-tracking terminology in code, comments, docs, or commit messages. Describe work by substance.
- Never install a git hook. Never push a release tag; the maintainer merges the release PR and CI mints the tag.
- Land through a squash-merge PR into `develop`.
- Village DTO JSON keys are `snake_case`. Root domain types (anything not prefixed `Village`) use `camelCase`. Match the neighbours in each file.
- Every exported root type in package `schema` must be classified in `openapi/testdata/typescript_catalog.yaml` and, when catalogued, listed in `openapi.TypeCatalogEntries`. Every closed string enum must have a row in `testdata/typescript/enums.yaml`.
- Commit messages end with these two trailer lines:

```
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J
```

**One spec clarification recorded here.** The spec says the user setting rides "the existing user update path". The Village API contract declares no user-update route today, so this plan declares `GET` and `PATCH /api/v1/users/me/settings`. Nothing else in the spec changes.

**Decision recorded here.** `TurnDetail.Command` is optional and safely ignorable: the invocation name is already present in the turn's content text, so a consumer that drops the field loses a structured duplicate, not meaning, provenance, or safety. Under `docs/content-capability-negotiation.md` that is an additive minor bump with no content-capability token. The Go doc comment on the type states this.

---

## File Structure

Paths are relative to the worktree `WT=/Users/pigeonzow/Documents/GitHub/polyrepo/schema/schema-feat--pr-prompt-attachment-contract`.

Created:

| File | Responsibility |
|---|---|
| `command_invocation.go` | `CommandInvocation` type, constructor, validator |
| `session_detail_turn_command_test.go` | fixture-driven tests for the constructor and the `TurnDetail.command` wire; the generic corpus inventory validator reused by later tasks |
| `testdata/session-detail/transcripts/turn_commands.yaml`, `turn_commands_manifest.yaml` | the command invocation corpus and its required-name manifest |
| `prompt_digest.go` | `DigestItemKind`, `PromptDigestHeader`, `PromptDigestSkill`, `PromptDigestItem`, `PromptDigest`, validators |
| `prompt_digest_test.go` | fixture-driven tests for item and whole-digest validation |
| `testdata/pulls/prompt_digest_items.yaml`, `prompt_digest_items_manifest.yaml`, `prompt_digests.yaml`, `prompt_digests_manifest.yaml` | digest corpora |
| `village_pulls_api.go` | Village attachment DTOs, the two Village closed sets, prompt-request and user-settings DTOs, the webhook payload type |
| `openapi/village_pulls.go` | `addVillagePullRequestOperations` declaring the seven routes |

Modified:

| File | Change |
|---|---|
| `versions.go` | bump `VillageAPIVersion` to `0.15.0`, `PeasantLocalAPIVersion` to `0.10.0`, `TypesVersion` to `0.15.0` |
| `cmd/schema-gen/testdata/retired_specs.yaml` | register the eight frozen 0.14.0 and 0.9.0 artifacts |
| `testdata/typescript/public_exports.yaml` | the three version constants |
| `local_api.go` | `TurnDetail.Command` |
| `village_api.go` | two settings fields on `VillageGroup` and `VillageUpdateGroupRequest` |
| `openapi/types.go` | `TypeCatalogEntries` gains every new type |
| `openapi/village.go` | extract the operation-adding loop into `addVillageOperations`; call `addVillagePullRequestOperations` |
| `openapi/testdata/typescript_catalog.yaml` | one row per new exported root type |
| `openapi/testdata/typescript_requiredness.yaml` | `TurnDetail` row gains `command`; new rows for `CommandInvocation` and `VillagePullRequestAttachment` |
| `openapi/testdata/village_collectives_operations.yaml` | seven operation rows, two enum rows, one required row, two property rows |
| `testdata/typescript/enums.yaml` | `DigestItemKind`, `VillagePullRequestAttachmentState`, `VillagePromptsCheckMode` |
| `CHANGELOG.md` | Unreleased / Added entry |
| `generated/*`, `typescript/src/internal/generated/*` | regenerated, never edited |

---

### Task 1: Open the new spec versions and freeze the retired ones

**Files:**
- Modify: `versions.go`
- Modify: `cmd/schema-gen/testdata/retired_specs.yaml`
- Modify: `testdata/typescript/public_exports.yaml`
- Modify: `CHANGELOG.md`
- Regenerate: `generated/`, `typescript/src/internal/generated/`

**Interfaces:**
- Consumes: nothing.
- Produces: artifact names `village-api-0.15.0.*`, `peasantlocal-api-0.10.0.*`, `types-0.15.0.*`, `publish-request-0.15.0.schema.json`, `annotation-push-request-0.15.0.schema.json`. Every later task regenerates into these names.

- [ ] **Step 1: Create the worktree and install the TypeScript toolchain**

```bash
cd /Users/pigeonzow/Documents/GitHub/polyrepo/schema/develop
git pull --ff-only
git worktree add ../schema-feat--pr-prompt-attachment-contract -b schema-feat--pr-prompt-attachment-contract develop
cd ../schema-feat--pr-prompt-attachment-contract
pnpm --dir typescript install --frozen-lockfile --ignore-scripts
go test -race ./... 2>&1 | tail -5
```

Expected: the last line reports `ok` for every package. If `oasdiff` or `go-apidiff` are absent, their tests print `SKIP` with an actionable message, which is fine outside `nix develop`.

- [ ] **Step 2: Pin the sha256 of the artifacts that will retire**

Compute the hashes from the committed bytes before changing anything:

```bash
for f in village-api-0.14.0.json village-api-0.14.0.yaml publish-request-0.14.0.schema.json annotation-push-request-0.14.0.schema.json types-0.14.0.json types-0.14.0.yaml peasantlocal-api-0.9.0.json peasantlocal-api-0.9.0.yaml; do
  printf '%s %s\n' "$f" "$(shasum -a 256 "generated/$f" | cut -d' ' -f1)"
done
```

Append these rows to the end of the list in `cmd/schema-gen/testdata/retired_specs.yaml`, substituting each printed hash. Keep the one-line flow style the file already uses:

```yaml
  - {name: village-api-0.14.0, json_sha256: <hash of village-api-0.14.0.json>, yaml_sha256: <hash of village-api-0.14.0.yaml>}
  - {name: publish-request-0.14.0.schema, json_sha256: <hash of publish-request-0.14.0.schema.json>, json_only: true}
  - {name: annotation-push-request-0.14.0.schema, json_sha256: <hash of annotation-push-request-0.14.0.schema.json>, json_only: true}
  - {name: types-0.14.0, json_sha256: <hash of types-0.14.0.json>, yaml_sha256: <hash of types-0.14.0.yaml>}
  - {name: peasantlocal-api-0.9.0, json_sha256: <hash of peasantlocal-api-0.9.0.json>, yaml_sha256: <hash of peasantlocal-api-0.9.0.yaml>}
```

- [ ] **Step 3: Bump the three version constants**

In `versions.go`, change the three values and add one history line to each comment block, directly above the constant:

```go
	// Bumped to 0.15.0 when the pull request prompt attachment surface was
	// declared: the GitHub webhook receiver, the attachment read, confirm, and
	// detach routes, the prompt-request and user-settings routes, and two
	// collective settings (additive = minor bump).
	VillageAPIVersion = "0.15.0"
```

```go
	// Bumped to 0.10.0 when TurnDetail gained the optional CommandInvocation
	// for skill and user slash-command turns (additive = minor bump).
	PeasantLocalAPIVersion = "0.10.0"
```

```go
	// Bumped to 0.15.0 when CommandInvocation, the PromptDigest projection with
	// its DigestItemKind closed set, and the Village pull request attachment
	// DTOs entered the catalog.
	TypesVersion = "0.15.0"
```

- [ ] **Step 4: Run the retired-spec guard to verify the pins**

Run: `go test -race ./cmd/schema-gen/ -run 'TestRetiredSpecsImmutable|TestRetiredSpecRegistryRejectsTrailingDocument' -v`
Expected: PASS. The five newly registered names are now retired, because the live constants no longer produce them, and their committed bytes match the pinned hashes. The freshness test is expected to fail until Step 6 regenerates; do not run it yet.

- [ ] **Step 5: Update the TypeScript public export constants**

In `testdata/typescript/public_exports.yaml`, under `constants:`, change the three values:

```yaml
  - name: VillageAPIVersion
    value: 0.15.0
    surfaces: [root, village]
  - name: PeasantLocalAPIVersion
    value: 0.10.0
    surfaces: [root, local]
  - name: TypesVersion
    value: 0.15.0
    surfaces: [root]
```

`MetadataSchemaVersion` stays `"9"`.

- [ ] **Step 6: Regenerate and confirm the new artifact names exist beside the frozen ones**

```bash
make schema
ls generated | grep -E '0\.15\.0|0\.10\.0'
git status --short generated typescript/src/internal/generated
```

Expected: `ls` lists `village-api-0.15.0.json`, `village-api-0.15.0.yaml`, `publish-request-0.15.0.schema.json`, `annotation-push-request-0.15.0.schema.json`, `types-0.15.0.json`, `types-0.15.0.yaml`, `peasantlocal-api-0.10.0.json`, `peasantlocal-api-0.10.0.yaml`. `git status` shows those eight as untracked plus `versions.gen.ts` modified. No 0.14.0 or 0.9.0 file is modified.

- [ ] **Step 7: Run the whole suite**

Run: `go test -race ./... && pnpm --dir typescript run typecheck && pnpm --dir typescript test`
Expected: all `ok`; the TypeScript `public-exports` test passes against the new constants.

- [ ] **Step 8: Start the changelog entry**

In `CHANGELOG.md`, under `## [Unreleased]`, add an `### Added` section above the existing `### Changed`:

```markdown
### Added

- Village API 0.15.0, Local API 0.10.0, and Types 0.15.0 open the pull request
  prompt attachment contract. Village API 0.14.0, Local API 0.9.0, and Types
  0.14.0 are frozen under the retired-spec guard. The remaining entries in this
  section list the surface as it lands.
```

- [ ] **Step 9: Commit**

```bash
git add versions.go cmd/schema-gen/testdata/retired_specs.yaml testdata/typescript/public_exports.yaml CHANGELOG.md generated typescript/src/internal/generated
git commit -m "chore(contract): open Village API 0.15.0, Local API 0.10.0, Types 0.15.0

Freeze the 0.14.0 Village, publish-request, annotation-push-request, and Types
artifacts and the 0.9.0 Local API artifacts under the retired-spec guard, bump
the three live constants, and regenerate. No type or route changes yet.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J"
```

---

### Task 2: `CommandInvocation` and `TurnDetail.Command`

**Files:**
- Create: `command_invocation.go`
- Modify: `local_api.go` (the `TurnDetail` struct, after `ObservedModel`)
- Create: `testdata/session-detail/transcripts/turn_commands.yaml`
- Create: `testdata/session-detail/transcripts/turn_commands_manifest.yaml`
- Create: `session_detail_turn_command_test.go`
- Modify: `openapi/types.go` (`TypeCatalogEntries`)
- Modify: `openapi/testdata/typescript_catalog.yaml`
- Modify: `openapi/testdata/typescript_requiredness.yaml`
- Regenerate: `generated/`, `typescript/src/internal/generated/`

**Interfaces:**
- Consumes: `schema.IsClaudeBuiltinCommand(name string) bool` from `command.go`; `schema.RoleUser`; `testcase.LoadCorpus[I, E]`; `decodeTurnModelFixtureManifest` and the `turnModelFixtureManifest` type from `session_detail_turn_model_test.go`.
- Produces: `type CommandInvocation struct { Name string; Args string }`, `func NewCommandInvocation(name, args string) (CommandInvocation, error)`, `func (c CommandInvocation) Validate() error`, field `TurnDetail.Command *CommandInvocation` with JSON key `command`. Test helper `validateCorpusInventory[I, E any](label string, corpus testcase.Corpus[I, E], manifest turnModelFixtureManifest) error` reused by Task 3.

- [ ] **Step 1: Write the fixture corpus**

Create `testdata/session-detail/transcripts/turn_commands.yaml`:

```yaml
cases:
  - name: namespaced-skill-valid
    input:
      name: /superpowers:brainstorming
    expected:
      accepted: true
      wireHasArgs: false
    classification: must-pass
    provenance: {source: requirement, ref: a namespaced skill name is the common Claude Code invocation form}
    mutation: {description: a valid invocation with no trailing arguments}

  - name: skill-with-args-valid
    input:
      name: /aura:epoch
      args: plan the migration
    expected:
      accepted: true
      wireHasArgs: true
    classification: must-pass
    provenance: {source: requirement, ref: text after the command on the same line is carried as args}
    mutation: {description: adds trailing arguments to a valid invocation}

  - name: plain-user-command-valid
    input:
      name: /review-pr
    expected:
      accepted: true
      wireHasArgs: false
    classification: must-pass
    provenance: {source: requirement, ref: a user-defined command without a namespace is also an invocation}
    mutation: {description: drops the namespace separator from a valid name}

  - name: opencode-skill-valid
    input:
      name: /commit
      args: ""
    expected:
      accepted: true
      wireHasArgs: false
    classification: must-pass
    provenance: {source: requirement, ref: OpenCode records skills under the same slash-prefixed form}
    mutation: {description: an explicit empty args string is treated as absent on the wire}

  - name: missing-slash-invalid
    input:
      name: superpowers:brainstorming
    expected:
      accepted: false
      errorContains: does not start with a slash
    classification: must-fail
    provenance: {source: boundary, ref: the wire keeps the harness form with the leading slash}
    mutation: {description: removes the leading slash from a valid name}

  - name: empty-invalid
    input:
      name: ""
    expected:
      accepted: false
      errorContains: the name is empty
    classification: must-fail
    provenance: {source: boundary, ref: an empty name cannot attribute the turn to a command}
    mutation: {description: empties the name}

  - name: bare-slash-invalid
    input:
      name: /
    expected:
      accepted: false
      errorContains: bare slash
    classification: must-fail
    provenance: {source: boundary, ref: a slash with nothing after it names no command}
    mutation: {description: keeps only the slash}

  - name: whitespace-in-name-invalid
    input:
      name: /aura epoch
    expected:
      accepted: false
      errorContains: whitespace or a control character
    classification: must-fail
    provenance: {source: boundary, ref: a name is one token; trailing text belongs in args}
    mutation: {description: inserts a space into the name instead of using args}

  - name: control-character-in-name-invalid
    input:
      name: "/aura\tepoch"
    expected:
      accepted: false
      errorContains: whitespace or a control character
    classification: must-fail
    provenance: {source: boundary, ref: control characters are never part of a command token}
    mutation: {description: inserts a tab into the name}

  - name: builtin-command-invalid
    input:
      name: /compact
    expected:
      accepted: false
      errorContains: built-in harness command
    classification: must-fail
    provenance: {source: requirement, ref: built-in commands are structural signals and are never emitted as invocations}
    mutation: {description: uses a Claude Code built-in command name}
```

Create `testdata/session-detail/transcripts/turn_commands_manifest.yaml`:

```yaml
expectedCaseCount: 10
requiredCaseNames:
  - namespaced-skill-valid
  - skill-with-args-valid
  - plain-user-command-valid
  - opencode-skill-valid
  - missing-slash-invalid
  - empty-invalid
  - bare-slash-invalid
  - whitespace-in-name-invalid
  - control-character-in-name-invalid
  - builtin-command-invalid
```

- [ ] **Step 2: Write the failing test**

Create `session_detail_turn_command_test.go`:

```go
package schema_test

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/peasant-labs/schema"
	"github.com/peasant-labs/schema/testcase"
)

//go:embed testdata/session-detail/transcripts/turn_commands.yaml
var turnCommandFixtureYAML []byte

//go:embed testdata/session-detail/transcripts/turn_commands_manifest.yaml
var turnCommandManifestYAML []byte

type turnCommandFixtureInput struct {
	Name string `yaml:"name"`
	Args string `yaml:"args,omitempty"`
}

type turnCommandFixtureExpected struct {
	Accepted      bool   `yaml:"accepted"`
	ErrorContains string `yaml:"errorContains,omitempty"`
	WireHasArgs   bool   `yaml:"wireHasArgs,omitempty"`
}

var turnCommandTimestamp = time.Date(2026, 9, 6, 12, 0, 0, 0, time.UTC)

func TestCommandInvocationFixture(t *testing.T) {
	corpus := loadTurnCommandFixtures(t)
	for _, fixtureCase := range corpus.Cases {
		fixtureCase := fixtureCase
		t.Run(fixtureCase.Name, func(t *testing.T) {
			invocation, err := schema.NewCommandInvocation(fixtureCase.Input.Name, fixtureCase.Input.Args)
			if (err == nil) != fixtureCase.Expected.Accepted {
				t.Fatalf("NewCommandInvocation(%q, %q) err=%v, want accepted=%v", fixtureCase.Input.Name, fixtureCase.Input.Args, err, fixtureCase.Expected.Accepted)
			}
			if !fixtureCase.Expected.Accepted {
				if fixtureCase.Expected.ErrorContains == "" {
					t.Fatal("must-fail case declares no errorContains needle")
				}
				if !strings.Contains(err.Error(), fixtureCase.Expected.ErrorContains) {
					t.Fatalf("error %q does not contain %q", err, fixtureCase.Expected.ErrorContains)
				}
				return
			}
			if invocation.Name != fixtureCase.Input.Name || invocation.Args != fixtureCase.Input.Args {
				t.Fatalf("constructor changed accepted bytes: got %+v", invocation)
			}
			if err := invocation.Validate(); err != nil {
				t.Fatalf("Validate rejected a constructed invocation: %v", err)
			}

			turn := schema.TurnDetail{
				Index:     0,
				Role:      schema.RoleUser,
				Content:   strings.TrimSpace(fixtureCase.Input.Name + " " + fixtureCase.Input.Args),
				Timestamp: turnCommandTimestamp,
				Command:   &invocation,
			}
			wire, err := json.Marshal(turn)
			if err != nil {
				t.Fatalf("marshal TurnDetail: %v", err)
			}
			var object map[string]json.RawMessage
			if err := json.Unmarshal(wire, &object); err != nil {
				t.Fatalf("decode marshaled TurnDetail: %v", err)
			}
			rawCommand, present := object["command"]
			if !present {
				t.Fatalf("command omitted from wire: %s", wire)
			}
			var command map[string]json.RawMessage
			if err := json.Unmarshal(rawCommand, &command); err != nil {
				t.Fatalf("decode command object: %v", err)
			}
			var gotName string
			if err := json.Unmarshal(command["name"], &gotName); err != nil || gotName != fixtureCase.Input.Name {
				t.Fatalf("command.name=%q err=%v, want %q", gotName, err, fixtureCase.Input.Name)
			}
			if _, hasArgs := command["args"]; hasArgs != fixtureCase.Expected.WireHasArgs {
				t.Fatalf("command.args present=%v, want %v; wire=%s", hasArgs, fixtureCase.Expected.WireHasArgs, wire)
			}
		})
	}
}

func TestTurnDetailOmitsAbsentCommand(t *testing.T) {
	wire, err := json.Marshal(schema.TurnDetail{Index: 0, Role: schema.RoleUser, Content: "hello", Timestamp: turnCommandTimestamp})
	if err != nil {
		t.Fatalf("marshal TurnDetail: %v", err)
	}
	var object map[string]json.RawMessage
	if err := json.Unmarshal(wire, &object); err != nil {
		t.Fatalf("decode marshaled TurnDetail: %v", err)
	}
	if _, present := object["command"]; present {
		t.Fatalf("a turn without an invocation must not emit command: %s", wire)
	}
}

func TestTurnCommandFixtureInventoryRejectsCountPreservingRename(t *testing.T) {
	manifest, err := decodeTurnModelFixtureManifest(turnCommandManifestYAML)
	if err != nil {
		t.Fatalf("decode manifest: %v", err)
	}
	old := "name: " + manifest.RequiredCaseNames[0]
	mutated := strings.Replace(string(turnCommandFixtureYAML), old, "name: unregistered-command-case", 1)
	if mutated == string(turnCommandFixtureYAML) {
		t.Fatalf("mutation did not apply: %q not found", old)
	}
	corpus, err := testcase.LoadCorpus[turnCommandFixtureInput, turnCommandFixtureExpected]([]byte(mutated))
	if err != nil {
		t.Fatalf("load mutated corpus: %v", err)
	}
	if err := validateCorpusInventory("turn command", corpus, manifest); err == nil {
		t.Fatal("count-preserving rename passed the required-name inventory")
	}
}

func loadTurnCommandFixtures(t *testing.T) testcase.Corpus[turnCommandFixtureInput, turnCommandFixtureExpected] {
	t.Helper()
	corpus, err := testcase.LoadCorpus[turnCommandFixtureInput, turnCommandFixtureExpected](turnCommandFixtureYAML)
	if err != nil {
		t.Fatalf("load turn command corpus: %v", err)
	}
	manifest, err := decodeTurnModelFixtureManifest(turnCommandManifestYAML)
	if err != nil {
		t.Fatalf("load turn command manifest: %v", err)
	}
	if err := validateCorpusInventory("turn command", corpus, manifest); err != nil {
		t.Fatalf("validate turn command fixture inventory: %v", err)
	}
	return corpus
}

// validateCorpusInventory is the generic required-name inventory check: the
// corpus must hold exactly the manifest's cases, no more and no fewer, with no
// duplicate names. It is shared by every corpus in this package that carries a
// manifest of the same shape.
func validateCorpusInventory[I, E any](label string, corpus testcase.Corpus[I, E], manifest turnModelFixtureManifest) error {
	if len(corpus.Cases) != manifest.ExpectedCaseCount {
		return fmt.Errorf("%s corpus has %d cases, want exactly %d", label, len(corpus.Cases), manifest.ExpectedCaseCount)
	}
	required := make(map[string]struct{}, len(manifest.RequiredCaseNames))
	for _, name := range manifest.RequiredCaseNames {
		required[name] = struct{}{}
	}
	actual := make(map[string]struct{}, len(corpus.Cases))
	for _, fixtureCase := range corpus.Cases {
		if _, duplicate := actual[fixtureCase.Name]; duplicate {
			return fmt.Errorf("%s corpus repeats case name %q", label, fixtureCase.Name)
		}
		actual[fixtureCase.Name] = struct{}{}
		if _, registered := required[fixtureCase.Name]; !registered {
			return fmt.Errorf("%s corpus contains unregistered case %q", label, fixtureCase.Name)
		}
	}
	for name := range required {
		if _, present := actual[name]; !present {
			return fmt.Errorf("%s corpus is missing required case %q", label, name)
		}
	}
	return nil
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `go test -race ./ -run 'TestCommandInvocationFixture|TestTurnDetailOmitsAbsentCommand|TestTurnCommandFixtureInventory' 2>&1 | head -20`
Expected: compile failure naming `schema.NewCommandInvocation` and `Command` as undefined.

- [ ] **Step 4: Implement the type and constructor**

Create `command_invocation.go`:

```go
package schema

import (
	"fmt"
	"unicode"
	"unicode/utf8"
)

// CommandInvocation records that a user-role turn invoked a skill or a
// user-defined slash command rather than typing a prompt. Name keeps the leading
// slash exactly as the harness recorded it, for example
// "/superpowers:brainstorming". Args is the text that followed the command on the
// same line and may be empty.
//
// Built-in harness commands (see BuiltinCommand) are structural signals and are
// never emitted as a CommandInvocation.
//
// Compatibility: the field is optional and safely ignorable. The invocation name
// is already present in the turn's content text, so a consumer that drops the
// field loses a structured duplicate, not meaning, provenance, or safety. Under
// docs/content-capability-negotiation.md that is an additive minor bump with no
// content-capability token.
type CommandInvocation struct {
	Name string `json:"name"`
	Args string `json:"args,omitempty"`
}

// NewCommandInvocation validates and constructs a CommandInvocation. Name must
// be a single slash-prefixed token that is not a built-in harness command. Args
// is carried as given.
func NewCommandInvocation(name, args string) (CommandInvocation, error) {
	const where = "command invocation validation failed at schema.NewCommandInvocation while recording a skill invocation: "
	if name == "" {
		return CommandInvocation{}, fmt.Errorf(where + "the name is empty, so the turn cannot be attributed to a command; omit the invocation or supply the slash-prefixed command name")
	}
	if !utf8.ValidString(name) {
		return CommandInvocation{}, fmt.Errorf(where+"name %q is not valid UTF-8, so it cannot be emitted on the wire; supply the harness-recorded name as valid UTF-8", name)
	}
	if name[0] != '/' {
		return CommandInvocation{}, fmt.Errorf(where+"name %q does not start with a slash, but the wire keeps the harness form; prefix the name with '/' at the producing boundary", name)
	}
	if len(name) == 1 {
		return CommandInvocation{}, fmt.Errorf(where + "the name is a bare slash and names no command; supply the command token after the slash")
	}
	for _, r := range name {
		if unicode.IsSpace(r) || unicode.IsControl(r) {
			return CommandInvocation{}, fmt.Errorf(where+"name %q contains whitespace or a control character, so it cannot be a single command token; put trailing text in args", name)
		}
	}
	if IsClaudeBuiltinCommand(name) {
		return CommandInvocation{}, fmt.Errorf(where+"name %q is a built-in harness command, which is a structural signal and not a user command; do not emit it as a CommandInvocation", name)
	}
	return CommandInvocation{Name: name, Args: args}, nil
}

// Validate reports whether c would be accepted by NewCommandInvocation.
func (c CommandInvocation) Validate() error {
	_, err := NewCommandInvocation(c.Name, c.Args)
	return err
}
```

In `local_api.go`, inside `TurnDetail`, add this field directly after `ObservedModel` and before the `// Enrichment fields` comment:

```go
	// Command is present when this user-role turn invoked a skill or a
	// user-defined slash command. It is optional and safely ignorable; the
	// invocation name is also in Content. Producers set it only on RoleUser
	// turns and never for built-in harness commands.
	Command *CommandInvocation `json:"command,omitempty"`
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `go test -race ./ -run 'TestCommandInvocationFixture|TestTurnDetailOmitsAbsentCommand|TestTurnCommandFixtureInventory' -v 2>&1 | tail -20`
Expected: every subtest PASS.

- [ ] **Step 6: Register the type in the catalog and the requiredness fixture**

In `openapi/types.go`, inside `TypeCatalogEntries`, add one entry. Place it on the line that begins with `{"ChangeSession", ...}` so the list keeps rough alphabetical order:

```go
		{"ChangeSession", new(schema.ChangeSession)}, {"ChangeSummary", new(schema.ChangeSummary)},
		{"CommandInvocation", new(schema.CommandInvocation)},
```

In `openapi/testdata/typescript_catalog.yaml`, add a row in the `types:` list, next to the other `catalog` rows that use the long form:

```yaml
  - go_name: CommandInvocation
    disposition: catalog
    component: CommandInvocation
    reason: public wire or domain contract type
```

In `openapi/testdata/typescript_requiredness.yaml`, change the `turn detail` case so `command` is optional and nullable, and add a case for the new component:

```yaml
  - name: turn detail
    input:
      component: TurnDetail
      required: [index, role, content, timestamp, depth]
      optional: [toolCalls, parentIndex, agentName, observedModel, command, entryType, hasThinking, stopReason, tokensIn, tokensOut]
      nullable: [parentIndex, command, stopReason, tokensIn, tokensOut]
      nonnullable: [index, role, content, timestamp, depth, toolCalls, agentName, observedModel, entryType, hasThinking]
    expected: true
    classification: must-pass
    provenance: {source: requirement, ref: optional source-observed model identity and command invocation in the session-detail wire}
    mutation: {description: "pins observedModel and command as optional while retaining legacy turns without them"}
  - name: command invocation
    input:
      component: CommandInvocation
      required: [name]
      optional: [args]
      nullable: []
      nonnullable: [name, args]
    expected: true
    classification: must-pass
    provenance: {source: requirement, ref: a skill invocation always names its command and may carry arguments}
    mutation: {description: contrasts the required name with the optional non-null args}
```

- [ ] **Step 7: Run the openapi package tests, then regenerate**

Run: `go test -race ./openapi/ 2>&1 | tail -5`
Expected: `ok`. If `TestTypesCatalogAccountsForEveryExportedRootType` fails naming `CommandInvocation`, the catalog row or the `TypeCatalogEntries` entry was missed.

```bash
make schema
go test -race ./... 2>&1 | tail -5
pnpm --dir typescript run typecheck && pnpm --dir typescript test 2>&1 | tail -5
```

Expected: all `ok`. The `turn-model` TypeScript test still passes because `command` is optional.

- [ ] **Step 8: Extend the changelog and commit**

Add under `### Added` in `CHANGELOG.md`:

```markdown
- `TurnDetail.command` (`CommandInvocation`, Local API 0.10.0, Types 0.15.0):
  the slash-prefixed name and optional arguments of a skill or user-defined
  slash command invoked on a user turn. Optional and safely ignorable; no
  content-capability token. Built-in harness commands are never emitted.
```

```bash
git add command_invocation.go local_api.go session_detail_turn_command_test.go testdata/session-detail/transcripts/turn_commands.yaml testdata/session-detail/transcripts/turn_commands_manifest.yaml openapi/types.go openapi/testdata/typescript_catalog.yaml openapi/testdata/typescript_requiredness.yaml CHANGELOG.md generated typescript/src/internal/generated
git commit -m "feat(contract): carry skill invocations on TurnDetail.command

Add CommandInvocation with a validating constructor and an optional command
field on TurnDetail, so a published transcript names the skills and user slash
commands a turn invoked without a consumer having to parse harness markup.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J"
```

---

### Task 3: The `PromptDigest` projection

**Files:**
- Create: `prompt_digest.go`
- Create: `testdata/pulls/prompt_digest_items.yaml`, `testdata/pulls/prompt_digest_items_manifest.yaml`
- Create: `testdata/pulls/prompt_digests.yaml`, `testdata/pulls/prompt_digests_manifest.yaml`
- Create: `prompt_digest_test.go`
- Modify: `openapi/types.go`, `openapi/testdata/typescript_catalog.yaml`, `testdata/typescript/enums.yaml`
- Regenerate: `generated/`, `typescript/src/internal/generated/`

**Interfaces:**
- Consumes: `closedStringEnumSchema` from `enum_schema.go`; `NewTranscriptID` from `pull.go`; `Harness` from `types.go`; `validateCorpusInventory` and `decodeTurnModelFixtureManifest` from the test package.
- Produces: `DigestItemKind` with constants `DigestItemSession`, `DigestItemPrompt`, `DigestItemSkill`, `DigestItemCommit` and `AllDigestItemKinds`; structs `PromptDigestHeader`, `PromptDigestSkill`, `PromptDigestItem`, `PromptDigest`; `func (i PromptDigestItem) Validate() error`; `func (d PromptDigest) Validate() error`. Village computes and stores this type; fairtrade renders it.

- [ ] **Step 1: Write the item corpus**

Create `testdata/pulls/prompt_digest_items.yaml`. The transcript id below is a synthetic UUID.

```yaml
cases:
  - name: prompt-valid
    input:
      kind: prompt
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:00Z"
      text: add a github check that posts the prompts behind a PR
      turnIndex: 4
      ordinal: 1
    expected:
      accepted: true
    classification: must-pass
    provenance: {source: requirement, ref: a prompt links to its turn and carries its 1-based number}
    mutation: {description: a complete prompt item}

  - name: skill-valid
    input:
      kind: skill
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:30Z"
      text: /superpowers:brainstorming
      turnIndex: 5
    expected:
      accepted: true
    classification: must-pass
    provenance: {source: requirement, ref: a skill marker shows the slash-prefixed invocation at its position}
    mutation: {description: a complete skill marker}

  - name: commit-valid
    input:
      kind: commit
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:10:00Z"
      text: a1b2c3d
      commitSha: a1b2c3d4e5f60718293a4b5c6d7e8f9012345678
    expected:
      accepted: true
    classification: must-pass
    provenance: {source: requirement, ref: a commit anchor carries the full SHA and links to GitHub}
    mutation: {description: a complete commit anchor}

  - name: commit-abbreviated-sha-valid
    input:
      kind: commit
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:10:00Z"
      commitSha: a1b2c3d
    expected:
      accepted: true
    classification: must-pass
    provenance: {source: boundary, ref: the publish wire may carry an abbreviated SHA and the anchor text may be empty}
    mutation: {description: shortens the SHA to seven characters and omits text}

  - name: session-valid
    input:
      kind: session
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:00:00Z"
      text: session 1
      promptCount: 9
      commitCount: 3
    expected:
      accepted: true
    classification: must-pass
    provenance: {source: requirement, ref: a session boundary reports how many prompts and commits it holds}
    mutation: {description: a complete session boundary}

  - name: unknown-kind-invalid
    input:
      kind: paragraph
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:00:00Z"
      text: x
    expected:
      accepted: false
      errorContains: outside the closed set
    classification: must-fail
    provenance: {source: enum, ref: DigestItemKind is closed}
    mutation: {description: uses a kind that is not in the set}

  - name: bad-transcript-id-invalid
    input:
      kind: prompt
      transcriptId: not-a-uuid
      timestamp: "2026-09-06T14:02:00Z"
      text: hello
      turnIndex: 0
      ordinal: 1
    expected:
      accepted: false
      errorContains: cannot link to its transcript
    classification: must-fail
    provenance: {source: boundary, ref: every item deep-links into a Village transcript}
    mutation: {description: replaces the UUID with a non-UUID string}

  - name: zero-timestamp-invalid
    input:
      kind: prompt
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "0001-01-01T00:00:00Z"
      text: hello
      turnIndex: 0
      ordinal: 1
    expected:
      accepted: false
      errorContains: zero timestamp
    classification: must-fail
    provenance: {source: boundary, ref: items are ordered by timestamp so a zero value cannot be placed}
    mutation: {description: zeroes the timestamp}

  - name: prompt-missing-turn-index-invalid
    input:
      kind: prompt
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:00Z"
      text: hello
      ordinal: 1
    expected:
      accepted: false
      errorContains: non-negative turnIndex
    classification: must-fail
    provenance: {source: requirement, ref: a prompt without a turn index cannot deep-link}
    mutation: {description: drops turnIndex from a valid prompt}

  - name: prompt-missing-ordinal-invalid
    input:
      kind: prompt
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:00Z"
      text: hello
      turnIndex: 4
    expected:
      accepted: false
      errorContains: positive ordinal
    classification: must-fail
    provenance: {source: requirement, ref: reviewers refer to prompts by number}
    mutation: {description: drops ordinal from a valid prompt}

  - name: prompt-empty-text-invalid
    input:
      kind: prompt
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:00Z"
      text: "   "
      turnIndex: 4
      ordinal: 1
    expected:
      accepted: false
      errorContains: non-empty text
    classification: must-fail
    provenance: {source: boundary, ref: a blank prompt line tells a reviewer nothing}
    mutation: {description: replaces the text with whitespace}

  - name: prompt-with-sha-invalid
    input:
      kind: prompt
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:00Z"
      text: hello
      turnIndex: 4
      ordinal: 1
      commitSha: a1b2c3d
    expected:
      accepted: false
      errorContains: carries no commitSha
    classification: must-fail
    provenance: {source: boundary, ref: commit anchors are their own items}
    mutation: {description: adds a commitSha to a prompt}

  - name: skill-text-without-slash-invalid
    input:
      kind: skill
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:30Z"
      text: superpowers:brainstorming
      turnIndex: 5
    expected:
      accepted: false
      errorContains: slash-prefixed invocation
    classification: must-fail
    provenance: {source: requirement, ref: the marker text is the invocation as recorded}
    mutation: {description: drops the leading slash from a skill marker}

  - name: skill-with-ordinal-invalid
    input:
      kind: skill
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:02:30Z"
      text: /superpowers:brainstorming
      turnIndex: 5
      ordinal: 2
    expected:
      accepted: false
      errorContains: skill marker carries no ordinal
    classification: must-fail
    provenance: {source: boundary, ref: only prompts are numbered}
    mutation: {description: numbers a skill marker}

  - name: commit-bad-sha-invalid
    input:
      kind: commit
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:10:00Z"
      commitSha: a1b2
    expected:
      accepted: false
      errorContains: 7 to 40 lowercase hex
    classification: must-fail
    provenance: {source: boundary, ref: a SHA shorter than seven characters is ambiguous}
    mutation: {description: shortens the SHA below the abbreviated minimum}

  - name: commit-with-turn-index-invalid
    input:
      kind: commit
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:10:00Z"
      commitSha: a1b2c3d
      turnIndex: 3
    expected:
      accepted: false
      errorContains: commit anchor carries no turnIndex
    classification: must-fail
    provenance: {source: boundary, ref: a commit links to GitHub, not to a turn}
    mutation: {description: adds a turnIndex to a commit anchor}

  - name: session-missing-counts-invalid
    input:
      kind: session
      transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13
      timestamp: "2026-09-06T14:00:00Z"
      text: session 1
      promptCount: 9
    expected:
      accepted: false
      errorContains: non-negative promptCount and commitCount
    classification: must-fail
    provenance: {source: requirement, ref: a boundary line reports both counts}
    mutation: {description: drops commitCount from a session boundary}
```

Create `testdata/pulls/prompt_digest_items_manifest.yaml`:

```yaml
expectedCaseCount: 17
requiredCaseNames:
  - prompt-valid
  - skill-valid
  - commit-valid
  - commit-abbreviated-sha-valid
  - session-valid
  - unknown-kind-invalid
  - bad-transcript-id-invalid
  - zero-timestamp-invalid
  - prompt-missing-turn-index-invalid
  - prompt-missing-ordinal-invalid
  - prompt-empty-text-invalid
  - prompt-with-sha-invalid
  - skill-text-without-slash-invalid
  - skill-with-ordinal-invalid
  - commit-bad-sha-invalid
  - commit-with-turn-index-invalid
  - session-missing-counts-invalid
```

- [ ] **Step 2: Write the whole-digest corpus**

Create `testdata/pulls/prompt_digests.yaml`:

```yaml
cases:
  - name: chronological-valid
    input:
      header: {sessionCount: 1, promptCount: 2, commitsCovered: 1, commitsTotal: 1, harness: claude-code, redactionLevel: standard, villageUrl: https://village.example/pulls/o/r/42}
      skills:
        - {name: /superpowers:brainstorming, invocationCount: 1}
      items:
        - {kind: session, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:00:00Z", text: session 1, promptCount: 2, commitCount: 1}
        - {kind: prompt, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:02:00Z", text: first ask, turnIndex: 0, ordinal: 1}
        - {kind: skill, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:02:30Z", text: /superpowers:brainstorming, turnIndex: 1}
        - {kind: prompt, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:05:00Z", text: second ask, turnIndex: 6, ordinal: 2}
        - {kind: commit, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:10:00Z", text: a1b2c3d, commitSha: a1b2c3d}
    expected:
      accepted: true
    classification: must-pass
    provenance: {source: requirement, ref: the complete chain for one session in order}
    mutation: {description: a minimal complete digest}

  - name: out-of-order-invalid
    input:
      header: {sessionCount: 1, promptCount: 2, commitsCovered: 0, commitsTotal: 0, harness: claude-code, redactionLevel: standard, villageUrl: https://village.example/pulls/o/r/42}
      skills: []
      items:
        - {kind: session, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:00:00Z", text: session 1, promptCount: 2, commitCount: 0}
        - {kind: prompt, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:05:00Z", text: second ask, turnIndex: 6, ordinal: 2}
        - {kind: prompt, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:02:00Z", text: first ask, turnIndex: 0, ordinal: 1}
    expected:
      accepted: false
      errorContains: chronological
    classification: must-fail
    provenance: {source: requirement, ref: the chain is what a reviewer reads top to bottom}
    mutation: {description: swaps two prompts so timestamps go backwards}

  - name: header-prompt-count-mismatch-invalid
    input:
      header: {sessionCount: 1, promptCount: 3, commitsCovered: 0, commitsTotal: 0, harness: claude-code, redactionLevel: standard, villageUrl: https://village.example/pulls/o/r/42}
      skills: []
      items:
        - {kind: session, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:00:00Z", text: session 1, promptCount: 1, commitCount: 0}
        - {kind: prompt, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:02:00Z", text: first ask, turnIndex: 0, ordinal: 1}
    expected:
      accepted: false
      errorContains: header promptCount
    classification: must-fail
    provenance: {source: requirement, ref: the header summarises the complete chain}
    mutation: {description: overstates promptCount in the header}

  - name: header-session-count-mismatch-invalid
    input:
      header: {sessionCount: 2, promptCount: 1, commitsCovered: 0, commitsTotal: 0, harness: claude-code, redactionLevel: standard, villageUrl: https://village.example/pulls/o/r/42}
      skills: []
      items:
        - {kind: session, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:00:00Z", text: session 1, promptCount: 1, commitCount: 0}
        - {kind: prompt, transcriptId: 7b1e4d2a-9c3f-4e8b-a1d6-2f5c8e9a0b13, timestamp: "2026-09-06T14:02:00Z", text: first ask, turnIndex: 0, ordinal: 1}
    expected:
      accepted: false
      errorContains: header sessionCount
    classification: must-fail
    provenance: {source: requirement, ref: the header summarises the complete chain}
    mutation: {description: overstates sessionCount in the header}

  - name: commits-covered-exceeds-total-invalid
    input:
      header: {sessionCount: 0, promptCount: 0, commitsCovered: 2, commitsTotal: 1, harness: claude-code, redactionLevel: standard, villageUrl: https://village.example/pulls/o/r/42}
      skills: []
      items: []
    expected:
      accepted: false
      errorContains: commitsCovered
    classification: must-fail
    provenance: {source: boundary, ref: covered commits are a subset of the PR's commits}
    mutation: {description: covers more commits than the PR has}

  - name: skill-without-slash-invalid
    input:
      header: {sessionCount: 0, promptCount: 0, commitsCovered: 0, commitsTotal: 0, harness: claude-code, redactionLevel: standard, villageUrl: https://village.example/pulls/o/r/42}
      skills:
        - {name: brainstorming, invocationCount: 1}
      items: []
    expected:
      accepted: false
      errorContains: slash-prefixed
    classification: must-fail
    provenance: {source: requirement, ref: the header lists invocations as recorded}
    mutation: {description: drops the slash from a header skill}

  - name: skill-zero-count-invalid
    input:
      header: {sessionCount: 0, promptCount: 0, commitsCovered: 0, commitsTotal: 0, harness: claude-code, redactionLevel: standard, villageUrl: https://village.example/pulls/o/r/42}
      skills:
        - {name: /superpowers:brainstorming, invocationCount: 0}
      items: []
    expected:
      accepted: false
      errorContains: invocationCount
    classification: must-fail
    provenance: {source: boundary, ref: a listed skill was invoked at least once}
    mutation: {description: lists a skill with a zero count}
```

Create `testdata/pulls/prompt_digests_manifest.yaml`:

```yaml
expectedCaseCount: 7
requiredCaseNames:
  - chronological-valid
  - out-of-order-invalid
  - header-prompt-count-mismatch-invalid
  - header-session-count-mismatch-invalid
  - commits-covered-exceeds-total-invalid
  - skill-without-slash-invalid
  - skill-zero-count-invalid
```

- [ ] **Step 3: Write the failing test**

Create `prompt_digest_test.go`:

```go
package schema_test

import (
	_ "embed"
	"strings"
	"testing"
	"time"

	"github.com/peasant-labs/schema"
	"github.com/peasant-labs/schema/testcase"
)

//go:embed testdata/pulls/prompt_digest_items.yaml
var digestItemFixtureYAML []byte

//go:embed testdata/pulls/prompt_digest_items_manifest.yaml
var digestItemManifestYAML []byte

//go:embed testdata/pulls/prompt_digests.yaml
var digestFixtureYAML []byte

//go:embed testdata/pulls/prompt_digests_manifest.yaml
var digestManifestYAML []byte

type digestItemFixtureInput struct {
	Kind         string    `yaml:"kind"`
	TranscriptID string    `yaml:"transcriptId"`
	Timestamp    time.Time `yaml:"timestamp"`
	Text         string    `yaml:"text,omitempty"`
	TurnIndex    *int      `yaml:"turnIndex,omitempty"`
	Ordinal      *int      `yaml:"ordinal,omitempty"`
	CommitSha    string    `yaml:"commitSha,omitempty"`
	PromptCount  *int      `yaml:"promptCount,omitempty"`
	CommitCount  *int      `yaml:"commitCount,omitempty"`
}

func (in digestItemFixtureInput) toItem() schema.PromptDigestItem {
	return schema.PromptDigestItem{
		Kind:         schema.DigestItemKind(in.Kind),
		TranscriptID: schema.TranscriptID(in.TranscriptID),
		Timestamp:    in.Timestamp,
		Text:         in.Text,
		TurnIndex:    in.TurnIndex,
		Ordinal:      in.Ordinal,
		CommitSHA:    in.CommitSha,
		PromptCount:  in.PromptCount,
		CommitCount:  in.CommitCount,
	}
}

type digestHeaderFixtureInput struct {
	SessionCount   int    `yaml:"sessionCount"`
	PromptCount    int    `yaml:"promptCount"`
	CommitsCovered int    `yaml:"commitsCovered"`
	CommitsTotal   int    `yaml:"commitsTotal"`
	Harness        string `yaml:"harness"`
	RedactionLevel string `yaml:"redactionLevel"`
	VillageURL     string `yaml:"villageUrl"`
}

type digestSkillFixtureInput struct {
	Name            string `yaml:"name"`
	InvocationCount int    `yaml:"invocationCount"`
}

type digestFixtureInput struct {
	Header digestHeaderFixtureInput  `yaml:"header"`
	Skills []digestSkillFixtureInput `yaml:"skills"`
	Items  []digestItemFixtureInput  `yaml:"items"`
}

func (in digestFixtureInput) toDigest() schema.PromptDigest {
	digest := schema.PromptDigest{
		Header: schema.PromptDigestHeader{
			SessionCount:   in.Header.SessionCount,
			PromptCount:    in.Header.PromptCount,
			CommitsCovered: in.Header.CommitsCovered,
			CommitsTotal:   in.Header.CommitsTotal,
			Harness:        schema.Harness(in.Header.Harness),
			RedactionLevel: in.Header.RedactionLevel,
			VillageURL:     in.Header.VillageURL,
		},
		Skills: make([]schema.PromptDigestSkill, 0, len(in.Skills)),
		Items:  make([]schema.PromptDigestItem, 0, len(in.Items)),
	}
	for _, skill := range in.Skills {
		digest.Skills = append(digest.Skills, schema.PromptDigestSkill{Name: skill.Name, InvocationCount: skill.InvocationCount})
	}
	for _, item := range in.Items {
		digest.Items = append(digest.Items, item.toItem())
	}
	return digest
}

type digestFixtureExpected struct {
	Accepted      bool   `yaml:"accepted"`
	ErrorContains string `yaml:"errorContains,omitempty"`
}

func TestPromptDigestItemFixture(t *testing.T) {
	corpus, err := testcase.LoadCorpus[digestItemFixtureInput, digestFixtureExpected](digestItemFixtureYAML)
	if err != nil {
		t.Fatalf("load digest item corpus: %v", err)
	}
	manifest, err := decodeTurnModelFixtureManifest(digestItemManifestYAML)
	if err != nil {
		t.Fatalf("load digest item manifest: %v", err)
	}
	if err := validateCorpusInventory("digest item", corpus, manifest); err != nil {
		t.Fatalf("validate digest item inventory: %v", err)
	}
	for _, fixtureCase := range corpus.Cases {
		fixtureCase := fixtureCase
		t.Run(fixtureCase.Name, func(t *testing.T) {
			assertValidation(t, fixtureCase.Input.toItem().Validate(), fixtureCase.Expected)
		})
	}
}

func TestPromptDigestFixture(t *testing.T) {
	corpus, err := testcase.LoadCorpus[digestFixtureInput, digestFixtureExpected](digestFixtureYAML)
	if err != nil {
		t.Fatalf("load digest corpus: %v", err)
	}
	manifest, err := decodeTurnModelFixtureManifest(digestManifestYAML)
	if err != nil {
		t.Fatalf("load digest manifest: %v", err)
	}
	if err := validateCorpusInventory("digest", corpus, manifest); err != nil {
		t.Fatalf("validate digest inventory: %v", err)
	}
	for _, fixtureCase := range corpus.Cases {
		fixtureCase := fixtureCase
		t.Run(fixtureCase.Name, func(t *testing.T) {
			assertValidation(t, fixtureCase.Input.toDigest().Validate(), fixtureCase.Expected)
		})
	}
}

func TestDigestItemKindClosedSet(t *testing.T) {
	for _, kind := range schema.AllDigestItemKinds {
		if !kind.IsValid() {
			t.Errorf("AllDigestItemKinds member %q is not valid", kind)
		}
	}
	if schema.DigestItemKind("paragraph").IsValid() {
		t.Error("an unknown kind must not be valid")
	}
}

func assertValidation(t *testing.T, err error, expected digestFixtureExpected) {
	t.Helper()
	if (err == nil) != expected.Accepted {
		t.Fatalf("Validate err=%v, want accepted=%v", err, expected.Accepted)
	}
	if expected.Accepted {
		return
	}
	if expected.ErrorContains == "" {
		t.Fatal("must-fail case declares no errorContains needle")
	}
	if !strings.Contains(err.Error(), expected.ErrorContains) {
		t.Fatalf("error %q does not contain %q", err, expected.ErrorContains)
	}
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `go test -race ./ -run 'TestPromptDigest|TestDigestItemKind' 2>&1 | head -20`
Expected: compile failure naming `schema.PromptDigestItem`, `schema.DigestItemKind`, and `schema.PromptDigest` as undefined.

- [ ] **Step 5: Implement the digest types and validators**

Create `prompt_digest.go`:

```go
package schema

import (
	"fmt"
	"regexp"
	"strings"
	"time"

	jsonschema "github.com/swaggest/jsonschema-go"
)

// DigestItemKind is the closed set of item kinds in a PromptDigest chain.
type DigestItemKind string

const (
	// DigestItemSession marks where one recorded session began.
	DigestItemSession DigestItemKind = "session"
	// DigestItemPrompt is one human-typed user turn.
	DigestItemPrompt DigestItemKind = "prompt"
	// DigestItemSkill marks a skill or user slash-command invocation at the
	// position it happened.
	DigestItemSkill DigestItemKind = "skill"
	// DigestItemCommit anchors the chain to a commit in the pull request.
	DigestItemCommit DigestItemKind = "commit"
)

// AllDigestItemKinds is the canonical inventory, in the order a renderer
// documents them.
var AllDigestItemKinds = []DigestItemKind{DigestItemSession, DigestItemPrompt, DigestItemSkill, DigestItemCommit}

// IsValid reports whether k is a known kind.
func (k DigestItemKind) IsValid() bool {
	switch k {
	case DigestItemSession, DigestItemPrompt, DigestItemSkill, DigestItemCommit:
		return true
	}
	return false
}

func (k DigestItemKind) String() string { return string(k) }

// JSONSchema implements jsonschema.Exposer.
func (DigestItemKind) JSONSchema() (jsonschema.Schema, error) {
	return closedStringEnumSchema(
		"Digest Item Kind",
		"Kind of one item in the prompt digest chain: a session boundary, a human prompt, a skill invocation marker, or a commit anchor",
		AllDigestItemKinds,
	), nil
}

// PromptDigestHeader summarises the complete chain. Counts describe the whole
// digest, never a rendered tier.
type PromptDigestHeader struct {
	SessionCount   int     `json:"sessionCount"`
	PromptCount    int     `json:"promptCount"`
	CommitsCovered int     `json:"commitsCovered"`
	CommitsTotal   int     `json:"commitsTotal"`
	Harness        Harness `json:"harness"`
	RedactionLevel string  `json:"redactionLevel"`
	VillageURL     string  `json:"villageUrl"`
}

// PromptDigestSkill is one distinct skill or user slash command across every
// attached session, with how many times it was invoked.
type PromptDigestSkill struct {
	Name            string `json:"name"`
	InvocationCount int    `json:"invocationCount"`
}

// PromptDigestItem is one entry in the chronological chain. Which optional
// fields are set depends on Kind; Validate states the rule for each kind.
type PromptDigestItem struct {
	Kind         DigestItemKind `json:"kind"`
	TranscriptID TranscriptID   `json:"transcriptId"`
	Timestamp    time.Time      `json:"timestamp"`
	Text         string         `json:"text"`
	// TurnIndex deep-links a prompt or skill marker into the transcript viewer.
	TurnIndex *int `json:"turnIndex,omitempty"`
	// Ordinal is the 1-based prompt number a reviewer sees. Prompts only.
	Ordinal *int `json:"ordinal,omitempty"`
	// CommitSHA is the full or abbreviated SHA of a commit anchor. Commits only.
	CommitSHA string `json:"commitSha,omitempty"`
	// PromptCount and CommitCount summarise a session boundary. Sessions only.
	PromptCount *int `json:"promptCount,omitempty"`
	CommitCount *int `json:"commitCount,omitempty"`
}

// PromptDigest is the reviewer-facing projection of the prompts behind a pull
// request. It is always the complete chain across every attached transcript;
// the comment and check-run budgets described in the design are applied by the
// renderer, never by dropping items from this type.
type PromptDigest struct {
	Header PromptDigestHeader  `json:"header"`
	Skills []PromptDigestSkill `json:"skills" nullable:"false"`
	Items  []PromptDigestItem  `json:"items" nullable:"false"`
}

var digestCommitSHAPattern = regexp.MustCompile(`^[0-9a-f]{7,40}$`)

// Validate enforces the per-kind field rules.
func (i PromptDigestItem) Validate() error {
	where := fmt.Sprintf("prompt digest item validation failed at schema.PromptDigestItem.Validate for kind %q: ", i.Kind)
	if !i.Kind.IsValid() {
		return fmt.Errorf(where+"the kind is outside the closed set %v, so a renderer cannot place the item; emit one of the known kinds", AllDigestItemKinds)
	}
	if _, err := NewTranscriptID(i.TranscriptID.String()); err != nil {
		return fmt.Errorf(where+"the item cannot link to its transcript: %w", err)
	}
	if i.Timestamp.IsZero() {
		return fmt.Errorf(where + "a zero timestamp cannot be ordered in the chain; supply the turn or commit time")
	}
	switch i.Kind {
	case DigestItemPrompt:
		if i.TurnIndex == nil || *i.TurnIndex < 0 {
			return fmt.Errorf(where + "a prompt needs a non-negative turnIndex to deep-link into the transcript")
		}
		if i.Ordinal == nil || *i.Ordinal < 1 {
			return fmt.Errorf(where + "a prompt needs a positive ordinal, the 1-based number shown to reviewers")
		}
		if strings.TrimSpace(i.Text) == "" {
			return fmt.Errorf(where + "a prompt needs non-empty text")
		}
		if i.CommitSHA != "" || i.PromptCount != nil || i.CommitCount != nil {
			return fmt.Errorf(where + "a prompt carries no commitSha, promptCount, or commitCount")
		}
	case DigestItemSkill:
		if i.TurnIndex == nil || *i.TurnIndex < 0 {
			return fmt.Errorf(where + "a skill marker needs a non-negative turnIndex to deep-link into the transcript")
		}
		if len(i.Text) < 2 || i.Text[0] != '/' {
			return fmt.Errorf(where + "a skill marker's text is the slash-prefixed invocation as recorded")
		}
		if i.Ordinal != nil {
			return fmt.Errorf(where + "a skill marker carries no ordinal; only prompts are numbered")
		}
		if i.CommitSHA != "" || i.PromptCount != nil || i.CommitCount != nil {
			return fmt.Errorf(where + "a skill marker carries no commitSha, promptCount, or commitCount")
		}
	case DigestItemCommit:
		if !digestCommitSHAPattern.MatchString(i.CommitSHA) {
			return fmt.Errorf(where+"commitSha %q must be 7 to 40 lowercase hex characters", i.CommitSHA)
		}
		if i.TurnIndex != nil {
			return fmt.Errorf(where + "a commit anchor carries no turnIndex; it links to the commit, not to a turn")
		}
		if i.Ordinal != nil || i.PromptCount != nil || i.CommitCount != nil {
			return fmt.Errorf(where + "a commit anchor carries no ordinal, promptCount, or commitCount")
		}
	case DigestItemSession:
		if i.PromptCount == nil || *i.PromptCount < 0 || i.CommitCount == nil || *i.CommitCount < 0 {
			return fmt.Errorf(where + "a session boundary needs a non-negative promptCount and commitCount")
		}
		if strings.TrimSpace(i.Text) == "" {
			return fmt.Errorf(where + "a session boundary needs non-empty text")
		}
		if i.TurnIndex != nil || i.Ordinal != nil || i.CommitSHA != "" {
			return fmt.Errorf(where + "a session boundary carries no turnIndex, ordinal, or commitSha")
		}
	}
	return nil
}

// Validate checks every item, the chronological order of the chain, the header
// skills, and that the header counts describe the complete chain.
func (d PromptDigest) Validate() error {
	const where = "prompt digest validation failed at schema.PromptDigest.Validate: "
	for index, skill := range d.Skills {
		if len(skill.Name) < 2 || skill.Name[0] != '/' {
			return fmt.Errorf(where+"skills[%d] name %q is not a slash-prefixed invocation", index, skill.Name)
		}
		if skill.InvocationCount < 1 {
			return fmt.Errorf(where+"skills[%d] %q has invocationCount %d; a listed skill was invoked at least once", index, skill.Name, skill.InvocationCount)
		}
	}
	prompts, sessions := 0, 0
	var previous time.Time
	for index, item := range d.Items {
		if err := item.Validate(); err != nil {
			return fmt.Errorf(where+"items[%d]: %w", index, err)
		}
		if index > 0 && item.Timestamp.Before(previous) {
			return fmt.Errorf(where+"items[%d] at %s precedes items[%d] at %s; the chain must be chronological", index, item.Timestamp.Format(time.RFC3339), index-1, previous.Format(time.RFC3339))
		}
		previous = item.Timestamp
		switch item.Kind {
		case DigestItemPrompt:
			prompts++
		case DigestItemSession:
			sessions++
		}
	}
	if d.Header.PromptCount != prompts {
		return fmt.Errorf(where+"header promptCount %d does not match the %d prompt items; the header describes the complete chain", d.Header.PromptCount, prompts)
	}
	if d.Header.SessionCount != sessions {
		return fmt.Errorf(where+"header sessionCount %d does not match the %d session items; the header describes the complete chain", d.Header.SessionCount, sessions)
	}
	if d.Header.CommitsCovered < 0 || d.Header.CommitsTotal < 0 || d.Header.CommitsCovered > d.Header.CommitsTotal {
		return fmt.Errorf(where+"header commitsCovered %d must be between 0 and commitsTotal %d", d.Header.CommitsCovered, d.Header.CommitsTotal)
	}
	return nil
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `go test -race ./ -run 'TestPromptDigest|TestDigestItemKind' -v 2>&1 | tail -30`
Expected: every subtest PASS.

- [ ] **Step 7: Register the types, the enum, and regenerate**

In `openapi/types.go`, inside `TypeCatalogEntries`, add these entries near the other `D` and `P` names (exact placement does not matter; the test checks set membership):

```go
		{"DigestItemKind", new(schema.DigestItemKind)},
		{"PromptDigest", new(schema.PromptDigest)}, {"PromptDigestHeader", new(schema.PromptDigestHeader)},
		{"PromptDigestItem", new(schema.PromptDigestItem)}, {"PromptDigestSkill", new(schema.PromptDigestSkill)},
```

In `openapi/testdata/typescript_catalog.yaml`, add five rows:

```yaml
  - {go_name: DigestItemKind, disposition: catalog, component: DigestItemKind, reason: prompt digest closed set}
  - {go_name: PromptDigest, disposition: catalog, component: PromptDigest, reason: prompt digest projection}
  - {go_name: PromptDigestHeader, disposition: catalog, component: PromptDigestHeader, reason: prompt digest projection}
  - {go_name: PromptDigestItem, disposition: catalog, component: PromptDigestItem, reason: prompt digest projection}
  - {go_name: PromptDigestSkill, disposition: catalog, component: PromptDigestSkill, reason: prompt digest projection}
```

Append to the `enums:` list in `testdata/typescript/enums.yaml`:

```yaml
  - name: DigestItemKind
    all_name: AllDigestItemKinds
    members:
      - {name: Session, value: "session"}
      - {name: Prompt, value: "prompt"}
      - {name: Skill, value: "skill"}
      - {name: Commit, value: "commit"}
    all_values: ["session", "prompt", "skill", "commit"]
```

```bash
go test -race ./openapi/ ./ 2>&1 | tail -5
make schema
go test -race ./... 2>&1 | tail -5
pnpm --dir typescript run typecheck && pnpm --dir typescript test 2>&1 | tail -5
```

Expected: all `ok`. `TestTypesOpenAPIExposesEveryClosedEnum` passes only when the enum row and the Go `JSONSchema` method agree on values and order.

- [ ] **Step 8: Extend the changelog and commit**

Add under `### Added` in `CHANGELOG.md`:

```markdown
- `PromptDigest` (Types 0.15.0): the reviewer-facing projection of the prompts
  behind a pull request, with `PromptDigestHeader`, `PromptDigestSkill`,
  `PromptDigestItem`, and the closed set `DigestItemKind`
  (`session | prompt | skill | commit`). Validators enforce the per-kind field
  rules, chronological order, and header consistency.
```

```bash
git add prompt_digest.go prompt_digest_test.go testdata/pulls openapi/types.go openapi/testdata/typescript_catalog.yaml testdata/typescript/enums.yaml CHANGELOG.md generated typescript/src/internal/generated
git commit -m "feat(contract): add the PromptDigest projection

Define the digest a pull request comment, check run, and Village page render:
a header, the distinct skills, and a chronological chain of session boundaries,
prompts, skill markers, and commit anchors, with validators for each kind.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J"
```

---

### Task 4: Village attachment DTOs and settings

**Files:**
- Create: `village_pulls_api.go`
- Modify: `village_api.go` (`VillageGroup`, `VillageUpdateGroupRequest`)
- Modify: `openapi/types.go`, `openapi/testdata/typescript_catalog.yaml`, `openapi/testdata/typescript_requiredness.yaml`, `testdata/typescript/enums.yaml`
- Regenerate: `generated/`, `typescript/src/internal/generated/`

**Interfaces:**
- Consumes: `VillageUUID`, `TranscriptID`, `VillageTranscriptVisibility`, `PromptDigest`, `closedStringEnumSchema`.
- Produces: `VillagePullRequestAttachmentState` (constants `VillagePullRequestAttachmentRequested`, `...Waiting`, `...Preview`, `...Attached`, `...Detached`, list `AllVillagePullRequestAttachmentStates`); `VillagePromptsCheckMode` (constants `VillagePromptsCheckInformational`, `VillagePromptsCheckRequired`, list `AllVillagePromptsCheckModes`); structs `VillagePullRequestAttachment`, `VillagePullRequestAttachedTranscript`, `VillagePullRequestAttachmentResponse`, `VillagePromptRequest`, `VillagePromptRequestsResponse`, `VillageUserSettings`, `VillageUpdateUserSettingsRequest`, map type `VillageGitHubWebhookPayload`; fields `VillageGroup.PostPromptsCheck`, `VillageGroup.PromptsCheckMode`, `VillageUpdateGroupRequest.PostPromptsCheck`, `VillageUpdateGroupRequest.PromptsCheckMode`. Task 5 references every one of these in route declarations.

- [ ] **Step 1: Write the failing test**

The contract for these DTOs is their JSON shape and closed sets, which the fixture gates check. Add the enum rows first so the enum test fails until the Go types exist. Append to `testdata/typescript/enums.yaml`:

```yaml
  - name: VillagePullRequestAttachmentState
    all_name: AllVillagePullRequestAttachmentStates
    members:
      - {name: Requested, value: "requested"}
      - {name: Waiting, value: "waiting"}
      - {name: Preview, value: "preview"}
      - {name: Attached, value: "attached"}
      - {name: Detached, value: "detached"}
    all_values: ["requested", "waiting", "preview", "attached", "detached"]
  - name: VillagePromptsCheckMode
    all_name: AllVillagePromptsCheckModes
    members:
      - {name: Informational, value: "informational"}
      - {name: Required, value: "required"}
    all_values: ["informational", "required"]
```

Add to `openapi/testdata/typescript_requiredness.yaml`:

```yaml
  - name: pull request attachment
    input:
      component: VillagePullRequestAttachment
      required: [id, owner, name, number, head_sha, is_private_repository, state, author_user_id, requested_by_github_id, comment_id, check_run_id, created_at, updated_at, confirmed_at, detached_at]
      optional: []
      nullable: [requested_by_github_id, comment_id, check_run_id, confirmed_at, detached_at]
      nonnullable: [id, owner, name, number, head_sha, is_private_repository, state, created_at, updated_at]
    expected: true
    classification: must-pass
    provenance: {source: requirement, ref: Village rows are emitted whole with null for fields a state has not reached}
    mutation: {description: contrasts always-present identity with nullable lifecycle fields}
  - name: update user settings request
    input:
      component: VillageUpdateUserSettingsRequest
      required: []
      optional: [preview_before_attach]
      nullable: [preview_before_attach]
      nonnullable: []
    expected: true
    classification: must-pass
    provenance: {source: requirement, ref: an omitted setting is left unchanged}
    mutation: {description: a single optional boolean patch}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `go test -race ./ -run TestTypesOpenAPIExposesEveryClosedEnum 2>&1 | tail -5; go test -race ./openapi/ -run TestTypesCatalogPreservesListedPropertyRequiredness 2>&1 | tail -5`
Expected: both FAIL, the first naming the two enum components as absent from the Types catalog, the second naming `VillagePullRequestAttachment`.

- [ ] **Step 3: Implement the DTOs**

Create `village_pulls_api.go`:

```go
package schema

import (
	"time"

	jsonschema "github.com/swaggest/jsonschema-go"
)

// VillagePullRequestAttachmentState is the closed lifecycle of one pull
// request's prompt attachment. The design's state machine names each
// transition; the wire only carries the current state.
type VillagePullRequestAttachmentState string

const (
	// VillagePullRequestAttachmentRequested: a non-author asked; nothing is exposed.
	VillagePullRequestAttachmentRequested VillagePullRequestAttachmentState = "requested"
	// VillagePullRequestAttachmentWaiting: the author consented; no matching transcript exists yet.
	VillagePullRequestAttachmentWaiting VillagePullRequestAttachmentState = "waiting"
	// VillagePullRequestAttachmentPreview: the digest is computed and awaits the author's confirm on Village.
	VillagePullRequestAttachmentPreview VillagePullRequestAttachmentState = "preview"
	// VillagePullRequestAttachmentAttached: the comment is posted and the transcripts are shared.
	VillagePullRequestAttachmentAttached VillagePullRequestAttachmentState = "attached"
	// VillagePullRequestAttachmentDetached: the comment is deleted and prior visibility restored.
	VillagePullRequestAttachmentDetached VillagePullRequestAttachmentState = "detached"
)

var AllVillagePullRequestAttachmentStates = []VillagePullRequestAttachmentState{
	VillagePullRequestAttachmentRequested,
	VillagePullRequestAttachmentWaiting,
	VillagePullRequestAttachmentPreview,
	VillagePullRequestAttachmentAttached,
	VillagePullRequestAttachmentDetached,
}

func (s VillagePullRequestAttachmentState) IsValid() bool {
	for _, known := range AllVillagePullRequestAttachmentStates {
		if s == known {
			return true
		}
	}
	return false
}

func (s VillagePullRequestAttachmentState) String() string { return string(s) }

func (VillagePullRequestAttachmentState) JSONSchema() (jsonschema.Schema, error) {
	return closedStringEnumSchema("Village Pull Request Attachment State", "Current lifecycle state of a pull request's prompt attachment", AllVillagePullRequestAttachmentStates), nil
}

// VillagePromptsCheckMode decides the check-run conclusion a collective's
// linked repositories receive when no prompts are attached.
type VillagePromptsCheckMode string

const (
	// VillagePromptsCheckInformational: neutral when nothing is attached. The default.
	VillagePromptsCheckInformational VillagePromptsCheckMode = "informational"
	// VillagePromptsCheckRequired: failure when nothing is attached, so branch protection can require prompts.
	VillagePromptsCheckRequired VillagePromptsCheckMode = "required"
)

var AllVillagePromptsCheckModes = []VillagePromptsCheckMode{VillagePromptsCheckInformational, VillagePromptsCheckRequired}

func (m VillagePromptsCheckMode) IsValid() bool {
	return m == VillagePromptsCheckInformational || m == VillagePromptsCheckRequired
}

func (m VillagePromptsCheckMode) String() string { return string(m) }

func (VillagePromptsCheckMode) JSONSchema() (jsonschema.Schema, error) {
	return closedStringEnumSchema("Village Prompts Check Mode", "Check-run conclusion policy for a collective's linked repositories when no prompts are attached", AllVillagePromptsCheckModes), nil
}

// VillagePullRequestAttachment is one pull request's attachment row.
type VillagePullRequestAttachment struct {
	ID                  VillageUUID                       `json:"id"`
	Owner               string                            `json:"owner"`
	Name                string                            `json:"name"`
	Number              int                               `json:"number"`
	HeadSHA             string                            `json:"head_sha"`
	IsPrivateRepository bool                              `json:"is_private_repository"`
	State               VillagePullRequestAttachmentState `json:"state"`
	AuthorUserID        *VillageUUID                      `json:"author_user_id"`
	RequestedByGithubID *int64                            `json:"requested_by_github_id"`
	CommentID           *int64                            `json:"comment_id"`
	CheckRunID          *int64                            `json:"check_run_id"`
	CreatedAt           time.Time                         `json:"created_at"`
	UpdatedAt           time.Time                         `json:"updated_at"`
	ConfirmedAt         *time.Time                        `json:"confirmed_at"`
	DetachedAt          *time.Time                        `json:"detached_at"`
}

// VillagePullRequestAttachedTranscript is one transcript in an attachment, in
// chain order, with the visibility to restore on detach.
type VillagePullRequestAttachedTranscript struct {
	TranscriptID       TranscriptID                `json:"transcript_id"`
	Position           int                         `json:"position"`
	PreviousVisibility VillageTranscriptVisibility `json:"previous_visibility"`
	Title              *string                     `json:"title"`
	SessionStart       *time.Time                  `json:"session_start"`
}

// VillagePullRequestAttachmentResponse is the read, confirm, and detach
// response. Digest is null until the attachment reaches preview or attached.
type VillagePullRequestAttachmentResponse struct {
	Attachment     VillagePullRequestAttachment           `json:"attachment"`
	Digest         *PromptDigest                          `json:"digest"`
	Transcripts    []VillagePullRequestAttachedTranscript `json:"transcripts" nullable:"false"`
	ViewerIsAuthor bool                                   `json:"viewer_is_author"`
}

// VillagePromptRequest is one attachment waiting on the caller's machine.
// Remote is the normalized repository remote so the CLI can match the
// repository it is pushing without re-deriving the rule.
type VillagePromptRequest struct {
	Owner       string                            `json:"owner"`
	Name        string                            `json:"name"`
	Number      int                               `json:"number"`
	State       VillagePullRequestAttachmentState `json:"state"`
	Remote      string                            `json:"remote"`
	RequestedAt time.Time                         `json:"requested_at"`
}

type VillagePromptRequestsResponse struct {
	Requests []VillagePromptRequest `json:"requests" nullable:"false"`
}

// VillageUserSettings is the caller's own settings surface.
type VillageUserSettings struct {
	PreviewBeforeAttach bool `json:"preview_before_attach"`
}

// VillageUpdateUserSettingsRequest patches the caller's settings. An omitted
// field is left unchanged.
type VillageUpdateUserSettingsRequest struct {
	PreviewBeforeAttach *bool `json:"preview_before_attach,omitempty"`
}

// VillageGitHubWebhookPayload is GitHub's event payload, forwarded verbatim.
// Village verifies the HMAC over the raw body and reads only the fields the
// event needs, so the contract leaves the object open.
type VillageGitHubWebhookPayload map[string]any

func (VillageGitHubWebhookPayload) JSONSchema() (jsonschema.Schema, error) {
	open := true
	s := jsonschema.Schema{}
	s.AddType(jsonschema.Object)
	s.WithTitle("GitHub Webhook Payload")
	s.WithDescription("GitHub event payload forwarded verbatim; validated by the X-Hub-Signature-256 HMAC over the raw body, never by shape")
	s.WithAdditionalProperties(jsonschema.SchemaOrBool{TypeBoolean: &open})
	return s, nil
}
```

In `village_api.go`, add two fields to the end of `VillageGroup`:

```go
	// PostPromptsCheck controls whether the prompts check is created on pull
	// requests in this collective's linked repositories. Defaults to true.
	PostPromptsCheck bool `json:"post_prompts_check"`
	// PromptsCheckMode decides the check conclusion when no prompts are attached.
	PromptsCheckMode VillagePromptsCheckMode `json:"prompts_check_mode"`
```

and two fields to the end of `VillageUpdateGroupRequest`:

```go
	PostPromptsCheck *bool                   `json:"post_prompts_check,omitempty"`
	PromptsCheckMode VillagePromptsCheckMode `json:"prompts_check_mode,omitempty"`
```

- [ ] **Step 4: Register in the catalog**

In `openapi/types.go`, inside `TypeCatalogEntries`, add (alphabetical placement among the `Village` entries):

```go
		{"VillageGitHubWebhookPayload", new(schema.VillageGitHubWebhookPayload)},
		{"VillagePromptRequest", new(schema.VillagePromptRequest)}, {"VillagePromptRequestsResponse", new(schema.VillagePromptRequestsResponse)},
		{"VillagePromptsCheckMode", new(schema.VillagePromptsCheckMode)},
		{"VillagePullRequestAttachedTranscript", new(schema.VillagePullRequestAttachedTranscript)}, {"VillagePullRequestAttachment", new(schema.VillagePullRequestAttachment)},
		{"VillagePullRequestAttachmentResponse", new(schema.VillagePullRequestAttachmentResponse)}, {"VillagePullRequestAttachmentState", new(schema.VillagePullRequestAttachmentState)},
		{"VillageUpdateUserSettingsRequest", new(schema.VillageUpdateUserSettingsRequest)}, {"VillageUserSettings", new(schema.VillageUserSettings)},
```

In `openapi/testdata/typescript_catalog.yaml`, add:

```yaml
  - {go_name: VillageGitHubWebhookPayload, disposition: catalog, component: VillageGitHubWebhookPayload, reason: pull request attachment contract}
  - {go_name: VillagePromptRequest, disposition: catalog, component: VillagePromptRequest, reason: pull request attachment contract}
  - {go_name: VillagePromptRequestsResponse, disposition: catalog, component: VillagePromptRequestsResponse, reason: pull request attachment contract}
  - {go_name: VillagePromptsCheckMode, disposition: catalog, component: VillagePromptsCheckMode, reason: pull request attachment contract}
  - {go_name: VillagePullRequestAttachedTranscript, disposition: catalog, component: VillagePullRequestAttachedTranscript, reason: pull request attachment contract}
  - {go_name: VillagePullRequestAttachment, disposition: catalog, component: VillagePullRequestAttachment, reason: pull request attachment contract}
  - {go_name: VillagePullRequestAttachmentResponse, disposition: catalog, component: VillagePullRequestAttachmentResponse, reason: pull request attachment contract}
  - {go_name: VillagePullRequestAttachmentState, disposition: catalog, component: VillagePullRequestAttachmentState, reason: pull request attachment contract}
  - {go_name: VillageUpdateUserSettingsRequest, disposition: catalog, component: VillageUpdateUserSettingsRequest, reason: pull request attachment contract}
  - {go_name: VillageUserSettings, disposition: catalog, component: VillageUserSettings, reason: pull request attachment contract}
```

- [ ] **Step 5: Run the tests to verify they pass, then regenerate**

```bash
go test -race ./ ./openapi/ 2>&1 | tail -5
make schema
go test -race ./... 2>&1 | tail -5
pnpm --dir typescript run typecheck && pnpm --dir typescript test 2>&1 | tail -5
```

Expected: all `ok`. If the TypeScript `public contract completeness` check reports `VillageGitHubWebhookPayload` without a Zod export, inspect `typescript/src/internal/generated/contract/zod.gen.ts` for `zVillageGitHubWebhookPayload`; Hey API renders an open object as a record schema, which satisfies the gate.

- [ ] **Step 6: Extend the changelog and commit**

Add under `### Added` in `CHANGELOG.md`:

```markdown
- Village attachment DTOs (Village API 0.15.0, Types 0.15.0):
  `VillagePullRequestAttachment`, `VillagePullRequestAttachedTranscript`,
  `VillagePullRequestAttachmentResponse`, `VillagePromptRequest`,
  `VillagePromptRequestsResponse`, `VillageUserSettings`,
  `VillageUpdateUserSettingsRequest`, `VillageGitHubWebhookPayload`, and the
  closed sets `VillagePullRequestAttachmentState`
  (`requested | waiting | preview | attached | detached`) and
  `VillagePromptsCheckMode` (`informational | required`). `VillageGroup` and
  `VillageUpdateGroupRequest` gain `post_prompts_check` and
  `prompts_check_mode`.
```

```bash
git add village_pulls_api.go village_api.go openapi/types.go openapi/testdata/typescript_catalog.yaml openapi/testdata/typescript_requiredness.yaml testdata/typescript/enums.yaml CHANGELOG.md generated typescript/src/internal/generated
git commit -m "feat(contract): add Village pull request attachment DTOs

Declare the attachment row, its attached transcripts, the read response, the
prompt-request list, the user settings surface, the webhook payload, the two
closed sets, and the two collective settings the prompts check needs.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J"
```

---

### Task 5: Declare the seven Village routes

**Files:**
- Create: `openapi/village_pulls.go`
- Modify: `openapi/village.go` (extract `addVillageOperations`; call the new function)
- Modify: `openapi/testdata/village_collectives_operations.yaml`
- Regenerate: `generated/`, `typescript/src/internal/generated/`

**Interfaces:**
- Consumes: `villageOperationSpec` and `requireRequestBody` from `openapi/village.go`; every DTO from Task 4; `openapicore.WithHTTPStatus`.
- Produces: `func addVillageOperations(r *openapi31.Reflector, operations []villageOperationSpec) error` and `func addVillagePullRequestOperations(r *openapi31.Reflector) error`; operation ids `receiveGitHubWebhook`, `getPullRequestAttachment`, `confirmPullRequestAttachment`, `detachPullRequestAttachment`, `listMyPromptRequests`, `getMySettings`, `updateMySettings`. Village's router and the TypeScript operations contract use these ids.

- [ ] **Step 1: Pin the routes in the fixture**

Append to the `operations:` list in `openapi/testdata/village_collectives_operations.yaml`, after the `listGroupRepositoryCommits` row:

```yaml
  - path: /api/v1/integrations/github/webhook
    method: post
    operation_id: receiveGitHubWebhook
    request_components: [VillageGitHubWebhookPayload]
    response_components: [VillageStatusResponse]
    statuses: ["202", "400", "401", "501"]
    description_anchors: [X-Hub-Signature-256, X-GitHub-Delivery, installation]
  - path: /api/v1/pulls/{owner}/{name}/{number}
    method: get
    operation_id: getPullRequestAttachment
    request_components: []
    response_components: [VillagePullRequestAttachmentResponse]
    statuses: ["200", "400", "403", "404", "500"]
    description_anchors: [digest, viewer_is_author]
  - path: /api/v1/pulls/{owner}/{name}/{number}/confirm
    method: post
    operation_id: confirmPullRequestAttachment
    request_components: []
    response_components: [VillagePullRequestAttachmentResponse]
    statuses: ["200", "400", "401", "403", "404", "409", "500", "502"]
    description_anchors: [preview, author]
  - path: /api/v1/pulls/{owner}/{name}/{number}
    method: delete
    operation_id: detachPullRequestAttachment
    request_components: []
    response_components: [VillagePullRequestAttachmentResponse]
    statuses: ["200", "400", "401", "403", "404", "409", "500", "502"]
    description_anchors: [Detach, previous visibility]
  - path: /api/v1/users/me/prompt-requests
    method: get
    operation_id: listMyPromptRequests
    request_components: []
    response_components: [VillagePromptRequestsResponse]
    statuses: ["200", "401", "500"]
    description_anchors: [waiting, remote]
  - path: /api/v1/users/me/settings
    method: get
    operation_id: getMySettings
    request_components: []
    response_components: [VillageUserSettings]
    statuses: ["200", "401", "500"]
    description_anchors: [preview_before_attach]
  - path: /api/v1/users/me/settings
    method: patch
    operation_id: updateMySettings
    request_components: [VillageUpdateUserSettingsRequest]
    response_components: [VillageUserSettings]
    statuses: ["200", "400", "401", "500"]
    description_anchors: [left unchanged]
```

Append to `component_enums:`:

```yaml
  - component: VillagePullRequestAttachmentState
    values: [requested, waiting, preview, attached, detached]
  - component: VillagePromptsCheckMode
    values: [informational, required]
```

Append to `component_required:`:

```yaml
  - component: VillagePullRequestAttachment
    contains:
      - id
      - owner
      - name
      - number
      - head_sha
      - state
      - created_at
      - updated_at
    excludes: []
```

Append to `component_properties:`:

```yaml
  - component: VillagePromptRequestsResponse
    property: requests
    required: true
    nullable: false
    items_ref: "#/components/schemas/SchemaVillagePromptRequest"
  - component: VillagePullRequestAttachmentResponse
    property: transcripts
    required: true
    nullable: false
    items_ref: "#/components/schemas/SchemaVillagePullRequestAttachedTranscript"
```

- [ ] **Step 2: Run the fixture test to verify it fails**

Run: `go test -race ./openapi/ -run 'TestBuildVillageAPISpec_Collectives' 2>&1 | head -10`
Expected: FAIL with `post /api/v1/integrations/github/webhook` reported as an undeclared operation.

- [ ] **Step 3: Extract the operation loop in `openapi/village.go`**

In `addVillageCollectiveOperations`, replace the `for _, op := range operations { ... }` loop (the block that begins `for _, op := range operations {` and ends just before the `for _, body := range []struct{` block) with:

```go
	if err := addVillageOperations(r, operations); err != nil {
		return err
	}
```

Add this function directly below `addVillageCollectiveOperations`:

```go
// addVillageOperations reflects one table of Village operations. Every request
// structure is added, the success response takes its declared status, and each
// error status shares the common VillageErrorResponse envelope.
func addVillageOperations(r *openapi31.Reflector, operations []villageOperationSpec) error {
	for _, op := range operations {
		oc, err := r.NewOperationContext(op.method, op.path)
		if err != nil {
			return fmt.Errorf("new Village operation %s %s: %w", op.method, op.path, err)
		}
		for _, request := range op.requests {
			oc.AddReqStructure(request)
		}
		if op.response != nil {
			if op.successStatus != 0 && op.successStatus != http.StatusOK {
				oc.AddRespStructure(op.response, openapicore.WithHTTPStatus(op.successStatus))
			} else {
				oc.AddRespStructure(op.response)
			}
		}
		for _, status := range op.errorStatuses {
			oc.AddRespStructure(new(schema.VillageErrorResponse), openapicore.WithHTTPStatus(status))
		}
		oc.SetDescription(op.description)
		oc.SetID(op.id)
		oc.SetTags(op.tag)
		if err := r.AddOperation(oc); err != nil {
			return fmt.Errorf("add Village operation %s %s: %w", op.method, op.path, err)
		}
	}
	return nil
}
```

In `BuildVillageAPISpec`, directly after the existing call:

```go
	if err := addVillageCollectiveOperations(r); err != nil {
		return nil, err
	}
	if err := addVillagePullRequestOperations(r); err != nil {
		return nil, err
	}
```

Run: `go test -race ./openapi/ -run 'TestBuildVillageAPISpec_CollectivesOperations' 2>&1 | tail -3`
Expected: still FAIL on the webhook route, but no compile error. The extraction changed nothing observable.

- [ ] **Step 4: Declare the routes**

Create `openapi/village_pulls.go`:

```go
package openapi

import (
	"net/http"

	"github.com/peasant-labs/schema"
	"github.com/swaggest/openapi-go/openapi31"
)

// addVillagePullRequestOperations declares the pull request prompt attachment
// surface: the GitHub webhook receiver, the attachment read, confirm, and
// detach routes, the caller's waiting requests, and the caller's settings.
func addVillagePullRequestOperations(r *openapi31.Reflector) error {
	pullPath := new(struct {
		Owner  string `path:"owner" description:"Repository owner login"`
		Name   string `path:"name" description:"Repository name"`
		Number int    `path:"number" minimum:"1" description:"Pull request number"`
	})
	webhookHeaders := new(struct {
		Event     string `header:"X-GitHub-Event" required:"true" description:"GitHub event name"`
		Delivery  string `header:"X-GitHub-Delivery" required:"true" description:"Unique delivery identifier; Village records it so a redelivery is idempotent"`
		Signature string `header:"X-Hub-Signature-256" required:"true" description:"HMAC SHA-256 of the raw body under the App webhook secret"`
	})

	operations := []villageOperationSpec{
		{
			method:        http.MethodPost,
			path:          "/api/v1/integrations/github/webhook",
			id:            "receiveGitHubWebhook",
			tag:           "integrations",
			description:   "Receive a GitHub App webhook delivery. The body is GitHub's payload, authenticated by the X-Hub-Signature-256 HMAC over the raw body; X-GitHub-Delivery makes redelivery idempotent. Handles installation, pull_request, check_run, and issue_comment events and acknowledges every other event without acting. Returns 501 when the App or its webhook secret is not configured.",
			requests:      []interface{}{webhookHeaders, new(schema.VillageGitHubWebhookPayload)},
			response:      new(schema.VillageStatusResponse),
			successStatus: http.StatusAccepted,
			errorStatuses: []int{
				http.StatusBadRequest,
				http.StatusUnauthorized,
				http.StatusNotImplemented,
			},
		},
		{
			method:      http.MethodGet,
			path:        "/api/v1/pulls/{owner}/{name}/{number}",
			id:          "getPullRequestAttachment",
			tag:         "pulls",
			description: "Read one pull request's prompt attachment. The digest is null until the attachment reaches preview or attached; viewer_is_author is true when the caller is the pull request author. Readers who may not see the attached transcripts receive 403.",
			requests:    []interface{}{pullPath},
			response:    new(schema.VillagePullRequestAttachmentResponse),
			errorStatuses: []int{
				http.StatusBadRequest,
				http.StatusForbidden,
				http.StatusNotFound,
				http.StatusInternalServerError,
			},
		},
		{
			method:      http.MethodPost,
			path:        "/api/v1/pulls/{owner}/{name}/{number}/confirm",
			id:          "confirmPullRequestAttachment",
			tag:         "pulls",
			description: "Confirm a preview and post it. Only the pull request author may confirm; the attachment must be in preview, otherwise 409. Posting to GitHub failing returns 502 and leaves the attachment in preview.",
			requests:    []interface{}{pullPath},
			response:    new(schema.VillagePullRequestAttachmentResponse),
			errorStatuses: []int{
				http.StatusBadRequest,
				http.StatusUnauthorized,
				http.StatusForbidden,
				http.StatusNotFound,
				http.StatusConflict,
				http.StatusInternalServerError,
				http.StatusBadGateway,
			},
		},
		{
			method:      http.MethodDelete,
			path:        "/api/v1/pulls/{owner}/{name}/{number}",
			id:          "detachPullRequestAttachment",
			tag:         "pulls",
			description: "Detach the prompts from a pull request. Only the pull request author may detach. Deletes the comment, resets the check, and restores each transcript's previous visibility; an attachment already detached returns 409.",
			requests:    []interface{}{pullPath},
			response:    new(schema.VillagePullRequestAttachmentResponse),
			errorStatuses: []int{
				http.StatusBadRequest,
				http.StatusUnauthorized,
				http.StatusForbidden,
				http.StatusNotFound,
				http.StatusConflict,
				http.StatusInternalServerError,
				http.StatusBadGateway,
			},
		},
		{
			method:      http.MethodGet,
			path:        "/api/v1/users/me/prompt-requests",
			id:          "listMyPromptRequests",
			tag:         "pulls",
			description: "List the caller's attachments that are waiting for a transcript from the caller's machine, with each repository's normalized remote so a client can match the repository it is about to push.",
			response:    new(schema.VillagePromptRequestsResponse),
			errorStatuses: []int{
				http.StatusUnauthorized,
				http.StatusInternalServerError,
			},
		},
		{
			method:      http.MethodGet,
			path:        "/api/v1/users/me/settings",
			id:          "getMySettings",
			tag:         "users",
			description: "Read the caller's settings, including preview_before_attach.",
			response:    new(schema.VillageUserSettings),
			errorStatuses: []int{
				http.StatusUnauthorized,
				http.StatusInternalServerError,
			},
		},
		{
			method:      http.MethodPatch,
			path:        "/api/v1/users/me/settings",
			id:          "updateMySettings",
			tag:         "users",
			description: "Patch the caller's settings. A field that is omitted is left unchanged.",
			requests:    []interface{}{new(schema.VillageUpdateUserSettingsRequest)},
			response:    new(schema.VillageUserSettings),
			errorStatuses: []int{
				http.StatusBadRequest,
				http.StatusUnauthorized,
				http.StatusInternalServerError,
			},
		},
	}

	if err := addVillageOperations(r, operations); err != nil {
		return err
	}
	if err := requireRequestBody(r.Spec, http.MethodPost, "/api/v1/integrations/github/webhook"); err != nil {
		return err
	}
	return requireRequestBody(r.Spec, http.MethodPatch, "/api/v1/users/me/settings")
}
```

- [ ] **Step 5: Run the openapi tests to verify they pass**

Run: `go test -race ./openapi/ 2>&1 | tail -5`
Expected: `ok`. If `TestBuildVillageAPISpec_CollectivesOperations` reports a status set mismatch, the `statuses` list in the fixture must equal the declared success status plus every `errorStatuses` entry for that operation; fix the one that disagrees with the table above.

- [ ] **Step 6: Regenerate and run everything**

```bash
make schema
go test -race ./... 2>&1 | tail -5
pnpm --dir typescript run typecheck && pnpm --dir typescript test 2>&1 | tail -5
grep -c 'receiveGitHubWebhook\|getPullRequestAttachment\|confirmPullRequestAttachment\|detachPullRequestAttachment\|listMyPromptRequests\|getMySettings\|updateMySettings' typescript/src/internal/generated/village-api.ts
```

Expected: all `ok`; the final count is at least 7, showing the operations reached the TypeScript contract.

- [ ] **Step 7: Extend the changelog and commit**

Add under `### Added` in `CHANGELOG.md`:

```markdown
- Village API 0.15.0 routes: `POST /api/v1/integrations/github/webhook`,
  `GET` and `DELETE /api/v1/pulls/{owner}/{name}/{number}`,
  `POST /api/v1/pulls/{owner}/{name}/{number}/confirm`,
  `GET /api/v1/users/me/prompt-requests`, and `GET` and
  `PATCH /api/v1/users/me/settings`. The route fixture pins each operation's
  id, components, statuses, and description anchors.
```

```bash
git add openapi/village.go openapi/village_pulls.go openapi/testdata/village_collectives_operations.yaml CHANGELOG.md generated typescript/src/internal/generated
git commit -m "feat(contract): declare the pull request attachment routes

Add the GitHub webhook receiver, the attachment read, confirm, and detach
routes, the caller's waiting prompt requests, and the caller's settings to the
Village API, sharing the operation-adding loop with the collectives surface.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J"
```

---

### Task 6: Full gates, pull request, and release handoff

**Files:**
- Modify: `CHANGELOG.md` (tidy the Unreleased section)
- No code changes.

**Interfaces:**
- Consumes: everything above.
- Produces: a merged schema PR on `develop` and a queued release PR. The tag it mints is what `2026-09-06-pr-prompt-review-peasant.md` and the Village plan re-pin.

- [ ] **Step 1: Run the authoritative gate**

```bash
make check 2>&1 | tail -15
```

Expected: `fmt`, `vet`, `freshness`, the TypeScript checks, the release-workflow guard, and `go test -race ./...` all succeed. If `freshness` fails, run `make schema` and commit the result; a generated file was edited or a regeneration was skipped.

- [ ] **Step 2: Run the breaking-change gates inside the dev shell**

```bash
nix develop --command make gates BASE_REF=origin/develop 2>&1 | tail -20
```

Expected: `vacuum` reports no error-severity findings, `oasdiff` reports no ERR-level break (every change is additive: new paths, new optional request fields, new response properties), and `go-apidiff` reports only compatible additions. If Nix is unavailable, note in the PR that the gates ran in CI only.

- [ ] **Step 3: Tidy the changelog**

Read the `### Added` block under `## [Unreleased]` once through. It should now have the opening line from Task 1 followed by the four entries from Tasks 2 to 5. Remove the sentence "The remaining entries in this section list the surface as it lands." from the first bullet so the section reads as a finished list.

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): finish the pull request attachment entry

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J"
```

- [ ] **Step 4: Push and open the pull request**

```bash
git push -u origin schema-feat--pr-prompt-attachment-contract
gh pr create -R peasant-labs/schema --base develop \
  --title "feat(contract): pull request prompt attachment surface" \
  --body-file - <<'EOF'
Declares the wire the pull request prompt attachment feature needs, per the
design in polyrepo `docs/superpowers/specs/2026-09-06-pr-prompt-review-design.md`.

- Village API 0.15.0, Local API 0.10.0, Types 0.15.0; 0.14.0 and 0.9.0 frozen.
- `TurnDetail.command` (`CommandInvocation`): optional, safely ignorable, no
  content-capability token; the name is already in the turn text.
- `PromptDigest` and `DigestItemKind` with validators.
- Village attachment DTOs, `VillagePullRequestAttachmentState`,
  `VillagePromptsCheckMode`, two collective settings, the user settings surface.
- Seven routes under `/api/v1/integrations/github/webhook`, `/api/v1/pulls/...`,
  `/api/v1/users/me/prompt-requests`, `/api/v1/users/me/settings`.

All changes are additive. `make check` and `make gates` are green.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J
EOF
```

Expected: the PR URL is printed. CI runs `make check` and `make gates` against `origin/develop`.

- [ ] **Step 5: After the PR is squash-merged, sync and queue the release PR**

Minting a tag is a reserved maintainer action. Prepare the release PR; do not merge it and do not push a tag.

```bash
cd /Users/pigeonzow/Documents/GitHub/polyrepo/schema/develop
git pull --ff-only
git worktree add ../schema-release--v0.1.4-rc1 -b schema-release--v0.1.4-rc1 develop
cd ../schema-release--v0.1.4-rc1
```

In `CHANGELOG.md`, rename `## [Unreleased]` to `## [v0.1.4-rc1] - <today's date>` and insert a fresh empty `## [Unreleased]` heading above it. Then:

```bash
go run ./cmd/release-guard parse-title "release(v0.1.4-rc1): pull request prompt attachment contract"
git add CHANGELOG.md
git commit -m "release(v0.1.4-rc1): pull request prompt attachment contract

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012X6jGijqLSyczKYj62RG8J"
git push -u origin schema-release--v0.1.4-rc1
gh pr create -R peasant-labs/schema --base develop \
  --title "release(v0.1.4-rc1): pull request prompt attachment contract" \
  --body "Release candidate for the pull request prompt attachment contract: Village API 0.15.0, Local API 0.10.0, Types 0.15.0. Merging mints the tag through the releaser App and publishes the contract assets and the npm package under next."
```

Expected: `parse-title` accepts the title; the release PR is open and waiting for the maintainer. Report the PR URL and stop. The peasant plan begins once `v0.1.4-rc1` exists.

- [ ] **Step 6: Remove the feature worktree after merge**

```bash
cd /Users/pigeonzow/Documents/GitHub/polyrepo/schema/develop
git worktree remove ../schema-feat--pr-prompt-attachment-contract
git push origin --delete schema-feat--pr-prompt-attachment-contract
```

Expected: the worktree directory is gone and the remote branch deleted, per the workspace's landing convention.
