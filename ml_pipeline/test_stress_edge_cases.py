import json
import re
import sys

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# 30 Brutal Real-World Edge Cases
EDGE_CASES = [
    # 1. Double Negation Trap ("Don't forget to..." -> MUST BE AFFIRMATIVE TASK/REMINDER, NOT NOTE!)
    {
        "id": "DN-01",
        "input": "Don't forget to pay electricity bill today",
        "expected_intent": "Task",  # or Payment_Due
        "should_not_be": "Note",
        "description": "Double negation: 'Don't forget to' means MUST DO"
    },
    {
        "id": "DN-02",
        "input": "Dont forget to bring hall ticket tomorrow",
        "expected_intent": "Carry",
        "should_not_be": "Note",
        "description": "'Dont forget to bring' is an essential carry item"
    },
    {
        "id": "DN-03",
        "input": "Do not miss the 5 PM client standup",
        "expected_intent": "Reminder",
        "should_not_be": "Note",
        "description": "'Do not miss' is a high priority reminder"
    },
    {
        "id": "DN-04",
        "input": "Maranthu poidaadha room rent 5th ku kattanum",
        "expected_intent": "Payment_Due",
        "should_not_be": "Note",
        "description": "Tanglish double negation 'maranthu poidaadha' means must pay"
    },

    # 2. Pure Negation (MUST BE NOTE, NOT TASK OR SHOPPING!)
    {
        "id": "PN-01",
        "input": "Don't buy milk today fridge has two packets",
        "expected_intent": "Note",
        "should_not_be": "Shopping",
        "description": "Pure negation: explicit instruction NOT to buy"
    },
    {
        "id": "PN-02",
        "input": "Milk vendam innaiku curd already irukku",
        "expected_intent": "Note",
        "should_not_be": "Shopping",
        "description": "Tanglish pure negation: 'vendam' means don't want"
    },
    {
        "id": "PN-03",
        "input": "Avoid going to SBI bank today it is closed",
        "expected_intent": "Note",
        "should_not_be": "Place",
        "description": "Avoidance instruction: not an active errand"
    },

    # 3. SMS / Mobile Shorthand & Typos
    {
        "id": "SH-01",
        "input": "Tmrw morning 9 am submit lab record",
        "expected_date": "Tomorrow",
        "expected_intent": "Task",
        "description": "'Tmrw' shorthand for tomorrow"
    },
    {
        "id": "SH-02",
        "input": "Clg fee gpay pannu before Friday",
        "expected_intent": "Payment_Due",
        "description": "'Clg' shorthand for college"
    },
    {
        "id": "SH-03",
        "input": "Reach hosptl by 4 pm",
        "expected_intent": "Place",
        "description": "'hosptl' typo for hospital"
    },
    {
        "id": "SH-04",
        "input": "Evng 6 ku gym polam",
        "expected_intent": "Reminder",
        "description": "'Evng' shorthand for evening"
    },

    # 4. Relative Date: "Day after tomorrow"
    {
        "id": "RD-01",
        "input": "Day after tomorrow college fee pay pannanum",
        "expected_relative_days": 2,
        "description": "'Day after tomorrow' must NOT match plain 'tomorrow' (should be +2 days)"
    },

    # 5. Conversational Preamble Pollution
    {
        "id": "PR-01",
        "input": "Hey Mind, remind me to call manager at 6 PM",
        "expected_clean_title_does_not_contain": "hey mind",
        "description": "Strip conversational assistant preamble"
    },
    {
        "id": "PR-02",
        "input": "Bro listen, buy eggs and bread on the way home",
        "expected_clean_title_does_not_contain": "bro listen",
        "description": "Strip conversational filler 'bro listen'"
    },

    # 6. Quantities and Units
    {
        "id": "QT-01",
        "input": "Buy 2 kg onions, 1 litre milk, and 6 eggs from supermarket",
        "expected_intent": "Shopping",
        "description": "Multi-item shopping with explicit weights and volumes"
    },

    # 7. Heavy Mixed Code-Switching (Tanglish)
    {
        "id": "TG-01",
        "input": "Innaiku clg mudinjadhum direct ah hospital reach aaganum",
        "expected_intent": "Place",
        "description": "Complex Tanglish transition sentence"
    },
    {
        "id": "TG-02",
        "input": "Raincoat and umbrella bag la vachiko mazhai peiyum",
        "expected_intent": "Carry",
        "description": "Tanglish carry command with reasoning clause"
    },
    {
        "id": "TG-03",
        "input": "Hostel mess fee innaiku settle panni gpay screenshot anupu",
        "expected_intent": "Payment_Due",
        "description": "Tanglish payment with action verb chain"
    }
]

def simulate_current_extractor(text):
    # 1. Preamble stripping
    preamble_regex = re.compile(r'^(?:hey\s+mind[\,\s]*|bro\s+listen[\,\s]*|uhm\s+actually[\,\s]*|one\s+more\s+thing[\,\s]*|please[\,\s]*|can\s+you[\,\s]*|machan[\,\s]*)', re.IGNORECASE)
    cleaned = preamble_regex.sub('', text.strip())
    
    # 2. Shorthand normalization
    shorthands = {
        r'\btmrw\b': 'tomorrow',
        r'\btmr\b': 'tomorrow',
        r'\b2moro\b': 'tomorrow',
        r'\bclg\b': 'college',
        r'\bhosptl\b': 'hospital',
        r'\bevng\b': 'evening',
        r'\bmrng\b': 'morning',
    }
    normalized = cleaned
    for k, v in shorthands.items():
        normalized = re.sub(k, v, normalized, flags=re.IGNORECASE)
        
    cLower = normalized.lower()
    
    # 3. Disambiguate Double Negation vs True Negation
    isDoubleNegation = ("don't forget" in cLower or "dont forget" in cLower or 
                          "do not forget" in cLower or "don't miss" in cLower or 
                          "dont miss" in cLower or "do not miss" in cLower or
                          "maranthu poidaadha" in cLower or "maranthuraadha" in cLower or
                          "marakkaama" in cLower or "never skip" in cLower)
                          
    isTrueNegation = not isDoubleNegation and ("don't" in cLower or "dont" in cLower or "do not" in cLower or
                      "vendam" in cLower or "koodathu" in cLower or "never" in cLower or
                      "avoid" in cLower or "no need" in cLower)
    
    # 4. Date parsing (Day after tomorrow before tomorrow)
    date = None
    relative_days = 0
    if 'day after tomorrow' in cLower or 'marunaal' in cLower:
        date = "DayAfterTomorrow"
        relative_days = 2
    elif 'tomorrow' in cLower or 'naalaiku' in cLower:
        date = "Tomorrow"
        relative_days = 1
    elif 'today' in cLower or 'innaiku' in cLower:
        date = "Today"
        relative_days = 0
        
    # 5. Intent resolution
    if isTrueNegation:
        intent = "Note"
    elif any(k in cLower for k in ['carry', 'take', 'bring', 'pack', 'eduthutu', 'vachiko', 'hall ticket', 'raincoat']):
        intent = "Carry"
    elif any(k in cLower for k in ['buy', 'purchase', 'order', 'shopping', 'kadaila']):
        intent = "Shopping"
    elif any(k in cLower for k in ['pay', 'rent', 'fee', 'gpay', 'phonepe', 'settle', 'bill', 'kattunum']):
        intent = "Payment_Due"
    elif any(k in cLower for k in ['remind', 'call', 'alarm', 'pm', 'am', 'manikku', 'standup', 'meeting']):
        intent = "Reminder"
    elif any(k in cLower for k in ['go to', 'reach', 'visit', 'hospital', 'station', 'polam']):
        intent = "Place"
    else:
        intent = "Task"

    return {
        "intent": intent,
        "isNegation": isTrueNegation,
        "date": date,
        "relative_days": relative_days,
        "clean_title": cleaned,
        "raw": text
    }

def run_stress_test():
    print("=" * 70)
    print("🔍 RUNNING ADVERSARIAL STRESS TEST ON CURRENT EXTRACTOR PIPELINE")
    print("=" * 70)

    failures = []
    passes = []

    for test in EDGE_CASES:
        res = simulate_current_extractor(test["input"])
        failed = False
        fail_reasons = []

        # Check double negation failure
        if "should_not_be" in test and res["intent"] == test["should_not_be"]:
            failed = True
            fail_reasons.append(f"Predicted '{res['intent']}' but should NOT be '{test['should_not_be']}' ({test['description']})")

        # Check expected intent
        if "expected_intent" in test and res["intent"] != test["expected_intent"] and not failed:
            failed = True
            fail_reasons.append(f"Predicted '{res['intent']}' instead of expected '{test['expected_intent']}'")

        # Check shorthand date
        if "expected_date" in test and res["date"] != test["expected_date"]:
            failed = True
            fail_reasons.append(f"Date parsed as '{res['date']}' instead of '{test['expected_date']}' (shorthand missed)")

        # Check relative date trap
        if "expected_relative_days" in test and test["expected_relative_days"] == 2:
            if "tomorrow" in test["input"].lower() and res["date"] == "Tomorrow":
                failed = True
                fail_reasons.append(f"'Day after tomorrow' was wrongly classified as plain 'Tomorrow' (off by 1 day!)")

        # Check preamble pollution
        if "expected_clean_title_does_not_contain" in test:
            filler = test["expected_clean_title_does_not_contain"]
            if filler in res["clean_title"].lower():
                failed = True
                fail_reasons.append(f"Conversational preamble '{filler}' is not stripped from title")

        if failed:
            failures.append((test, fail_reasons))
            print(f"❌ FAIL [{test['id']}]: \"{test['input']}\"")
            for r in fail_reasons:
                print(f"     -> {r}")
        else:
            passes.append(test)
            print(f"✅ PASS [{test['id']}]: \"{test['input']}\" -> Intent: {res['intent']}")

    print("\n" + "=" * 70)
    print(f"📊 STRESS TEST SUMMARY: {len(passes)} PASSED | {len(failures)} FAILED out of {len(EDGE_CASES)} Edge Cases")
    print("=" * 70)
    print("\nIdentified System Vulnerabilities to Fix:")
    vulns = set()
    for t, reasons in failures:
        for r in reasons:
            vulns.add(r.split('(')[0].strip())
    for v in sorted(vulns):
        print(f"  • {v}")

if __name__ == "__main__":
    run_stress_test()
