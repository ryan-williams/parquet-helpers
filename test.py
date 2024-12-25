#!/usr/bin/env bash

import pandas as pd

df = pd.read_parquet("test2.parquet")
df = df.rename(columns={'Stop Time': 'End Time'})
df.to_parquet('test.parquet', index=False)
