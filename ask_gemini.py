import sys
import os
from pathlib import Path
from dotenv import load_dotenv
from google import genai

load_dotenv(Path(__file__).resolve().parent / ".env")
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

prompt = " ".join(sys.argv[1:])
if not prompt:
    print("Lutfen bir soru belirtin.")
    sys.exit(1)

system_role = (
    "Sen kidemli bir FinTech yazilim mimarisin. Asagidaki konuyu/soruyu analiz et "
    "ve teknik, somut bir mimari degerlendirme yap:"
)

# Hesabinizda aktif olan yedek modeller
MODELS_TO_TRY = [
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.7-flash",
    "gemini-flash-latest",
    "gemini-3.5-flash-lite"
]

success = False
for model_name in MODELS_TO_TRY:
    try:
        chat = client.chats.create(
            model=model_name,
            config={"system_instruction": system_role}
        )
        response = chat.send_message(prompt)
        print(f"[{model_name} Yaniti]:\n")
        print(response.text.strip())
        success = True
        break
    except Exception as e:
        # 503 veya gecici hatalarda sonraki modeli dene
        continue

if not success:
    print("Tum Gemini modelleri su an yogun, lutfen birkac saniye sonra tekrar deneyin.")