from pathlib import Path
from unittest.mock import patch

import pytest

from app.data_ownership import (
    DELETE_CONFIRMATION,
    delete_all_recovery_data,
)


def test_delete_all_recovery_data_removes_data_and_backups(
    tmp_path: Path,
):
    data_dir = tmp_path / "data"
    backup_dir = tmp_path / "backups"

    data_dir.mkdir()
    backup_dir.mkdir()

    data_files = (
        data_dir / "profile.json",
        data_dir / "journal.json",
        data_dir / "step-work.json",
    )

    for path in data_files:
        path.write_text(
            '{"recovery": "data"}',
            encoding="utf-8",
        )

    backup_one = (
        backup_dir
        / "recovery-companion-backup-20260825-080000.json"
    )
    backup_two = (
        backup_dir
        / "recovery-companion-backup-20260825-081500.json"
    )

    backup_one.write_text("{}", encoding="utf-8")
    backup_two.write_text("{}", encoding="utf-8")

    unrelated_file = backup_dir / "keep-me.txt"
    unrelated_file.write_text(
        "not a Recovery Companion backup",
        encoding="utf-8",
    )

    with (
        patch(
            "app.data_ownership.DATA_FILES",
            data_files,
        ),
        patch(
            "app.data_ownership.BACKUP_DIR",
            backup_dir,
        ),
    ):
        result = delete_all_recovery_data(
            DELETE_CONFIRMATION
        )

    assert result == {
        "deleted": True,
        "deleted_data_files": 3,
        "deleted_backup_files": 2,
    }

    for path in data_files:
        assert not path.exists()

    assert not backup_one.exists()
    assert not backup_two.exists()
    assert unrelated_file.exists()


def test_delete_all_recovery_data_requires_exact_confirmation(
    tmp_path: Path,
):
    data_file = tmp_path / "profile.json"
    data_file.write_text(
        '{"sobriety_date": "2025-08-12"}',
        encoding="utf-8",
    )

    with patch(
        "app.data_ownership.DATA_FILES",
        (data_file,),
    ):
        with pytest.raises(
            ValueError,
            match="Confirmation phrase does not match",
        ):
            delete_all_recovery_data(
                "delete my recovery data"
            )

    assert data_file.exists()
