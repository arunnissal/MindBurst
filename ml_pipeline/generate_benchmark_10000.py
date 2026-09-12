import json
import random
import os
import sys

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

def generate_benchmark_10000():
    print("🚀 Generating massive 10,000-sentence Benchmark Suite (5,000 English + 5,000 Tanglish)...")
    english_cases = []
    tanglish_cases = []

    # -------------------------------------------------------------
    # 1. ENGLISH TEST CASES (Target: 5,000)
    # -------------------------------------------------------------
    
    # 1.1 Tasks (750 cases)
    task_verbs_en = [
        "Complete the {subject} assignment before {deadline}",
        "Submit the {subject} lab record {timeframe}",
        "Finish the {domain} presentation slides by {timeframe}",
        "Prepare documentation for {project} REST API",
        "Review pull request for {feature} module on GitHub",
        "Wash {chore_item} before {timeframe}",
        "Clean the {home_area} thoroughly {timeframe}",
        "Fix the leaking {home_fixture} in bathroom",
        "Service the {vehicle} before {deadline}",
        "Update the client invoice spreadsheet {timeframe}",
        "Draft the quarterly report for {dept} team",
        "Compile sprint backlog tickets for upcoming release",
        "Send signed contract document to {recipient}",
        "Inspect server logs for memory leak issue",
        "Write unit tests for authentication service",
        "Debug {feature} crash on Android 14 devices",
        "Sign and return the revised NDA document",
        "Schedule code freeze for production deployment {timeframe}"
    ]
    double_neg_tasks_en = [
        "Don't forget to submit the {subject} assignment {timeframe}",
        "Dont forget to complete the {subject} project report",
        "Do not miss sending the {domain} proposal to client",
        "Never skip washing {chore_item} {timeframe}",
        "Do not delay fixing the {home_fixture}",
        "Don't forget to upload the lab manual today",
        "Please don't forget to review the PR before merging",
        "Dont miss updating the sprint board today"
    ]
    subjects = ["Microprocessor", "Compiler Design", "Machine Learning", "Operating Systems", "Cloud Computing", "DSP", "DBMS", "Computer Networks", "Data Structures", "Web Dev", "Robotics", "Cybersecurity", "Embedded Systems"]
    deadlines = ["Friday 5 PM", "tomorrow midnight", "Monday morning", "end of day", "tomorrow noon", "this evening", "tonight 11 PM"]
    timeframes = ["today", "tomorrow", "tmrw", "this evening", "by tonight", "before Monday", "by 6 PM", "before deadline"]
    domains = ["fintech", "healthcare", "e-commerce", "AI agent", "analytics", "inventory", "crypto", "edtech", "logistics"]
    projects = ["MindBurst", "JeevanSetu", "PaymentService", "AuthCore", "NotificationHub", "SyncWorker"]
    features = ["biometric login", "payment checkout", "voice note transcription", "SQLite caching", "dark mode toggle", "offline sync"]
    chore_items = ["the laundry", "white shirts", "winter blankets", "kitchen dishes", "car windshield", "bedroom curtains", "bike engine"]
    home_areas = ["kitchen sink", "study table", "balcony garden", "refrigerator shelves", "hostel room floor", "bathroom tiles"]
    home_fixtures = ["tap", "shower head", "kitchen sink pipe", "flush valve", "water heater pipe"]
    vehicles = ["two-wheeler bike", "car engine", "scooter brakes", "bicycle chain", "car windshield"]
    depts = ["engineering", "finance", "operations", "design", "marketing", "security"]
    recipients = ["manager", "client", "vendor", "accountant", "professor", "auditor"]

    for i in range(550):
        t = random.choice(task_verbs_en).format(
            subject=random.choice(subjects),
            deadline=random.choice(deadlines),
            timeframe=random.choice(timeframes),
            domain=random.choice(domains),
            project=random.choice(projects),
            feature=random.choice(features),
            chore_item=random.choice(chore_items),
            home_area=random.choice(home_areas),
            home_fixture=random.choice(home_fixtures),
            vehicle=random.choice(vehicles),
            dept=random.choice(depts),
            recipient=random.choice(recipients)
        )
        english_cases.append({"id": f"EN-TSK-{len(english_cases)+1:04d}", "text": t, "intent": "Task", "language": "English"})
    for i in range(200):
        t = random.choice(double_neg_tasks_en).format(
            subject=random.choice(subjects),
            timeframe=random.choice(timeframes),
            domain=random.choice(domains),
            chore_item=random.choice(chore_items),
            home_fixture=random.choice(home_fixtures)
        )
        english_cases.append({"id": f"EN-TSK-{len(english_cases)+1:04d}", "text": t, "intent": "Task", "language": "English", "double_negation": True})

    # 1.2 Reminders (750 cases)
    reminder_actions_en = [
        "call Mom", "call manager", "call Dr. Smith for consultation", "take blood pressure tablet",
        "take vitamin D3 supplement", "join Google Meet client standup", "attend project sync with team",
        "drink 2 glasses of water", "check oven temperature", "turn off geyser heater", "take evening insulin dose",
        "wish Sarah happy birthday", "check flight check-in status", "feed pet dog evening meal", "attend design review sync"
    ]
    times_en = ["at 5 PM", "at 6:30 PM", "morning 9 AM", "sharp 7:15 AM", "night 10 PM", "at 3.45pm", "at 2:30 PM", "in 30 minutes", "at 8:00 AM", "afternoon 2 PM", "at 7 PM sharp", "at 12 midnight"]
    preambles_en = ["Hey Mind, ", "Bro listen, ", "Please ", "Quick alert: ", "Can you ", ""]

    for i in range(550):
        text = f"{random.choice(preambles_en)}remind me to {random.choice(reminder_actions_en)} {random.choice(times_en)} {random.choice(['today', 'tomorrow', 'tonight', ''])}".strip()
        english_cases.append({"id": f"EN-REM-{len(english_cases)+1:04d}", "text": text, "intent": "Reminder", "language": "English"})
    for i in range(200):
        text = f"Don't forget the {random.choice(times_en)} team review meeting {random.choice(['tomorrow', 'today', 'before Friday'])}"
        english_cases.append({"id": f"EN-REM-{len(english_cases)+1:04d}", "text": text, "intent": "Reminder", "language": "English", "double_negation": True})

    # 1.3 Shopping (750 cases)
    groceries_en = [
        "2 kg onions, 1 litre milk, and 6 brown eggs", "whole wheat bread and peanut butter", "1.5 kg tomatoes and fresh ginger",
        "paracetamol tablets, vicks vaporub, and band-aids", "shampoo bottle, bathing soap, and toothpaste",
        "A4 ruled notebook, sticky notes, and blue ballpoint pens", "ground coffee powder and low-fat milk",
        "basmati rice 5kg and refined sunflower cooking oil", "dark chocolate bar and green tea bags",
        "detergent powder and floor cleaning liquid", "fresh apples, bananas, and sweet oranges",
        "rolled oats, almond butter, and chia seeds", "500g paneer, butter, and cheese slices"
    ]
    shop_verbs_en = ["Buy", "Purchase", "Pick up", "Order", "Restock", "Get"]
    shop_locs_en = ["from supermarket", "from nearby grocery shop", "from pharmacy", "online via Zepto", "from Reliance Smart", ""]

    for i in range(750):
        text = f"{random.choice(shop_verbs_en)} {random.choice(groceries_en)} {random.choice(shop_locs_en)} {random.choice(['today', 'tomorrow', 'this evening', ''])}".strip()
        english_cases.append({"id": f"EN-SHP-{len(english_cases)+1:04d}", "text": text, "intent": "Shopping", "language": "English"})

    # 1.4 Payment_Due (700 cases)
    bills_en = [
        "hostel rent on 5th", "house rent on 1st of next month", "monthly mess fee",
        "electricity bill before power disconnection", "broadband optical fiber wifi bill",
        "Airtel mobile recharge expiring on 28th", "gym membership quarterly fee",
        "college tuition fee for 6th semester", "credit card outstanding balance",
        "piped gas cylinder bill", "vehicle comprehensive insurance renewal"
    ]
    pay_verbs_en = ["Pay", "Clear", "Transfer", "Settle", "GPay", "PhonePe", "Make payment for"]

    for i in range(500):
        text = f"{random.choice(pay_verbs_en)} {random.choice(bills_en)} {random.choice(['today', 'tomorrow', 'before due date', 'immediately'])}".strip()
        english_cases.append({"id": f"EN-PAY-{len(english_cases)+1:04d}", "text": text, "intent": "Payment_Due", "language": "English"})
    for i in range(200):
        text = f"Don't forget to pay {random.choice(bills_en)} before deadline"
        english_cases.append({"id": f"EN-PAY-{len(english_cases)+1:04d}", "text": text, "intent": "Payment_Due", "language": "English", "double_negation": True})

    # 1.5 Carry (700 cases)
    carry_items_en = [
        "hall ticket and college ID card", "laptop, type-C charger, and wireless mouse",
        "umbrella and compact raincoat because rain is forecasted", "scientific calculator and geometric compass",
        "water bottle and gym workout towel", "power bank and lightning charging cable",
        "bike helmet and driving license smartcard", "original passport, visa copy, and boarding pass",
        "house keys and leather wallet", "stethoscope and white lab coat", "noise-cancelling headphones and notebook"
    ]
    carry_verbs_en = ["Carry", "Take", "Bring", "Pack in bag", "Keep with you"]

    for i in range(500):
        text = f"{random.choice(carry_verbs_en)} {random.choice(carry_items_en)} {random.choice(['to exam hall', 'to campus lab', 'to office tomorrow', 'for travel', 'to college today'])}".strip()
        english_cases.append({"id": f"EN-CRY-{len(english_cases)+1:04d}", "text": text, "intent": "Carry", "language": "English"})
    for i in range(200):
        text = f"Don't forget to bring {random.choice(carry_items_en)} {random.choice(['tomorrow', 'to college', 'to lab', 'to airport'])}"
        english_cases.append({"id": f"EN-CRY-{len(english_cases)+1:04d}", "text": text, "intent": "Carry", "language": "English", "double_negation": True})

    # 1.6 Place (700 cases)
    places_en = [
        "Apollo hospital", "central railway station", "SBI bank branch", "city civil court",
        "regional passport seva kendra", "dentist dental clinic", "car authorized service center",
        "international airport terminal 1", "central public library", "metro railway station",
        "supermarket plaza", "government municipal corporation office", "mechanic garage"
    ]
    for i in range(700):
        text = f"Go to {random.choice(places_en)} {random.choice(['tomorrow at 10 AM', 'before 4 PM for appointment', 'by evening', 'on Friday', 'this afternoon'])}".strip()
        english_cases.append({"id": f"EN-PLC-{len(english_cases)+1:04d}", "text": text, "intent": "Place", "language": "English"})

    # 1.7 Note & Pure Negation (650 cases)
    pure_negations_en = [
        "Don't buy milk today fridge has two unopened packets", "Do not pay house rent today landlord requested payment next week",
        "Avoid going to SBI bank today it is declared a public holiday", "Never wash white linen shirts with dark blue jeans",
        "No need to carry umbrella today weather is completely sunny", "Don't submit project proposal yet awaiting senior manager signoff",
        "Never skip morning breakfast before heavy weight lifting", "Do not visit municipal office on Saturday it remains closed",
        "No need to buy eggs today tray is already full", "Don't transfer mess fee until revised ledger is issued"
    ]
    notes_info_en = [
        "Idea for startup: edge-computed personal intelligence engine without cloud", "Book recommendation: Atomic Habits by James Clear",
        "WiFi password for office conference room is AlphaSec99", "Recommended four-wheeler tyre pressure is 33 PSI cold",
        "Blood donor group is O positive and emergency contact is saved", "Vehicle registration number is TN 09 BK 4021",
        "Quote of the day: consistency beats intensity in long term execution", "Key insight: vector TF-IDF runs in sub-millisecond on mobile CPU",
        "Important contact number for plumbing maintenance is 9840123456", "Note: Server database backup runs every midnight at 2 AM"
    ]
    for i in range(400):
        english_cases.append({"id": f"EN-NOT-{len(english_cases)+1:04d}", "text": random.choice(pure_negations_en), "intent": "Note", "language": "English"})
    for i in range(250):
        english_cases.append({"id": f"EN-NOT-{len(english_cases)+1:04d}", "text": random.choice(notes_info_en), "intent": "Note", "language": "English"})

    # -------------------------------------------------------------
    # 2. TANGLISH TEST CASES (Target: 5,000)
    # -------------------------------------------------------------

    # 2.1 Tasks (750 cases)
    tasks_ta = [
        "Innaiku {subj} assignment mudikanum da", "{subj} lab record naalaiku submit pannanum",
        "Seminar ppt ready panni mail anupanum {timeframe}", "Bike service panni oil change pannanum",
        "Hostel room clean panni clothes wash pannanum innaiku", "Client proposal draft pannitu review ku send pannu",
        "Project repo la pull request merge pannanum", "Kitchen sink block aagirukku plumber kitta fix pannanum",
        "Resume update panni job portal la upload pannu", "Sprint demo ku code freeze pannanum by evening"
    ]
    for i in range(550):
        t = random.choice(tasks_ta).format(
            subj=random.choice(["DSP", "Compiler", "DBMS", "Networks", "Python", "Web", "Cloud", "OS"]),
            timeframe=random.choice(["evening kulla", "innaiku night", "tomorrow morning"])
        )
        tanglish_cases.append({"id": f"TG-TSK-{len(tanglish_cases)+1:04d}", "text": t, "intent": "Task", "language": "Tanglish"})
    for i in range(200):
        t = f"Maranthu poidaadha {random.choice(['DSP', 'Compiler', 'DBMS', 'Cloud'])} assignment submit pannanum"
        tanglish_cases.append({"id": f"TG-TSK-{len(tanglish_cases)+1:04d}", "text": t, "intent": "Task", "language": "Tanglish", "double_negation": True})

    # 2.2 Reminders (750 cases)
    times_ta = ["evening 6:30 ku", "night 9 manikku", "kaalaila 8:00 ku", "afternoon 3:15 ku", "sharp 5 PM ku", "innaiku 7 ku", "night 10 ku"]
    for i in range(550):
        act_ta = random.choice(["amma ku call pannu", "doctor appointment marakadha", "BP tablet podanum remind pannu", "manager kitta project status pesanum", "meeting start aagudhu alert pannu"])
        t = f"{act_ta} {random.choice(times_ta)}"
        tanglish_cases.append({"id": f"TG-REM-{len(tanglish_cases)+1:04d}", "text": t, "intent": "Reminder", "language": "Tanglish"})
    for i in range(200):
        t = f"Maranthu poidaadha {random.choice(times_ta)} doctor kitta poganum"
        tanglish_cases.append({"id": f"TG-REM-{len(tanglish_cases)+1:04d}", "text": t, "intent": "Reminder", "language": "Tanglish", "double_negation": True})

    # 2.3 Shopping (750 cases)
    items_ta_list = [
        "paal 1 litre and bread packet", "6 muttai and 1 kg thakkali", "vengayam 2 kg and urulai",
        "kaapi thool and sakkarai", "atta flour 5kg and cooking sunflower oil", "curd packet and cheese slices",
        "biscuit packet and maggie noodles", "vicks vaporub and dolo 650", "blue gel pen and long size notebook"
    ]
    for i in range(750):
        t = f"Kadaila {random.choice(items_ta_list)} {random.choice(['vangitu va', 'vaanganum', 'vangu da', 'marakkama vangitu va'])}"
        tanglish_cases.append({"id": f"TG-SHP-{len(tanglish_cases)+1:04d}", "text": t, "intent": "Shopping", "language": "Tanglish"})

    # 2.4 Payment_Due (700 cases)
    pay_ta = [
        "Hostel rent 5th ku gpay pannanum", "Room rent owner ku transfer pannu innaiku", "Current bill kattanum deadline naalaiku",
        "Mess fee pay panni screenshot warden ku anupu", "Wifi bill expire aagudhu phonepe pannu", "Airtel recharge 28th ku mudiyudhu innaiku pannu",
        "College tuition fee semester 6 ku kattanum", "Gym subscription renewal fee transfer pannu"
    ]
    for i in range(500):
        tanglish_cases.append({"id": f"TG-PAY-{len(tanglish_cases)+1:04d}", "text": random.choice(pay_ta), "intent": "Payment_Due", "language": "Tanglish"})
    for i in range(200):
        t = f"Maranthu poidaadha {random.choice(['room rent 5th ku', 'mess fee', 'current bill', 'wifi bill'])} kattanum"
        tanglish_cases.append({"id": f"TG-PAY-{len(tanglish_cases)+1:04d}", "text": t, "intent": "Payment_Due", "language": "Tanglish", "double_negation": True})

    # 2.5 Carry (700 cases)
    carry_ta = [
        "College id card marakkama eduthutu po", "Hall ticket and blue pen bag la vachiko da", "Laptop and charger lab ku eduthutu ponum",
        "Mazhai peiyum umbrella bag la vachiko", "Bike rc book and helmet eduthutu po veliya", "Water bottle and towel gym ku eduthuko",
        "Power bank and mobile cable eduthu vai", "Calculator and graph sheet exam ku eduthutu po"
    ]
    for i in range(500):
        tanglish_cases.append({"id": f"TG-CRY-{len(tanglish_cases)+1:04d}", "text": random.choice(carry_ta), "intent": "Carry", "language": "Tanglish"})
    for i in range(200):
        t = f"Hall ticket and id card bag la vaikka maranthu poidaadha"
        tanglish_cases.append({"id": f"TG-CRY-{len(tanglish_cases)+1:04d}", "text": t, "intent": "Carry", "language": "Tanglish", "double_negation": True})

    # 2.6 Place (700 cases)
    places_ta = [
        "Innaiku clg mudinjadhum direct ah Apollo hospital reach aaganum", "SBI bank branch ku visit panrom naalaiku kaalaila",
        "Central railway station ku 5 manikku poganum", "Supermarket ku evening polam groceries vanga",
        "Car service center ku travel panrom delivery edukka", "Dentist clinic reach aaganum evening 6 pm kulla",
        "Library ku morning 10 ku poga plan pannirukom", "Airport terminal 1 ku drop panna travel aaganum"
    ]
    for i in range(700):
        tanglish_cases.append({"id": f"TG-PLC-{len(tanglish_cases)+1:04d}", "text": random.choice(places_ta), "intent": "Place", "language": "Tanglish"})

    # 2.7 Note (650 cases)
    notes_ta = [
        "Milk vendam innaiku curd already fridge la irukku", "Innaiku rent pay panna vendam owner 10th sonnaru",
        "SBI bank ku poga vendam innaiku leave public holiday", "Veliya poga vendam outside heavy rain peiyudhu",
        "Laptop lab ku eduthu poga vendam professor sonnaru", "Assignment innaiku submit panna vendam deadline postpone",
        "Eggs vaanga vendam tray full ah irukku", "Bike service innaiku panna vendam mechanic closed",
        "Hostel wifi password SecretPass99 innaiku change pannanga", "Bike mileage service ku apparam 48 kmpl varudhu",
        "Idea: offline voice assistant for Tamil students", "Doctor blood test report normal ah irukku",
        "Current meter reading 2410 units note panniko", "Car tyre air pressure 33 psi maintain pannanum"
    ]
    for i in range(650):
        tanglish_cases.append({"id": f"TG-NOT-{len(tanglish_cases)+1:04d}", "text": random.choice(notes_ta), "intent": "Note", "language": "Tanglish"})

    print(f"   • English cases : {len(english_cases)}")
    print(f"   • Tanglish cases: {len(tanglish_cases)}")
    assert len(english_cases) == 5000, f"Expected 5,000 EN cases, got {len(english_cases)}"
    assert len(tanglish_cases) == 5000, f"Expected 5,000 TG cases, got {len(tanglish_cases)}"

    all_cases = english_cases + tanglish_cases
    random.seed(42)
    random.shuffle(all_cases)

    output_path = "ml_pipeline/benchmark_10000.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(all_cases, f, indent=2, ensure_ascii=False)

    print(f"✅ Created 10,000 Benchmark Suite at {output_path} ({os.path.getsize(output_path)/1024:.1f} KB)")

if __name__ == "__main__":
    generate_benchmark_10000()
