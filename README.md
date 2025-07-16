# Sync Music

Script to convert/copy FLAC/MP3 files from an input dir to an output dir.

Designed to be used in conjunction with [Syncthing](https://syncthing.net/)
to sync the output to my phone.

- If MP3 > Copy
- If FLAC > Convert to MP3
  - Uses [ffmpeg](https://ffmpeg.org/) with the
    [lame](https://lame.sourceforge.io/) encoder
  - Ability to set desired quality profile
- Maintains dir structure
- Maintains tags
- Only processes files if they do not exist in the output dir so it's as quick
  as possible
- Deletes files from output dir if they are removed from the input dir
- Safety check to make sure a file isn't being modified before processing
  - Handles files being written to and waits for them to complete
  - Handles files deleted after scanning but deleted before processing
  - Note: This adds processing time for each file as it performs the check on
    each file. set `STABILITY_CHECK_TIME` to disable this functionality.

## Configuration

The script is configured using environmental variables:

<!-- markdownlint-disable MD013 -->

| Variable               | Default  | Description                                                                              |
| ---------------------- | -------- | ---------------------------------------------------------------------------------------- |
| `INPUT_DIR`            | `/input` | Input directory                                                                          |
| `OUTPUT_DIR`           | `/ouput` | Output directory                                                                         |
| `LAME_QUALITY`         | `0`      | LAME [quality preset](https://trac.ffmpeg.org/wiki/Encode/MP3) used for conveerted files |
| `LOOP`                 | `true`   | Whether continually run so if adding new files they get converted                        |
| `SLEEP_TIME`           | `900`    | Time to wait between LOOPs, no effect if LOOP =! true                                    |
| `STABILITY_CHECK_TIME` | `2`      | Time to wait when checking if a files is being copied into the input dir                 |
| `STABILITY_MAX_WAIT`   | `300`    | Max time to wait for a file to be copied into the input dir                              |

<!-- markdownlint-enable -->

## Usage

### Local

```sh
export INPUT_DIR="/path/to/input/files"
export OUTPUT_DIR="/path/to/output/files"
./sync-music.sh
```

### Docker

When running via Docker you need to mount your input/output dirs via volumes.
The `PUID`/`GUID` must have access to read from the `input` dir and access to
write to the `output dir`.

Extra Environment Variables used by the container:

<!-- markdownlint-disable MD013 -->

| Variable | Default | Description                                                                                                    |
| -------- | ------- | -------------------------------------------------------------------------------------------------------------- |
| `PUID`   | `1000`  | UID to run the script as, must have read access to `INPUT_DIR`. Will be used for `OUTPUT_DIR` and output files |
| `PGID`   | `1000`  | GID to run the script as, must have read access to `INPUT_DIR`. Will be used for `OUTPUT_DIR` and output files |
| `UMASK`  | `0022`  | UMASK to use for output files/dirs                                                                             |

<!-- markdownlint-enable -->

#### Docker Command

<!-- markdownlint-disable MD013 -->

```sh
docker run \
  -e PUID="1000" \
  -e PGID="1000" \
  -e UMASK="0022" \
  -v /path/to/input/files:/input:ro \
  -v /path/to/output/files:/output:rw \
  ghcr.io/ryanwalder/sync-music:latest
```

<!-- markdownlint-enable -->

#### Docker Compose

```yaml
services:
  sync-music:
    image: ghcr.io/ryanwalder/sync-music:latest
    environment:
      PUID: "1000"
      PGID: "1000"
      UMASK: "0022"
    volumes:
      - /path/to/input/files:/input:ro
      - /path/to/output/files:/output:rw
    restart: on-failure:5
```
