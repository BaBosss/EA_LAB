@echo off
set ANTHROPIC_BASE_URL=https://gateway.9arm.co

claude --bare ^
  --settings "%USERPROFILE%\.claude-9arm.json" ^
  --model qwen3.6-35b-a3b ^
  --allowedTools "Bash,Read,Edit,Write,Glob,Grep" ^
  -p "อ่าน D:\EA_LAB\QWEN_RUN_LOG.md ดูว่าทำถึง TASK ไหนแล้ว จากนั้นอ่าน D:\EA_LAB\QWEN_RUN_PLAN.md แล้วทำ task ที่ยังไม่เสร็จต่อ วนจนถึง 2026-07-02 ทุกผล append ลง D:\EA_LAB\QWEN_RUN_LOG.md ตามรูปแบบในแผน ห้ามตัดสิน/แก้ canonical docs/commit git error ให้ log แล้วข้าม" ^
  >> "D:\EA_LAB\QWEN_RUN_LOG.md" 2>&1

echo.
echo Qwen finished. Check D:\EA_LAB\QWEN_RUN_LOG.md
pause