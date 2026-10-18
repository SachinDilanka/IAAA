import argparse
import os
import re
import sys

from extract_landmarks import process_video

VIDEO_EXTENSIONS = (".mp4", ".mov", ".avi", ".mkv")


def sanitize_filename(name):
    cleaned = re.sub(r"[^a-zA-Z0-9_]", "_", name)
    return re.sub(r"_+", "_", cleaned).strip("_").lower()


def dataset_output_path(videos_dir, output_dir, video_path):
    relative_parent = os.path.relpath(os.path.dirname(video_path), videos_dir)
    stem = os.path.splitext(os.path.basename(video_path))[0]
    sample_name = sanitize_filename(stem)

    if relative_parent == ".":
        # Top-level recordings are individual alphabet classes.
        label_parts = ["letter", sample_name]
        sample_parts = [sample_name]
    else:
        parent_parts = [
            part for part in relative_parent.split(os.sep) if part not in ("", ".")
        ]
        normalized_parts = [sanitize_filename(part) for part in parent_parts]

        if normalized_parts[0] in ("month", "months"):
            normalized_parts[0] = "month"
            if len(normalized_parts) >= 2:
                label_parts = normalized_parts[:2]
                sample_parts = normalized_parts[2:] + [sample_name]
            else:
                # Also support videos stored directly under videos/months.
                month_name = re.sub(r"[_\s-]?\d+$", "", sample_name)
                label_parts = ["month", month_name]
                sample_parts = [sample_name]
        elif normalized_parts[0] in ("verb", "verbs"):
            normalized_parts[0] = "verb"
            if len(normalized_parts) >= 2:
                label_parts = normalized_parts[:2]
                sample_parts = normalized_parts[2:] + [sample_name]
            else:
                label_parts = ["verb", sample_name]
                sample_parts = [sample_name]
        else:
            label_parts = normalized_parts
            sample_parts = [sample_name]

    return os.path.join(output_dir, *label_parts, *sample_parts) + ".json"


def discover_videos(videos_dir, output_dir):
    videos = []
    for root, directories, filenames in os.walk(videos_dir):
        directories.sort()
        for filename in sorted(filenames):
            if filename.lower().endswith(VIDEO_EXTENSIONS):
                video_path = os.path.join(root, filename)
                output_path = dataset_output_path(videos_dir, output_dir, video_path)
                videos.append((video_path, output_path))

    output_paths = [output_path for _, output_path in videos]
    if len(output_paths) != len(set(output_paths)):
        raise ValueError("Multiple video files map to the same dataset output path.")
    return videos


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)

    parser = argparse.ArgumentParser(
        description="Extract labeled hand-landmark sequences from videos."
    )
    parser.add_argument(
        "--videos-dir",
        default=os.path.join(project_dir, "videos"),
        help="Root directory containing labeled video folders.",
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join(project_dir, "dataset", "landmarks"),
        help="Output root. Each video is written separately under its sign label.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List video-to-label output paths without extracting landmarks.",
    )
    args = parser.parse_args()

    videos_dir = os.path.abspath(args.videos_dir)
    output_dir = os.path.abspath(args.output_dir)
    if not os.path.isdir(videos_dir):
        parser.error(f"Video directory does not exist: {videos_dir}")

    videos = discover_videos(videos_dir, output_dir)
    if not videos:
        print(f"No supported videos found under '{videos_dir}'.", file=sys.stderr)
        return 1

    print(f"Found {len(videos)} video(s):")
    for video_path, output_path in videos:
        relative_video = os.path.relpath(video_path, videos_dir)
        relative_output = os.path.relpath(output_path, output_dir)
        print(f"{relative_video} -> {relative_output}")

    if args.dry_run:
        return 0

    processed_count = 0
    failed_count = 0
    for video_path, output_path in videos:
        try:
            frame_count = process_video(video_path, output_path)
            if frame_count == 0:
                failed_count += 1
                print(
                    f"Failed: no hand landmarks detected in '{video_path}'.",
                    file=sys.stderr,
                )
                continue
            processed_count += 1
        except (OSError, RuntimeError, ValueError) as error:
            failed_count += 1
            print(f"Failed to process '{video_path}': {error}", file=sys.stderr)

    print(
        f"Finished: {processed_count} video(s) extracted, "
        f"{failed_count} failed. Dataset output: '{output_dir}'."
    )
    return 1 if failed_count else 0


if __name__ == "__main__":
    sys.exit(main())
