# parquet-helpers
Bash scripts/aliases and `git {diff,show}` plugins for Parquet files.

<!-- toc -->
- [parquet2json helpers](#parquet2json)
- [git-diff-parquet.sh](#git-diff-parquet)
    - [Setup](#setup)
    - [Examples](#examples)
        - [Field dtype changed](#dtype-changed)
        - [Field values changed](#values-changed)
        - [File added](#file-added)
        - [Customizing output with `$DIFF_PQT_OPTS`](#customizing)
        - [Appending rows](#appending-rows)
<!-- /toc -->

## [parquet2json] helpers <a id="parquet2json"></a>
[parquet-2-json.sh] wraps [parquet2json], but can read from stdin when no positional argument is provided:

```bash
cat foo.parquet | parquet2json - rowcount  # ❌
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

Useful aliases (from [.pqt-rc]):
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

## [git-diff-parquet.sh] <a id="git-diff-parquet"></a>
Wraps [`parquet2json-all`] for use as a Git diff driver:

### Setup <a id="setup"></a>
```bash
# From a clone of this repo: ensure git-diff-parquet.sh is on your $PATH
echo "export PATH=$PATH:$PWD" >> ~/.bashrc && . ~/.bashrc

# Git configs
git config --global diff.parquet.command git-diff-parquet.sh
git config --global diff.parquet.textconv parquet2json-all

# Git attributes (map globs/extensions to commands above):
git config --global core.attributesfile ~/.gitattributes
echo "*.parquet diff=parquet" >> ~/.gitattributes

# Or, initialize just one repo:
git config diff.parquet.command git-diff-parquet.sh
git config diff.parquet.textconv parquet2json-all
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
test.parquet (3a84f68..27fb7a10)
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

#### Field values changed <a id="values-changed"></a>
[`34d2b1d`] changed the "Gender" field to a categorical string type:

<!-- `bmdff -stdiff -- git diff 34d2b1d^..34d2b1d -- test.parquet` -->
```bash
git diff '34d2b1d^..34d2b1d' -- test.parquet
```
```diff
test.parquet (27fb7a1..5ca97430)
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
35c35
<   "Gender": 0,
---
>   "Gender": "U",
53c53
<   "Gender": 0,
---
>   "Gender": "U",

```
Here we see diffs to the first two rows of data (in addition to the MD5, size, and schema).

#### File added <a id="file-added"></a>
[`c232deb`] came before the 2 above, and added [`test.parquet`]:
<!-- `bmdff -stdiff -EDIFF_PQT_OPTS=-s git diff 5a5b84e..c232deb` -->
```bash
DIFF_PQT_OPTS=-s git diff 5a5b84e..c232deb
```
```diff
test.parquet (000000..3a84f68, ..100644)
0a1,23
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
> {"Ride ID":"47D7696609CD77E4","Rideable Type":"classic_bike","Start Time":"2024-10-31T03:53:24.765","Stop Time":"2024-11-01T00:10:45.107","Start Station Name":"Cedar St & Myrtle Ave","Start Station ID":"4751.01","End Station Name":"Moffat St & Bushwick","End Station ID":"4357.01","Start Station Latitude":40.697842,"Start Station Longitude":-73.926241,"End Station Latitude":40.68458,"End Station Longitude":-73.90925,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}
> {"Ride ID":"ADE40852FD10329E","Rideable Type":"classic_bike","Start Time":"2024-10-31T05:18:29.219","Stop Time":"2024-11-01T01:03:53.219","Start Station Name":"9 Ave & W 39 St","Start Station ID":"6644.08","End Station Name":"11 Ave & W 59 St","End Station ID":"7059.01","Start Station Latitude":40.756403523272496,"Start Station Longitude":-73.99410143494606,"End Station Latitude":40.77149671054441,"End Station Longitude":-73.99046033620834,"Gender":0,"User Type":"Customer","Start Region":"NYC","End Region":"NYC"}

```

#### Customizing output with `$DIFF_PQT_OPTS` <a id="customizing"></a>
`$DIFF_PQT_OPTS` can customize output formatting:
<!-- `bmdf git-diff-parquet.sh` -->
```bash
git-diff-parquet.sh
# git-diff-parquet.sh:
#
#   # Invoked by `git diff`:
#   git-diff-parquet.sh <repo relpath> <old version tmpfile> <old hexsha> <old filemode> <new version tmpfile> <new hexsha> <new filemode>
#
#   # Invoked by e.g. `git diff --no-index --ext-diff`:
#   git-diff-parquet.sh <old version tmpfile> <new version tmpfile>
#
# Pass opts via the $DIFF_PQT_OPTS env var:
#
# - `-c`: `--color=always`
# - `-C`: `--color=never`
# - `-n`: number of rows to display (default: 2)
# - `-o`: offset (e.g. `-o100` skips the first 100 rows, -o-5 begins 5 rows from the end)
# - `-s`: compact output (a la `jq -c`, one row-object per line; default: one field per line)
# - `-v`: verbose/debug mode
#
# The "opts var" itself (default "DIFF_PQT_OPTS") can also be customized, by setting `$DIFF_PQT_OPTS_VAR`, e.g.:
#
#   export DIFF_PQT_OPTS_VAR=PQT  # This can be done once, e.g. in your .bashrc
#   PQT="-sn3" git diff           # Shorter var name can then be used to configure diffs (in this case: compact output, 3 rows)
```

#### Appending rows <a id="appending-rows"></a>
[`69e8ea3`] appends 5 rows to [`test.parquet`]; `-n0` (compare all rows) and `-o20` (skip first 20 rows) is a nice way to view this case:

<!-- `bmdff -stdiff -EDIFF_PQT_OPTS="-sn0 -o20" git diff 69e8ea3^..69e8ea3` -->
```bash
DIFF_PQT_OPTS=-sn0 -o20 git diff '69e8ea3^..69e8ea3'
```
```diff
test.parquet (5ca9743..c621f0e0)
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


`-o<offset>` can also be negative, printing the last `<offset>` rows of the file (though in this case it would make for a noisier diff, since the "before" side's last rows are expected to be different from the "after" side's).

[parquet-2-json.sh]: ./parquet-2-json.sh
[`parquet2json-all`]: parquet2json-all
[.pqt-rc]: ./.pqt-rc
[git-diff-parquet.sh]: ./git-diff-parquet.sh
[parquet2json]: https://github.com/jupiter/parquet2json/
[JSONL]: https://jsonlines.org/
[`63dcdba`]: https://github.com/ryan-williams/parquet-helpers/commit/63dcdba
[`c232deb`]: https://github.com/ryan-williams/parquet-helpers/commit/c232deb
[`34d2b1d`]: https://github.com/ryan-williams/parquet-helpers/commit/34d2b1d
[`69e8ea3`]: https://github.com/ryan-williams/parquet-helpers/commit/69e8ea3
[@test]: https://github.com/ryan-williams/parquet-helpers/tree/test
[`test.py`]: https://github.com/ryan-williams/parquet-helpers/tree/test/test.py
[`test.parquet`]: https://github.com/ryan-williams/parquet-helpers/tree/test/test.parquet
