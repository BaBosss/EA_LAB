"""Create-once durable evidence. Never overwrites an existing run."""
import os

from preflight import canonical, identity, inventory, relative_path, require, sha256, validate


def write_once(path, raw):
    with path.open("xb") as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
        created = os.fstat(stream.fileno())
        require(created.st_ino != 0 and created.st_nlink == 1, "CREATED_FILE_IDENTITY")
        return {"device": created.st_dev, "inode": created.st_ino}


class Artifacts:
    """Creation identities plus sealed bytes, pinned until receipt completion.

    Creation and read-only pinning cannot overlap Windows write handles. Bind
    fstat on the creator handle, then compare that identity and bytes on pinning:
    substitution in the close/open gap refuses, including same-byte replacement.
    """
    def __init__(self, root, pins):
        self.root = root
        self.pins = pins
        self.root_identity = identity(root)
        pins.root(str(root), self.root_identity)
        self.expected = {}
        self.failed = False

    def add(self, name, raw):
        require(len(relative_path(name)) == 1 and name not in self.expected, "ARTIFACT_NAME")
        self.failed = True  # Incomplete/failed creation can never earn completion.
        created = write_once(self.root / name, raw)
        self.expected[name] = (created, raw)
        require(self.pins.read(self.root, name, len(raw), created) == raw, "ARTIFACT_BYTES")
        self.failed = False

    def verify(self):
        require(not self.failed, "ARTIFACT_CREATION_INCOMPLETE")
        require(identity(self.root) == self.root_identity, "ARTIFACT_ROOT_IDENTITY")
        require(inventory(self.root, include_directories=True) == sorted(self.expected), "ARTIFACT_INVENTORY")
        for name, (created, raw) in self.expected.items():
            require(self.pins.read(self.root, name, len(raw), created) == raw, "ARTIFACT_BYTES")


def reserve_run(control, run_id):
    base = control / "evidence"
    require(base.is_dir(), "OUTPUT_PARENT_MISSING")
    run = base / ("review-transport-v2-" + run_id)
    run.mkdir()  # EXISTING is an error, including incomplete previous attempts.
    return run


def raw_output_inventory(raw_outputs):
    return [{"path": "model_output_%04d.bin" % index, "size": len(raw),
             "sha256": sha256(raw)} for index, raw in enumerate(raw_outputs)]


def persist(run, receipt, read_log, raw_outputs, result, schema, pins, bundle=None):
    validate(receipt, schema)
    outputs = raw_output_inventory(raw_outputs)
    raw_model = canonical(outputs)
    require(outputs == receipt["raw_model_outputs"], "RECEIPT_MODEL_INVENTORY")
    require(sha256(read_log) == receipt["read_log_sha256"], "RECEIPT_READ_LOG_HASH")
    require(sha256(raw_model) == receipt["raw_model_output_sha256"], "RECEIPT_MODEL_HASH")
    result_bytes = canonical(result)
    require(sha256(result_bytes) == receipt["validated_result_sha256"], "RECEIPT_RESULT_HASH")
    artifacts = Artifacts(run, pins)
    artifacts.add("read_log.json", read_log)
    # Ordered raw binary sizes/hashes: no lossy text decoding in the binding.
    for index, raw in enumerate(raw_outputs):
        artifacts.add("model_output_%04d.bin" % index, raw)
    artifacts.add("raw_model_outputs.json", raw_model)
    artifacts.add("validated_result.json", result_bytes)
    # Final on-disk verification, while every created file remains pinned.
    receipt_bytes = canonical(receipt)
    if bundle is not None:
        bundle.verify()
    artifacts.verify()
    artifacts.add("receipt.json", receipt_bytes)  # completion marker LAST
    return run / "receipt.json"
