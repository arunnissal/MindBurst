"""
Date Normalizer for MindBurst
Deterministically resolves relative natural language date expressions (e.g., 'today', 'tomorrow',
'yesterday', 'this Friday', 'next Monday', Tanglish 'naalaiku') into canonical ISO date strings (YYYY-MM-DD).
"""
import re
from datetime import datetime, timedelta
from typing import Optional

WEEKDAYS = {
    "monday": 0,
    "tuesday": 1,
    "wednesday": 2,
    "thursday": 3,
    "friday": 4,
    "saturday": 5,
    "sunday": 6,
}

class DateNormalizer:
    @staticmethod
    def resolve_date(date_str: Optional[str], ref_date: Optional[datetime] = None) -> Optional[str]:
        """
        Resolves relative date strings to ISO 'YYYY-MM-DD' format.
        If reference date is omitted, current local time is used.
        """
        if not date_str or not date_str.strip():
            return None

        clean_str = date_str.strip()

        # Check if already ISO format YYYY-MM-DD
        if re.match(r"^\d{4}-\d{2}-\d{2}$", clean_str):
            return clean_str

        now = ref_date or datetime.now()
        s = clean_str.lower()

        # Relative keywords
        if "today" in s or "inru" in s:
            return now.strftime("%Y-%m-%d")

        if "tomorrow" in s or "naalaiku" in s:
            return (now + timedelta(days=1)).strftime("%Y-%m-%d")

        if "yesterday" in s:
            return (now - timedelta(days=1)).strftime("%Y-%m-%d")

        # Day of week parsing
        for day_name, day_idx in WEEKDAYS.items():
            if day_name in s:
                current_idx = now.weekday()
                days_ahead = (day_idx - current_idx + 7) % 7
                if days_ahead == 0:
                    days_ahead = 7 if "next" in s else 0

                target_date = now + timedelta(days=days_ahead)
                return target_date.strftime("%Y-%m-%d")

        return clean_str

    @staticmethod
    def format_human_date(date_str: Optional[str], ref_date: Optional[datetime] = None) -> str:
        """
        Converts ISO date string (YYYY-MM-DD) or relative expression into human-friendly format:
        e.g., '2026-09-04' -> 'Tomorrow · Sep 04'
        e.g., None or '' -> 'No date'
        """
        if not date_str or not str(date_str).strip():
            return "No date"

        clean_str = str(date_str).strip()

        # Handle ISO date parsing
        if re.match(r"^\d{4}-\d{2}-\d{2}$", clean_str):
            try:
                dt = datetime.strptime(clean_str, "%Y-%m-%d")
                now = ref_date or datetime.now()
                diff_days = (dt.date() - now.date()).days
                month_day = dt.strftime("%b %d")

                if diff_days == 0:
                    return f"Today · {month_day}"
                elif diff_days == 1:
                    return f"Tomorrow · {month_day}"
                elif diff_days == -1:
                    return f"Yesterday · {month_day}"
                elif 2 <= diff_days <= 6:
                    day_name = dt.strftime("%A")
                    return f"{day_name} · {month_day}"
                else:
                    return dt.strftime("%b %d, %Y")
            except Exception:
                return clean_str

        # If already natural language (e.g. 'Tomorrow', 'this Friday')
        s_lower = clean_str.lower()
        if "tomorrow" in s_lower or "naalaiku" in s_lower:
            return "Tomorrow"
        elif "today" in s_lower:
            return "Today"
        elif "yesterday" in s_lower:
            return "Yesterday"

        return clean_str

    @staticmethod
    def get_date_range_for_filter(
        filter_name: str,
        custom_start: Optional[str] = None,
        custom_end: Optional[str] = None,
        ref_date: Optional[datetime] = None
    ) -> tuple[Optional[str], Optional[str]]:
        """
        Returns (start_date_iso, end_date_iso) for date filter option:
        - 'All': (None, None)
        - 'Today': (today_iso, today_iso)
        - 'Yesterday': (yesterday_iso, yesterday_iso)
        - 'This week': (monday_iso, sunday_iso)
        - 'This month': (first_of_month_iso, last_of_month_iso)
        - 'Custom': (custom_start, custom_end)
        """
        if not filter_name or filter_name.strip().lower() == "all":
            return (None, None)

        now = ref_date or datetime.now()
        today = now.date()

        f_lower = filter_name.strip().lower()

        if f_lower == "today":
            iso = today.strftime("%Y-%m-%d")
            return (iso, iso)
        elif f_lower == "yesterday":
            iso = (today - timedelta(days=1)).strftime("%Y-%m-%d")
            return (iso, iso)
        elif f_lower == "this week":
            monday = today - timedelta(days=today.weekday())
            sunday = monday + timedelta(days=6)
            return (monday.strftime("%Y-%m-%d"), sunday.strftime("%Y-%m-%d"))
        elif f_lower == "this month":
            first_day = today.replace(day=1)
            # Find last day of month
            if today.month == 12:
                next_month_first = today.replace(year=today.year + 1, month=1, day=1)
            else:
                next_month_first = today.replace(month=today.month + 1, day=1)
            last_day = next_month_first - timedelta(days=1)
            return (first_day.strftime("%Y-%m-%d"), last_day.strftime("%Y-%m-%d"))
        elif f_lower == "custom":
            start = DateNormalizer.resolve_date(custom_start, ref_date=now)
            end = DateNormalizer.resolve_date(custom_end, ref_date=now)
            return (start, end)

        return (None, None)


