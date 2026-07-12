# onboard-state.md — журнал фаз onboarding wizard

> Пишет ТОЛЬКО `scripts/agent-team-onboard.sh` (mothership LV_AGENT_TEAM); append-only.
> Это НЕ state /pipeline: state.md прогонов живёт в `specs/*` и ведётся `pipeline-state.sh`.
> Resume читает последний исход каждой фазы; правки руками ломают resume-семантику.

| ts (UTC) | phase | outcome | detail |
|---|---|---|---|
| 2026-07-07T11:58:00Z | guards | ok | target=hr_interview |
| 2026-07-07T11:58:29Z | bootstrap | ok | dur=29s · skip=0 |
| 2026-07-07T11:58:52Z | env-audit | ok | dur=23s · REQUIRED 2/3 установлено · RECOMMENDED 5/5 установлено. |
| 2026-07-07T11:58:56Z | dod-check | ok | dur=4s · auto:5/7 manual:8 |
| 2026-07-07T11:58:57Z | smoke | ok | dur=1s · state+lint exit=0 (tmpdir) |
| 2026-07-07T11:58:57Z | run | done | - |
