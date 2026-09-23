"""
ask_gemini.py'nin dosya tabanlı kardeşi: uzun istemler (kaynak dosya içerikleri) komut satırı sınırına takılmasın.

Kullanım:  python tools/ask_gemini_file.py <istem_dosyası> <yanıt_dosyası>
Anahtar ve model listesi ask_gemini.py ile aynıdır (.env → GEMINI_API_KEY).
"""
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google import genai

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

MODELS_TO_TRY = ["gemini-3.6-flash", "gemini-3.5-flash", "gemini-3.7-flash", "gemini-flash-latest"]

SYSTEM_ROLE = (
    "Sen kıdemli bir Flutter/Dart mühendisisin. Verilen proje dosyalarını ve paket API imzalarını esas al; "
    "imzaları uydurma. İstenen çıktı biçimine harfiyen uy; biçim dışı açıklama yazma."
)


def main():
    prompt_path, out_path = Path(sys.argv[1]), Path(sys.argv[2])
    prompt = prompt_path.read_text(encoding="utf-8")
    client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
    last_error = None
    for model in MODELS_TO_TRY:
        try:
            chat = client.chats.create(model=model, config={"system_instruction": SYSTEM_ROLE})
            response = chat.send_message(prompt)
            out_path.write_text(f"[model: {model}]\n{response.text}", encoding="utf-8")
            print(f"ok {model} -> {out_path}")
            return
        except Exception as e:  # yoğunluk / 503: sıradaki model
            last_error = e
    print(f"FAIL: {last_error}")
    sys.exit(1)


if __name__ == "__main__":
    main()
