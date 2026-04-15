from pathlib import Path
p = Path(r'c:/Users/Jake/humidity detector/esp32-climate-monitor/lib/screens/device_screen_new.dart')
text = p.read_text(encoding='utf-8')
brackets = {'(': 0, ')': 0, '[': 0, ']': 0, '{': 0, '}': 0}
for ch in text:
    if ch in brackets:
        brackets[ch] += 1
print(brackets)
