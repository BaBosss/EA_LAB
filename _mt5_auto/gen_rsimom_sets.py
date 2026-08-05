import os

OUT = r"D:\EA_LAB\_mt5_auto\ab_sets\rsimom_fine"
os.makedirs(OUT, exist_ok=True)

combos = []  # (label, dict of overrides)

# TASK1a: mode B around P9/L55
for p in [7,8,9,10,11]:
    for l in [52,54,55,56,58]:
        combos.append((f"T1A_P{p}_L{l}", {"_01_RsiMode":1, "_01_RsiPeriod":p, "_01_Level":l}))

# TASK1b: mode B around P21/L50
for p in [18,20,21,23,25]:
    for l in [47,49,50,51,53]:
        combos.append((f"T1B_P{p}_L{l}", {"_01_RsiMode":1, "_01_RsiPeriod":p, "_01_Level":l}))

# TASK2a: mode A
for sma in [10,14,20,30]:
    for p in [9,14,21]:
        combos.append((f"T2A_SMA{sma}_P{p}", {"_01_RsiMode":0, "_01_SmaPeriod":sma, "_01_RsiPeriod":p}))

# TASK2b: mode C
for lb in [10,15,20,30]:
    for p in [9,14,21]:
        combos.append((f"T2C_LB{lb}_P{p}", {"_01_RsiMode":2, "_01_Lookback":lb, "_01_RsiPeriod":p}))

for label, ov in combos:
    path = os.path.join(OUT, label + ".set")
    lines = []
    for k, v in ov.items():
        lines.append(f"{k}={v}")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")

print(f"generated {len(combos)} set files in {OUT}")
