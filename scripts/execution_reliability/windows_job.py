"""Small stdlib-only Windows Job Object boundary for a suspended subprocess."""

import ctypes as C
from ctypes import wintypes as W
import time


class BasicLimits(C.Structure):
    _fields_ = [("process_time", C.c_int64), ("job_time", C.c_int64),
                ("flags", W.DWORD), ("min_ws", C.c_size_t),
                ("max_ws", C.c_size_t), ("active_limit", W.DWORD),
                ("affinity", C.c_size_t), ("priority", W.DWORD),
                ("scheduling", W.DWORD)]


class ExtendedLimits(C.Structure):
    _fields_ = [("basic", BasicLimits), ("io", C.c_uint64 * 6),
                ("process_memory", C.c_size_t), ("job_memory", C.c_size_t),
                ("peak_process", C.c_size_t), ("peak_job", C.c_size_t)]


class Accounting(C.Structure):
    _fields_ = [("times", C.c_int64 * 4), ("faults", W.DWORD),
                ("total", W.DWORD), ("active", W.DWORD),
                ("terminated", W.DWORD)]


class ThreadEntry(C.Structure):
    _fields_ = [("size", W.DWORD), ("usage", W.DWORD), ("tid", W.DWORD),
                ("pid", W.DWORD), ("base", W.LONG), ("delta", W.LONG),
                ("flags", W.DWORD)]


class Job:
    def __init__(self):
        self.api = C.WinDLL("kernel32", use_last_error=True)
        signatures = {
            "CreateJobObjectW": ([W.LPVOID, W.LPCWSTR], W.HANDLE),
            "SetInformationJobObject": ([W.HANDLE, C.c_int, W.LPVOID, W.DWORD], W.BOOL),
            "QueryInformationJobObject": ([W.HANDLE, C.c_int, W.LPVOID, W.DWORD, W.LPVOID], W.BOOL),
            "AssignProcessToJobObject": ([W.HANDLE, W.HANDLE], W.BOOL),
            "TerminateJobObject": ([W.HANDLE, W.UINT], W.BOOL),
            "OpenThread": ([W.DWORD, W.BOOL, W.DWORD], W.HANDLE),
            "CreateToolhelp32Snapshot": ([W.DWORD, W.DWORD], W.HANDLE),
            "Thread32First": ([W.HANDLE, C.POINTER(ThreadEntry)], W.BOOL),
            "Thread32Next": ([W.HANDLE, C.POINTER(ThreadEntry)], W.BOOL),
            "ResumeThread": ([W.HANDLE], W.DWORD),
            "CloseHandle": ([W.HANDLE], W.BOOL),
        }
        for name, (args, result) in signatures.items():
            fn = getattr(self.api, name)
            fn.argtypes, fn.restype = args, result
        self.handle = self.api.CreateJobObjectW(None, None)
        self._check(self.handle)
        limits = ExtendedLimits()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; no breakaway
        try:
            self._check(self.api.SetInformationJobObject(
                self.handle, 9, C.byref(limits), C.sizeof(limits)))
        except BaseException:
            self.close()
            raise

    @staticmethod
    def _check(value):
        if not value:
            raise C.WinError(C.get_last_error())
        return value

    def assign_and_resume(self, process):
        # Child is CREATE_SUSPENDED: no target code can run before assignment.
        # CPython's Windows Popen retains this handle until disposal. Using it
        # avoids reopening a numeric PID that could otherwise be reused.
        self._check(self.api.AssignProcessToJobObject(self.handle, int(process._handle)))
        pid = process.pid
        snapshot = self.api.CreateToolhelp32Snapshot(4, 0)  # TH32CS_SNAPTHREAD
        if snapshot == C.c_void_p(-1).value:
            raise C.WinError(C.get_last_error())
        try:
            entry = ThreadEntry()
            entry.size = C.sizeof(entry)
            more = self.api.Thread32First(snapshot, C.byref(entry))
            while more:
                if entry.pid == pid:
                    thread = self._check(self.api.OpenThread(2, False, entry.tid))
                    try:
                        if self.api.ResumeThread(thread) == 0xFFFFFFFF:
                            raise C.WinError(C.get_last_error())
                        return
                    finally:
                        self.api.CloseHandle(thread)
                more = self.api.Thread32Next(snapshot, C.byref(entry))
            raise OSError("suspended child thread not found")
        finally:
            self.api.CloseHandle(snapshot)

    def terminate_and_wait(self, seconds=5):
        self._check(self.api.TerminateJobObject(self.handle, 0xC000013A))
        deadline = time.monotonic() + seconds
        while True:
            info = Accounting()
            self._check(self.api.QueryInformationJobObject(
                self.handle, 1, C.byref(info), C.sizeof(info), None))
            if info.active == 0:
                return True
            if time.monotonic() >= deadline:
                return False
            time.sleep(0.02)

    def close(self):
        if self.handle:
            self.api.CloseHandle(self.handle)
            self.handle = None
