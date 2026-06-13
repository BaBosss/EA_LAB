# mql-code-generator

Purpose: generate or revise MQL5 Expert Advisor source from an approved specification.

Inputs:
- Strategy specification
- Risk limits
- Required indicators
- Backtest assumptions

Outputs:
- `.mq5` source
- Compile notes
- Known limitations

Safety:
- Generated code must default to tester-safe behavior.
- Live trading must remain disabled until manually reviewed.
