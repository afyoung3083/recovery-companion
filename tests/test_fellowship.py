from app.fellowship import (
    format_contacts,
    recommend_contacts,
)


def sample_contacts():
    return [
        {
            "id": 1,
            "handle": "SponsorBob",
            "contact_type": "sponsor",
            "contact_method": "text",
            "notes": "Primary sponsor",
            "active": True,
        },
        {
            "id": 2,
            "handle": "MikeDSR",
            "contact_type": "dsr",
            "contact_method": "call",
            "notes": "Daily check-in",
            "active": True,
        },
        {
            "id": 3,
            "handle": "FellowshipJoe",
            "contact_type": "fellowship",
            "contact_method": "text",
            "notes": "",
            "active": True,
        },
    ]


def test_recommend_contacts_priority():
    ranked = recommend_contacts(
        contacts=sample_contacts(),
        limit=3,
    )

    assert ranked[0]["handle"] == "SponsorBob"
    assert ranked[1]["handle"] == "MikeDSR"
    assert ranked[2]["handle"] == "FellowshipJoe"


def test_recommend_contacts_excludes_inactive():
    contacts = sample_contacts()
    contacts[0]["active"] = False

    ranked = recommend_contacts(
        contacts=contacts,
        limit=3,
    )

    handles = [contact["handle"] for contact in ranked]

    assert "SponsorBob" not in handles


def test_recommend_contacts_respects_limit():
    ranked = recommend_contacts(
        contacts=sample_contacts(),
        limit=2,
    )

    assert len(ranked) == 2


def test_format_contacts_displays_contact_details():
    output = format_contacts(sample_contacts())

    assert "SponsorBob" in output
    assert "Type: sponsor" in output
    assert "Contact: text" in output
    assert "Status: active" in output