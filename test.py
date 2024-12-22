#!/usr/bin/env bash

import pandas as pd

df = pd.read_parquet("test.parquet")
gender_map = { 0: "U", 1: "M", 2: "F" }
df["Gender"] = df["Gender"].map(gender_map).astype("category")
df.to_parquet('test.parquet')
