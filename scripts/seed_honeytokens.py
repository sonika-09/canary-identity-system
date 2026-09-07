#!/usr/bin/env python3
"""Plant canary AWS credentials into decoy locations.

Usage:
    python -m scripts.seed_honeytokens --access-key-id AKIA... --secret-access-key wJalrXU...
    CANARY_ACCESS_KEY_ID=AKIA... CANARY_SECRET_ACCESS_KEY=wJalrXU... python -m scripts.seed_honeytokens
"""

from __future__ import annotations

import argparse
import os
import stat
from pathlib import Path


def _write_restricted(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(stat.S_IRUSR | stat.S_IWUSR)


def plant_local_credentials(
    access_key_id: str, secret_access_key: str, profile: str = "canary"
) -> list[Path]:
    """Plant credentials in common locations an attacker would check."""
    planted: list[Path] = []

    # 1. ~/.aws/credentials
    aws_dir = Path.home() / ".aws"
    aws_dir.mkdir(exist_ok=True)
    creds_file = aws_dir / "credentials"

    entry = (
        f"[{profile}]\n"
        f"aws_access_key_id = {access_key_id}\n"
        f"aws_secret_access_key = {secret_access_key}\n"
    )

    if creds_file.exists():
        content = creds_file.read_text(encoding="utf-8")
        if f"[{profile}]" not in content:
            content += "\n" + entry
            creds_file.write_text(content, encoding="utf-8")
    else:
        creds_file.write_text(entry, encoding="utf-8")

    creds_file.chmod(stat.S_IRUSR | stat.S_IWUSR)
    planted.append(creds_file)

    # 2. Decoy environment file
    env_path = Path("/tmp/canary_aws_env")
    _write_restricted(
        env_path,
        f"AWS_ACCESS_KEY_ID={access_key_id}\nAWS_SECRET_ACCESS_KEY={secret_access_key}\n",
    )
    planted.append(env_path)

    # 3. Decoy JSON config
    json_path = Path("/tmp/canary_aws_config.json")
    _write_restricted(
        json_path,
        f'{{"access_key_id": "{access_key_id}", "secret_access_key": "{secret_access_key}"}}',
    )
    planted.append(json_path)

    return planted


def plant_ssm_parameters(
    access_key_id: str, secret_access_key: str, prefix: str = "/canary/credentials"
) -> None:
    """Optionally plant credentials in AWS SSM Parameter Store."""
    try:
        import boto3  # noqa: F811 - optional dependency
    except ImportError:
        return

    client = boto3.client("ssm")
    for name, value in [
        (f"{prefix}/access_key_id", access_key_id),
        (f"{prefix}/secret_access_key", secret_access_key),
    ]:
        try:
            client.put_parameter(
                Name=name,
                Value=value,
                Type="SecureString",
                Tags=[
                    {"Key": "Type", "Value": "CanaryIdentity"},
                    {"Key": "Environment", "Value": "Deception"},
                ],
            )
        except client.exceptions.ParameterAlreadyExists:
            client.put_parameter(Name=name, Value=value, Type="SecureString", Overwrite=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Plant canary AWS credentials into decoy locations"
    )
    parser.add_argument("--access-key-id", default=os.environ.get("CANARY_ACCESS_KEY_ID", ""))
    parser.add_argument("--secret-access-key", default=os.environ.get("CANARY_SECRET_ACCESS_KEY", ""))
    parser.add_argument("--profile", default="canary")
    parser.add_argument("--ssm-prefix", default=None)
    args = parser.parse_args(argv)

    if not args.access_key_id or not args.secret_access_key:
        parser.error(
            "Provide --access-key-id and --secret-access-key, "
            "or set CANARY_ACCESS_KEY_ID / CANARY_SECRET_ACCESS_KEY"
        )

    planted = plant_local_credentials(args.access_key_id, args.secret_access_key, args.profile)
    print(f"Planted {len(planted)} local decoy files:")
    for path in planted:
        print(f"  - {path}")

    if args.ssm_prefix:
        plant_ssm_parameters(args.access_key_id, args.secret_access_key, args.ssm_prefix)
        print(f"Planted SSM parameters under {args.ssm_prefix}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
