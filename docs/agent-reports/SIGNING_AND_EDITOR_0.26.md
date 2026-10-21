# Signing and editor recommendations — 0.26

## Signing (owner decision; no service enabled)
Current releases use GitHub asset digests and SHA256SUMS with strict updater
verification. These detect corrupt/mismatched downloads; they are not a Windows
publisher identity or proof against repository compromise. The EXE remains
unsigned and may trigger SmartScreen.

| Option | Tradeoff |
| --- | --- |
| Unsigned + clear SmartScreen guidance | No service enrollment; warning/reputation friction remains. |
| SignPath | Evaluate project eligibility, identity checks, CI integration and current terms before choosing. No enrollment or price assumed. |
| Microsoft Azure Trusted Signing | Evaluate current geographic/identity eligibility, cost and CI keyless setup; do not assume the owner's location qualifies. |
| Self-signed certificate | Useful in controlled internal testing with explicit certificate distribution; does not establish public Windows trust. |

Recommendation: keep checksum enforcement and publish honest unsigned status
while the owner evaluates a publicly trusted signing option they qualify for.
Do not distribute a self-signed root as a public-install workaround. No purchase,
account enrollment, certificate issuance or signing-service activation occurred.

## B1 text editor (Windows agent evidence required)
Today: Flutter fields with active-paragraph first-strong direction, neutral
paragraph inheritance and no inserted direction marks. Read mode renders
paragraph bases separately. Existing tests cover state preservation and paste
races; they cannot certify physical Persian IME, selection or composition.
Known limitation: inactive edited paragraphs still share the field's base
layout. Historical B1 typing/selection complaints remain unverified on hardware.

Recommendation: retain current Flutter editor pending checklist item 9. If
mixed-direction selection/composition fails reproducibly, prototype a native
Windows editor behind the existing draft/save API, then compare exact text,
undo, accessibility, focus and IME behavior. Avoid a wholesale replacement
without this evidence. Final verdict belongs to the Windows agent/owner; no
physical typing acceptance is claimed here.
