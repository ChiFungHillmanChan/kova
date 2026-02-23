# demo.tape — Kova Quick Demo
# Generate the GIF: vhs demo.tape
# Requires: https://github.com/charmbracelet/vhs

# Terminal settings
Set Shell "bash"
Set FontSize 16
Set Width 1000
Set Height 600
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms
Set WindowBar Colorful
Set WindowBarSize 40

# ─────────────────────────────────────────────
# Scene 1: Check Kova status — hooks are active
# ─────────────────────────────────────────────
Type "# Step 1: Check that Kova hooks are active"
Enter
Sleep 500ms

Type "kova status"
Enter
Sleep 3s

# ─────────────────────────────────────────────
# Scene 2: Launch the Kova loop on an example PRD
# ─────────────────────────────────────────────
Type "# Step 2: Run the Kova loop on a PRD"
Enter
Sleep 500ms

Type@100ms 'claude "/kova:loop docs/example-prd.md"'
Enter
Sleep 2s

# Simulate the loop output (kova-loop.sh prints this)
Output "═══════════════════════════════════════════════"
Sleep 200ms
Output " KOVA LOOP — Starting"
Sleep 200ms
Output " PRD: docs/example-prd.md (1 items)"
Sleep 200ms
Output "═══════════════════════════════════════════════"
Sleep 1s
Output ""
Output "▶ Item 1/1: Add a greet CLI command"
Output "  Mode: implement"
Sleep 1s
Output "  ✓ Claude session completed"
Sleep 1s

# ─────────────────────────────────────────────
# Scene 3: Verification gate runs
# ─────────────────────────────────────────────
Output ""
Output "─── Verification Gate ───"
Sleep 500ms
Output "  [1/7] Build ............... ✓ pass"
Sleep 400ms
Output "  [2/7] Tests ............... ✓ 193 passed"
Sleep 400ms
Output "  [3/7] Lint ................ ✓ pass"
Sleep 400ms
Output "  [4/7] Typecheck ........... ✓ pass"
Sleep 400ms
Output "  [5/7] Format .............. ✓ pass"
Sleep 400ms
Output "  [6/7] Security ............ ✓ pass"
Sleep 400ms
Output "  [7/7] Coverage ............ ✓ pass"
Sleep 800ms
Output ""
Output "  ✅ Verification PASSED"
Sleep 1s

# ─────────────────────────────────────────────
# Scene 4: Code review + commit
# ─────────────────────────────────────────────
Output ""
Output "─── Code Review ───"
Sleep 500ms
Output "  Reviewer: Claude (separate session)"
Output "  Verdict: PASS — no issues found"
Sleep 1s
Output ""
Output "─── Commit ───"
Sleep 500ms
Output '  feat(greet): add greet CLI command'
Output "  1 file changed, 12 insertions(+)"
Sleep 1s
Output ""
Output "═══════════════════════════════════════════════"
Output " KOVA LOOP — Complete (1/1 items shipped)"
Output "═══════════════════════════════════════════════"
Sleep 3s
