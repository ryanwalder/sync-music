# Sync Music

Finds all FLAC/MP3 files in the input directory and converts them to MP3 (or
copies them if already MP3) to an output directory while preserving the file
structure and tags.

## Configuration

The script is configured using environmental variables:

| Variable       | Default        | Description                                                                              |
| -------------- | -------------- | ---------------------------------------------------------------------------------------- |
| `INPUT_DIR`    | `/input`       | Input directory                                                                          |
| `OUTPUT_DIR`   | `/ouput`       | Output directory                                                                         |
| `LAME_QUALITY` | `0`            | LAME [quality preset](https://trac.ffmpeg.org/wiki/Encode/MP3) used for conveerted files |
| `LOOP`         | `true`         | Whether continually run so if adding new files they get converted                        |
| `SLEEP_TIME`   | `900` (15mins) | Time to wait between LOOPs, no effect if LOOP =! true                                    |

## Usage

```
export INPUT_DIR="/path/to/input/files"
export OUTPUT_DIR="/path/to/output/files"
./sync-music.sh
```

## Docker Compose

```yaml
services:
  sync-music:
    image: ghcr.io/ryanwalder/sync-music:latest
    user: "1000"
    environment:
    volumes:
      - /path/to/input/files:/input
      - /path/to/output/files:/output
    restart: on-failure:5
```
