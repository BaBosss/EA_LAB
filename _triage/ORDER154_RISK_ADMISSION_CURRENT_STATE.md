# ORDER-154 -- Portfolio Risk Admission: Current-State Report

> DD95 values are drawdown quantiles, not returns; combining them through a return-correlation matrix is a screening heuristic, not a theorem. This output is a prior for admission control, never a verdict, and does not replace per-EA Monte Carlo.

**Formula:** `portfolio_DD_est = sqrt( sum_i sum_j corr_ij * DD95_i * DD95_j ), corr_ii = 1`

## Data coverage: **34/57 magics have real DD95 data (60%)** -- 23 are UNKNOWN

Budget rule: DEMO accounts = **25%** of equity (fixed project number (docs/JUDGE_DAY_RUNBOOK.md "Sizing" step 3)). REAL_CENT accounts: computed/reported only, **no budget assigned -- user decision needed**.

## Correlation coverage (ORDER-174): **422/1540 pairs measured** (0 live, 422 backtest) -- **1118 pairs on the conservative default 1.0**

| pair | corr | source |
|---|---|---|
| 990020~990025 | -0.0731 | **backtest** |
| 990020~990030 | 0.2431 | **backtest** |
| 990020~990066 | 0.0236 | **backtest** |
| 990020~990068 | 0.6985 | **backtest** |
| 990020~990101 | -0.0498 | **backtest** |
| 990020~990103 | -0.2414 | **backtest** |
| 990020~990110 | -0.1075 | **backtest** |
| 990020~990120 | 0.1222 | **backtest** |
| 990020~990201 | -0.045 | **backtest** |
| 990020~990202 | 0.1329 | **backtest** |
| 990020~990203 | 0.0426 | **backtest** |
| 990020~990204 | -0.285 | **backtest** |
| 990020~990205 | 0.2655 | **backtest** |
| 990020~990206 | 0.5321 | **backtest** |
| 990020~990207 | 0.7656 | **backtest** |
| 990020~990208 | 0.201 | **backtest** |
| 990020~990301 | -0.0388 | **backtest** |
| 990020~990302 | 0.1145 | **backtest** |
| 990020~990303 | 0.1343 | **backtest** |
| 990020~990984 | -0.1185 | **backtest** |
| 990020~991002 | 0.4071 | **backtest** |
| 990020~991003 | 0.3468 | **backtest** |
| 990020~991004 | -0.4337 | **backtest** |
| 990020~991005 | 0.0483 | **backtest** |
| 990020~991070 | 0.2405 | **backtest** |
| 990020~992003 | 0.112 | **backtest** |
| 990020~992004 | 0.754 | **backtest** |
| 990020~992017 | 0.4452 | **backtest** |
| 990020~999094 | 0.2051 | **backtest** |
| 990025~990030 | -0.0265 | **backtest** |
| 990025~990066 | -0.258 | **backtest** |
| 990025~990068 | 0.0482 | **backtest** |
| 990025~990101 | 0.0774 | **backtest** |
| 990025~990103 | -0.1797 | **backtest** |
| 990025~990110 | -0.1065 | **backtest** |
| 990025~990120 | 0.2112 | **backtest** |
| 990025~990201 | -0.0732 | **backtest** |
| 990025~990202 | -0.0703 | **backtest** |
| 990025~990203 | -0.2368 | **backtest** |
| 990025~990204 | 0.0821 | **backtest** |
| 990025~990205 | 0.0696 | **backtest** |
| 990025~990206 | -0.13 | **backtest** |
| 990025~990207 | 0.062 | **backtest** |
| 990025~990208 | -0.0136 | **backtest** |
| 990025~990301 | 0.0635 | **backtest** |
| 990025~990302 | -0.3069 | **backtest** |
| 990025~990303 | 0.0465 | **backtest** |
| 990025~990984 | 0.0487 | **backtest** |
| 990025~991002 | -0.4836 | **backtest** |
| 990025~991003 | -0.1815 | **backtest** |
| 990025~991004 | 0.4534 | **backtest** |
| 990025~991005 | 0.3296 | **backtest** |
| 990025~991070 | -0.0002 | **backtest** |
| 990025~992003 | 0.0411 | **backtest** |
| 990025~992004 | -0.1672 | **backtest** |
| 990025~992017 | -0.0538 | **backtest** |
| 990025~999094 | 0.1042 | **backtest** |
| 990030~990066 | -0.0952 | **backtest** |
| 990030~990068 | 0.1658 | **backtest** |
| 990030~990101 | 0.1691 | **backtest** |
| 990030~990103 | 0.1226 | **backtest** |
| 990030~990110 | -0.5483 | **backtest** |
| 990030~990120 | 0.082 | **backtest** |
| 990030~990201 | 0.0036 | **backtest** |
| 990030~990202 | 0.0514 | **backtest** |
| 990030~990203 | -0.0561 | **backtest** |
| 990030~990204 | -0.1699 | **backtest** |
| 990030~990205 | -0.1576 | **backtest** |
| 990030~990206 | 0.4625 | **backtest** |
| 990030~990207 | 0.0579 | **backtest** |
| 990030~990208 | 0.0654 | **backtest** |
| 990030~990301 | -0.0044 | **backtest** |
| 990030~990302 | 0.2796 | **backtest** |
| 990030~990303 | 0.2616 | **backtest** |
| 990030~990984 | 0.1067 | **backtest** |
| 990030~991002 | 0.7223 | **backtest** |
| 990030~991003 | -0.3227 | **backtest** |
| 990030~991004 | 0.2535 | **backtest** |
| 990030~991005 | -0.1879 | **backtest** |
| 990030~991070 | 0.0958 | **backtest** |
| 990030~992003 | 0.1467 | **backtest** |
| 990030~992004 | 0.1889 | **backtest** |
| 990030~992017 | 0.4648 | **backtest** |
| 990030~999094 | 0.0831 | **backtest** |
| 990066~990068 | 0.004 | **backtest** |
| 990066~990101 | 0.0521 | **backtest** |
| 990066~990103 | -0.1796 | **backtest** |
| 990066~990110 | 0.3796 | **backtest** |
| 990066~990120 | 0.6189 | **backtest** |
| 990066~990201 | 0.1844 | **backtest** |
| 990066~990202 | -0.1637 | **backtest** |
| 990066~990203 | -0.0434 | **backtest** |
| 990066~990204 | -0.2718 | **backtest** |
| 990066~990205 | 0.0818 | **backtest** |
| 990066~990206 | 0.1975 | **backtest** |
| 990066~990207 | 0.1058 | **backtest** |
| 990066~990208 | 0.0279 | **backtest** |
| 990066~990301 | -0.2357 | **backtest** |
| 990066~990302 | -0.0043 | **backtest** |
| 990066~990303 | 0.2236 | **backtest** |
| 990066~990984 | -0.2694 | **backtest** |
| 990066~991002 | 0.1858 | **backtest** |
| 990066~991003 | 0.5269 | **backtest** |
| 990066~991004 | -0.0769 | **backtest** |
| 990066~991005 | -0.0438 | **backtest** |
| 990066~991070 | 0.315 | **backtest** |
| 990066~992003 | -0.1499 | **backtest** |
| 990066~992004 | 0.4008 | **backtest** |
| 990066~992017 | -0.2128 | **backtest** |
| 990066~999094 | -0.0531 | **backtest** |
| 990068~990101 | 0.1222 | **backtest** |
| 990068~990103 | 0.01 | **backtest** |
| 990068~990110 | -0.0249 | **backtest** |
| 990068~990120 | 0.3213 | **backtest** |
| 990068~990201 | -0.2931 | **backtest** |
| 990068~990202 | 0.1026 | **backtest** |
| 990068~990203 | 0.0926 | **backtest** |
| 990068~990204 | 0.1072 | **backtest** |
| 990068~990205 | 0.355 | **backtest** |
| 990068~990206 | -0.283 | **backtest** |
| 990068~990207 | 0.6442 | **backtest** |
| 990068~990208 | 0.0639 | **backtest** |
| 990068~990301 | 0.055 | **backtest** |
| 990068~990302 | 0.2307 | **backtest** |
| 990068~990303 | -0.0048 | **backtest** |
| 990068~990984 | -0.0934 | **backtest** |
| 990068~991002 | 0.5645 | **backtest** |
| 990068~991003 | 0.2203 | **backtest** |
| 990068~991004 | 0.1998 | **backtest** |
| 990068~991005 | 0.1668 | **backtest** |
| 990068~991070 | 0.0208 | **backtest** |
| 990068~992003 | 0.4705 | **backtest** |
| 990068~992004 | 0.3941 | **backtest** |
| 990068~992017 | 0.4945 | **backtest** |
| 990068~999094 | 0.4103 | **backtest** |
| 990101~990103 | 0.2894 | **backtest** |
| 990101~990110 | -0.131 | **backtest** |
| 990101~990120 | 0.587 | **backtest** |
| 990101~990201 | 0.0358 | **backtest** |
| 990101~990202 | -0.4058 | **backtest** |
| 990101~990203 | 0.7089 | **backtest** |
| 990101~990204 | -0.1195 | **backtest** |
| 990101~990205 | 0.8211 | **backtest** |
| 990101~990207 | 0.1021 | **backtest** |
| 990101~990208 | -0.5714 | **backtest** |
| 990101~990301 | -0.2106 | **backtest** |
| 990101~990302 | -0.242 | **backtest** |
| 990101~990303 | -0.4359 | **backtest** |
| 990101~990984 | 0.1828 | **backtest** |
| 990101~991002 | -0.1314 | **backtest** |
| 990101~991003 | 0.4715 | **backtest** |
| 990101~991004 | 0.5305 | **backtest** |
| 990101~991005 | 0.1413 | **backtest** |
| 990101~991070 | -0.1618 | **backtest** |
| 990101~992003 | 0.1164 | **backtest** |
| 990101~992004 | 0.0053 | **backtest** |
| 990101~992017 | 0.0925 | **backtest** |
| 990101~999094 | -0.1383 | **backtest** |
| 990103~990110 | 0.1241 | **backtest** |
| 990103~990120 | -0.3479 | **backtest** |
| 990103~990201 | 0.3367 | **backtest** |
| 990103~990202 | -0.0849 | **backtest** |
| 990103~990203 | 0.4076 | **backtest** |
| 990103~990204 | 0.1396 | **backtest** |
| 990103~990205 | 0.5472 | **backtest** |
| 990103~990206 | 0.3792 | **backtest** |
| 990103~990207 | 0.1506 | **backtest** |
| 990103~990208 | -0.014 | **backtest** |
| 990103~990301 | -0.1697 | **backtest** |
| 990103~990302 | 0.0496 | **backtest** |
| 990103~990303 | 0.0295 | **backtest** |
| 990103~990984 | -0.1929 | **backtest** |
| 990103~991002 | -0.0965 | **backtest** |
| 990103~991003 | -0.0777 | **backtest** |
| 990103~991004 | -0.3525 | **backtest** |
| 990103~991005 | -0.0655 | **backtest** |
| 990103~991070 | -0.1638 | **backtest** |
| 990103~992003 | 0.1369 | **backtest** |
| 990103~992004 | -0.1134 | **backtest** |
| 990103~992017 | -0.072 | **backtest** |
| 990103~999094 | -0.1249 | **backtest** |
| 990110~990120 | 0.3559 | **backtest** |
| 990110~990201 | 0.2791 | **backtest** |
| 990110~990202 | 0.4471 | **backtest** |
| 990110~990203 | 0.1606 | **backtest** |
| 990110~990204 | -0.0947 | **backtest** |
| 990110~990205 | 0.5341 | **backtest** |
| 990110~990207 | -0.2077 | **backtest** |
| 990110~990208 | 0.7277 | **backtest** |
| 990110~990301 | -0.1886 | **backtest** |
| 990110~990302 | 0.2591 | **backtest** |
| 990110~990303 | -0.2857 | **backtest** |
| 990110~990984 | -0.2378 | **backtest** |
| 990110~991002 | 0.3946 | **backtest** |
| 990110~991003 | 0.4441 | **backtest** |
| 990110~991004 | 0.4821 | **backtest** |
| 990110~991005 | 0.0394 | **backtest** |
| 990110~991070 | 0.3021 | **backtest** |
| 990110~992003 | -0.3168 | **backtest** |
| 990110~992004 | 0.1613 | **backtest** |
| 990110~992017 | -0.0967 | **backtest** |
| 990110~999094 | -0.2527 | **backtest** |
| 990120~990201 | -0.6019 | **backtest** |
| 990120~990202 | 0.6971 | **backtest** |
| 990120~990203 | -0.1625 | **backtest** |
| 990120~990204 | -0.7763 | **backtest** |
| 990120~990205 | 0.0717 | **backtest** |
| 990120~990207 | -0.5549 | **backtest** |
| 990120~990208 | 0.5173 | **backtest** |
| 990120~990301 | 0.3973 | **backtest** |
| 990120~990302 | -0.3971 | **backtest** |
| 990120~990303 | 0.0015 | **backtest** |
| 990120~990984 | 0.376 | **backtest** |
| 990120~991002 | 0.1302 | **backtest** |
| 990120~991003 | 0.1655 | **backtest** |
| 990120~991005 | 0.3795 | **backtest** |
| 990120~991070 | 0.4828 | **backtest** |
| 990120~992003 | 0.1764 | **backtest** |
| 990120~992004 | 0.0578 | **backtest** |
| 990120~992017 | 0.6376 | **backtest** |
| 990120~999094 | 0.54 | **backtest** |
| 990201~990202 | -0.2035 | **backtest** |
| 990201~990203 | 0.4395 | **backtest** |
| 990201~990204 | 0.0742 | **backtest** |
| 990201~990205 | 0.6714 | **backtest** |
| 990201~990207 | 0.073 | **backtest** |
| 990201~990208 | 0.2596 | **backtest** |
| 990201~990301 | -0.3107 | **backtest** |
| 990201~990302 | 0.2128 | **backtest** |
| 990201~990303 | -0.5348 | **backtest** |
| 990201~990984 | -0.0265 | **backtest** |
| 990201~991002 | -0.0299 | **backtest** |
| 990201~991003 | 0.2085 | **backtest** |
| 990201~991004 | -0.1053 | **backtest** |
| 990201~991005 | -0.4095 | **backtest** |
| 990201~991070 | 0.1858 | **backtest** |
| 990201~992003 | -0.1062 | **backtest** |
| 990201~992004 | 0.0465 | **backtest** |
| 990201~992017 | -0.0132 | **backtest** |
| 990201~999094 | -0.1383 | **backtest** |
| 990202~990203 | -0.1468 | **backtest** |
| 990202~990204 | 0.5524 | **backtest** |
| 990202~990205 | 0.2889 | **backtest** |
| 990202~990207 | -0.0994 | **backtest** |
| 990202~990208 | 0.1663 | **backtest** |
| 990202~990301 | 0.3772 | **backtest** |
| 990202~990302 | 0.2262 | **backtest** |
| 990202~990303 | -0.0334 | **backtest** |
| 990202~990984 | -0.162 | **backtest** |
| 990202~991002 | 0.0866 | **backtest** |
| 990202~991003 | -0.1333 | **backtest** |
| 990202~991004 | 0.112 | **backtest** |
| 990202~991005 | -0.0789 | **backtest** |
| 990202~991070 | 0.5561 | **backtest** |
| 990202~992003 | -0.0695 | **backtest** |
| 990202~992004 | -0.0265 | **backtest** |
| 990202~992017 | 0.0167 | **backtest** |
| 990202~999094 | -0.2342 | **backtest** |
| 990203~990204 | 0.2548 | **backtest** |
| 990203~990205 | 0.5054 | **backtest** |
| 990203~990206 | 0.374 | **backtest** |
| 990203~990207 | 0.2709 | **backtest** |
| 990203~990208 | 0.1084 | **backtest** |
| 990203~990301 | -0.1132 | **backtest** |
| 990203~990302 | 0.1849 | **backtest** |
| 990203~990303 | -0.7106 | **backtest** |
| 990203~990984 | -0.1601 | **backtest** |
| 990203~991002 | -0.0863 | **backtest** |
| 990203~991003 | 0.082 | **backtest** |
| 990203~991004 | 0.0189 | **backtest** |
| 990203~991005 | -0.3541 | **backtest** |
| 990203~991070 | -0.1414 | **backtest** |
| 990203~992003 | 0.1254 | **backtest** |
| 990203~992004 | -0.0044 | **backtest** |
| 990203~992017 | 0.0643 | **backtest** |
| 990203~999094 | 0.3255 | **backtest** |
| 990204~990205 | 0.086 | **backtest** |
| 990204~990207 | -0.2432 | **backtest** |
| 990204~990208 | 0.05 | **backtest** |
| 990204~990301 | 0.1739 | **backtest** |
| 990204~990302 | -0.1711 | **backtest** |
| 990204~990303 | -0.5468 | **backtest** |
| 990204~990984 | -0.2076 | **backtest** |
| 990204~991002 | -0.385 | **backtest** |
| 990204~991003 | -0.6757 | **backtest** |
| 990204~991004 | 0.0891 | **backtest** |
| 990204~991005 | 0.0417 | **backtest** |
| 990204~991070 | 0.1883 | **backtest** |
| 990204~992003 | 0.1635 | **backtest** |
| 990204~992004 | -0.3827 | **backtest** |
| 990204~992017 | -0.127 | **backtest** |
| 990204~999094 | 0.2731 | **backtest** |
| 990205~990207 | 0.4287 | **backtest** |
| 990205~990208 | 0.1627 | **backtest** |
| 990205~990301 | 0.0284 | **backtest** |
| 990205~990302 | 0.3034 | **backtest** |
| 990205~990303 | -0.2617 | **backtest** |
| 990205~990984 | -0.3289 | **backtest** |
| 990205~991002 | -0.106 | **backtest** |
| 990205~991003 | 0.4267 | **backtest** |
| 990205~991004 | 0.1851 | **backtest** |
| 990205~991005 | -0.6143 | **backtest** |
| 990205~991070 | -0.0193 | **backtest** |
| 990205~992003 | 0.0868 | **backtest** |
| 990205~992004 | 0.1474 | **backtest** |
| 990205~992017 | 0.1086 | **backtest** |
| 990205~999094 | -0.3986 | **backtest** |
| 990206~990301 | 0.5447 | **backtest** |
| 990206~990302 | 0.0522 | **backtest** |
| 990206~990984 | 0.5063 | **backtest** |
| 990206~991003 | 0.6641 | **backtest** |
| 990206~991005 | 0.0236 | **backtest** |
| 990206~991070 | -0.4814 | **backtest** |
| 990206~992003 | -0.2424 | **backtest** |
| 990206~992004 | 0.6413 | **backtest** |
| 990206~992017 | -0.6127 | **backtest** |
| 990206~999094 | 0.2107 | **backtest** |
| 990207~990208 | -0.3026 | **backtest** |
| 990207~990301 | -0.0371 | **backtest** |
| 990207~990302 | 0.5483 | **backtest** |
| 990207~990303 | 0.3084 | **backtest** |
| 990207~990984 | -0.4701 | **backtest** |
| 990207~991002 | 0.29 | **backtest** |
| 990207~991003 | 0.1219 | **backtest** |
| 990207~991004 | -0.2802 | **backtest** |
| 990207~991005 | 0.066 | **backtest** |
| 990207~991070 | 0.2608 | **backtest** |
| 990207~992003 | 0.5434 | **backtest** |
| 990207~992004 | 0.7171 | **backtest** |
| 990207~992017 | 0.4436 | **backtest** |
| 990207~999094 | 0.2115 | **backtest** |
| 990208~990301 | 0.015 | **backtest** |
| 990208~990302 | 0.1821 | **backtest** |
| 990208~990303 | 0.1237 | **backtest** |
| 990208~990984 | -0.0679 | **backtest** |
| 990208~991002 | 0.4568 | **backtest** |
| 990208~991003 | -0.0037 | **backtest** |
| 990208~991004 | 0.0559 | **backtest** |
| 990208~991005 | -0.1748 | **backtest** |
| 990208~991070 | 0.2584 | **backtest** |
| 990208~992003 | -0.4325 | **backtest** |
| 990208~992004 | 0.1876 | **backtest** |
| 990208~992017 | 0.2252 | **backtest** |
| 990208~999094 | -0.0194 | **backtest** |
| 990301~990302 | 0.3212 | **backtest** |
| 990301~990303 | -0.1345 | **backtest** |
| 990301~990984 | 0.1272 | **backtest** |
| 990301~991002 | 0.3474 | **backtest** |
| 990301~991003 | -0.045 | **backtest** |
| 990301~991004 | -0.0447 | **backtest** |
| 990301~991005 | -0.007 | **backtest** |
| 990301~991070 | 0.0624 | **backtest** |
| 990301~992003 | -0.054 | **backtest** |
| 990301~992004 | -0.2988 | **backtest** |
| 990301~992017 | 0.161 | **backtest** |
| 990301~999094 | 0.2022 | **backtest** |
| 990302~990303 | -0.0271 | **backtest** |
| 990302~990984 | -0.1712 | **backtest** |
| 990302~991002 | 0.3139 | **backtest** |
| 990302~991003 | 0.1483 | **backtest** |
| 990302~991004 | 0.0168 | **backtest** |
| 990302~991005 | -0.1893 | **backtest** |
| 990302~991070 | 0.0598 | **backtest** |
| 990302~992003 | 0.3253 | **backtest** |
| 990302~992004 | 0.3759 | **backtest** |
| 990302~992017 | 0.4753 | **backtest** |
| 990302~999094 | 0.3152 | **backtest** |
| 990303~990984 | -0.1621 | **backtest** |
| 990303~991002 | 0.3652 | **backtest** |
| 990303~991003 | -0.149 | **backtest** |
| 990303~991004 | -0.486 | **backtest** |
| 990303~991005 | -0.0828 | **backtest** |
| 990303~991070 | 0.1293 | **backtest** |
| 990303~992003 | 0.1907 | **backtest** |
| 990303~992004 | 0.4567 | **backtest** |
| 990303~992017 | 0.031 | **backtest** |
| 990303~999094 | -0.4257 | **backtest** |
| 990984~991002 | 0.1333 | **backtest** |
| 990984~991003 | 0.1643 | **backtest** |
| 990984~991004 | 0.3779 | **backtest** |
| 990984~991005 | 0.1513 | **backtest** |
| 990984~991070 | -0.23 | **backtest** |
| 990984~992003 | -0.1584 | **backtest** |
| 990984~992004 | -0.2502 | **backtest** |
| 990984~992017 | 0.058 | **backtest** |
| 990984~999094 | -0.0643 | **backtest** |
| 991002~991003 | 0.1046 | **backtest** |
| 991002~991004 | 0.3086 | **backtest** |
| 991002~991005 | -0.4836 | **backtest** |
| 991002~991070 | 0.1246 | **backtest** |
| 991002~992003 | 0.0146 | **backtest** |
| 991002~992004 | 0.4288 | **backtest** |
| 991002~992017 | 0.7972 | **backtest** |
| 991002~999094 | -0.0691 | **backtest** |
| 991003~991004 | -0.1256 | **backtest** |
| 991003~991005 | 0.0607 | **backtest** |
| 991003~991070 | -0.1285 | **backtest** |
| 991003~992003 | -0.1246 | **backtest** |
| 991003~992004 | 0.1732 | **backtest** |
| 991003~992017 | -0.085 | **backtest** |
| 991003~999094 | -0.0232 | **backtest** |
| 991004~991005 | -0.2354 | **backtest** |
| 991004~991070 | -0.3237 | **backtest** |
| 991004~992003 | 0.1576 | **backtest** |
| 991004~992004 | -0.3429 | **backtest** |
| 991004~992017 | 0.1742 | **backtest** |
| 991004~999094 | 0.054 | **backtest** |
| 991005~991070 | 0.1162 | **backtest** |
| 991005~992003 | -0.0743 | **backtest** |
| 991005~992004 | 0.1533 | **backtest** |
| 991005~992017 | 0.1098 | **backtest** |
| 991005~999094 | 0.2182 | **backtest** |
| 991070~992003 | -0.1774 | **backtest** |
| 991070~992004 | 0.4446 | **backtest** |
| 991070~992017 | 0.1232 | **backtest** |
| 991070~999094 | -0.1532 | **backtest** |
| 992003~992004 | 0.0905 | **backtest** |
| 992003~992017 | 0.1677 | **backtest** |
| 992003~999094 | 0.3465 | **backtest** |
| 992004~992017 | 0.342 | **backtest** |
| 992004~999094 | -0.0437 | **backtest** |
| 992017~999094 | 0.1536 | **backtest** |

_Live and backtest correlations are different evidence quality -- live outranks backtest when both exist. Every pair not listed used corr=1.0 (fully additive, conservative)._

---

## Account 463666728 -- Demo bundle 10 (DEMO)

- magics (ACTIVE+PENDING_ATTACH): **17** | known DD95: **15** | UNKNOWN: **2**
- UNKNOWN magics: 990067, 990069
- budget: **25.0%** of equity (fixed project number (docs/JUDGE_DAY_RUNBOOK.md "Sizing" step 3))
- **portfolio_DD_est = 84.37%**
  - headroom vs budget: -59.37 pts (OVER BUDGET)
- computed from 15/17 magics (2 UNKNOWN excluded from the sum, not zeroed) -- treat as a PARTIAL number, not full coverage

## Account 415573666 -- Demo Mt5-2 (DEMO)

- magics (ACTIVE+PENDING_ATTACH): **14** | known DD95: **14** | UNKNOWN: **0**
- budget: **25.0%** of equity (fixed project number (docs/JUDGE_DAY_RUNBOOK.md "Sizing" step 3))
- **portfolio_DD_est = 40.10%**
  - headroom vs budget: -15.10 pts (OVER BUDGET)
- computed from 14/14 magics (full coverage on this account)

## Account 141049900 -- 01. Celestial Woodfire (REAL_CENT)

- magics (ACTIVE+PENDING_ATTACH): **5** | known DD95: **0** | UNKNOWN: **5**
- UNKNOWN magics: 1112, 1113, 1114, 1115, 7777
- budget: **not assigned** (REAL_CENT: computed/reported only -- NO budget assigned, user decision needed)
- cannot compute -- 0/5 magics on this account have known DD95 (all UNKNOWN). portfolio_dd_est is NOT a portfolio risk number here, it is absent.

## Account 159475669 -- Boss - Trend Swing (REAL_CENT)

- magics (ACTIVE+PENDING_ATTACH): **13** | known DD95: **1** | UNKNOWN: **12**
- UNKNOWN magics: 1524, 20240001, 8001, 8002, 8005, 8008, 8009, 8012, 8014, 8015, 990005, 99000512
- budget: **not assigned** (REAL_CENT: computed/reported only -- NO budget assigned, user decision needed)
- **portfolio_DD_est = 1.88%**
- computed from 1/13 magics (12 UNKNOWN excluded from the sum, not zeroed) -- treat as a PARTIAL number, not full coverage

## Account 159503454 -- 08. Blazing Arrow (REAL_CENT)

- magics (ACTIVE+PENDING_ATTACH): **4** | known DD95: **4** | UNKNOWN: **0**
- budget: **not assigned** (REAL_CENT: computed/reported only -- NO budget assigned, user decision needed)
- **portfolio_DD_est = 10.67%**
- computed from 4/4 magics (full coverage on this account)

## Account 69424711 -- Demo EA3 (DEMO)

- magics (ACTIVE+PENDING_ATTACH): **4** | known DD95: **0** | UNKNOWN: **4**
- UNKNOWN magics: 1, 2, 5888, 990
- budget: **25.0%** of equity (fixed project number (docs/JUDGE_DAY_RUNBOOK.md "Sizing" step 3))
- cannot compute -- 0/4 magics on this account have known DD95 (all UNKNOWN). portfolio_dd_est is NOT a portfolio risk number here, it is absent.

---

_Generated by `scripts/portfolio_risk_admission.py`. Advisory only -- never writes to any .set file, never modifies DEPLOYMENTS.csv, never auto-applies a lot change, never issues a verdict about an EA._
