import subprocess, sys
try:
    import pdfplumber
except ImportError:
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'pdfplumber', '-q'])
    import pdfplumber

pdf_path = "documentation/rc_did/de Chaisemartin et D\u2019Haultf\u0153uille - 2023 - Causal Inference with Differences-in-Differences Credible Answers to Hard Questions.pdf"
with pdfplumber.open(pdf_path) as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    full_text = []
    for page in pdf.pages:
        t = page.extract_text()
        if t:
            full_text.append(t)
    text = "\n".join(full_text)

# Search for sections about treatment intensity / exposure / dose / continuous
import re
keywords = [
    r"(?i)treatment.{0,20}intensity",
    r"(?i)treatment.{0,20}dose",
    r"(?i)continuous.{0,20}treatment",
    r"(?i)heterogeneous.{0,20}treatment.{0,20}effect",
    r"(?i)varying.{0,20}treatment",
    r"(?i)non.?binary.{0,20}treatment",
    r"(?i)exposure.{0,15}level",
    r"(?i)fuzzy.{0,15}(did|diff)",
    r"(?i)dose.?response",
    r"(?i)synthetic.{0,15}control",
    r"(?i)synthetic.{0,15}diff",
    r"(?i)sdid",
    r"(?i)gsynth",
    r"(?i)augmented.{0,15}synth",
    r"(?i)staggered",
    r"(?i)multiple.{0,15}treatment.{0,15}level",
]

for kw in keywords:
    matches = list(re.finditer(kw, text))
    if matches:
        print(f"\n=== Pattern: {kw} ({len(matches)} matches) ===")
        for m in matches[:5]:
            start = max(0, m.start() - 200)
            end = min(len(text), m.end() + 300)
            snippet = text[start:end].replace("\n", " ")
            print(f"  ...{snippet}...")
            print()
