#!/usr/bin/env -S uv run -q --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["click", "pyarrow"]
# ///
import json
import signal
from datetime import datetime
from io import BytesIO
from json import JSONEncoder
from sys import stdin, stdout

from click import argument, command
from pyarrow import parquet as pq

# Restore default SIGPIPE handling (exit 141) instead of Python's BrokenPipeError (exit 1)
signal.signal(signal.SIGPIPE, signal.SIG_DFL)


class DateTimeEncoder(JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)


@command(context_settings=dict(help_option_names=['-h', '--help']))
@argument('path', required=False)
def main(path: str | None):
    """Print the metadata of a Parquet file."""
    if path:
        meta = pq.read_metadata(path)
    else:
        pf = pq.ParquetFile(BytesIO(stdin.buffer.read()))
        meta = pf.metadata

    json.dump(meta.to_dict(), stdout, indent=2, cls=DateTimeEncoder)
    print()


if __name__ == '__main__':
    main()
