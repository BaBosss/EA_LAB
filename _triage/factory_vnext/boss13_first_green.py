from pathlib import Path
from .boss_family_first_green import *

if __name__ == '__main__':
    write_boss_first_green(str(Path(__file__).resolve().parents[2]), 13)
