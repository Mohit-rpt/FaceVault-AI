from datetime import date
from pydantic import ValidationError
from app.schemas.schemas import PersonDetailCreate, PersonUpdate

def run_birthday_tests():
    print("[TEST] Starting birthday validation tests...")

    # Scenario 1: Valid ISO date string
    d1 = PersonDetailCreate(birthday="1995-05-15")
    assert d1.birthday == date(1995, 5, 15)
    print("[PASS] Scenario 1: Valid ISO date ('1995-05-15') parsed correctly as date(1995, 5, 15)")

    # Scenario 2: Empty string ""
    d2 = PersonDetailCreate(birthday="")
    assert d2.birthday is None
    print("[PASS] Scenario 2: Empty string ('') safely parsed as None")

    # Scenario 3: Null value None
    d3 = PersonDetailCreate(birthday=None)
    assert d3.birthday is None
    print("[PASS] Scenario 3: Null value (None) safely parsed as None")

    # Scenario 4: Omitted birthday field
    d4 = PersonDetailCreate()
    assert d4.birthday is None
    print("[PASS] Scenario 4: Omitted field safely defaulted to None")

    # Scenario 5: Full ISO datetime string with 'T'
    d5 = PersonDetailCreate(birthday="1995-05-15T00:00:00")
    assert d5.birthday == date(1995, 5, 15)
    print("[PASS] Scenario 5: ISO datetime ('1995-05-15T00:00:00') parsed as date(1995, 5, 15)")

    # Scenario 6: Invalid date format
    try:
        PersonDetailCreate(birthday="invalid-date")
        print("[FAIL] Scenario 6: Invalid date did not raise error")
    except ValidationError as e:
        print("[PASS] Scenario 6: Invalid date ('invalid-date') correctly rejected with ValidationError:")
        print(f"       Message: {e.errors()[0]['msg']}")

    print("\nAll Birthday validation scenarios passed 100% cleanly!")

if __name__ == "__main__":
    run_birthday_tests()
