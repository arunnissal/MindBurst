import json
import random
import os

INTENTS = [
    "Task",
    "Reminder",
    "Shopping",
    "Payment_Due",
    "Carry",
    "Place",
    "Note"
]

def generate_dataset(total_samples=1800):
    samples = []
    
    # 1. Tasks & Double Negation Tasks
    task_verbs_en = ["complete", "finish", "submit", "prepare", "wash", "clean", "fix", "send", "update", "debug", "review"]
    task_verbs_ta = ["mudikanum", "pannanum", "wash pannanum", "clean panni vai", "send pannu", "ready pannu"]
    task_objects = ["assignment", "lab record", "seminar ppt", "project report", "clothes", "kitchen sink", "client proposal", "invoice", "sprint tickets"]
    
    # Standard tasks
    for _ in range(200):
        v = random.choice(task_verbs_en)
        obj = random.choice(task_objects)
        day = random.choice(["today", "tomorrow", "tmrw", "before Friday", "by evening", ""])
        samples.append((f"{v.capitalize()} {obj} {day}".strip(), "Task"))
        
        v_ta = random.choice(task_verbs_ta)
        samples.append((f"{obj.capitalize()} innaiku {v_ta}", "Task"))

    # Double negation tasks (Must be classified as Task, NOT Note!)
    double_neg_tasks = [
        "Don't forget to submit lab record tomorrow",
        "Dont forget to complete the assignment today",
        "Do not miss submitting project report before Friday",
        "Never skip washing clothes today",
        "Maranthu poidaadha seminar ppt ready pannu",
        "Marakkama lab record finish pannanum tmrw",
        "Don't forget to send client proposal by evng",
        "Do not delay fixing the kitchen sink"
    ]
    for _ in range(12):
        for s in double_neg_tasks:
            samples.append((s, "Task"))

    # 2. Reminders & Double Negation Reminders
    times = ["at 5 PM", "at 6:30 PM", "morning 9 AM", "night 10 PM", "in 2 hours", "by 4 PM", "sharp 7 AM", "afternoon 2 PM", "evng 6 pm"]
    times_ta = ["innaiku 5 manikku", "naalaiku kaalaila 8 ku", "evening 6:30 ku", "night 9 ku", "2 mani nerathula"]
    reminder_actions = ["call mom", "call manager", "take blood pressure medicine", "take vitamin tablet", "zoom meeting", "doctor appointment", "water intake"]
    
    for _ in range(200):
        act = random.choice(reminder_actions)
        t = random.choice(times)
        preamble = random.choice(["Hey Mind, ", "Please ", "Bro listen, ", ""])
        samples.append((f"{preamble}remind me to {act} {t}".strip(), "Reminder"))
        
        act_ta = random.choice(["amma ku call pannu", "doctor appointment marakadha", "medicine podanum", "manager call irukku"])
        t_ta = random.choice(times_ta)
        samples.append((f"{act_ta} {t_ta}", "Reminder"))

    # Double negation reminders
    double_neg_reminders = [
        "Do not miss the 5 PM client standup call",
        "Don't forget to call doctor at 6:30 PM",
        "Do not forget meeting with manager at 4 PM",
        "Maranthu poidaadha evening 6 ku gym polam",
        "Marakkama take medicine at night 10 PM",
        "Don't miss the 9 AM team standup tomorrow"
    ]
    for _ in range(12):
        for s in double_neg_reminders:
            samples.append((s, "Reminder"))

    # 3. Shopping
    shop_items = [
        "milk and bread", "eggs and bananas", "curd and tomatoes", "onions and potatoes",
        "coffee powder", "toothpaste and soap", "notebook and blue pen", "shampoo bottle",
        "paracetamol and vicks", "atta flour and cooking oil", "maggie and biscuits",
        "2 kg onions, 1 litre milk, and 6 eggs", "1.5 kg tomatoes and sugar"
    ]
    for _ in range(200):
        item = random.choice(shop_items)
        v = random.choice(["buy", "purchase", "pick up", "order", "restock"])
        samples.append((f"{v.capitalize()} {item} today from supermarket", "Shopping"))
        
        item_ta = random.choice(["paal and bread", "muttai and thakkali", "vengayam and urulai", "kaapi thool", "oil packet"])
        samples.append((f"Kadaila {item_ta} vangitu va", "Shopping"))

    # 4. Payment_Due & Double Negation Bills
    pay_objects = [
        "hostel rent on 5th", "mess fee", "house rent on 1st", "electricity bill",
        "wifi bill", "mobile recharge on 28th", "gym membership fee", "college tuition fee", "clg fee"
    ]
    for _ in range(190):
        bill = random.choice(pay_objects)
        v = random.choice(["pay", "clear", "transfer", "settle", "gpay", "phonepe"])
        samples.append((f"{v.capitalize()} {bill}", "Payment_Due"))
        samples.append((f"{bill.capitalize()} innaiku gpay pannu", "Payment_Due"))

    # Double negation payments
    double_neg_payments = [
        "Don't forget to pay electricity bill today",
        "Dont forget to gpay hostel rent on 5th",
        "Do not delay paying house rent on 1st",
        "Maranthu poidaadha room rent 5th ku kattanum",
        "Marakkama mess fee gpay pannanum",
        "Don't forget mobile recharge on 28th"
    ]
    for _ in range(12):
        for s in double_neg_payments:
            samples.append((s, "Payment_Due"))

    # 5. Carry & Double Negation Carry
    carry_items = [
        "laptop and charger", "umbrella and raincoat", "college id card", "hall ticket",
        "water bottle", "house keys", "power bank", "bike rc book and helmet", "passport and ticket"
    ]
    for _ in range(190):
        item = random.choice(carry_items)
        v = random.choice(["carry", "take", "bring", "pack", "keep in bag"])
        samples.append((f"{v.capitalize()} {item} tomorrow to college", "Carry"))
        samples.append((f"{item.capitalize()} marakkama eduthutu po", "Carry"))

    # Double negation carry
    double_neg_carry = [
        "Dont forget to bring hall ticket tomorrow",
        "Don't forget to carry laptop and charger to lab",
        "Do not forget to take umbrella and raincoat",
        "Maranthu poidaadha college id card eduthutu po",
        "Raincoat and umbrella bag la vachiko mazhai peiyum"
    ]
    for _ in range(12):
        for s in double_neg_carry:
            samples.append((s, "Carry"))

    # 6. Places
    places = ["Apollo hospital", "central library", "metro station", "railway station", "SBI bank branch", "supermarket", "car service center", "dentist clinic", "hosptl"]
    for _ in range(180):
        p = random.choice(places)
        samples.append((f"Go to {p} tomorrow at 10 AM", "Place"))
        samples.append((f"Reach {p} by 4 pm", "Place"))
        samples.append((f"{p} ku visit panrom evening", "Place"))
        samples.append((f"Innaiku clg mudinjadhum direct ah {p} reach aaganum", "Place"))

    # 7. Pure Negation & Notes (MUST REMAIN NOTE!)
    pure_negations = [
        "Don't buy milk today fridge has two packets",
        "Milk vendam innaiku curd already irukku",
        "Do not pay rent today owner said wait till 10th",
        "Avoid going to SBI bank today it is closed",
        "Never skip morning breakfast",
        "Don't wash white shirt with colored clothes",
        "Veliya poga vendam heavy rain outside",
        "Don't carry laptop to lab prof said no need",
        "No need to buy eggs today",
        "Don't submit project yet pending review",
        "Idea for startup: automated expense tracker",
        "Book recommendation: Atomic Habits by James Clear",
        "Wifi password for new router is SecretPass99"
    ]
    for _ in range(14):
        for s in pure_negations:
            samples.append((s, "Note"))

    # Shuffle
    random.seed(42)
    random.shuffle(samples)
    return samples[:total_samples]

if __name__ == "__main__":
    os.makedirs("ml_pipeline", exist_ok=True)
    data = generate_dataset(1800)
    with open("ml_pipeline/dataset.json", "w", encoding="utf-8") as f:
        json.dump([{"text": text, "intent": intent} for text, intent in data], f, indent=2)
    print(f"Generated {len(data)} enhanced training samples!")
