
from playwright.sync_api import sync_playwright

URL = "https://www.ratesudan.com/rates"


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        page = browser.new_page(
            locale="ar",
            viewport={
                "width": 1365,
                "height": 900
            }
        )

        response = page.goto(
            URL,
            wait_until="domcontentloaded",
            timeout=90000
        )

        print(
            "HTTP STATUS:",
            response.status if response else "No response"
        )

        print("PAGE TITLE:", page.title())
        print("PAGE URL:", page.url)

        page.wait_for_timeout(10000)

        buttons = page.get_by_role(
            "button",
            name="السوق الموازي"
        )

        if buttons.count() > 0:
            buttons.first.click()
            page.wait_for_timeout(5000)

        text = page.locator("body").inner_text()

        print("\n========== PAGE TEXT ==========")
        print(text[:10000])
        print("========== END PAGE TEXT ==========")

        browser.close()


if __name__ == "__main__":
    main()
