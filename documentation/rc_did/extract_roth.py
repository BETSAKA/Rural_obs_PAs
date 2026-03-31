import pdfplumber, os

d = r'c:\Users\fbede\Documents\Statistiques\madagascar-rural-observatories-2025\documentation\rc_did'
files = os.listdir(d)

# Find Roth file
roth_file = [f for f in files if 'trending' in f][0]
print(f"Roth file: {roth_file}")

# Extract Roth
print("\n\n=== ROTH ET AL. 2023 ===")
with pdfplumber.open(os.path.join(d, roth_file)) as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    for i, page in enumerate(pdf.pages):
        text = page.extract_text()
        if text:
            print(f"\n--- PAGE {i+1} ---")
            print(text)
