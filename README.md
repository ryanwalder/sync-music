# Sync Music

Script to convert/copy FLAC > MP3 files from an input dir to an output dir.

- If FLAC > Convert to MP3
- If MP3 > Copy
- Maintains dir structure
- Maintains tags
- Safety check to make sure a file isn't being written to before processing
  - Note: This adds processing time for each file as it performs the check on
    each file. set `STABILITY_CHECK_TIME` to disable this functionality.

## Configuration

The script is configured using environmental variables:

| Variable               | Default  | Description                                                                              |
| ---------------------- | -------- | ---------------------------------------------------------------------------------------- |
| `INPUT_DIR`            | `/input` | Input directory                                                                          |
| `OUTPUT_DIR`           | `/ouput` | Output directory                                                                         |
| `LAME_QUALITY`         | `0`      | LAME [quality preset](https://trac.ffmpeg.org/wiki/Encode/MP3) used for conveerted files |
| `LOOP`                 | `true`   | Whether continually run so if adding new files they get converted                        |
| `SLEEP_TIME`           | `900`    | Time to wait between LOOPs, no effect if LOOP =! true                                    |
| `STABILITY_CHECK_TIME` | `5`      | Time to wait when checking if a files is being copied into the input dir                 |
| `STABILITY_MAX_WAIT`   | `300`    | Max time to wait for a file to be copied into the input dir`                             |

## Usage

### Local

```
export INPUT_DIR="/path/to/input/files"
export OUTPUT_DIR="/path/to/output/files"
./sync-music.sh
```

### Docker

When running via Docker you need to mount your input/output dirs via volumes.
The `PUID`/`GUID` must have access to read from the `input` dir and access to
write to the `output dir`.

```yaml
services:
  sync-music:
    image: ghcr.io/ryanwalder/sync-music:latest
    environment:
      PUID: 1000 # User id of output files
      PGID: 1000 # Group id of output files
      UMASK: 022
    volumes:
      - /path/to/input/files:/input:ro
      - /path/to/output/files:/output:rw
    restart: on-failure:5
```
