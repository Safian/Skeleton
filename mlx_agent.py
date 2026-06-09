#!/usr/bin/env python3
"""
mlx_agent.py — Egyszerű agent-loop a lokális MLX modellnek (OpenAI-kompatibilis API).

A modell (mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit, http://localhost:8080)
nem tud önmagától fájlt írni vagy parancsot futtatni — ez a script ad neki
"kezeket": minden válaszából kiolvas egy JSON akciót, végrehajtja a te gépeden,
majd visszaküldi az eredményt, hogy a modell tovább tudjon iterálni.

BIZTONSÁG:
- Alapértelmezésben minden side-effect (run_command, write_file) előtt megerősítést
  kér tőled (y/n). A --yes kapcsolóval ez kikapcsolható — csak akkor használd,
  ha megbízol a feladatban és a modell válaszaiban!
- read_file / list_dir mindig megerősítés nélkül lefut (csak olvasás).
- Max. iterációszám van beépítve a végtelen ciklus elkerülésére.

HASZNÁLAT:
    python3 mlx_agent.py "Végezd el a flutter3_cleanup_plan.md tervben leírt lépéseket"
    python3 mlx_agent.py --yes "..."          # megerősítés nélkül (KOCKÁZATOS)
    python3 mlx_agent.py --max-steps 15 "..."

A modell az alábbi JSON formátumokkal "cselekedhet" (egy JSON objektum / válasz):
    {"action": "run_command", "command": "ls -la"}
    {"action": "read_file", "path": "/abs/path/to/file"}
    {"action": "write_file", "path": "/abs/path/to/file", "content": "..."}
    {"action": "list_dir", "path": "/abs/path"}
    {"action": "final_answer", "content": "Kész vagyok, ezt csináltam: ..."}
"""

import argparse
import json
import re
import subprocess
import sys
import urllib.request
import urllib.error

API_URL = "http://localhost:8080/v1/chat/completions"
MODEL = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit"

SYSTEM_PROMPT = """Te egy autonóm coding agent vagy, aki egy Flutter + Supabase projekten dolgozik
a felhasználó gépén. Hozzáférésed van a fájlrendszerhez és a shellhez — de KIZÁRÓLAG
az alábbi JSON-akció protokollon keresztül.

MINDEN válaszodban PONTOSAN EGY JSON objektumot adj vissza, más szöveg nélkül
(sem magyarázat, sem markdown code fence — csak a nyers JSON).

Lehetséges akciók:
  {"action": "run_command", "command": "<shell parancs>"}
  {"action": "read_file", "path": "<abszolút elérési út>"}
  {"action": "write_file", "path": "<abszolút elérési út>", "content": "<teljes fájltartalom>"}
  {"action": "list_dir", "path": "<abszolút elérési út>"}
  {"action": "final_answer", "content": "<összefoglaló a felhasználónak: mit csináltál, mi az eredmény>"}

Szabályok:
- SOHA ne találj ki elérési utat vagy fájltartalmat. Ha nem tudod biztosan egy fájl
  pontos elérési útját, ELŐSZÖR listázd ki a könyvtárat (list_dir) vagy olvasd el a
  létező fájlt (read_file), és csak a TÉNYLEGESEN visszakapott adatokra építs.
- Mielőtt bármilyen fájlt írnál (write_file), először OLVASD EL a meglévő tartalmát
  (read_file), hogy a módosításod illeszkedjen a valódi fájlhoz — ne írj felül
  vakon egy fájlt kitalált tartalommal.
- Mindig abszolút elérési utat használj — kizárólag olyat, amit a felhasználó
  feladatleírásában kaptál, vagy amit egy list_dir/read_file eredményében ténylegesen
  visszakaptál. Soha ne használj példa/placeholder utakat (pl. /tmp/..., /path/to/...).
- Egyszerre csak egy lépést tegyél meg, és várd meg az eredményt, mielőtt a következőt eldöntenéd.
- Ha végeztél (vagy nem tudsz tovább lépni), küldj "final_answer" akciót, és FEJEZD BE.
- Ne találj ki parancskimenetet — mindig a kapott eredményekre építs.
- Ha egy parancs hibát ad vissza, elemezd a hibaüzenetet, és próbálj más megközelítést.
"""

ACTION_RE = re.compile(r"\{.*\}", re.DOTALL)


def call_model(messages, timeout=300):
    payload = {
        "model": MODEL,
        "messages": messages,
        "temperature": 0.1,
        "max_tokens": 4096,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        API_URL, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print(f"\n[HIBA] Nem sikerült elérni a modellt ({API_URL}): {e}", file=sys.stderr)
        sys.exit(1)
    return body["choices"][0]["message"]["content"]


def extract_action(raw_text):
    """Kinyeri az első JSON objektumot a modell válaszából (markdown fence-ekkel,
    chat-template végjelekkel — pl. <|im_end|> — és escapelés nélküli sortörésekkel
    a stringeken belül is megbirkózik)."""
    cleaned = raw_text.strip()
    cleaned = re.sub(r"^```(?:json)?", "", cleaned).strip()
    cleaned = re.sub(r"```.*$", "", cleaned, flags=re.DOTALL).strip()
    cleaned = re.sub(r"<\|im_end\|>.*$", "", cleaned, flags=re.DOTALL).strip()
    match = ACTION_RE.search(cleaned)
    if not match:
        return None
    raw_json = match.group(0)
    # Először szigorú módban próbáljuk; ha a modell nyers (escapelés nélküli)
    # sortöréseket / vezérlőkaraktereket tett a stringekbe, strict=False mellett
    # a Python json modul ezeket is elfogadja.
    for strict in (True, False):
        try:
            return json.loads(raw_json, strict=strict)
        except json.JSONDecodeError:
            continue
    return None


def confirm(prompt):
    answer = input(f"{prompt} [y/N]: ").strip().lower()
    return answer in ("y", "yes", "igen", "i")


def execute_action(action, auto_yes):
    kind = action.get("action")

    if kind == "run_command":
        cmd = action.get("command", "")
        print(f"\n>>> Parancs futtatása: {cmd}")
        if not auto_yes and not confirm("Engedélyezed a futtatást?"):
            return "A felhasználó NEM engedélyezte ezt a parancsot. Válassz másik megközelítést."
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=600
            )
            output = (result.stdout or "") + (result.stderr or "")
            return f"Exit code: {result.returncode}\nOutput:\n{output[-8000:]}"
        except Exception as e:
            return f"Hiba a parancs futtatásakor: {e}"

    if kind == "read_file":
        path = action.get("path", "")
        print(f"\n>>> Fájl olvasása: {path}")
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
            return f"Fájl tartalma ({path}):\n{content[:12000]}"
        except Exception as e:
            return f"Hiba a fájl olvasásakor: {e}"

    if kind == "write_file":
        path = action.get("path", "")
        content = action.get("content", "")
        print(f"\n>>> Fájl írása: {path} ({len(content)} karakter)")
        if not auto_yes and not confirm("Engedélyezed a fájl felülírását/létrehozását?"):
            return "A felhasználó NEM engedélyezte ezt a fájlírást. Válassz másik megközelítést."
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            return f"Fájl sikeresen elmentve: {path}"
        except Exception as e:
            return f"Hiba a fájl írásakor: {e}"

    if kind == "list_dir":
        path = action.get("path", "")
        print(f"\n>>> Könyvtár listázása: {path}")
        try:
            result = subprocess.run(
                ["ls", "-la", path], capture_output=True, text=True, timeout=30
            )
            return result.stdout + result.stderr
        except Exception as e:
            return f"Hiba a könyvtár listázásakor: {e}"

    return f"Ismeretlen akció: {kind!r}. Használj egy a támogatott akciók közül."


def main():
    parser = argparse.ArgumentParser(description="Agent-loop a lokális MLX modellnek")
    parser.add_argument("task", help="A feladat leírása, amit a modellnek el kell végeznie")
    parser.add_argument("--yes", action="store_true", help="Side-effectek automatikus jóváhagyása (KOCKÁZATOS)")
    parser.add_argument("--max-steps", type=int, default=20, help="Maximális iterációszám (alapértelmezett: 20)")
    args = parser.parse_args()

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": args.task},
    ]

    last_action_signature = None
    repeat_count = 0

    for step in range(1, args.max_steps + 1):
        print(f"\n========== Lépés {step}/{args.max_steps} ==========")
        raw = call_model(messages)
        action = extract_action(raw)

        if action is None:
            print(f"\n[Modell nyers válasza — nem sikerült JSON akciót kinyerni belőle]\n{raw}")
            looks_truncated = raw.strip() and not raw.strip().endswith("}")
            messages.append({"role": "assistant", "content": raw})
            if looks_truncated:
                hint = (
                    "A válaszod félbeszakadt / nem volt teljes JSON (valószínűleg túl hosszú volt). "
                    "Ha write_file-t akartál küldeni, bontsd kisebb, rövidebb darabokra a tartalmat "
                    "(pl. csak az új bekezdést írd a meglévő fájl elejére append-szerűen, vagy használj "
                    "run_command-ot egy rövid shell paranccsal a módosításhoz), és KIZÁRÓLAG egy "
                    "teljes, rövid JSON objektumot küldj."
                )
            else:
                hint = (
                    "A válaszod nem volt érvényes JSON akció. Kérlek, KIZÁRÓLAG egy JSON objektummal "
                    "válaszolj a megadott formátumok egyikében, más szöveg vagy code fence nélkül."
                )
            messages.append({"role": "user", "content": hint})
            continue

        messages.append({"role": "assistant", "content": json.dumps(action, ensure_ascii=False)})

        if action.get("action") == "final_answer":
            print(f"\n✅ KÉSZ — a modell összefoglalója:\n{action.get('content', '')}")
            return

        # Ismétlődés-detektálás: ha 2x egymás után ugyanazt az akciót küldi, állj meg.
        signature = json.dumps(action, sort_keys=True, ensure_ascii=False)
        if signature == last_action_signature:
            repeat_count += 1
        else:
            repeat_count = 0
        last_action_signature = signature

        if repeat_count >= 1:
            print(
                "\n⛔ A modell kétszer egymás után UGYANAZT az akciót küldte "
                "— ez valószínűleg hurok vagy elszakadás a feladattól. Megszakítom.\n"
                f"Ismételt akció: {signature}"
            )
            return

        result = execute_action(action, args.yes)
        print(f"\n[Eredmény visszaküldve a modellnek]\n{result[:2000]}")
        messages.append({"role": "user", "content": f"Az akció eredménye:\n{result}"})

    print(f"\n⚠️  Elértem a max. lépésszámot ({args.max_steps}) anélkül, hogy a modell 'final_answer'-t küldött volna.")


if __name__ == "__main__":
    main()
