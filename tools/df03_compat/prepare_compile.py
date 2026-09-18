"""Prepare only fresh temp compile inputs; no terminal/deployment operations."""
import json
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate as g

parent = g.PARENT.read_bytes()
generated, manifest = g.build(parent)
g.require((g.DEST / 'DF03_Generated.mqh').read_bytes() == generated, 'dependency drift')
repaired, changes = g.transform(parent, lifecycle=False)
g.verify(parent, repaired, changes, lifecycle=False)
stage = Path(tempfile.mkdtemp(prefix='df03-compile-'))
(stage / 'DF03_RepairedParent.mq5').write_bytes(repaired)
for rel in ('ea_template/compat/df03/DF03_Generated.mqh',
            'ea_template/core/entries/Entry_GridFibo.mqh',
            'ea_template/tests/GridFibo_AdapterCompile.mq5'):
    dest = stage / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes((g.ROOT / rel).read_bytes())
print(json.dumps({'stage': str(stage), 'repaired_parent_sha256': g.sha(repaired),
                  'generated_sha256': manifest['generated_sha256'],
                  'adapter_sha256': g.sha((stage / 'ea_template/core/entries/Entry_GridFibo.mqh').read_bytes()),
                  'probe_sha256': g.sha((stage / 'ea_template/tests/GridFibo_AdapterCompile.mq5').read_bytes())}))
