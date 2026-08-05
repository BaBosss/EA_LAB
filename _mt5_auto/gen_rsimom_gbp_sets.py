import os

OUT = r"D:\EA_LAB\_mt5_auto\ab_sets\rsimom_gbp"
os.makedirs(OUT, exist_ok=True)

combos = []

# mode B
for p in [9,14,21]:
    for l in [45,50,55]:
        combos.append((f"B_P{p}_L{l}", {"_01_RsiMode":1, "_01_RsiPeriod":p, "_01_Level":l}))

# mode A
for sma in [14,20,30]:
    for p in [9,14,21]:
        combos.append((f"A_SMA{sma}_P{p}", {"_01_RsiMode":0, "_01_SmaPeriod":sma, "_01_RsiPeriod":p}))

# mode C
for lb in [15,20,30]:
    for p in [9,14,21]:
        combos.append((f"C_LB{lb}_P{p}", {"_01_RsiMode":2, "_01_Lookback":lb, "_01_RsiPeriod":p}))

for label, ov in combos:
    path = os.path.join(OUT, label + ".set")
    lines = [f"{k}={v}" for k, v in ov.items()]
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")

print(f"generated {len(combos)} set files in {OUT}")
