import json
import random
import os
import sys

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

INTENTS = [
    "Task",
    "Reminder",
    "Shopping",
    "Payment_Due",
    "Carry",
    "Place",
    "Note"
]

def generate_dataset(total_samples=3800):
    samples = []

    # =========================================================================
    # 1. TASKS (English & Tanglish)
    # =========================================================================
    task_verbs_en = [
        "complete", "finish", "submit", "prepare", "wash", "clean", "fix", "send",
        "update", "debug", "review", "draft", "compile", "inspect", "write unit tests for",
        "code freeze", "upload", "sign and return", "service"
    ]
    task_verbs_ta = [
        "mudikanum", "pannanum", "wash pannanum", "clean panni vai", "send pannu",
        "ready pannu", "anupanum", "ezhudhanum", "service panni edu", "fix pannanum",
        "upload pannu", "merge pannanum", "review ku anupu", "sign vanga po"
    ]
    task_objects = [
        "assignment", "lab record", "seminar ppt", "project report", "clothes", "laundry",
        "kitchen sink", "client proposal", "invoice spreadsheet", "sprint backlog tickets",
        "REST API documentation", "pull request on GitHub", "server logs for memory leak",
        "biometric login crash", "quarterly report", "two-wheeler bike", "resume on job portal",
        "white shirts", "car windshield", "car engine", "winter blankets", "kitchen dishes"
    ]
    
    for _ in range(320):
        v = random.choice(task_verbs_en)
        obj = random.choice(task_objects)
        day = random.choice(["today", "tomorrow", "tmrw", "before Friday", "by evening", "before deadline", ""])
        samples.append((f"{v.capitalize()} {obj} {day}".strip(), "Task"))
        
        v_ta = random.choice(task_verbs_ta)
        samples.append((f"{obj.capitalize()} innaiku {v_ta}", "Task"))
        samples.append((f"Naalaiku kulla {obj} {v_ta}", "Task"))

    # Double negation tasks (MUST BE TASK, NOT NOTE!)
    double_neg_tasks = [
        "Don't forget to submit lab record tomorrow",
        "Dont forget to complete the assignment today",
        "Do not miss sending the client proposal before Friday",
        "Never skip washing clothes today",
        "Maranthu poidaadha seminar ppt ready pannu",
        "Marakkama lab record finish pannanum tmrw",
        "Don't forget to send client invoice by evng",
        "Do not delay fixing the kitchen sink",
        "Please don't forget to review the PR before merging",
        "Dont miss updating the sprint board today",
        "Maranthu poidaadha client invoice mail anupu",
        "Thuni wash panna maranthuraadha innaiku"
    ]
    for _ in range(25):
        for s in double_neg_tasks:
            samples.append((s, "Task"))

    # =========================================================================
    # 2. REMINDERS (English & Tanglish)
    # =========================================================================
    times_en = [
        "at 5 PM", "at 6:30 PM", "morning 9 AM", "night 10 PM", "in 2 hours",
        "by 4 PM", "sharp 7 AM", "afternoon 2 PM", "at 3.45pm", "at 7:15 AM",
        "at 12 midnight", "in 30 minutes"
    ]
    times_ta = [
        "innaiku 5 manikku", "naalaiku kaalaila 8 ku", "evening 6:30 ku",
        "night 9 ku", "night 10 manikku", "afternoon 3:15 ku", "sharp 5 PM ku", "12 midnight ku"
    ]
    reminder_actions_en = [
        "call Mom", "call manager", "call Dr. Smith for appointment", "take blood pressure tablet",
        "take vitamin D3 supplement", "join Google Meet client standup", "attend project sync with team",
        "drink 2 glasses of water", "turn off geyser heater", "wish friend happy birthday",
        "check flight check-in status", "feed pet dog evening meal"
    ]
    reminder_actions_ta = [
        "amma ku call pannu", "doctor appointment marakadha", "BP tablet podanum",
        "manager kitta project status pesanum", "gym poganum alarm vai", "meeting start aagudhu alert pannu",
        "friend birthday ku wish pannanum"
    ]

    for _ in range(300):
        act = random.choice(reminder_actions_en)
        t = random.choice(times_en)
        preamble = random.choice(["Hey Mind, ", "Please ", "Bro listen, ", "Can you ", ""])
        samples.append((f"{preamble}remind me to {act} {t}".strip(), "Reminder"))
        
        act_ta = random.choice(reminder_actions_ta)
        t_ta = random.choice(times_ta)
        samples.append((f"{act_ta} {t_ta}", "Reminder"))
        samples.append((f"{t_ta} {act_ta} remind pannu", "Reminder"))

    # Double negation reminders
    double_neg_reminders = [
        "Do not miss the 5 PM client standup call",
        "Don't forget to call doctor at 6:30 PM",
        "Do not forget meeting with manager at 4 PM",
        "Maranthu poidaadha evening 6 ku gym polam",
        "Marakkama take medicine at night 10 PM",
        "Don't miss the 9 AM team standup tomorrow",
        "Maranthu poidaadha doctor appointment evening 6 ku",
        "Marakkama amma ku night call pannu",
        "Client standup 5 PM ku miss pannidaadha"
    ]
    for _ in range(25):
        for s in double_neg_reminders:
            samples.append((s, "Reminder"))

    # =========================================================================
    # 3. SHOPPING (English & Tanglish)
    # =========================================================================
    shop_items_en = [
        "milk and bread", "eggs and bananas", "curd and tomatoes", "onions and potatoes",
        "coffee powder and low-fat milk", "toothpaste and bathing soap", "notebook and blue pens",
        "shampoo bottle and conditioner", "paracetamol tablets and vicks", "atta flour and sunflower cooking oil",
        "maggie noodles and biscuits", "2 kg onions, 1 litre milk, and 6 eggs", "1.5 kg tomatoes and ginger",
        "sticky notes and highlighter", "dark chocolate and green tea bags"
    ]
    shop_items_ta = [
        "paal and bread packet", "muttai 6 and thakkali 1 kg", "vengayam and urulai",
        "kaapi thool and sakkarai", "oil packet and atta flour", "vicks and dolo 650",
        "curd packet and cheese", "blue gel pen and notebook"
    ]
    for _ in range(300):
        item = random.choice(shop_items_en)
        v = random.choice(["buy", "purchase", "pick up", "order", "restock", "get"])
        loc = random.choice(["from supermarket", "from nearby grocery store", "online via Zepto", "from pharmacy", ""])
        samples.append((f"{v.capitalize()} {item} {loc} today".strip(), "Shopping"))
        
        item_ta = random.choice(shop_items_ta)
        v_ta = random.choice(["vangitu va", "vaanganum", "vangu da", "marakkama vangitu va"])
        samples.append((f"Kadaila {item_ta} {v_ta}", "Shopping"))
        samples.append((f"Supermarket poitu {item_ta} {v_ta}", "Shopping"))

    # =========================================================================
    # 4. PAYMENT_DUE (English & Tanglish)
    # =========================================================================
    pay_objects_en = [
        "hostel rent on 5th", "monthly mess fee", "house rent on 1st of month",
        "electricity bill before power cut", "broadband optical fiber wifi bill",
        "Airtel mobile recharge expiring on 28th", "gym membership quarterly fee",
        "college tuition fee for 6th semester", "credit card outstanding balance",
        "vehicle comprehensive insurance renewal before due date", "piped gas cylinder bill",
        "apartment maintenance fee"
    ]
    pay_objects_ta = [
        "hostel rent 5th ku", "room rent owner ku", "current bill",
        "mess fee", "wifi bill recharge", "Airtel mobile recharge 28th ku",
        "college tuition fee semester 6 ku", "gym subscription renewal fee"
    ]
    for _ in range(300):
        bill = random.choice(pay_objects_en)
        v = random.choice(["pay", "clear", "transfer", "settle", "gpay", "phonepe", "make payment for"])
        samples.append((f"{v.capitalize()} {bill}", "Payment_Due"))
        samples.append((f"Transfer {bill} before due date", "Payment_Due"))
        
        bill_ta = random.choice(pay_objects_ta)
        samples.append((f"{bill_ta.capitalize()} innaiku gpay pannu", "Payment_Due"))
        samples.append((f"{bill_ta.capitalize()} kattanum deadline naalaiku", "Payment_Due"))
        samples.append((f"{bill_ta.capitalize()} transfer pannu owner ku", "Payment_Due"))

    # Double negation payments
    double_neg_payments = [
        "Don't forget to pay electricity bill today",
        "Dont forget to gpay hostel rent on 5th",
        "Do not delay paying house rent on 1st",
        "Maranthu poidaadha room rent 5th ku kattanum",
        "Marakkama mess fee gpay pannanum",
        "Don't forget mobile recharge on 28th",
        "Do not miss paying wifi bill before tomorrow",
        "Mess fee gpay panna maranthuraadha",
        "Current bill pay panna maranthu poidaadha da"
    ]
    for _ in range(25):
        for s in double_neg_payments:
            samples.append((s, "Payment_Due"))

    # =========================================================================
    # 5. CARRY (English & Tanglish)
    # =========================================================================
    carry_items_en = [
        "laptop and type-C charger", "umbrella and compact raincoat because rain is forecasted",
        "college id card and hall ticket", "scientific calculator and blue pen",
        "water bottle and gym towel", "house keys and leather wallet",
        "power bank and charging cable", "bike helmet and driving license",
        "passport, visa copy, and boarding pass", "stethoscope and white lab coat",
        "noise-cancelling headphones and notebook"
    ]
    carry_items_ta = [
        "college id card and hall ticket", "laptop and charger",
        "umbrella and raincoat", "bike rc book and helmet",
        "water bottle and towel", "power bank and cable", "calculator and graph sheet"
    ]
    for _ in range(300):
        item = random.choice(carry_items_en)
        v = random.choice(["carry", "take", "bring", "pack in bag", "keep with you"])
        dest = random.choice(["to exam hall", "to campus lab", "to office tomorrow", "for travel", "to college today"])
        samples.append((f"{v.capitalize()} {item} {dest}".strip(), "Carry"))
        
        item_ta = random.choice(carry_items_ta)
        samples.append((f"{item_ta.capitalize()} marakkama eduthutu po", "Carry"))
        samples.append((f"{item_ta.capitalize()} bag la vachiko da", "Carry"))
        samples.append((f"{item_ta.capitalize()} eduthutu ponum veliya", "Carry"))

    # Double negation carry
    double_neg_carry = [
        "Dont forget to bring hall ticket tomorrow",
        "Don't forget to carry laptop and charger to lab",
        "Do not forget to take umbrella and raincoat",
        "Maranthu poidaadha college id card eduthutu po",
        "Raincoat and umbrella bag la vachiko mazhai peiyum",
        "Hall ticket eduka maranthuraadha exam hall ku",
        "Laptop charger bag la vaikka maranthu poidaadha",
        "Marakkama id card eduthutu po"
    ]
    for _ in range(25):
        for s in double_neg_carry:
            samples.append((s, "Carry"))

    # =========================================================================
    # 6. PLACES (English & Tanglish - HARDENED TRANSIT & ERRANDS)
    # =========================================================================
    places_en = [
        "Apollo hospital", "central railway station", "SBI bank branch", "city civil court",
        "regional passport seva kendra", "dentist dental clinic", "car authorized service center",
        "international airport terminal 1", "central public library", "metro railway station",
        "supermarket plaza", "government municipal corporation office", "mechanic garage", "hosptl"
    ]
    places_ta = [
        "Apollo hospital", "SBI bank branch", "central railway station",
        "supermarket", "car service center", "dentist clinic", "central library",
        "airport terminal 1", "metro station", "hosptl"
    ]
    place_templates_en = [
        "Go to {place} tomorrow at 10 AM",
        "Reach {place} before 4 PM for scheduled appointment",
        "Visit {place} to collect certified documents",
        "Head over to {place} by evening",
        "Travel to {place} tomorrow morning",
        "Stop by {place} on the way back home",
        "Heading to {place} for routine checkup"
    ]
    place_templates_ta = [
        "Innaiku clg mudinjadhum direct ah {place} reach aaganum",
        "{place} ku visit panrom naalaiku kaalaila",
        "{place} ku 5 manikku poganum",
        "{place} ku evening polam",
        "{place} ku travel panrom delivery edukka",
        "{place} reach aaganum evening 6 pm kulla",
        "{place} ku drop panna travel aaganum"
    ]
    for _ in range(320):
        p = random.choice(places_en)
        samples.append((random.choice(place_templates_en).format(place=p), "Place"))
        
        p_ta = random.choice(places_ta)
        samples.append((random.choice(place_templates_ta).format(place=p_ta), "Place"))

    # =========================================================================
    # 7. NOTES & PURE NEGATIONS (English & Tanglish - HARDENED)
    # =========================================================================
    pure_negations = [
        "Don't buy milk today fridge has two unopened packets",
        "Do not pay house rent today landlord requested payment next week",
        "Avoid going to SBI bank today it is declared a public holiday",
        "Never wash white linen shirts with dark blue jeans",
        "No need to carry umbrella today weather is completely sunny",
        "Don't submit project proposal yet awaiting senior manager signoff",
        "Never skip morning breakfast before heavy weight lifting",
        "Do not visit municipal office on Saturday it remains closed",
        "No need to buy eggs today tray is already full",
        "Don't transfer mess fee until revised ledger is issued",
        "Milk vendam innaiku curd already fridge la irukku",
        "Innaiku rent pay panna vendam owner 10th sonnaru",
        "SBI bank ku poga vendam innaiku leave public holiday",
        "Veliya poga vendam outside heavy rain peiyudhu",
        "Laptop lab ku eduthu poga vendam professor sonnaru",
        "Assignment innaiku submit panna vendam deadline postpone",
        "Eggs vaanga vendam tray full ah irukku",
        "Bike service innaiku panna vendam mechanic closed",
        "No need to recharge wifi today valid till next week",
        "Don't travel to airport today flight is cancelled"
    ]
    informational_notes = [
        "Idea for startup: edge-computed personal intelligence engine without cloud",
        "Book recommendation: Atomic Habits by James Clear on compounding habits",
        "WiFi password for office conference room is AlphaSec99",
        "Recommended four-wheeler tyre pressure is 33 PSI cold",
        "Blood donor group is O positive and emergency contact is saved",
        "Vehicle registration number is TN 09 BK 4021",
        "Quote of the day: consistency beats intensity in long term execution",
        "Key insight: vector TF-IDF runs in sub-millisecond on mobile CPU",
        "Hostel wifi password SecretPass99 innaiku change pannanga",
        "Bike mileage service ku apparam 48 kmpl varudhu",
        "Idea: offline voice assistant for Tamil students",
        "Doctor blood test report normal ah irukku",
        "Current meter reading 2410 units note panniko",
        "Car tyre air pressure 33 psi maintain pannanum",
        "Note: Server database backup runs every midnight at 2 AM",
        "Important contact number for plumbing maintenance is 9840123456"
    ]
    for _ in range(20):
        for s in pure_negations:
            samples.append((s, "Note"))
        for s in informational_notes:
            samples.append((s, "Note"))

    # Shuffle
    random.seed(42)
    random.shuffle(samples)
    return samples[:total_samples]

if __name__ == "__main__":
    os.makedirs("ml_pipeline", exist_ok=True)
    data = generate_dataset(3800)
    with open("ml_pipeline/dataset.json", "w", encoding="utf-8") as f:
        json.dump([{"text": text, "intent": intent} for text, intent in data], f, indent=2, ensure_ascii=False)
    print(f"✅ Generated {len(data)} hardened training samples across 7 intents!")
