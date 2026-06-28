import os
import re

files = [
    '/Users/nm/Library/Application Support/Google/Chrome/Profile 1/Session Storage/000212.ldb',
    '/Users/nm/Library/Application Support/Google/Chrome/Profile 1/Local Storage/leveldb/000671.ldb',
    '/Users/nm/Library/Application Support/Google/Chrome/Default/Local Storage/leveldb/005085.ldb'
]

import string
printable = set(string.printable.encode('ascii'))

for fp in files:
    if not os.path.exists(fp):
        continue
    print(f"\nScanning {fp}...")
    with open(fp, 'rb') as f:
        data = f.read()
        
    # Search for keys containing auth, token, or github
    for term in [b'auth', b'token', b'github', b'session']:
        idx = 0
        while True:
            idx = data.find(term, idx)
            if idx == -1:
                break
            
            # Print around
            start = max(0, idx - 50)
            end = min(len(data), idx + 300)
            chunk = data[start:end]
            
            # Clean and display
            clean = bytearray()
            for b in chunk:
                if b in printable:
                    clean.append(b)
                else:
                    clean.extend(b'.')
            print(f"[{term.decode()}] offset {idx}: {clean.decode('ascii', errors='ignore')[:150]}")
            idx += len(term)
