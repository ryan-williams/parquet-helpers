#!/usr/bin/env python
import json
from datetime import datetime
from json import JSONEncoder
from sys import stdin, stdout

from click import command, argument
from pyarrow import parquet as pq


class DateTimeEncoder(JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)


@command
@argument('path', required=False)
def main(path: str | None):
    """Print the metadata of a Parquet file."""
    if path:
        meta = pq.read_metadata(path)
    else:
        pf = pq.ParquetFile(stdin.buffer)
        meta = pf.metadata

    json.dump(meta.to_dict(), stdout, indent=2, cls=DateTimeEncoder)
    print()


if __name__ == '__main__':
    main()
