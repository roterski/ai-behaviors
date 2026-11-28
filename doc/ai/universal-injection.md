# Universal injection

Status: framed and researched (2026-11-28). No design chosen.

# Frame

## Situation
Behaviors reach the model two ways, both injected by the host before the model sees the turn:
- Hooks: `hooks/inject-behaviors.sh` (Claude Code), `hooks/eca-inject-behaviors.sh` (ECA). Session-sticky via a state file.
- Clojure API: `ai-behaviors.api/augment`. Stateless; needs a Clojure host wrapping the agent.

## Complication
Harnesses without a usable prompt hook or a Clojure host get no behaviors.
CLI and MCP reach almost any agent, but they invert who acts: the model or the user calls them.
That puts at risk three properties the host-injected paths get for free:
1. Guarantee: injection happens only if the call is made.
2. Authority: text arrives as a tool result, not in the user turn; modes are HARD CONSTRAINTs.
3. Session identity: stickiness needs a session id a tool call may not carry.

## Question
What injection path works in terminal agents like opencode and copilot-cli,
using the strongest trigger each harness offers,
and do modes hold when their text comes from a tool?

## Decisions (user)
- Trigger: tiered — best available per harness. Order: host-added on every prompt > user-run command > model-called tool.
- Authority of tool-returned text: unknown; measure it.
- Stickiness: per-prompt only, like the API.
- Targets: terminal agents beyond Claude Code / ECA — opencode, copilot-cli.
  IDE agents, chat apps, headless pipelines: left unticked; treated as deferred, not ruled out.
- Syntax: inline `#hashtags` preferred, best effort; another invocation is acceptable where inline is infeasible.
- Placement: alongside hooks and API. If CLI or MCP, implement in Clojure/babashka, sharing `ai-behaviors.core`.

## Constraints
- Behavior files (`behaviors/*/prompt.md`, `compose`) and project/user-local lookup stay the source of truth.
- Existing hook and API users keep working.
- Clojure/babashka, reusing `ai-behaviors.core`.

## Non-goals
- Session stickiness.
- Changing behavior content or the hashtag grammar.

# Research

Neither harness is installed on the devbox; nothing below was tried in a harness.

## opencode
| Trigger | Mechanism | Confidence |
|---|---|---|
| Host-added | Plugin hook `chat.message` (TS/JS in `.opencode/plugins/` or `~/.config/opencode/plugins/`) rewrites or adds parts of the user message | probable: community sources; official hook docs 404, types not fetched |
| User-run command | `.opencode/commands/*.md` templates; `$ARGUMENTS`; `` !`cmd` `` inserts shell output before submit, outside the permission flow | confirmed (docs) |
| User-run command | MCP prompts appear as `/<server>:<prompt>` | confirmed (docs) |
| Model-called | MCP tools as `<server>_<tool>` | confirmed (docs) |

## copilot-cli
| Trigger | Mechanism | Confidence |
|---|---|---|
| Host-added | `userPromptSubmitted`: config-file hook output is dropped; only SDK hooks may modify | confirmed — ruled out |
| Host-added | `userPromptTransformed` → `modifiedTransformedPrompt` rewrites model-facing content; command hooks said to run on all events | uncertain: fields from a summary, not page text |
| Standing instruction | `sessionStart` `additionalContext` honored for command hooks, once per session | confirmed |
| Existing Claude hook | Copilot reads `.claude/settings.json` hooks, but `UserPromptSubmit` output is dropped | probable (entailed) |
| User-run command | User slash commands, prompt files, MCP prompts: not documented; skills exist, locations not stated | unknown |
| Model-called | MCP servers supported | confirmed |

## Authority of tool-returned text
Unmeasured for ai-behaviors.
Prompt-injection preprints show models often obey instructions in tool output, varying by model (uncertain; analogy).
`tests/dogfood/*/KEY.md` cases exist; no runner per trigger path.

## Babashka entry point
- `ai-behaviors.api/augment` runs under bb v1.13.229 with `bb -cp src` from outside the repo (confirmed, run).
- `core.clj` requires only `babashka.fs`, `babashka.process`, `clojure.string` — all built into bb (confirmed).
- MCP libraries: modex-bb (bb-native, stdio, tool DSL; probable), roklenarcic/mcp-server (alpha, bb JSON option; probable). Neither tried.

## Open unknowns
1. Is opencode `chat.message` typed and stable in the current `@opencode-ai/plugin`?
2. Does copilot-cli honor `userPromptTransformed` output from a command hook?
3. Does copilot-cli have user commands, prompt files, or MCP prompts?
4. Mode adherence: tool-returned vs host-injected.
5. Does either MCP library work with this repo?

## Sources
- https://opencode.ai/docs/plugins/
- https://opencode.ai/docs/commands/
- https://opencode.ai/docs/mcp-servers/
- https://tessl.io/registry/pantheon-ai/opencode-toolkit/0.2.0/files/build-plugins/references/hooks.md
- https://cdn.jsdelivr.net/npm/opencode-design-lab@0.2.3/skills/build-opencode-plugin/plugin-studies/05-context-manipulation.md
- https://github.com/JuliusBrussee/caveman/issues/418
- https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-hooks-reference
- https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
- https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers
- https://arxiv.org/html/2606.07992
- https://arxiv.org/html/2603.21642
- https://cljdoc.org/d/io.github.hive-agi/modex-bb/0.1.6
- https://cljdoc.org/d/org.clojars.roklenarcic/mcp-server/0.3.40
