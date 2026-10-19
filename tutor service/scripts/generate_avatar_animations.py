import argparse
import json
import math
import struct
from pathlib import Path


FINGER_PATHS = {
    "thumb": (0, 1, 2, 3, 4),
    "index": (0, 5, 6, 7, 8),
    "middle": (0, 9, 10, 11, 12),
    "ring": (0, 13, 14, 15, 16),
    "pinky": (0, 17, 18, 19, 20),
}
FINGER_NODES = {
    "Left": {
        "thumb": ("LeftHandThumb1_018", "LeftHandThumb2_019", "LeftHandThumb3_020"),
        "index": ("LeftHandIndex1_022", "LeftHandIndex2_023", "LeftHandIndex3_024"),
        "middle": ("LeftHandMiddle1_026", "LeftHandMiddle2_027", "LeftHandMiddle3_028"),
        "ring": ("LeftHandRing1_030", "LeftHandRing2_031", "LeftHandRing3_032"),
        "pinky": ("LeftHandPinky1_034", "LeftHandPinky2_035", "LeftHandPinky3_036"),
    },
    "Right": {
        "thumb": ("RightHandThumb1_044", "RightHandThumb2_045", "RightHandThumb3_046"),
        "index": ("RightHandIndex1_048", "RightHandIndex2_049", "RightHandIndex3_050"),
        "middle": ("RightHandMiddle1_052", "RightHandMiddle2_00", "RightHandMiddle3_053"),
        "ring": ("RightHandRing1_055", "RightHandRing2_056", "RightHandRing3_057"),
        "pinky": ("RightHandPinky1_059", "RightHandPinky2_060", "RightHandPinky3_061"),
    },
}
SPEEDS = {0.5: "0_5x", 0.75: "0_75x", 1.0: "1x"}
FRAME_INTERVAL_SECONDS = 0.04


def _read_glb(path):
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        raise ValueError(f"Not a valid GLB file: {path}")
    version, total_length = struct.unpack_from("<II", data, 4)
    if version != 2 or total_length != len(data):
        raise ValueError(f"Unsupported or truncated GLB file: {path}")

    offset = 12
    json_chunk = None
    binary_chunk = None
    while offset < len(data):
        length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset : offset + length]
        offset += length
        if chunk_type == 0x4E4F534A:
            json_chunk = json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\0"))
        elif chunk_type == 0x004E4942:
            binary_chunk = bytearray(chunk)

    if json_chunk is None or binary_chunk is None:
        raise ValueError("GLB must contain JSON and binary chunks.")
    return json_chunk, binary_chunk


def _quaternion_multiply(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ]


def _bend_angle(previous, joint, following):
    incoming = tuple(joint[i] - previous[i] for i in range(3))
    outgoing = tuple(following[i] - joint[i] for i in range(3))
    incoming_length = math.sqrt(sum(value * value for value in incoming))
    outgoing_length = math.sqrt(sum(value * value for value in outgoing))
    if incoming_length == 0 or outgoing_length == 0:
        return 0.0
    cosine = sum(incoming[i] * outgoing[i] for i in range(3))
    cosine /= incoming_length * outgoing_length
    return math.acos(max(-1.0, min(1.0, cosine)))


def _hand_angles(landmarks):
    points = {}
    for landmark in landmarks:
        landmark_id = landmark.get("id")
        if isinstance(landmark_id, int) and landmark_id not in points:
            points[landmark_id] = (
                float(landmark["x"]),
                float(landmark["y"]),
                float(landmark["z"]),
            )
    if len(points) != 21 or any(index not in points for index in range(21)):
        return None
    return {
        finger: [
            _bend_angle(points[path[joint - 1]], points[path[joint]], points[path[joint + 1]])
            for joint in range(1, 4)
        ]
        for finger, path in FINGER_PATHS.items()
    }


def _load_sign_frames(path):
    raw_frames = json.loads(path.read_text(encoding="utf-8"))
    frames = []
    for raw_frame in raw_frames:
        hands = []
        for hand_index, raw_hand in enumerate(raw_frame.get("hands", [])):
            angles = _hand_angles(raw_hand.get("landmarks", []))
            if angles is None:
                continue
            hand_label = str(raw_hand.get("handLabel", "")).lower()
            side = "Left" if hand_label == "left" else "Right" if hand_label == "right" else (
                "Right" if hand_index == 0 else "Left"
            )
            hands.append((side, angles))
        if hands:
            frames.append(hands)
    if not frames:
        raise ValueError(f"No complete hand frames found in {path}")
    return frames


def _rest_rotations(gltf):
    nodes_by_name = {
        node["name"]: index
        for index, node in enumerate(gltf.get("nodes", []))
        if node.get("name")
    }
    rest = {}
    for side in FINGER_NODES:
        for finger_nodes in FINGER_NODES[side].values():
            for node_name in finger_nodes:
                if node_name not in nodes_by_name:
                    raise ValueError(f"Avatar rig is missing the joint {node_name}")
                node = gltf["nodes"][nodes_by_name[node_name]]
                rest[node_name] = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    return nodes_by_name, rest


def _frame_rotations(hands, rest):
    rotations = dict(rest)
    for side, fingers in hands:
        for finger, angles in fingers.items():
            for node_name, angle in zip(FINGER_NODES[side][finger], angles):
                bend = [math.sin(-angle / 2), 0.0, 0.0, math.cos(angle / 2)]
                rotations[node_name] = _quaternion_multiply(rest[node_name], bend)
    return rotations


def _append_accessor(gltf, binary, values, accessor_type, count, minimum=None, maximum=None):
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    binary.extend(struct.pack(f"<{len(values)}f", *values))
    view_index = len(gltf.setdefault("bufferViews", []))
    gltf["bufferViews"].append(
        {"buffer": 0, "byteOffset": offset, "byteLength": len(values) * 4}
    )
    accessor = {
        "bufferView": view_index,
        "componentType": 5126,
        "count": count,
        "type": accessor_type,
    }
    if minimum is not None:
        accessor["min"] = minimum
    if maximum is not None:
        accessor["max"] = maximum
    accessor_index = len(gltf.setdefault("accessors", []))
    gltf["accessors"].append(accessor)
    return accessor_index


def _add_animation(gltf, binary, nodes_by_name, rest, name, hands_per_frame, times):
    rotations_per_frame = [_frame_rotations(hands, rest) for hands in hands_per_frame]
    samplers = []
    channels = []
    time_values = [time for time in times]
    input_accessor = _append_accessor(
        gltf,
        binary,
        time_values,
        "SCALAR",
        len(time_values),
        [min(time_values)],
        [max(time_values)],
    )
    for side in FINGER_NODES:
        for finger_nodes in FINGER_NODES[side].values():
            for node_name in finger_nodes:
                values = [
                    component
                    for rotations in rotations_per_frame
                    for component in rotations[node_name]
                ]
                output_accessor = _append_accessor(
                    gltf, binary, values, "VEC4", len(rotations_per_frame)
                )
                sampler_index = len(samplers)
                samplers.append(
                    {
                        "input": input_accessor,
                        "output": output_accessor,
                        "interpolation": "LINEAR",
                    }
                )
                channels.append(
                    {
                        "sampler": sampler_index,
                        "target": {
                            "node": nodes_by_name[node_name],
                            "path": "rotation",
                        },
                    }
                )
    gltf.setdefault("animations", []).append(
        {"name": name, "samplers": samplers, "channels": channels}
    )


def _animation_name(path):
    category = path.parent.parent.name
    sign = path.parent.name
    if category not in ("letter", "month", "verb"):
        return None
    return f"{category}_{sign}"


def generate_animations(input_root, model_path, output_path):
    gltf, binary = _read_glb(model_path)
    nodes_by_name, rest = _rest_rotations(gltf)
    data_files = sorted(input_root.glob("*/*/*.json"))
    if not data_files:
        raise ValueError(f"No gesture landmark files found under {input_root}")

    count = 0
    for path in data_files:
        name = _animation_name(path)
        if name is None:
            continue
        frames = _load_sign_frames(path)
        if path.parent.parent.name == "letter":
            static_pose = frames[len(frames) // 2]
            _add_animation(
                gltf,
                binary,
                nodes_by_name,
                rest,
                name,
                [static_pose, static_pose],
                [0.0, 1.0],
            )
            count += 1
            continue

        for speed, speed_name in SPEEDS.items():
            times = [
                index * FRAME_INTERVAL_SECONDS / speed
                for index in range(len(frames))
            ]
            _add_animation(
                gltf,
                binary,
                nodes_by_name,
                rest,
                f"{name}_{speed_name}",
                frames,
                times,
            )
            count += 1

    gltf["buffers"][0]["byteLength"] = len(binary)
    json_chunk = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * ((-len(json_chunk)) % 4)
    binary.extend(b"\0" * ((-len(binary)) % 4))
    total_length = 12 + 8 + len(json_chunk) + 8 + len(binary)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("wb") as output:
        output.write(struct.pack("<4sII", b"glTF", 2, total_length))
        output.write(struct.pack("<II", len(json_chunk), 0x4E4F534A))
        output.write(json_chunk)
        output.write(struct.pack("<II", len(binary), 0x004E4942))
        output.write(binary)
    return count


def main():
    project_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Retarget captured hand landmarks into GLB animation clips."
    )
    parser.add_argument(
        "--input-root",
        type=Path,
        default=project_root / "dataset" / "landmarks",
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=project_root / "assets" / "models" / "avatar.glb",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=project_root / "assets" / "models" / "avatar_signs.glb",
    )
    args = parser.parse_args()
    animation_count = generate_animations(
        args.input_root, args.model, args.output
    )
    print(f"Generated {animation_count} sign animations: {args.output}")


if __name__ == "__main__":
    main()
