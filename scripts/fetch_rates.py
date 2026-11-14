
import json
import re
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright

URL = "https://www.ratesudan.com/rates"

CURRENCIES = {
    "USD": "الدولار الأمريكي",
    "SAR": "الريال السعودي",
    "EGP": "الجنيه المصري",
}

NUMBER = r"([\d,]+(?:\.\d+)?)"


def number_value(value):
    return float(value.replace(",", ""))


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(locale="ar")
        page.goto(URL, wait_until="domcontentloaded", timeout=60000)

        page.get_by_text("USD", exact=False).first.wait_for(
            state="visible", timeout=45000
        )

        page.wait_for_timeout(4000)

        # اختيار السوق الموازي
        market_button = page.get_by_role(
            "button", name=re.compile("السوق الموازي")
        )
        if market_button.count():
            market_button.first.click()
            page.wait_for_timeout(2500)

        text = page.locator("body").inner_text()
        browser.close()

    rates = {}

    for code, name in CURRENCIES.items():
        pattern = (
            rf"(?<![A-Z]){code}\s+{re.escape(name)}\s+"
            rf"{NUMBER}\s+{NUMBER}\s+{NUMBER}\s+{NUMBER}"
        )

        match = re.search(pattern, text, re.IGNORECASE)

        if not match:
            raise RuntimeError(
                f"لم يتم العثور على بيانات العملة {code}"
            )

        values = [number_value(v) for v in match.groups()]

        # ترتيب القيم في صف الموقع:
        # شراء الموازي، شراء الرسمي، بيع الموازي، بيع الرسمي
        buy = values[0]
        sell = values[2]

        if buy <= 0 or sell <= 0 or buy > sell:
            raise RuntimeError(
                f"أسعار غير منطقية للعملة {code}: {values}"
            )

        rates[code] = {
            "buy": buy,
            "sell": sell,
        }

    output = {
        "source": URL,
        "market": "parallel",
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "rates": rates,
    }

    output_path = Path("data/rates.json")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(output, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
