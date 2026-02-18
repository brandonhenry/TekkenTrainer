import requests
from bs4 import BeautifulSoup
import os
import json
import time

BASE_URL = "https://tekken8combo.kagewebsite.com"
OUTPUT_DIR = "src/dll/ui/assets"
IMG_DIR = os.path.join(OUTPUT_DIR, "inputs")

# List of characters to scrape (will be populated from the home page)
CHARACTERS = []

def get_characters():
    print("Fetching character list...")
    response = requests.get(BASE_URL)
    soup = BeautifulSoup(response.text, 'html.parser')
    # Find all links that look like /combos-character/
    char_links = soup.select('a[href*="/combos-"]')
    chars = []
    for link in char_links:
        href = link['href']
        name = href.split('/')[-2].replace('combos-', '')
        if name not in [c['name'] for c in chars]:
            chars.append({'name': name, 'url': href})
    return chars

def scrape_combos(character):
    print(f"Scraping combos for {character['name']}...")
    combos = []
    page = 1
    while True:
        url = f"{BASE_URL}/combos-{character['name']}/?&page={page}"
        response = requests.get(url)
        if response.status_code != 200:
            break
            
        soup = BeautifulSoup(response.text, 'html.parser')
        combo_items = soup.select('li.combo-item')
        
        if not combo_items:
            break
            
        for item in combo_items:
            combo_data = {
                'id': item.get('id'),
                'hits': '',
                'damage': '',
                'moves': [],
                'text': ''
            }
            
            # Stats
            powered = item.select_one('.powered')
            if powered:
                text = powered.get_text(strip=True)
                if 'hits' in text:
                    combo_data['hits'] = text.split('|')[0].strip()
                if 'damages' in text:
                    combo_data['damage'] = text.split('|')[-1].strip()
            
            # Textual representation
            text_elem = item.select_one('.comboTxt')
            if text_elem:
                combo_data['text'] = text_elem.get_text(strip=True)
            
            # Sequence inputs (both images and text-based stances)
            input_container = item.select_one('.comboImg')
            if input_container:
                for child in input_container.find_all('span', recursive=False):
                    if 'key' in child.get('class', []):
                        img = child.find('img')
                        if img:
                            src = img['src']
                            alt = img['alt']
                            filename = os.path.basename(src)
                            combo_data['moves'].append({
                                'type': 'img',
                                'name': alt,
                                'img': filename
                            })
                            download_image(src)
                        else:
                            # Text-based input (stance, etc)
                            text = child.get_text(strip=True)
                            combo_data['moves'].append({
                                'type': 'text',
                                'name': text
                            })
            
            combos.append(combo_data)
            
        print(f"  Page {page} done. Found {len(combo_items)} combos.")
        page += 1
        time.sleep(0.5) # Be nice
        if page > 5: # Limit for now to avoid massive downloads during dev
            break
            
    return combos

def download_image(url):
    if not os.path.exists(IMG_DIR):
        os.makedirs(IMG_DIR)
    
    filename = os.path.basename(url)
    filepath = os.path.join(IMG_DIR, filename)
    
    if os.path.exists(filepath):
        return
        
    try:
        if not url.startswith('http'):
            url = BASE_URL + url
        response = requests.get(url)
        with open(filepath, 'wb') as f:
            f.write(response.content)
    except Exception as e:
        print(f"Failed to download {url}: {e}")

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        
    characters = get_characters()
    all_data = {}
    
    # For dev, just do a few characters
    for char in characters[:3]: 
        combos = scrape_combos(char)
        all_data[char['name']] = combos
        
    with open(os.path.join(OUTPUT_DIR, "combos.json"), "w") as f:
        json.dump(all_data, f, indent=4)
        
    print(f"Done! Data saved to {OUTPUT_DIR}/combos.json")

if __name__ == "__main__":
    main()
