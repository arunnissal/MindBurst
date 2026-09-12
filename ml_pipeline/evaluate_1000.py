import json
import time
import os
import sys
import math
import re
import numpy as np

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

def load_benchmark(path="ml_pipeline/benchmark_1000.json"):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def load_edge_model(weights_path="ml_pipeline/edge_model_weights.json"):
    with open(weights_path, "r", encoding="utf-8") as f:
        model_data = json.load(f)
    return model_data

def build_neural_inference_fn(model_data):
    classes = model_data["classes"]
    vocab = model_data["vocabulary"]
    idf = model_data["idf"]
    weights = model_data["weights"]
    intercept = model_data["intercept"]
    token_regex = re.compile(r"\b\w+\b")

    def neural_predict(text):
        lower = text.lower()
        tokens = token_regex.findall(lower)
        ngrams = list(tokens)
        for i in range(len(tokens) - 1):
            ngrams.append(f"{tokens[i]} {tokens[i+1]}")

        tf_map = {}
        for ng in ngrams:
            if ng in vocab:
                idx = vocab[ng]
                tf_map[idx] = tf_map.get(idx, 0.0) + 1.0

        if not tf_map:
            return "Note", 0.50, {c: 1.0 / len(classes) for c in classes}

        sum_squares = 0.0
        tfidf_map = {}
        for idx, raw_tf in tf_map.items():
            sublinear_tf = 1.0 + math.log(raw_tf)
            val = sublinear_tf * idf[idx]
            tfidf_map[idx] = val
            sum_squares += val * val

        l2_norm = math.sqrt(sum_squares)
        if l2_norm > 0:
            for idx in list(tfidf_map.keys()):
                tfidf_map[idx] = tfidf_map[idx] / l2_norm

        logits = [intercept[c] for c in range(len(classes))]
        for c in range(len(classes)):
            cw = weights[c]
            dot = intercept[c]
            for idx, val in tfidf_map.items():
                dot += cw[idx] * val
            logits[c] = dot

        max_logit = max(logits)
        exps = [math.exp(l - max_logit) for l in logits]
        exp_sum = sum(exps)
        probs = [e / exp_sum for e in exps]

        best_idx = int(np.argmax(probs))
        prob_dict = {classes[i]: probs[i] for i in range(len(classes))}
        return classes[best_idx], probs[best_idx], prob_dict

    return neural_predict

def regex_predict(text):
    t = text.lower()
    # Baseline regex rules
    is_double_neg = ("don't forget" in t or "dont forget" in t or "do not forget" in t or 
                     "maranthu poidaadha" in t or "maranthuraadha" in t or "marakkama" in t or
                     "never skip" in t or "do not miss" in t or "don't miss" in t)
                     
    if not is_double_neg and ("don't" in t or "dont" in t or "do not" in t or "vendam" in t or "never" in t or "no need" in t):
        return "Note"
    if any(k in t for k in ["buy", "purchase", "shopping", "kadaila", "order", "vaanganum", "vangu"]):
        return "Shopping"
    if any(k in t for k in ["carry", "take", "pack", "bag", "eduthutu", "vachiko", "hall ticket", "umbrella", "raincoat"]):
        return "Carry"
    if any(k in t for k in ["pay", "rent", "fee", "bill", "gpay", "phonepe", "settle", "kattunum", "kattanum", "recharge"]):
        return "Payment_Due"
    if any(k in t for k in ["go to", "visit", "hospital", "station", "poganum", "reach", "terminal", "clinic", "travel"]):
        return "Place"
    if any(k in t for k in ["remind", "alarm", "call", "appointment", "pm", "am", "manikku", "standup", "meeting", "alert"]):
        return "Reminder"
    if any(k in t for k in ["wash", "clean", "submit", "complete", "finish", "send", "pannanum", "mudikanum", "review", "pr", "service"]):
        return "Task"
    return "Note"

def run_evaluation():
    print("=" * 70)
    print("🏁 MINDBURST 1,000 BENCHMARK EVALUATOR (500 English + 500 Tanglish)")
    print("=" * 70)

    dataset = load_benchmark()
    model_data = load_edge_model()
    neural_predict = build_neural_inference_fn(model_data)

    en_cases = [d for d in dataset if d["language"] == "English"]
    tg_cases = [d for d in dataset if d["language"] == "Tanglish"]

    print(f"\n📂 Benchmark Dataset Loaded:")
    print(f"   • Total Cases   : {len(dataset)}")
    print(f"   • English Cases : {len(en_cases)}")
    print(f"   • Tanglish Cases: {len(tg_cases)}")

    # 1. Evaluate Neural Model
    latencies = []
    neural_preds = []
    hard_negatives = []

    for item in dataset:
        t0 = time.perf_counter()
        pred_intent, conf, all_probs = neural_predict(item["text"])
        lat = (time.perf_counter() - t0) * 1000
        latencies.append(lat)
        neural_preds.append(pred_intent)

        if pred_intent != item["intent"]:
            hard_negatives.append({
                "id": item["id"],
                "text": item["text"],
                "language": item["language"],
                "ground_truth": item["intent"],
                "predicted": pred_intent,
                "confidence": round(conf, 4),
                "tags": item.get("tags", [])
            })

    ground_truth = [d["intent"] for d in dataset]
    overall_acc = accuracy_score(ground_truth, neural_preds) * 100
    avg_latency = np.mean(latencies)

    # English vs Tanglish breakdown
    en_gt = [d["intent"] for d in en_cases]
    en_preds = [neural_preds[i] for i, d in enumerate(dataset) if d["language"] == "English"]
    en_acc = accuracy_score(en_gt, en_preds) * 100

    tg_gt = [d["intent"] for d in tg_cases]
    tg_preds = [neural_preds[i] for i, d in enumerate(dataset) if d["language"] == "Tanglish"]
    tg_acc = accuracy_score(tg_gt, tg_preds) * 100

    # 2. Evaluate Baseline Regex
    t0 = time.perf_counter()
    regex_preds = [regex_predict(d["text"]) for d in dataset]
    reg_latency = ((time.perf_counter() - t0) * 1000) / len(dataset)
    regex_acc = accuracy_score(ground_truth, regex_preds) * 100

    print("\n" + "-" * 70)
    print(f"🎯 ACCURACY BENCHMARK RESULTS")
    print("-" * 70)
    print(f"   • MindBurst Edge Neural Model : {overall_acc:.2f}% (Latency: {avg_latency:.3f} ms)")
    print(f"     ├── English (500 cases)     : {en_acc:.2f}%")
    print(f"     └── Tanglish (500 cases)    : {tg_acc:.2f}%")
    print(f"   • Baseline Regex Rules        : {regex_acc:.2f}% (Latency: {reg_latency:.3f} ms)")

    # Per-Class Classification Report
    classes = model_data["classes"]
    clf_report = classification_report(ground_truth, neural_preds, target_names=classes, output_dict=True)
    print("\n📊 PER-CLASS DETAILED BREAKDOWN:")
    print(f"{'Class':<15} | {'Precision':<10} | {'Recall':<10} | {'F1-Score':<10} | {'Support':<8}")
    print("-" * 65)
    for c in classes:
        cr = clf_report[c]
        print(f"{c:<15} | {cr['precision']*100:<9.1f}% | {cr['recall']*100:<9.1f}% | {cr['f1-score']*100:<9.1f}% | {cr['support']:<8}")

    # Tag analysis: double negation vs pure negation
    double_neg_cases = [d for d in dataset if "double_negation" in d.get("tags", [])]
    if double_neg_cases:
        dn_gt = [d["intent"] for d in double_neg_cases]
        dn_preds = [neural_preds[dataset.index(d)] for d in double_neg_cases]
        dn_acc = accuracy_score(dn_gt, dn_preds) * 100
        print(f"\n🛡️ Double-Negation Defense Accuracy: {dn_acc:.2f}% ({len(double_neg_cases)} cases)")

    pure_neg_cases = [d for d in dataset if "pure_negation" in d.get("tags", [])]
    if pure_neg_cases:
        pn_gt = [d["intent"] for d in pure_neg_cases]
        pn_preds = [neural_preds[dataset.index(d)] for d in pure_neg_cases]
        pn_acc = accuracy_score(pn_gt, pn_preds) * 100
        print(f"🚫 Pure-Negation Protection Accuracy : {pn_acc:.2f}% ({len(pure_neg_cases)} cases)")

    # Hard Negatives
    print(f"\n🔍 Hard Negatives Discovered: {len(hard_negatives)} / {len(dataset)}")
    with open("ml_pipeline/hard_negatives.json", "w", encoding="utf-8") as f:
        json.dump(hard_negatives, f, indent=2, ensure_ascii=False)
        
    if hard_negatives:
        print("\nTop Hard Negative Samples:")
        for h in hard_negatives[:10]:
            print(f"   ❌ [{h['language']}] '{h['text']}' -> Predicted: {h['predicted']}, Expected: {h['ground_truth']} ({h['confidence']*100:.1f}%)")

    return {
        "overall_accuracy": overall_acc,
        "english_accuracy": en_acc,
        "tanglish_accuracy": tg_acc,
        "regex_accuracy": regex_acc,
        "avg_latency_ms": avg_latency,
        "num_hard_negatives": len(hard_negatives)
    }

if __name__ == "__main__":
    run_evaluation()
