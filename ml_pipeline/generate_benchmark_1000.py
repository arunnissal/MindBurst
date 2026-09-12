import json
import random
import os
import sys

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

def create_benchmark_1000():
    english_cases = []
    tanglish_cases = []

    # -------------------------------------------------------------
    # 1. ENGLISH TEST CASES (Target: 500)
    # -------------------------------------------------------------
    
    # 1.1 Tasks (75 cases)
    task_templates_en = [
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
        "Debug {feature} crash on Android 14 devices"
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

    subjects = ["Microprocessor", "Compiler Design", "Machine Learning", "Operating Systems", "Cloud Computing", "Digital Signal Processing", "DBMS", "Computer Networks", "Data Structures", "Web Dev"]
    deadlines = ["Friday 5 PM", "tomorrow midnight", "Monday morning", "end of day", "tomorrow noon", "this evening"]
    timeframes = ["today", "tomorrow", "tmrw", "this evening", "by tonight", "before Monday", "by 6 PM"]
    domains = ["fintech", "healthcare", "e-commerce", "AI agent", "analytics", "inventory"]
    projects = ["MindBurst", "JeevanSetu", "PaymentService", "AuthCore", "NotificationHub"]
    features = ["biometric login", "payment checkout", "voice note transcription", "SQLite caching", "dark mode toggle"]
    chore_items = ["the laundry", "white shirts", "winter blankets", "kitchen dishes", "car windshield"]
    home_areas = ["kitchen sink", "study table", "balcony garden", "refrigerator shelves", "hostel room floor"]
    home_fixtures = ["tap", "shower head", "kitchen sink pipe", "flush valve"]
    vehicles = ["two-wheeler bike", "car engine", "scooter brakes", "bicycle chain"]
    depts = ["engineering", "finance", "operations", "design", "marketing"]
    recipients = ["manager", "client", "vendor", "accountant", "professor"]

    # Generate 75 Task EN
    for i in range(50):
        t = random.choice(task_templates_en).format(
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
        english_cases.append({
            "id": f"EN-TSK-{len(english_cases)+1:03d}",
            "text": t,
            "intent": "Task",
            "language": "English",
            "tags": ["task", "affirmative"]
        })
    for i in range(25):
        t = random.choice(double_neg_tasks_en).format(
            subject=random.choice(subjects),
            timeframe=random.choice(timeframes),
            domain=random.choice(domains),
            chore_item=random.choice(chore_items),
            home_fixture=random.choice(home_fixtures)
        )
        english_cases.append({
            "id": f"EN-TSK-{len(english_cases)+1:03d}",
            "text": t,
            "intent": "Task",
            "language": "English",
            "tags": ["task", "double_negation", "affirmative"]
        })

    # 1.2 Reminders (75 cases)
    reminder_actions_en = [
        "call Mom", "call manager", "call Dr. Smith for consultation", "take blood pressure tablet",
        "take vitamin D3 supplement", "join Google Meet client standup", "attend project sync with team",
        "drink 2 glasses of water", "check oven temperature", "turn off geyser heater", "take evening insulin dose",
        "wish Sarah happy birthday", "check flight check-in status", "feed pet dog evening meal"
    ]
    times_en = [
        "at 5 PM", "at 6:30 PM", "morning 9 AM", "sharp 7:15 AM", "night 10 PM", "at 3.45pm", "at 2:30 PM",
        "in 30 minutes", "at 8:00 AM", "afternoon 2 PM", "at 7 PM sharp"
    ]
    preambles_en = ["Hey Mind, ", "Bro listen, ", "Please ", "Quick alert: ", "Can you ", ""]
    
    for i in range(55):
        act = random.choice(reminder_actions_en)
        tm = random.choice(times_en)
        pr = random.choice(preambles_en)
        day = random.choice(["today", "tomorrow", "tonight", ""])
        text = f"{pr}remind me to {act} {tm} {day}".strip()
        english_cases.append({
            "id": f"EN-REM-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Reminder",
            "language": "English",
            "tags": ["reminder", "time_bound"]
        })
    # Double negation reminders
    double_neg_rems_en = [
        "Don't forget the {time} client standup call",
        "Dont forget to call {person} at {time}",
        "Do not miss the {time} doctor appointment",
        "Never skip taking evening medicine at {time}",
        "Don't miss the {time} team review meeting tomorrow",
        "Do not forget meeting with {person} at {time}"
    ]
    persons = ["Mom", "manager", "Dr. Rao", "advisor", "team lead", "mentor"]
    for i in range(20):
        t = random.choice(double_neg_rems_en).format(
            time=random.choice(times_en),
            person=random.choice(persons)
        )
        english_cases.append({
            "id": f"EN-REM-{len(english_cases)+1:03d}",
            "text": t,
            "intent": "Reminder",
            "language": "English",
            "tags": ["reminder", "double_negation"]
        })

    # 1.3 Shopping (75 cases)
    groceries = [
        "2 kg onions, 1 litre milk, and 6 brown eggs",
        "whole wheat bread and peanut butter",
        "1.5 kg tomatoes and fresh ginger",
        "paracetamol tablets, vicks vaporub, and band-aids",
        "shampoo bottle, bathing soap, and toothpaste",
        "A4 ruled notebook, sticky notes, and blue ballpoint pens",
        "ground coffee powder and low-fat milk",
        "basmati rice 5kg and refined sunflower cooking oil",
        "dark chocolate bar and green tea bags",
        "detergent powder and floor cleaning liquid",
        "fresh apples, bananas, and sweet oranges",
        "rolled oats, almond butter, and chia seeds"
    ]
    shop_verbs = ["Buy", "Purchase", "Pick up", "Order", "Restock", "Get"]
    shop_locs = ["from supermarket", "from nearby grocery shop", "from pharmacy", "online via Zepto", "from Reliance Smart", ""]
    
    for i in range(75):
        g = random.choice(groceries)
        v = random.choice(shop_verbs)
        loc = random.choice(shop_locs)
        day = random.choice(["today", "tomorrow", "this evening", ""])
        text = f"{v} {g} {loc} {day}".strip()
        english_cases.append({
            "id": f"EN-SHP-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Shopping",
            "language": "English",
            "tags": ["shopping", "grocery"]
        })

    # 1.4 Payment_Due (70 cases)
    bills = [
        "hostel rent on 5th", "house rent on 1st of next month", "monthly mess fee",
        "electricity bill before power disconnection", "broadband optical fiber wifi bill",
        "Airtel mobile recharge expiring on 28th", "gym membership quarterly fee",
        "college tuition fee for 6th semester", "credit card outstanding balance",
        "piped gas cylinder bill", "vehicle comprehensive insurance renewal"
    ]
    pay_verbs = ["Pay", "Clear", "Transfer", "Settle", "GPay", "PhonePe", "Make payment for"]
    
    for i in range(50):
        b = random.choice(bills)
        v = random.choice(pay_verbs)
        day = random.choice(["today", "tomorrow", "before due date", "this week", "immediately"])
        text = f"{v} {b} {day}".strip()
        english_cases.append({
            "id": f"EN-PAY-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Payment_Due",
            "language": "English",
            "tags": ["payment", "finance"]
        })
    # Double negation bills
    for i in range(20):
        b = random.choice(bills)
        text = f"Don't forget to pay {b} before deadline"
        english_cases.append({
            "id": f"EN-PAY-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Payment_Due",
            "language": "English",
            "tags": ["payment", "double_negation"]
        })

    # 1.5 Carry (70 cases)
    carry_items_en = [
        "hall ticket and college ID card",
        "laptop, type-C charger, and wireless mouse",
        "umbrella and compact raincoat because rain is forecasted",
        "scientific calculator and geometric compass",
        "water bottle and gym workout towel",
        "power bank and lightning charging cable",
        "bike helmet and driving license smartcard",
        "original passport, visa copy, and boarding pass",
        "house keys and leather wallet",
        "stethoscope and white lab coat",
        "noise-cancelling headphones and notebook"
    ]
    carry_verbs = ["Carry", "Take", "Bring", "Pack in bag", "Keep with you"]
    
    for i in range(50):
        it = random.choice(carry_items_en)
        v = random.choice(carry_verbs)
        dest = random.choice(["to exam hall", "to campus lab", "to office tomorrow", "for travel", "to college today"])
        text = f"{v} {it} {dest}".strip()
        english_cases.append({
            "id": f"EN-CRY-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Carry",
            "language": "English",
            "tags": ["carry", "luggage"]
        })
    for i in range(20):
        it = random.choice(carry_items_en)
        dest = random.choice(["tomorrow", "to college", "to lab", "to airport"])
        text = f"Don't forget to bring {it} {dest}"
        english_cases.append({
            "id": f"EN-CRY-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Carry",
            "language": "English",
            "tags": ["carry", "double_negation"]
        })

    # 1.6 Place (70 cases)
    places_en = [
        "Apollo hospital", "central railway station", "SBI bank branch", "city civil court",
        "regional passport seva kendra", "dentist dental clinic", "car authorized service center",
        "international airport terminal 1", "central public library", "metro railway station",
        "supermarket plaza", "government municipal corporation office"
    ]
    place_templates = [
        "Go to {place} tomorrow at {time}",
        "Reach {place} before {time} for scheduled appointment",
        "Visit {place} {timeframe} to collect certified documents",
        "Head over to {place} by {time}",
        "Travel to {place} {timeframe}",
        "Stop by {place} on the way back home"
    ]
    for i in range(70):
        p = random.choice(places_en)
        t = random.choice(place_templates).format(
            place=p,
            time=random.choice(["10:00 AM", "4:30 PM", "noon", "sharp 2 PM", "6 PM"]),
            timeframe=random.choice(["tomorrow", "this afternoon", "on Friday", "today"])
        )
        english_cases.append({
            "id": f"EN-PLC-{len(english_cases)+1:03d}",
            "text": t,
            "intent": "Place",
            "language": "English",
            "tags": ["place", "transit"]
        })

    # 1.7 Note & Pure Negation (65 cases)
    pure_negations_en = [
        "Don't buy milk today fridge has two unopened packets",
        "Do not pay house rent today landlord requested payment next week",
        "Avoid going to SBI bank today it is declared a public holiday",
        "Never wash white linen shirts with dark blue jeans",
        "No need to carry umbrella today weather is completely sunny",
        "Don't submit project proposal yet awaiting senior manager signoff",
        "Never skip morning breakfast before heavy weight lifting",
        "Do not visit municipal office on Saturday it remains closed",
        "No need to buy eggs today tray is already full",
        "Don't transfer mess fee until revised ledger is issued"
    ]
    informational_notes_en = [
        "Idea for startup: edge-computed personal intelligence engine without cloud",
        "Book recommendation: Atomic Habits by James Clear on compounding habits",
        "WiFi password for office conference room is AlphaSec99",
        "Recommended four-wheeler tyre pressure is 33 PSI cold",
        "Blood donor group is O positive and emergency contact is saved",
        "Vehicle registration number is TN 09 BK 4021",
        "Quote of the day: consistency beats intensity in long term execution",
        "Key insight: vector TF-IDF runs in sub-millisecond on mobile CPU"
    ]
    for i in range(40):
        text = random.choice(pure_negations_en)
        english_cases.append({
            "id": f"EN-NOT-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Note",
            "language": "English",
            "tags": ["note", "pure_negation"]
        })
    for i in range(25):
        text = random.choice(informational_notes_en)
        english_cases.append({
            "id": f"EN-NOT-{len(english_cases)+1:03d}",
            "text": text,
            "intent": "Note",
            "language": "English",
            "tags": ["note", "information"]
        })

    # -------------------------------------------------------------
    # 2. TANGLISH TEST CASES (Target: 500)
    # -------------------------------------------------------------

    # 2.1 Tasks (75 cases)
    task_templates_ta = [
        "Innaiku {subj} assignment mudikanum da",
        "{subj} lab record naalaiku submit pannanum",
        "Seminar ppt ready panni mail anupanum {timeframe}",
        "Bike service panni oil change pannanum",
        "Hostel room clean panni clothes wash pannanum innaiku",
        "Client proposal draft pannitu review ku send pannu",
        "Project repo la pull request merge pannanum",
        "Kitchen sink block aagirukku plumber kitta fix pannanum",
        "Resume update panni job portal la upload pannu",
        "Sprint demo ku code freeze pannanum by evening"
    ]
    double_neg_tasks_ta = [
        "Maranthu poidaadha {subj} assignment submit pannanum",
        "Marakkama lab record sign vanga eduthutu po",
        "Seminar ppt ready panna maranthuraadha",
        "Thuni wash panna maranthuraadha innaiku",
        "Maranthu poidaadha client invoice mail anupu"
    ]
    for i in range(50):
        t = random.choice(task_templates_ta).format(
            subj=random.choice(["DSP", "Compiler", "DBMS", "Networks", "Python", "Web"]),
            timeframe=random.choice(["evening kulla", "innaiku night", "tomorrow morning"])
        )
        tanglish_cases.append({
            "id": f"TG-TSK-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Task",
            "language": "Tanglish",
            "tags": ["tanglish", "task"]
        })
    for i in range(25):
        t = random.choice(double_neg_tasks_ta).format(
            subj=random.choice(["DSP", "Compiler", "DBMS", "Maths", "Cloud"])
        )
        tanglish_cases.append({
            "id": f"TG-TSK-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Task",
            "language": "Tanglish",
            "tags": ["tanglish", "task", "double_negation"]
        })

    # 2.2 Reminders (75 cases)
    rem_templates_ta = [
        "Amma ku {time_ta} call pannanum marakadha",
        "Doctor appointment {time_ta} irukku",
        "Night 10 ku BP tablet podanum remind pannu",
        "Manager kitta project status pesanum {time_ta}",
        "Kaalaila 6:30 ku gym poganum alarm vai",
        "Meeting {time_ta} start aagudhu alert pannu",
        "Friend birthday ku 12 midnight wish pannanum"
    ]
    times_ta = ["evening 6:30 ku", "night 9 manikku", "kaalaila 8:00 ku", "afternoon 3:15 ku", "sharp 5 PM ku", "innaiku 7 ku"]
    for i in range(50):
        t = random.choice(rem_templates_ta).format(time_ta=random.choice(times_ta))
        tanglish_cases.append({
            "id": f"TG-REM-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Reminder",
            "language": "Tanglish",
            "tags": ["tanglish", "reminder"]
        })
    double_neg_rems_ta = [
        "Maranthu poidaadha {time_ta} doctor kitta poganum",
        "Marakkama amma ku night call pannu",
        "Evening 6 ku gym polam maranthuraadha",
        "Client standup {time_ta} miss pannidaadha"
    ]
    for i in range(25):
        t = random.choice(double_neg_rems_ta).format(time_ta=random.choice(times_ta))
        tanglish_cases.append({
            "id": f"TG-REM-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Reminder",
            "language": "Tanglish",
            "tags": ["tanglish", "reminder", "double_negation"]
        })

    # 2.3 Shopping (75 cases)
    shop_templates_ta = [
        "Kadaila {items_ta} vangitu va",
        "Supermarket poitu {items_ta} vaanganum innaiku",
        "Medical shop la {med_items} vangitu va",
        "Stationery kadaila {stat_items} vangu da",
        "Veetuku varum bodhu {items_ta} marakkama vangitu va"
    ]
    items_ta_list = [
        "paal 1 litre and bread packet",
        "6 muttai and 1 kg thakkali",
        "vengayam 2 kg and urulai",
        "kaapi thool and sakkarai",
        "atta flour 5kg and cooking sunflower oil",
        "curd packet and cheese slices",
        "biscuit packet and maggie noodles"
    ]
    med_items_list = ["vicks vaporub and dolo 650", "paracetamol and cough syrup", "band-aid and dettol"]
    stat_items_list = ["blue gel pen and long size notebook", "sticky notes and highlighter", "A4 paper bundle"]
    
    for i in range(75):
        t = random.choice(shop_templates_ta).format(
            items_ta=random.choice(items_ta_list),
            med_items=random.choice(med_items_list),
            stat_items=random.choice(stat_items_list)
        )
        tanglish_cases.append({
            "id": f"TG-SHP-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Shopping",
            "language": "Tanglish",
            "tags": ["tanglish", "shopping"]
        })

    # 2.4 Payment_Due (70 cases)
    pay_templates_ta = [
        "Hostel rent 5th ku gpay pannanum",
        "Room rent owner ku transfer pannu innaiku",
        "Current bill kattanum deadline naalaiku",
        "Mess fee pay panni screenshot warden ku anupu",
        "Wifi bill expire aagudhu phonepe pannu",
        "Airtel recharge 28th ku mudiyudhu innaiku pannu",
        "College tuition fee semester 6 ku kattanum",
        "Gym subscription renewal fee transfer pannu"
    ]
    for i in range(50):
        t = random.choice(pay_templates_ta)
        tanglish_cases.append({
            "id": f"TG-PAY-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Payment_Due",
            "language": "Tanglish",
            "tags": ["tanglish", "payment"]
        })
    double_neg_pay_ta = [
        "Maranthu poidaadha room rent 5th ku kattanum",
        "Mess fee gpay panna maranthuraadha",
        "Current bill pay panna maranthu poidaadha da",
        "Wifi bill recharge panna marakkama gpay pannu"
    ]
    for i in range(20):
        t = random.choice(double_neg_pay_ta)
        tanglish_cases.append({
            "id": f"TG-PAY-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Payment_Due",
            "language": "Tanglish",
            "tags": ["tanglish", "payment", "double_negation"]
        })

    # 2.5 Carry (70 cases)
    carry_templates_ta = [
        "College id card marakkama eduthutu po",
        "Hall ticket and blue pen bag la vachiko da",
        "Laptop and charger lab ku eduthutu ponum",
        "Mazhai peiyum umbrella bag la vachiko",
        "Bike rc book and helmet eduthutu po veliya",
        "Water bottle and towel gym ku eduthuko",
        "Power bank and mobile cable eduthu vai",
        "Calculator and graph sheet exam ku eduthutu po"
    ]
    for i in range(50):
        t = random.choice(carry_templates_ta)
        tanglish_cases.append({
            "id": f"TG-CRY-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Carry",
            "language": "Tanglish",
            "tags": ["tanglish", "carry"]
        })
    double_neg_carry_ta = [
        "Hall ticket eduka maranthuraadha exam hall ku",
        "Laptop charger bag la vaikka maranthu poidaadha",
        "College id card eduka marakkama bag la podu",
        "Raincoat eduthutu poga maranthuraadha mazhai varum"
    ]
    for i in range(20):
        t = random.choice(double_neg_carry_ta)
        tanglish_cases.append({
            "id": f"TG-CRY-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Carry",
            "language": "Tanglish",
            "tags": ["tanglish", "carry", "double_negation"]
        })

    # 2.6 Place (70 cases)
    place_templates_ta = [
        "Innaiku clg mudinjadhum direct ah Apollo hospital reach aaganum",
        "SBI bank branch ku visit panrom naalaiku kaalaila",
        "Central railway station ku 5 manikku poganum",
        "Supermarket ku evening polam groceries vanga",
        "Car service center ku travel panrom delivery edukka",
        "Dentist clinic reach aaganum evening 6 pm kulla",
        "Library ku morning 10 ku poga plan pannirukom",
        "Airport terminal 1 ku drop panna travel aaganum"
    ]
    for i in range(70):
        t = random.choice(place_templates_ta)
        tanglish_cases.append({
            "id": f"TG-PLC-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Place",
            "language": "Tanglish",
            "tags": ["tanglish", "place"]
        })

    # 2.7 Note & Pure Negation (65 cases)
    pure_negations_ta = [
        "Milk vendam innaiku curd already fridge la irukku",
        "Innaiku rent pay panna vendam owner 10th sonnaru",
        "SBI bank ku poga vendam innaiku leave public holiday",
        "Veliya poga vendam outside heavy rain peiyudhu",
        "Laptop lab ku eduthu poga vendam professor sonnaru",
        "Assignment innaiku submit panna vendam deadline postpone",
        "Eggs vaanga vendam tray full ah irukku",
        "Bike service innaiku panna vendam mechanic closed"
    ]
    info_notes_ta = [
        "Hostel wifi password SecretPass99 innaiku change pannanga",
        "Bike mileage service ku apparam 48 kmpl varudhu",
        "Idea: offline voice assistant for Tamil students",
        "Doctor blood test report normal ah irukku",
        "Current meter reading 2410 units note panniko",
        "Car tyre air pressure 33 psi maintain pannanum"
    ]
    for i in range(40):
        t = random.choice(pure_negations_ta)
        tanglish_cases.append({
            "id": f"TG-NOT-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Note",
            "language": "Tanglish",
            "tags": ["tanglish", "note", "pure_negation"]
        })
    for i in range(25):
        t = random.choice(info_notes_ta)
        tanglish_cases.append({
            "id": f"TG-NOT-{len(tanglish_cases)+1:03d}",
            "text": t,
            "intent": "Note",
            "language": "Tanglish",
            "tags": ["tanglish", "note", "information"]
        })

    # Check totals
    print(f"English cases: {len(english_cases)}")
    print(f"Tanglish cases: {len(tanglish_cases)}")
    assert len(english_cases) == 500, f"Expected 500 English cases, got {len(english_cases)}"
    assert len(tanglish_cases) == 500, f"Expected 500 Tanglish cases, got {len(tanglish_cases)}"

    all_cases = english_cases + tanglish_cases
    random.seed(42)
    random.shuffle(all_cases)

    output_path = "ml_pipeline/benchmark_1000.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(all_cases, f, indent=2, ensure_ascii=False)
        
    print(f"✅ Created benchmark with {len(all_cases)} total cases at {output_path}")

if __name__ == "__main__":
    create_benchmark_1000()
