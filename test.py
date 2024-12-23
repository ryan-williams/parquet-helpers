#!/usr/bin/env bash

import pandas as pd

df = pd.read_parquet("test.parquet")
df = df.astype({'Gender': 'Int8'})
df.to_parquet('test.parquet')
