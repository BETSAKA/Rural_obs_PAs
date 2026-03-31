import pdfplumber, os

d = r'c:\Users\fbede\Documents\Statistiques\madagascar-rural-observatories-2025\documentation\rc_did'
files = os.listdir(d)

# Find the two target files
dch_file = [f for f in files if 'Chaisemartin' in f][0]
roth_file = [f for f in files if 'trending' in f][0]

print(f"DCH file: {dch_file}")
print(f"Roth file: {roth_file}")

# Extract DCH
print("\n\n=== DE CHAISEMARTIN & D'HAULTFOEUILLE 2023 ===")
with pdfplumber.open(os.path.join(d, dch_file)) as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    for i, page in enumerate(pdf.pages):
        text = page.extract_text()
        if text:
            print(f"\n--- PAGE {i+1} ---")
            print(text)
