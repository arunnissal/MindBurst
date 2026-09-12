import json
import random
import os

# 7 Target Intent Classes
INTENTS = [
    "Task",
    "Reminder",
    "Shopping",
    "Payment_Due",
    "Carry",
    "Place",
    "Note"
]

def generate_dataset(total_samples=1600):
    samples = []
    
    # Templates & vocabularies for realistic English + Tanglish synthesis
    
    # 1. Tasks
    task_verbs_en = ["complete", "finish", "submit", "prepare", "wash", "clean", "fix", "send", "update", "debug", "review"]
    task_verbs_ta = ["mudikanum", "pannanum", "wash pannanum", "clean panni vai", "send pannu", "ready pannu"]
    task_objects_student = ["assignment", "lab record", "seminar ppt", "project report", "internship application", "exam notes"]
    task_objects_prof = ["sprint tickets", "PR review", "quarterly deck", "client email", "architecture doc", "standup notes"]
    task_objects_home = ["clothes", "kitchen sink", "hall room", "curtains", "fridge cleaning", "water filter change"]
    task_objects_biz = ["client proposal", "vendor agreement", "monthly invoice", "quotation for customer", "balance sheet"]
    
    # 2. Reminders
    times = ["at 5 PM", "at 6:30 PM", "morning 9 AM", "night 10 PM", "in 2 hours", "by 4 PM", "sharp 7 AM", "afternoon 2 PM"]
    times_ta = ["innaiku 5 manikku", "naalaiku kaalaila 8 ku", "evening 6:30 ku", "night 9 ku", "2 mani nerathula"]
    reminder_actions = ["call mom", "call manager", "take blood pressure medicine", "take vitamin tablet", "zoom meeting", "doctor appointment", "alarm for medicine", "water intake"]
    reminder_actions_ta = ["amma ku call pannu", "doctor appointment marakadha", "medicine podanum", "manager call irukku", "tab pottuko"]

    # 3. Shopping
    shop_verbs_en = ["buy", "purchase", "get", "pick up", "order", "restock"]
    shop_verbs_ta = ["vangitu va", "vangikanum", "vaanga vendum", "order pannu", "kadaila vaangu"]
    shop_items = [
        "milk and bread", "eggs and bananas", "curd and tomatoes", "onions and potatoes",
        "coffee powder", "toothpaste and soap", "notebook and blue pen", "shampoo bottle",
        "paracetamol and vicks", "atta flour and cooking oil", "maggie and biscuits",
        "washing detergent", "fruits for home", "chicken and masala"
    ]
    shop_items_ta = [
        "paal and bread", "muttai and thakkali", "vengayam and urulai", "kaapi thool",
        "soap and paste", "marundhu and tablet", "arisi and paruppu", "oil packet"
    ]

    # 4. Payment_Due
    pay_verbs = ["pay", "clear", "transfer", "send money for", "settle", "gpay", "phonepe"]
    pay_verbs_ta = ["kattunum", "pay pannanum", "gpay pannu", "settle pannanum", "transfer pannidu"]
    pay_objects_hostel = ["hostel rent", "mess fee", "room rent on 5th", "caution deposit", "hostel electricity charge"]
    pay_objects_rent = ["house rent on 1st", "maintenance fee", "water bill", "flat rent to owner"]
    pay_objects_general = ["wifi bill", "electricity bill", "mobile recharge on 28th", "gym membership fee", "credit card bill", "milkman payment", "college tuition fee"]
    
    # 5. Carry
    carry_verbs = ["carry", "bring", "take", "pack", "don't forget to take", "keep in bag"]
    carry_verbs_ta = ["eduthutu po", "bag la vai", "marakkama kondu po", "maranthudadha take"]
    carry_items = [
        "laptop and charger", "umbrella and raincoat", "college id card", "hall ticket",
        "water bottle", "house keys", "power bank", "bike RC book and helmet",
        "office badge", "stethoscope and lab coat", "gym shoes and towel", "passport and ticket"
    ]
    
    # 6. Places
    place_verbs = ["go to", "visit", "reach", "travel to", "drop by", "head to"]
    place_verbs_ta = ["poganum", "poitu va", "visit panrom", "reach aaganum"]
    places = [
        "Apollo hospital", "central library", "metro station", "railway station",
        "SBI bank branch", "supermarket", "car service center", "dentist clinic",
        "client office in T Nagar", "airport terminal 2", "post office", "gym center"
    ]

    # 7. Notes & Negation Protection
    note_ideas = [
        "Idea for startup: automated expense tracker",
        "Book recommendation: Atomic Habits by James Clear",
        "Movie to watch on weekend: Interstellar",
        "Quote: Consistency beats talent every single day",
        "Meeting summary: discuss quarterly roadmap next Monday",
        "Research about Flutter on-device neural model quantization",
        "Wifi password for new router is SecretPass99"
    ]
    # Negation samples (must be classified as Note/Reminder, NOT Task/Shopping)
    negations = [
        "Don't buy milk today fridge has two packets",
        "Milk vendam innaiku curd already irukku",
        "Do not pay rent today owner said wait till 10th",
        "Never skip morning breakfast",
        "Don't wash white shirt with colored clothes",
        "Veliya poga vendam heavy rain outside",
        "Don't carry laptop to lab prof said no need",
        "No need to buy eggs today",
        "Don't submit project yet pending review",
        "Avoid going to bank today it is a public holiday"
    ]

    # Generate balanced samples
    # Tasks
    for _ in range(250):
        v = random.choice(task_verbs_en)
        obj = random.choice(task_objects_student + task_objects_prof + task_objects_home + task_objects_biz)
        day = random.choice(["today", "tomorrow", "before Friday", "by evening", "this weekend", ""])
        samples.append((f"{v.capitalize()} {obj} {day}".strip(), "Task"))
        
        # Tanglish tasks
        v_ta = random.choice(task_verbs_ta)
        samples.append((f"{obj.capitalize()} innaiku {v_ta}", "Task"))

    # Reminders
    for _ in range(240):
        act = random.choice(reminder_actions)
        t = random.choice(times)
        samples.append((f"Remind me to {act} {t}", "Reminder"))
        
        # Tanglish reminders
        act_ta = random.choice(reminder_actions_ta)
        t_ta = random.choice(times_ta)
        samples.append((f"{act_ta} {t_ta}", "Reminder"))

    # Shopping
    for _ in range(240):
        v = random.choice(shop_verbs_en)
        item = random.choice(shop_items)
        when = random.choice(["today", "from supermarket", "in evening", "for home", ""])
        samples.append((f"{v.capitalize()} {item} {when}".strip(), "Shopping"))
        
        # Tanglish shopping
        v_ta = random.choice(shop_verbs_ta)
        item_ta = random.choice(shop_items_ta)
        samples.append((f"Kadaila {item_ta} {v_ta}", "Shopping"))

    # Payment_Due
    for _ in range(240):
        v = random.choice(pay_verbs)
        bill = random.choice(pay_objects_hostel + pay_objects_rent + pay_objects_general)
        samples.append((f"{v.capitalize()} {bill}", "Payment_Due"))
        
        # Tanglish payment
        v_ta = random.choice(pay_verbs_ta)
        samples.append((f"{bill.capitalize()} {v_ta}", "Payment_Due"))

    # Carry
    for _ in range(220):
        v = random.choice(carry_verbs)
        item = random.choice(carry_items)
        where = random.choice(["tomorrow to college", "for tomorrow office", "when going out", "in backpack", ""])
        samples.append((f"{v.capitalize()} {item} {where}".strip(), "Carry"))
        
        # Tanglish carry
        v_ta = random.choice(carry_verbs_ta)
        samples.append((f"{item.capitalize()} {v_ta}", "Carry"))

    # Places
    for _ in range(220):
        v = random.choice(place_verbs)
        p = random.choice(places)
        when = random.choice(["tomorrow 10 AM", "today evening", "this Saturday", "at 4 PM", ""])
        samples.append((f"{v.capitalize()} {p} {when}".strip(), "Place"))
        
        # Tanglish place
        v_ta = random.choice(place_verbs_ta)
        samples.append((f"{p} ku {v_ta}", "Place"))

    # Notes & Negation Protection
    for _ in range(120):
        samples.append((random.choice(note_ideas), "Note"))
    for _ in range(120):
        samples.append((random.choice(negations), "Note"))

    # Shuffle
    random.seed(42)
    random.shuffle(samples)
    
    return samples[:total_samples]

if __name__ == "__main__":
    os.makedirs("ml_pipeline", exist_ok=True)
    data = generate_dataset(1600)
    
    with open("ml_pipeline/dataset.json", "w", encoding="utf-8") as f:
        json.dump([{"text": text, "intent": intent} for text, intent in data], f, indent=2)
        
    print(f"Generated {len(data)} labeled training samples across 7 intent classes!")
    counts = {}
    for _, intent in data:
        counts[intent] = counts.get(intent, 0) + 1
    for k, v in sorted(counts.items()):
        print(f"  {k:15}: {v} samples")
