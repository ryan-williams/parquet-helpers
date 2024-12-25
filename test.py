#!/usr/bin/env bash

import pandas as pd

df = pd.read_parquet("test.parquet")
df = df.drop(columns='Gender').sort_values('Ride ID')
df = df[sorted(df.columns)]
df.to_parquet('test.parquet', index=False)
