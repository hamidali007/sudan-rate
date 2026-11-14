
import json
import os
import re
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote_plus

from playwright.sync_api import sync_playwright

SEARCH_URL = (
    "https://azzapress.com/?s="
    + quote_plus("أسعار العملات في السودان")
)

CURRENCIES = {
    "USD": ["الدولار الأمريكي", "الدولار الامريكي"],
    "SAR": ["الريال السعودي"],
    "EGP": ["الجنيه المصري", "الجنية المصري"],
}


def find_number(text, patterns, currency):
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return float(match.group(1).replace(",", ""))

    raise RuntimeError(
        f"لم يتم العثور على سعر {currency}"
    )


def supabase_request(base_url, key, method, path, body=None):
    """طلب بسيط إلى Supabase REST API بدون أي مكتبة إضافية."""
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/rest/v1/{path}",
        data=json.dumps(body).encode("utf-8") if body is not None else None,
        method=method,
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8") or "[]")
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"فشل طلب Supabase ({error.code}): {details}"
        ) from error


def push_to_supabase(rates):
    """يكتب الأسعار في جدول exchange_rates الذي يقرأ منه التطبيق."""
    base_url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")

    if not base_url or not key:
        print(
            "تنبيه: SUPABASE_URL أو SUPABASE_SERVICE_KEY غير مضبوط، "
            "تم تخطي الرفع إلى Supabase."
        )
        return

    now = datetime.now(timezone.utc).isoformat()

    for code, values in rates.items():
        payload = {
            "buy": values["buy"],
            "sell": values["sell"],
            "updated_at": now,
        }

        updated = supabase_request(
            base_url, key, "PATCH",
            f"exchange_rates?currency=eq.{code}",
            payload,
        )

        if not updated:
            supabase_request(
                base_url, key, "POST",
                "exchange_rates",
                {"currency": code, **payload},
            )

        print(f"تم تحديث {code} في Supabase")


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(locale="ar")

        response = page.goto(
            SEARCH_URL,
            wait_until="domcontentloaded",
            timeout=90000
        )

        if not response or response.status != 200:
            raise RuntimeError(
                f"تعذر فتح عزة برس: "
                f"{response.status if response else 'No response'}"
            )

        page.wait_for_timeout(3000)

        links = page.locator("a").evaluate_all(
            """els => els.map(a => ({
                text: (a.innerText || '').trim(),
                href: a.href
            }))"""
        )

        candidates = [
            item for item in links
            if "/archives/" in item["href"]
            and re.search(
                r"أسعار.*العملات|الدولار.*السودان|سعر الدولار",
                item["text"]
            )
        ]

        if not candidates:
            raise RuntimeError(
                "لم نعثر على مقال أسعار العملات في نتائج البحث"
            )

        article_url = candidates[0]["href"]

        page.goto(
            article_url,
            wait_until="domcontentloaded",
            timeout=90000
        )

        page.wait_for_timeout(2000)
        text = page.locator("body").inner_text()
        title = page.title()

        browser.close()

    print("ARTICLE:", title)
    print("URL:", article_url)

    sell_section = text.split(
        "أسعار بيع العملات مقابل الجنيه السوداني", 1
    )[1].split(
        "متوسط اسعار العملات", 1
    )[0]

    buy_section = text.split(
        "متوسط اسعار العملات في السودان في السوق الموازي الشراء", 1
    )[1]

    buy_section = buy_section.split(
        "يوميا كل دقيقة", 1
    )[0]

    rates = {}

    for code, names in CURRENCIES.items():
        name_pattern = "|".join(map(re.escape, names))

        sell = find_number(
            sell_section,
            [rf"(?:{name_pattern})\s*([\d,]+(?:\.\d+)?)"],
            code
        )

        buy_patterns = [
            rf"(?:{name_pattern})\s*([\d,]+(?:\.\d+)?)\s*جنيه(?:اً)?",
            rf"(?:{name_pattern})\s*([\d,]+(?:\.\d+)?)\s*جنيها",
        ]

        buy = find_number(buy_section, buy_patterns, code)

        if buy <= 0 or sell <= 0 or buy > sell:
            raise RuntimeError(
                f"أسعار غير صحيحة للعملة {code}: "
                f"شراء={buy} بيع={sell}"
            )

        rates[code] = {
            "buy": buy,
            "sell": sell
        }

    output = {
        "source": article_url,
        "source_name": "عزة برس",
        "market": "parallel",
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "rates": rates
    }

    output_path = Path("data/rates.json")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    output_path.write_text(
        json.dumps(output, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    print(json.dumps(output, ensure_ascii=False, indent=2))

    push_to_supabase(rates)


if __name__ == "__main__":
    main()
