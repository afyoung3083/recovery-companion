from app.journal import (
    filter_entries_by_tag,
    format_entries,
    search_entries,
)


def sample_entries():
    return [
        {
            "id": 1,
            "created_at": "2026-08-01T08:00:00",
            "text": "Called my sponsor and felt relieved.",
            "tags": ["sponsor", "connection"],
        },
        {
            "id": 2,
            "created_at": "2026-08-02T08:00:00",
            "text": "Grateful for another sober day.",
            "tags": ["gratitude"],
        },
        {
            "id": 3,
            "created_at": "2026-08-03T08:00:00",
            "text": "Worked on Step One.",
            "tags": [],
        },
    ]


def test_search_entries_by_text():
    matches = search_entries(
        entries=sample_entries(),
        query="sponsor",
    )

    assert len(matches) == 1
    assert matches[0]["id"] == 1


def test_search_entries_by_tag():
    matches = search_entries(
        entries=sample_entries(),
        query="gratitude",
    )

    assert len(matches) == 1
    assert matches[0]["id"] == 2


def test_filter_entries_by_exact_tag():
    matches = filter_entries_by_tag(
        entries=sample_entries(),
        tag="connection",
    )

    assert len(matches) == 1
    assert matches[0]["id"] == 1


def test_format_entries_handles_missing_tags():
    entries = [
        {
            "id": 1,
            "created_at": "2026-08-01T08:00:00",
            "text": "Older journal entry.",
        }
    ]

    output = format_entries(entries)

    assert "Tags: none" in output
    assert "Older journal entry." in output