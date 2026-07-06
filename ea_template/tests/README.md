# tests\ — Boss V2 module smoke-asserts (MERGE-06)

- รันทั้งชุด: `powershell -File ea_template\tests\run_tests.ps1` (ปิด MT5 GUI ก่อน) → ตาราง PASS/FAIL, exit 0 = เขียวหมด
- เพิ่ม test: วาง `<ชื่อ>.mq5` ที่ print `[PASS] <ชื่อ>: ...` หรือ `[FAIL] <ชื่อ>...` ใน OnInit/tick แรก · ต้องการ input พิเศษ → วาง `<ชื่อ>.set` ชื่อเดียวกัน
- pattern มาจาก EA_CORE `<Module>_v1_Test.mq5` — เอาแค่แนวคิด assert ไม่ลาก harness/dependency มา
- ตัวที่มี: `Persist_Test` (GV helper 8 asserts) · `AcctGate_Test` (acct-DD boundary 5 asserts) · `StackStep_Test` (pip/step math 4 asserts)
- cage ระดับ EA (เลข backtest) = `scripts\tpl_regression.ps1` — คนละชั้นกัน ใช้คู่กัน
