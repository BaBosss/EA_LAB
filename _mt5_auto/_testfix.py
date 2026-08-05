with open(r"D:\EA_LAB\_mt5_auto\ab_sets\o1411\PVT_base.set", "r") as f:
    lines = f.readlines()

with open(r"D:\EA_LAB\_mt5_auto\ab_sets\o1411\TESTFIX.set", "w") as f:
    for line in lines:
        if line.startswith("_02_SlAtrMult"):
            f.write("_02_SlAtrMult=2.5\n")
        elif line.startswith("_01_AtrPeriod"):
            f.write("_01_AtrPeriod=20\n")
        else:
            f.write(line)

# Verify
with open(r"D:\EA_LAB\_mt5_auto\ab_sets\o1411\TESTFIX.set", "r") as f:
    print(f.read())
