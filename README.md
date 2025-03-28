# parquet-helpers
Bash scripts/aliases and `git {diff,show}` plugins for Parquet files.

<!-- toc -->
- [`parquet2json` helpers](#parquet2json)
    - [`.pqt-rc`: Bash aliases/functions](#pqt-rc)
    - [Examples](#alias-examples)
        - [`pqn`: row count](#pqn)
        - [`pqs`: schema](#pqs)
        - [`pqc` / `pql`: print rows (as JSONL)](#pql)
- [`git {diff,show}` plugins](#git)
    - [Setup](#diff-setup)
    - [Examples](#examples)
        - [Field dtype changed](#dtype-changed)
        - [Field values changed](#values-changed)
        - [File added](#file-added)
        - [Customizing output with `$PQT_TXT_OPTS`](#customizing)
        - [Appending rows](#appending-rows)
        - [File move](#file-move)
        - [File move with modifications](#file-move-mods)
- [Advanced Parquet diffing with `git-diff-x`](#git-diff-x)
    - [Comparing sorted schemas](#sorted-schemas)
    - [Comparing rows sorted by primary key](#sorted-primary-keys)
    - [Comparing sorted rows and columns](#sorted-rows-cols)
<!-- /toc -->

## [`parquet2json`] helpers <a id="parquet2json"></a>
[`parquet-2-json.sh`] wraps [`parquet2json`], but can read from stdin when no positional argument is provided:

```bash
cat foo.parquet | parquet2json - rowcount  # ❌ doesn't work, can't pipe, difficult to define partially-applied aliases
# thread 'main' panicked at 'called `Result::unwrap()` on an `Err` value: Os { code: 2, kind: NotFound, message: "No such file or directory" }', /Users/ryan/.cargo/registry/src/github.com-1ecc6299db9ec823/parquet2json-2.0.1/src/main.rs:144:54
# stack backtrace:
#    0: _rust_begin_unwind
#    1: core::panicking::panic_fmt
#    2: core::result::unwrap_failed
#    3: tokio::runtime::park::CachedParkThread::block_on
#    4: tokio::runtime::scheduler::multi_thread::MultiThread::block_on
#    5: tokio::runtime::runtime::Runtime::block_on
#    6: parquet2json::main
# note: Some details are omitted, run with `RUST_BACKTRACE=full` for a verbose backtrace.
cat foo.parquet | parquet-2-json.sh rowcount  # ✅ works
# 4
cat foo.parquet | pqc  # 🎉 even easier
# 4
```

### [`.pqt-rc`]: Bash aliases/functions <a id="pqt-rc"></a>
[`.pqt-rc`] can be `source`d from `~/.bashrc`, and provides useful aliases:
- `pqn` (`parquet-2-json.sh rowcount`): # rows
- `pqs` (`parquet-2-json.sh schema`): schema
- `pqc` (`parquet-2-json.sh cat`): print all rows (as [JSONL])
- `pql` (`parquet-2-json.sh cat -l <n>`): print `n` rows
- `pqa` ([`parquet2json-all`]): overview including:
  - MD5 sum
  - File size
  - Row count
  - First 10 rows
    - Configurable via `-n <n>`
    - `-c`: "compact" one row per line (by default, rows are piped through `jq`, which pretty-prints them, one field per line)

### Examples <a id="alias-examples"></a>
Inspecting [`test.parquet@63dcdba`]:

#### `pqn`: row count <a id="pqn"></a>
<!-- `bmdf git show 63dcdba:test.parquet | pqn` -->
```bash
git show 63dcdba:test.parquet | pqn
# 20
```

#### `pqs`: schema <a id="pqs"></a>
<!-- `bmdf git show 63dcdba:test.parquet | pqs` -->
```bash
git show 63dcdba:test.parquet | pqs
# message schema {
#   OPTIONAL BYTE_ARRAY Ride ID (STRING);
#   OPTIONAL BYTE_ARRAY Rideable Type (STRING);
#   OPTIONAL INT64 Start Time (TIMESTAMP(MICROS,false));
#   OPTIONAL INT64 Stop Time (TIMESTAMP(MICROS,false));
#   OPTIONAL BYTE_ARRAY Start Station Name (STRING);
#   OPTIONAL BYTE_ARRAY Start Station ID (STRING);
#   OPTIONAL BYTE_ARRAY End Station Name (STRING);
#   OPTIONAL BYTE_ARRAY End Station ID (STRING);
#   OPTIONAL DOUBLE Start Station Latitude;
#   OPTIONAL DOUBLE Start Station Longitude;
#   OPTIONAL DOUBLE End Station Latitude;
#   OPTIONAL DOUBLE End Station Longitude;
#   OPTIONAL INT32 Gender (INTEGER(8,true));
#   OPTIONAL BYTE_ARRAY User Type (STRING);
#   OPTIONAL BYTE_ARRAY Start Region (STRING);
#   OPTIONAL BYTE_ARRAY End Region (STRING);
# }
```

#### `pqc` / `pql`: print rows (as JSONL) <a id="pql"></a>
<!-- `bmdf git show 63dcdba:test.parquet | pql 3` -->
```bash
git show 63dcdba:test.parquet | pql 3
# {"Ride ID":"47D7696609CD77E4","Rideable Type":"classic_bike","Start Time":"2024-10-31T03:53:24.765","Stop Time":"2024-11-01T00:10:45.107","Start Station Name":"Cedar St & Myrtle Ave","Start Station ID":"4751.01","End Station Name":"Moffat St & Bushwick","End Station ID":"4357.01","Start Station Latitude":40.697842,"Start Station Longitude":-73.926241,"End Station Latitude":40.68458,"End Station Longitude":-73.90925,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
# {"Ride ID":"ADE40852FD10329E","Rideable Type":"classic_bike","Start Time":"2024-10-31T05:18:29.219","Stop Time":"2024-11-01T01:03:53.219","Start Station Name":"9 Ave & W 39 St","Start Station ID":"6644.08","End Station Name":"11 Ave & W 59 St","End Station ID":"7059.01","Start Station Latitude":40.756403523272496,"Start Station Longitude":-73.99410143494606,"End Station Latitude":40.77149671054441,"End Station Longitude":-73.99046033620834,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
# {"Ride ID":"9E5F3D963655B207","Rideable Type":"electric_bike","Start Time":"2024-10-31T13:19:29.118","Stop Time":"2024-11-01T05:15:23.984","Start Station Name":"Union Ave & E 169 St","Start Station ID":"8064.03","End Station Name":"Franklin Ave & E 169 St","End Station ID":"8118.02","Start Station Latitude":40.82995,"Start Station Longitude":-73.898802,"End Station Latitude":40.83171,"End Station Longitude":-73.90208,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
```

## `git {diff,show}` plugins <a id="git"></a>
[git-diff-parquet.sh] wraps [`parquet2json-all`] for use as a Git diff driver:

### Setup <a id="diff-setup"></a>
```bash
# From a clone of this repo: ensure git-diff-parquet.sh is on your $PATH
echo "export PATH=$PATH:$PWD" >> ~/.bashrc && . ~/.bashrc

# Git configs
git config --global diff.parquet.command git-diff-parquet.sh      # For git diff
git config --global diff.parquet.textconv "parquet2json-all -n2"  # For git show, include first and last 2 rows

# Git attributes (map globs/extensions to commands above):
git config --global core.attributesfile ~/.gitattributes
echo "*.parquet diff=parquet" >> ~/.gitattributes

# Or, initialize just one repo:
git config diff.parquet.command git-diff-parquet.sh      # For git diff
git config diff.parquet.textconv "parquet2json-all -n2"  # For git show, include 2 rows by default
echo "*.parquet diff=parquet" >> .gitattributes
```

### Examples <a id="examples"></a>
Using commits from the [@test] branch:

#### Field dtype changed <a id="dtype-changed"></a>
[`63dcdba`] converted a field from int64 to int8 ([`test.py`]):
<!-- `bmdff -stdiff git diff 63dcdba^..63dcdba` -->
```bash
git diff '63dcdba^..63dcdba'
```
```diff
test.parquet (3a84f68..27fb7a1)
1,2c1,2
< MD5: 7957c8cc859f03517dcdac05dcdfee8a
< 13274 bytes
---
> MD5: 7c079c1420c5edffc54955a54ca38795
> 13245 bytes
17c17
<   OPTIONAL INT64 Gender;
---
>   OPTIONAL INT32 Gender (INTEGER(8,true));

```

We see diffs in the MD5, file size, and schema. Better than nothing!

Similarly, with `git show`:
<!-- `bmdfff -stdiff git show 63dcdba` -->
<details><summary><code>git show 63dcdba</code></summary>

```diff
commit 63dcdbabf9c97833a11571f2bab65a487835a67d
Author: Ryan Williams <ryan@runsascoded.com>
Date:   Sun Dec 22 20:30:03 2024 -0500

    `test.parquet`: "make Gender" an int8
    
    ran `test.py`

diff --git test.parquet test.parquet
index 3a84f68..27fb7a1 100644
--- test.parquet
+++ test.parquet
@@ -1,5 +1,5 @@
-MD5: 7957c8cc859f03517dcdac05dcdfee8a
-13274 bytes
+MD5: 7c079c1420c5edffc54955a54ca38795
+13245 bytes
 20 rows
 message schema {
   OPTIONAL BYTE_ARRAY Ride ID (STRING);
@@ -14,7 +14,7 @@ message schema {
   OPTIONAL DOUBLE Start Station Longitude;
   OPTIONAL DOUBLE End Station Latitude;
   OPTIONAL DOUBLE End Station Longitude;
-  OPTIONAL INT64 Gender;
+  OPTIONAL INT32 Gender (INTEGER(8,true));
   OPTIONAL BYTE_ARRAY User Type (STRING);
   OPTIONAL BYTE_ARRAY Start Region (STRING);
   OPTIONAL BYTE_ARRAY End Region (STRING);
```
</details>


#### Field values changed <a id="values-changed"></a>
[`34d2b1d`] changed the "Gender" field to a categorical string type:

<!-- `bmdff -stdiff -- git diff 34d2b1d^..34d2b1d -- test.parquet` -->
```bash
git diff '34d2b1d^..34d2b1d' -- test.parquet
```
```diff
test.parquet (27fb7a1..5ca9743)
1,2c1,2
< MD5: 7c079c1420c5edffc54955a54ca38795
< 13245 bytes
---
> MD5: 0bf2c7f825a70660319e578201a04543
> 13343 bytes
17c17
<   OPTIONAL INT32 Gender (INTEGER(8,true));
---
>   OPTIONAL BYTE_ARRAY Gender (STRING);
36c36
<   "Gender": 0,
---
>   "Gender": "U",
54c54
<   "Gender": 0,
---
>   "Gender": "U",
73c73
<   "Gender": 0,
---
>   "Gender": "U",
91c91
<   "Gender": 0,
---
>   "Gender": "U",

```
Here we see diffs to the first and last two rows of data (in addition to the MD5, size, and schema).

Similarly, with `git show`:
<!-- `bmdfff -stdiff -- git show 34d2b1d` -->
<details><summary><code>git show 34d2b1d</code></summary>

```diff
commit 34d2b1ddc93f3a3cd04270268338c41309e41fa3
Author: Ryan Williams <ryan@runsascoded.com>
Date:   Sun Dec 22 14:08:07 2024 -0500

    `test.parquet`: make "Gender" a categorical

diff --git test.parquet test.parquet
index 27fb7a1..5ca9743 100644
--- test.parquet
+++ test.parquet
@@ -1,5 +1,5 @@
-MD5: 7c079c1420c5edffc54955a54ca38795
-13245 bytes
+MD5: 0bf2c7f825a70660319e578201a04543
+13343 bytes
 20 rows
 message schema {
   OPTIONAL BYTE_ARRAY Ride ID (STRING);
@@ -14,7 +14,7 @@ message schema {
   OPTIONAL DOUBLE Start Station Longitude;
   OPTIONAL DOUBLE End Station Latitude;
   OPTIONAL DOUBLE End Station Longitude;
-  OPTIONAL INT32 Gender (INTEGER(8,true));
+  OPTIONAL BYTE_ARRAY Gender (STRING);
   OPTIONAL BYTE_ARRAY User Type (STRING);
   OPTIONAL BYTE_ARRAY Start Region (STRING);
   OPTIONAL BYTE_ARRAY End Region (STRING);
@@ -33,7 +33,7 @@ First 2 rows:
   "Start Station Longitude": -73.926241,
   "End Station Latitude": 40.68458,
   "End Station Longitude": -73.90925,
-  "Gender": 0,
+  "Gender": "U",
   "User Type": "Customer",
   "Start Region": "NYC",
   "End Region": "NYC"
@@ -51,7 +51,7 @@ First 2 rows:
   "Start Station Longitude": -73.99410143494606,
   "End Station Latitude": 40.77149671054441,
   "End Station Longitude": -73.99046033620834,
-  "Gender": 0,
+  "Gender": "U",
   "User Type": "Customer",
   "Start Region": "NYC",
   "End Region": "NYC"
@@ -70,7 +70,7 @@ Last 2 rows:
   "Start Station Longitude": -73.9532423,
   "End Station Latitude": 40.84463,
   "End Station Longitude": -73.87988,
-  "Gender": 0,
+  "Gender": "U",
   "User Type": "Customer",
   "Start Region": "NYC",
   "End Region": "NYC"
@@ -88,7 +88,7 @@ Last 2 rows:
   "Start Station Longitude": -73.9532423,
   "End Station Latitude": 40.830529,
   "End Station Longitude": -73.894717,
-  "Gender": 0,
+  "Gender": "U",
   "User Type": "Customer",
   "Start Region": "NYC",
   "End Region": "NYC"
diff --git test.py test.py
index b18c424..7f0177a 100644
--- test.py
+++ test.py
@@ -3,5 +3,6 @@
 import pandas as pd
 
 df = pd.read_parquet("test.parquet")
-df = df.astype({'Gender': 'Int8'})
+gender_map = { 0: "U", 1: "M", 2: "F" }
+df["Gender"] = df["Gender"].map(gender_map).astype("category")
 df.to_parquet('test.parquet')
```
</details>

#### File added <a id="file-added"></a>
[`c232deb`] came before the 2 above, and added [`test.parquet`]:
<!-- `bmdff -stdiff -EPQT_TXT_OPTS=-s git diff c232deb^..c232deb` -->
```bash
PQT_TXT_OPTS=-s git diff 'c232deb^..c232deb'
```
```diff
test.parquet (000000..3a84f68, ..100644)
0a1,27
> MD5: 7957c8cc859f03517dcdac05dcdfee8a
> 13274 bytes
> 20 rows
> message schema {
>   OPTIONAL BYTE_ARRAY Ride ID (STRING);
>   OPTIONAL BYTE_ARRAY Rideable Type (STRING);
>   OPTIONAL INT64 Start Time (TIMESTAMP(MICROS,false));
>   OPTIONAL INT64 Stop Time (TIMESTAMP(MICROS,false));
>   OPTIONAL BYTE_ARRAY Start Station Name (STRING);
>   OPTIONAL BYTE_ARRAY Start Station ID (STRING);
>   OPTIONAL BYTE_ARRAY End Station Name (STRING);
>   OPTIONAL BYTE_ARRAY End Station ID (STRING);
>   OPTIONAL DOUBLE Start Station Latitude;
>   OPTIONAL DOUBLE Start Station Longitude;
>   OPTIONAL DOUBLE End Station Latitude;
>   OPTIONAL DOUBLE End Station Longitude;
>   OPTIONAL INT64 Gender;
>   OPTIONAL BYTE_ARRAY User Type (STRING);
>   OPTIONAL BYTE_ARRAY Start Region (STRING);
>   OPTIONAL BYTE_ARRAY End Region (STRING);
> }
> First 2 rows:
> {"Ride ID":"47D7696609CD77E4","Rideable Type":"classic_bike","Start Time":"2024-10-31T03:53:24.765","Stop Time":"2024-11-01T00:10:45.107","Start Station Name":"Cedar St & Myrtle Ave","Start Station ID":"4751.01","End Station Name":"Moffat St & Bushwick","End Station ID":"4357.01","Start Station Latitude":40.697842,"Start Station Longitude":-73.926241,"End Station Latitude":40.68458,"End Station Longitude":-73.90925,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> {"Ride ID":"ADE40852FD10329E","Rideable Type":"classic_bike","Start Time":"2024-10-31T05:18:29.219","Stop Time":"2024-11-01T01:03:53.219","Start Station Name":"9 Ave & W 39 St","Start Station ID":"6644.08","End Station Name":"11 Ave & W 59 St","End Station ID":"7059.01","Start Station Latitude":40.756403523272496,"Start Station Longitude":-73.99410143494606,"End Station Latitude":40.77149671054441,"End Station Longitude":-73.99046033620834,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> Last 2 rows:
> {"Ride ID":"6FC782109BE6324C","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:14:03.015","Stop Time":"2024-11-01T00:05:26.225","Start Station Name":"Adam Clayton Powell Blvd & W 115 St","Start Station ID":"7643.18","End Station Name":"Vyse Ave & E 181 St","End Station ID":"8306.03","Start Station Latitude":40.802535,"Start Station Longitude":-73.9532423,"End Station Latitude":40.84463,"End Station Longitude":-73.87988,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> {"Ride ID":"1D1C1A99053BD6B2","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:14:18.703","Stop Time":"2024-11-01T00:18:10.884","Start Station Name":"Adam Clayton Powell Blvd & W 115 St","Start Station ID":"7643.18","End Station Name":"Freeman St & Reverend James A Polite Ave","End Station ID":"8080.01","Start Station Latitude":40.802535,"Start Station Longitude":-73.9532423,"End Station Latitude":40.830529,"End Station Longitude":-73.894717,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}

```

`PQT_TXT_OPTS=-s` causes the previewed rows to be compact (one object per line).

Similarly, with `git show`:
<!-- `bmdfff -stdiff -EPQT_TXT_OPTS=-s git show c232deb` -->
<details><summary><code>PQT_TXT_OPTS=-s git show c232deb</code></summary>

```diff
commit c232deb412dae45046da37f9680a08122073a641
Author: Ryan Williams <ryan@runsascoded.com>
Date:   Sun Dec 22 13:51:08 2024 -0500

    initial `test.parquet`

diff --git test.parquet test.parquet
new file mode 100644
index 0000000..3a84f68
--- /dev/null
+++ test.parquet
@@ -0,0 +1,27 @@
+MD5: 7957c8cc859f03517dcdac05dcdfee8a
+13274 bytes
+20 rows
+message schema {
+  OPTIONAL BYTE_ARRAY Ride ID (STRING);
+  OPTIONAL BYTE_ARRAY Rideable Type (STRING);
+  OPTIONAL INT64 Start Time (TIMESTAMP(MICROS,false));
+  OPTIONAL INT64 Stop Time (TIMESTAMP(MICROS,false));
+  OPTIONAL BYTE_ARRAY Start Station Name (STRING);
+  OPTIONAL BYTE_ARRAY Start Station ID (STRING);
+  OPTIONAL BYTE_ARRAY End Station Name (STRING);
+  OPTIONAL BYTE_ARRAY End Station ID (STRING);
+  OPTIONAL DOUBLE Start Station Latitude;
+  OPTIONAL DOUBLE Start Station Longitude;
+  OPTIONAL DOUBLE End Station Latitude;
+  OPTIONAL DOUBLE End Station Longitude;
+  OPTIONAL INT64 Gender;
+  OPTIONAL BYTE_ARRAY User Type (STRING);
+  OPTIONAL BYTE_ARRAY Start Region (STRING);
+  OPTIONAL BYTE_ARRAY End Region (STRING);
+}
+First 2 rows:
+{"Ride ID":"47D7696609CD77E4","Rideable Type":"classic_bike","Start Time":"2024-10-31T03:53:24.765","Stop Time":"2024-11-01T00:10:45.107","Start Station Name":"Cedar St & Myrtle Ave","Start Station ID":"4751.01","End Station Name":"Moffat St & Bushwick","End Station ID":"4357.01","Start Station Latitude":40.697842,"Start Station Longitude":-73.926241,"End Station Latitude":40.68458,"End Station Longitude":-73.90925,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
+{"Ride ID":"ADE40852FD10329E","Rideable Type":"classic_bike","Start Time":"2024-10-31T05:18:29.219","Stop Time":"2024-11-01T01:03:53.219","Start Station Name":"9 Ave & W 39 St","Start Station ID":"6644.08","End Station Name":"11 Ave & W 59 St","End Station ID":"7059.01","Start Station Latitude":40.756403523272496,"Start Station Longitude":-73.99410143494606,"End Station Latitude":40.77149671054441,"End Station Longitude":-73.99046033620834,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
+Last 2 rows:
+{"Ride ID":"6FC782109BE6324C","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:14:03.015","Stop Time":"2024-11-01T00:05:26.225","Start Station Name":"Adam Clayton Powell Blvd & W 115 St","Start Station ID":"7643.18","End Station Name":"Vyse Ave & E 181 St","End Station ID":"8306.03","Start Station Latitude":40.802535,"Start Station Longitude":-73.9532423,"End Station Latitude":40.84463,"End Station Longitude":-73.87988,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
+{"Ride ID":"1D1C1A99053BD6B2","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:14:18.703","Stop Time":"2024-11-01T00:18:10.884","Start Station Name":"Adam Clayton Powell Blvd & W 115 St","Start Station ID":"7643.18","End Station Name":"Freeman St & Reverend James A Polite Ave","End Station ID":"8080.01","Start Station Latitude":40.802535,"Start Station Longitude":-73.9532423,"End Station Latitude":40.830529,"End Station Longitude":-73.894717,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
```
</details>

#### Customizing output with `$PQT_TXT_OPTS` <a id="customizing"></a>
`$PQT_TXT_OPTS` can customize output formatting:
<!-- `bmdf -- parquet2json-all -h` -->
```bash
parquet2json-all -h
# Usage: parquet2json-all [-n <head_rows=10>] [-o <offset_args>] [-s] <path>
#   -n: number of first and last rows to display; comma-separate to distinguish head/tail (e.g. default `-n3` is equivalent to `-n3,3`, which displays 3 rows from start and end). `,` prints all rows (useful in conjunction with an `-o` offset).
#   -o: skip this number of rows; negative ⇒ skip to last N rows
#   -s: compact mode (one object per line)
#
# Opts passed via $PQT_TXT_OPTS will override those passed via CLI (to allow for configuring `git show`):
#
# The "opts var" itself ("PQT_TXT_OPTS" by default) can also be customized, by setting `$PQT_TXT_OPTS_VAR`, e.g.:
#
#   export PQT_TXT_OPTS_VAR=PQT  # This can be done once, e.g. in your .bashrc
#   PQT="-sn3" git show          # Shorter var name can then be used to configure diffs rendered by `git show` (in this case: compact output, 3 rows)
```

#### Appending rows <a id="appending-rows"></a>
[`69e8ea3`] appends 5 rows to [`test.parquet`]; `-n,` (compare all rows) and `-o20` (skip first 20 rows) is a nice way to view this case:

<!-- `bmdff -stdiff -EPQT_TXT_OPTS="-sn, -o20" git diff 69e8ea3^..69e8ea3` -->
```bash
"PQT_TXT_OPTS=-sn, -o20" git diff '69e8ea3^..69e8ea3'
```
```diff
test.parquet (5ca9743..c621f0e)
1,3c1,3
< MD5: 0bf2c7f825a70660319e578201a04543
< 13343 bytes
< 20 rows
---
> MD5: 762aeca641059e0773382adab8d23fa5
> 13786 bytes
> 25 rows
21a22,26
> {"Ride ID":"A708CB5F5B9B0A0A","Rideable Type":"classic_bike","Start Time":"2024-10-31T18:24:32.978","Stop Time":"2024-11-01T01:00:53.858","Start Station Name":"4 Ave & E 12 St","Start Station ID":"5788.15","End Station Name":"8 Ave & W 31 St","End Station ID":"6450.05","Start Station Latitude":40.732647,"Start Station Longitude":-73.99011,"End Station Latitude":40.7505853470215,"End Station Longitude":-73.9946848154068,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> {"Ride ID":"AF7B0AA23EA2BEEA","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:30:18.577","Stop Time":"2024-11-01T00:19:32.156","Start Station Name":"Columbus Ave & W 95 St","Start Station ID":"7520.07","End Station Name":"Freeman St & Reverend James A Polite Ave","End Station ID":"8080.01","Start Station Latitude":40.7919557,"Start Station Longitude":-73.968087,"End Station Latitude":40.830529,"End Station Longitude":-73.894717,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> {"Ride ID":"7D719878E8164589","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:30:29.155","Stop Time":"2024-11-01T00:19:43.550","Start Station Name":"Columbus Ave & W 95 St","Start Station ID":"7520.07","End Station Name":"Freeman St & Reverend James A Polite Ave","End Station ID":"8080.01","Start Station Latitude":40.7919557,"Start Station Longitude":-73.968087,"End Station Latitude":40.830529,"End Station Longitude":-73.894717,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> {"Ride ID":"BE959FD40D19CB5B","Rideable Type":"classic_bike","Start Time":"2024-10-31T18:41:57.297","Stop Time":"2024-11-01T03:28:43.499","Start Station Name":"W 34 St & 11 Ave","Start Station ID":"6578.01","End Station Name":"Broadway & E 21 St","End Station ID":"6098.1","Start Station Latitude":40.75594159,"Start Station Longitude":-74.0021163,"End Station Latitude":40.739888408589955,"End Station Longitude":-73.98958593606949,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> {"Ride ID":"A1EB017D7CB1A09F","Rideable Type":"classic_bike","Start Time":"2024-10-31T18:46:42.479","Stop Time":"2024-11-01T17:28:56.677","Start Station Name":"W 34 St & 11 Ave","Start Station ID":"6578.01","End Station Name":"E 13 St & Ave A","End Station ID":"5779.09","Start Station Latitude":40.75594159,"Start Station Longitude":-74.0021163,"End Station Latitude":40.72966729392978,"End Station Longitude":-73.98067966103554,"Gender":"U","User Type":"Subscriber","Start Region":"NYC","End Region":"NYC"}

```

`-o<offset>` can also be negative, printing the last `<offset>` rows of the file. In the example above, that would make for a noisier diff (since the "before" side's last rows are expected to be different from the "after" side's); `-n, -o20` (print all rows, beginning from offset 20) works better.

Again with `git show`:
<!-- `bmdfff -stdiff -EPQT_TXT_OPTS="-sn, -o20" git show 69e8ea3` -->
<details><summary><code>"PQT_TXT_OPTS=-sn, -o20" git show 69e8ea3</code></summary>

```diff
commit 69e8ea39952a90a0313506dba649d789837936f2
Author: Ryan Williams <ryan@runsascoded.com>
Date:   Mon Dec 23 11:13:48 2024 -0500

    append 5 rows

diff --git test.parquet test.parquet
index 5ca9743..c621f0e 100644
--- test.parquet
+++ test.parquet
@@ -1,6 +1,6 @@
-MD5: 0bf2c7f825a70660319e578201a04543
-13343 bytes
-20 rows
+MD5: 762aeca641059e0773382adab8d23fa5
+13786 bytes
+25 rows
 message schema {
   OPTIONAL BYTE_ARRAY Ride ID (STRING);
   OPTIONAL BYTE_ARRAY Rideable Type (STRING);
@@ -19,3 +19,8 @@ message schema {
   OPTIONAL BYTE_ARRAY Start Region (STRING);
   OPTIONAL BYTE_ARRAY End Region (STRING);
 }
+{"Ride ID":"A708CB5F5B9B0A0A","Rideable Type":"classic_bike","Start Time":"2024-10-31T18:24:32.978","Stop Time":"2024-11-01T01:00:53.858","Start Station Name":"4 Ave & E 12 St","Start Station ID":"5788.15","End Station Name":"8 Ave & W 31 St","End Station ID":"6450.05","Start Station Latitude":40.732647,"Start Station Longitude":-73.99011,"End Station Latitude":40.7505853470215,"End Station Longitude":-73.9946848154068,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
+{"Ride ID":"AF7B0AA23EA2BEEA","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:30:18.577","Stop Time":"2024-11-01T00:19:32.156","Start Station Name":"Columbus Ave & W 95 St","Start Station ID":"7520.07","End Station Name":"Freeman St & Reverend James A Polite Ave","End Station ID":"8080.01","Start Station Latitude":40.7919557,"Start Station Longitude":-73.968087,"End Station Latitude":40.830529,"End Station Longitude":-73.894717,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
+{"Ride ID":"7D719878E8164589","Rideable Type":"electric_bike","Start Time":"2024-10-31T18:30:29.155","Stop Time":"2024-11-01T00:19:43.550","Start Station Name":"Columbus Ave & W 95 St","Start Station ID":"7520.07","End Station Name":"Freeman St & Reverend James A Polite Ave","End Station ID":"8080.01","Start Station Latitude":40.7919557,"Start Station Longitude":-73.968087,"End Station Latitude":40.830529,"End Station Longitude":-73.894717,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
+{"Ride ID":"BE959FD40D19CB5B","Rideable Type":"classic_bike","Start Time":"2024-10-31T18:41:57.297","Stop Time":"2024-11-01T03:28:43.499","Start Station Name":"W 34 St & 11 Ave","Start Station ID":"6578.01","End Station Name":"Broadway & E 21 St","End Station ID":"6098.1","Start Station Latitude":40.75594159,"Start Station Longitude":-74.0021163,"End Station Latitude":40.739888408589955,"End Station Longitude":-73.98958593606949,"Gender":"U","User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
+{"Ride ID":"A1EB017D7CB1A09F","Rideable Type":"classic_bike","Start Time":"2024-10-31T18:46:42.479","Stop Time":"2024-11-01T17:28:56.677","Start Station Name":"W 34 St & 11 Ave","Start Station ID":"6578.01","End Station Name":"E 13 St & Ave A","End Station ID":"5779.09","Start Station Latitude":40.75594159,"Start Station Longitude":-74.0021163,"End Station Latitude":40.72966729392978,"End Station Longitude":-73.98067966103554,"Gender":"U","User Type":"Subscriber","Start Region":"NYC","End Region":"NYC"}
```
</details>

#### File move <a id="file-move"></a>
[`07f2234`] moved test.parquet to `test2.parquet`:

<!-- `bmdf -stdiff git diff 07f2234^..07f2234` -->
```bash
git diff '07f2234^..07f2234'
# test.parquet..test2.parquet (14a2491..14a2491)
#
```

<!-- `bmdf -stdiff git show 07f2234` -->
```bash
git show 07f2234
# commit 07f2234ea762caff378b55e2a8829b2d495cdc4c
# Author: Ryan Williams <ryan@runsascoded.com>
# Date:   Wed Dec 25 13:08:52 2024 -0500
#
#     `mv test{,2}.parquet`
#
# diff --git test.parquet test2.parquet
# similarity index 100%
# rename from test.parquet
# rename to test2.parquet
```

#### File move with modifications <a id="file-move-mods"></a>
[`cb6d349`] moved `test2.parquet` back to `test.parquet`, and renamed "Stop Time" to "End Time":

<!-- `bmdff -stdiff git diff cb6d349^..cb6d349` -->
```bash
git diff 'cb6d349^..cb6d349'
```
```diff
test2.parquet..test.parquet (14a2491..6aff192)
1,2c1,2
< MD5: dcc622c03f1164196dcd4a9583ba2651
< 12736 bytes
---
> MD5: f94c17ff76a51cf1acb370d065da190d
> 12732 bytes
18c18
<   OPTIONAL INT64 Stop Time (TIMESTAMP(MICROS,false));
---
>   OPTIONAL INT64 End Time (TIMESTAMP(MICROS,false));
36c36
<   "Stop Time": "2024-11-01T03:01:00.430",
---
>   "End Time": "2024-11-01T03:01:00.430",
53c53
<   "Stop Time": "2024-11-01T00:36:34.579",
---
>   "End Time": "2024-11-01T00:36:34.579",
71c71
<   "Stop Time": "2024-11-01T18:05:01.028",
---
>   "End Time": "2024-11-01T18:05:01.028",
88c88
<   "Stop Time": "2024-11-01T02:38:14.161",
---
>   "End Time": "2024-11-01T02:38:14.161",

```

<!-- `bmdfff -stdiff git show cb6d349` -->
<details><summary><code>git show cb6d349</code></summary>

```diff
commit cb6d34907b430e6df598de650c5ab625479d6e18
Author: Ryan Williams <ryan@runsascoded.com>
Date:   Wed Dec 25 15:07:16 2024 -0500

    `mv test{2,}.parquet`, rename "Stop Time" to "End Time"

diff --git test2.parquet test.parquet
similarity index 59%
rename from test2.parquet
rename to test.parquet
index 14a2491..6aff192 100644
--- test2.parquet
+++ test.parquet
@@ -1,5 +1,5 @@
-MD5: dcc622c03f1164196dcd4a9583ba2651
-12736 bytes
+MD5: f94c17ff76a51cf1acb370d065da190d
+12732 bytes
 25 rows
 message schema {
   OPTIONAL BYTE_ARRAY End Region (STRING);
@@ -15,7 +15,7 @@ message schema {
   OPTIONAL DOUBLE Start Station Longitude;
   OPTIONAL BYTE_ARRAY Start Station Name (STRING);
   OPTIONAL INT64 Start Time (TIMESTAMP(MICROS,false));
-  OPTIONAL INT64 Stop Time (TIMESTAMP(MICROS,false));
+  OPTIONAL INT64 End Time (TIMESTAMP(MICROS,false));
   OPTIONAL BYTE_ARRAY User Type (STRING);
 }
 First 2 rows:
@@ -33,7 +33,7 @@ First 2 rows:
   "Start Station Longitude": -73.954295,
   "Start Station Name": "Amsterdam Ave & W 131 St",
   "Start Time": "2024-10-31T17:24:06.707",
-  "Stop Time": "2024-11-01T03:01:00.430",
+  "End Time": "2024-11-01T03:01:00.430",
   "User Type": "Customer"
 }
 {
@@ -50,7 +50,7 @@ First 2 rows:
   "Start Station Longitude": -73.918316,
   "Start Station Name": "Walton Ave & E 168 St",
   "Start Time": "2024-10-31T16:42:08.174",
-  "Stop Time": "2024-11-01T00:36:34.579",
+  "End Time": "2024-11-01T00:36:34.579",
   "User Type": "Subscriber"
 }
 Last 2 rows:
@@ -68,7 +68,7 @@ Last 2 rows:
   "Start Station Longitude": -73.973736,
   "Start Station Name": "Carlton Ave & Flushing Ave",
   "Start Time": "2024-10-31T17:11:11.877",
-  "Stop Time": "2024-11-01T18:05:01.028",
+  "End Time": "2024-11-01T18:05:01.028",
   "User Type": "Subscriber"
 }
 {
@@ -85,6 +85,6 @@ Last 2 rows:
   "Start Station Longitude": -73.98034,
   "Start Station Name": "St Marks Pl & 4 Ave",
   "Start Time": "2024-10-31T15:54:09.615",
-  "Stop Time": "2024-11-01T02:38:14.161",
+  "End Time": "2024-11-01T02:38:14.161",
   "User Type": "Customer"
 }
```
</details>


## Advanced Parquet diffing with [`git-diff-x`] <a id="git-diff-x"></a>
Scripts in this repo can be used with [`git-diff-x`] (from the [`dffs`] PyPI package) for even more powerful Parquet-file diffing.

For example, `git {diff,show}` above (even with `$PQT_TXT_OPTS`) aren't much help inferring what happened to `test.parquet` in [`9a9370c`]:

<!-- `bmdfff -stdiff -- git diff 9a9370c^..9a9370c -- test.parquet` -->
<details><summary><code>git diff '9a9370c^..9a9370c' -- test.parquet</code></summary>

```diff
test.parquet (c621f0e..14a2491)
1,2c1,2
< MD5: 762aeca641059e0773382adab8d23fa5
< 13786 bytes
---
> MD5: dcc622c03f1164196dcd4a9583ba2651
> 12736 bytes
4a5,9
>   OPTIONAL BYTE_ARRAY End Region (STRING);
>   OPTIONAL BYTE_ARRAY End Station ID (STRING);
>   OPTIONAL DOUBLE End Station Latitude;
>   OPTIONAL DOUBLE End Station Longitude;
>   OPTIONAL BYTE_ARRAY End Station Name (STRING);
7,9c12
<   OPTIONAL INT64 Start Time (TIMESTAMP(MICROS,false));
<   OPTIONAL INT64 Stop Time (TIMESTAMP(MICROS,false));
<   OPTIONAL BYTE_ARRAY Start Station Name (STRING);
---
>   OPTIONAL BYTE_ARRAY Start Region (STRING);
11,12d13
<   OPTIONAL BYTE_ARRAY End Station Name (STRING);
<   OPTIONAL BYTE_ARRAY End Station ID (STRING);
15,17c16,18
<   OPTIONAL DOUBLE End Station Latitude;
<   OPTIONAL DOUBLE End Station Longitude;
<   OPTIONAL BYTE_ARRAY Gender (STRING);
---
>   OPTIONAL BYTE_ARRAY Start Station Name (STRING);
>   OPTIONAL INT64 Start Time (TIMESTAMP(MICROS,false));
>   OPTIONAL INT64 Stop Time (TIMESTAMP(MICROS,false));
19,20d19
<   OPTIONAL BYTE_ARRAY Start Region (STRING);
<   OPTIONAL BYTE_ARRAY End Region (STRING);
24,37c23,29
<   "Ride ID": "47D7696609CD77E4",
<   "Rideable Type": "classic_bike",
<   "Start Time": "2024-10-31T03:53:24.765",
<   "Stop Time": "2024-11-01T00:10:45.107",
<   "Start Station Name": "Cedar St & Myrtle Ave",
<   "Start Station ID": "4751.01",
<   "End Station Name": "Moffat St & Bushwick",
<   "End Station ID": "4357.01",
<   "Start Station Latitude": 40.697842,
<   "Start Station Longitude": -73.926241,
<   "End Station Latitude": 40.68458,
<   "End Station Longitude": -73.90925,
<   "Gender": "U",
<   "User Type": "Customer",
---
>   "End Region": "NYC",
>   "End Station ID": "7338.02",
>   "End Station Latitude": 40.7839636,
>   "End Station Longitude": -73.9471673,
>   "End Station Name": "2 Ave & E 96 St",
>   "Ride ID": "03F9A0B025966750",
>   "Rideable Type": "electric_bike",
39c31,37
<   "End Region": "NYC"
---
>   "Start Station ID": "7842.16",
>   "Start Station Latitude": 40.816355,
>   "Start Station Longitude": -73.954295,
>   "Start Station Name": "Amsterdam Ave & W 131 St",
>   "Start Time": "2024-10-31T17:24:06.707",
>   "Stop Time": "2024-11-01T03:01:00.430",
>   "User Type": "Customer"
42,55c40,46
<   "Ride ID": "ADE40852FD10329E",
<   "Rideable Type": "classic_bike",
<   "Start Time": "2024-10-31T05:18:29.219",
<   "Stop Time": "2024-11-01T01:03:53.219",
<   "Start Station Name": "9 Ave & W 39 St",
<   "Start Station ID": "6644.08",
<   "End Station Name": "11 Ave & W 59 St",
<   "End Station ID": "7059.01",
<   "Start Station Latitude": 40.756403523272496,
<   "Start Station Longitude": -73.99410143494606,
<   "End Station Latitude": 40.77149671054441,
<   "End Station Longitude": -73.99046033620834,
<   "Gender": "U",
<   "User Type": "Customer",
---
>   "End Region": "NYC",
>   "End Station ID": "7979.17",
>   "End Station Latitude": 40.824811,
>   "End Station Longitude": -73.916407,
>   "End Station Name": "E 161 St & Park Ave",
>   "Ride ID": "08D7AFEB94079985",
>   "Rideable Type": "electric_bike",
57c48,54
<   "End Region": "NYC"
---
>   "Start Station ID": "8179.03",
>   "Start Station Latitude": 40.83649,
>   "Start Station Longitude": -73.918316,
>   "Start Station Name": "Walton Ave & E 168 St",
>   "Start Time": "2024-10-31T16:42:08.174",
>   "Stop Time": "2024-11-01T00:36:34.579",
>   "User Type": "Subscriber"
61c58,63
<   "Ride ID": "BE959FD40D19CB5B",
---
>   "End Region": "NYC",
>   "End Station ID": "4724.03",
>   "End Station Latitude": 40.69610226,
>   "End Station Longitude": -73.96751037,
>   "End Station Name": "Washington Ave & Park Ave",
>   "Ride ID": "BFCF7F13556941D9",
63,74d64
<   "Start Time": "2024-10-31T18:41:57.297",
<   "Stop Time": "2024-11-01T03:28:43.499",
<   "Start Station Name": "W 34 St & 11 Ave",
<   "Start Station ID": "6578.01",
<   "End Station Name": "Broadway & E 21 St",
<   "End Station ID": "6098.1",
<   "Start Station Latitude": 40.75594159,
<   "Start Station Longitude": -74.0021163,
<   "End Station Latitude": 40.739888408589955,
<   "End Station Longitude": -73.98958593606949,
<   "Gender": "U",
<   "User Type": "Customer",
76c66,72
<   "End Region": "NYC"
---
>   "Start Station ID": "4732.08",
>   "Start Station Latitude": 40.697787,
>   "Start Station Longitude": -73.973736,
>   "Start Station Name": "Carlton Ave & Flushing Ave",
>   "Start Time": "2024-10-31T17:11:11.877",
>   "Stop Time": "2024-11-01T18:05:01.028",
>   "User Type": "Subscriber"
79c75,80
<   "Ride ID": "A1EB017D7CB1A09F",
---
>   "End Region": "NYC",
>   "End Station ID": "4455.1",
>   "End Station Latitude": 40.68825516598005,
>   "End Station Longitude": -73.99545192718506,
>   "End Station Name": "Congress St & Clinton St",
>   "Ride ID": "EE3F608FF69C87B9",
81,92d81
<   "Start Time": "2024-10-31T18:46:42.479",
<   "Stop Time": "2024-11-01T17:28:56.677",
<   "Start Station Name": "W 34 St & 11 Ave",
<   "Start Station ID": "6578.01",
<   "End Station Name": "E 13 St & Ave A",
<   "End Station ID": "5779.09",
<   "Start Station Latitude": 40.75594159,
<   "Start Station Longitude": -74.0021163,
<   "End Station Latitude": 40.72966729392978,
<   "End Station Longitude": -73.98067966103554,
<   "Gender": "U",
<   "User Type": "Subscriber",
94c83,89
<   "End Region": "NYC"
---
>   "Start Station ID": "4249.01",
>   "Start Station Latitude": 40.68197,
>   "Start Station Longitude": -73.98034,
>   "Start Station Name": "St Marks Pl & 4 Ave",
>   "Start Time": "2024-10-31T15:54:09.615",
>   "Stop Time": "2024-11-01T02:38:14.161",
>   "User Type": "Customer"

```
</details>

The number of rows evidently stayed the same, but the schema and first 2 previewed rows seem pretty scrambled.

### Comparing sorted schemas <a id="sorted-schemas"></a>
`git-diff-x -R <commit> pqs sort` is useful for inspecting schema changes: it renders the "before" and "after" schemas as text, and sorts them:

<!-- `bmdff -stdiff git dxr 9a9370c pqs sort test.parquet` -->
```bash
git dxr 9a9370c pqs sort test.parquet
```
```diff
4d3
<   OPTIONAL BYTE_ARRAY Gender (STRING);
```

([`dxr`] is an alias for `diff-x -R`)

This immediately makes clear that:
1. The "Gender" field was dropped, and
2. The remaining fields were merely reordered.

### Comparing rows sorted by primary key <a id="sorted-primary-keys"></a>
The rows above have an (apparently unique) "Ride ID" column; we can use that to check whether rows were added/deleted or just rearranged:

<!-- `bmdf -stdiff git dxr 9a9370c pqc 'jq ".\"Ride ID\""' sort test.parquet` -->
```bash
git dxr 9a9370c pqc 'jq ".\"Ride ID\""' sort test.parquet
```

Empty diff here implies the rows were just reordered. Viewing the first 10 "Ride ID"s from the "after" version:

<!-- `bmdfff -- git show 9a9370c:test.parquet | pqh | jq -r '."Ride ID"'` -->
<details><summary><code>git show 9a9370c:test.parquet | pqh | jq -r ".\"Ride ID\""</code></summary>

```
03F9A0B025966750
08D7AFEB94079985
0C6AC59991FDA228
1D1C1A99053BD6B2
203BC6AB04336C9E
2357DBB7281E26E8
2ECB677DB071F76A
35AD489DAF340A5A
47D7696609CD77E4
4B6716B2215DEC6D
```
</details>

implies that [`9a9370c`] sorted rows by "Ride ID". Let's check that…

### Comparing sorted rows and columns <a id="sorted-rows-cols"></a>
Diffing again, but sorting the rows by "Ride ID", and only comparing the first row:

<!-- `bmdfff -stdiff git dxr 9a9370c pqc 'jq -s "sort_by(.[\"Ride ID\"])[0]"' test.parquet` -->
<details><summary><code>git dxr 9a9370c pqc 'jq -s "sort_by(.[\"Ride ID\"])[0]"' test.parquet</code></summary>

```diff
1a2,6
>   "End Region": "NYC",
>   "End Station ID": "7338.02",
>   "End Station Latitude": 40.7839636,
>   "End Station Longitude": -73.9471673,
>   "End Station Name": "2 Ave & E 96 St",
4,6c9
<   "Start Time": "2024-10-31T17:24:06.707",
<   "Stop Time": "2024-11-01T03:01:00.430",
<   "Start Station Name": "Amsterdam Ave & W 131 St",
---
>   "Start Region": "NYC",
8,9d10
<   "End Station Name": "2 Ave & E 96 St",
<   "End Station ID": "7338.02",
12,17c13,16
<   "End Station Latitude": 40.7839636,
<   "End Station Longitude": -73.9471673,
<   "Gender": "U",
<   "User Type": "Customer",
<   "Start Region": "NYC",
<   "End Region": "NYC"
---
>   "Start Station Name": "Amsterdam Ave & W 131 St",
>   "Start Time": "2024-10-31T17:24:06.707",
>   "Stop Time": "2024-11-01T03:01:00.430",
>   "User Type": "Customer"
```
</details>

It seems to be the same object, but with the keys reordered. Here we check by sorting the keys within the first row (after sorting by "Ride ID"), examining just the first 5 rows:

<!-- `bmdf -stdiff git dxr 9a9370c pqc 'jq -s "sort_by(.[\"Ride ID\"])[:5][] | to_entries | sort_by(.key) | from_entries"' test.parquet` -->
```bash
git dxr 9a9370c pqc 'jq -s "sort_by(.[\"Ride ID\"])[:5][] | to_entries | sort_by(.key) | from_entries"' test.parquet
# 7d6
# <   "Gender": "U",
# 25d23
# <   "Gender": "U",
# 43d40
# <   "Gender": "U",
# 61d57
# <   "Gender": "U",
# 79d74
# <   "Gender": "U",
```

Putting it all together, we can see that [`9a9370c`] changed `test.parquet` by:
- Dropping the "Gender" column
- Sorting the rows by "Ride ID"
- Sorting the columns in the schema / within each row.

It's a contrived example, but based on real comparisons I did on Parquet files in [ctbk.dev]. See also [this similar example][ctbk CSV example], from [dvc-utils], dealing with gzipped CSVs of the same Citi Bike data.

[`parquet-2-json.sh`]: ./parquet-2-json.sh
[`parquet2json-all`]: parquet2json-all
[git-diff-parquet.sh]: ./git-diff-parquet.sh
[`.pqt-rc`]: ./.pqt-rc
[`parquet2json`]: https://github.com/jupiter/parquet2json/
[JSONL]: https://jsonlines.org/

[`63dcdba`]: https://github.com/ryan-williams/parquet-helpers/commit/63dcdba
[`test.parquet@63dcdba`]: https://github.com/ryan-williams/parquet-helpers/commit/63dcdba/test.parquet
[`c232deb`]: https://github.com/ryan-williams/parquet-helpers/commit/c232deb
[`34d2b1d`]: https://github.com/ryan-williams/parquet-helpers/commit/34d2b1d
[`69e8ea3`]: https://github.com/ryan-williams/parquet-helpers/commit/69e8ea3
[`9a9370c`]: https://github.com/ryan-williams/parquet-helpers/commit/9a9370c
[`07f2234`]: https://github.com/ryan-williams/parquet-helpers/commit/07f2234
[`cb6d349`]: https://github.com/ryan-williams/parquet-helpers/commit/cb6d349
[@test]: https://github.com/ryan-williams/parquet-helpers/tree/test
[`test.py`]: https://github.com/ryan-williams/parquet-helpers/tree/test/test.py
[`test.parquet`]: https://github.com/ryan-williams/parquet-helpers/tree/test/test.parquet

[`dffs`]: https://pypi.org/project/dffs/
[`git-diff-x`]: https://github.com/runsascoded/dffs?tab=readme-ov-file#git-diff-x
[`dxr`]: https://github.com/ryan-williams/git-helpers/blob/5f27c2e4e88e3e14ede21483c998bdbe2cfccc6f/diff/.gitconfig#L69
[ctbk.dev]: https://github.com/neighbor-ryan/ctbk.dev
[ctbk CSV example]: https://github.com/runsascoded/dvc-utils?tab=readme-ov-file#csv-gz
[dvc-utils]: https://pypi.org/project/dvc-utils/
