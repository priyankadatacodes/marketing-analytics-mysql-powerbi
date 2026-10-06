"""
verify_kpis.py - independent re-computation of the project's headline KPIs in pandas.

It re-implements the cleaning rules of sql/02_data_cleaning.sql and the KPI logic of
sql/04, 08, 10, 11 and 14 directly from data_raw/*.csv, so the SQL pipeline can be
cross-checked without a database. The SQL pipeline remains the primary analysis; this
script is a validation aid (it was added after the SQL/Power BI work, not part of it).

Run (from the repository root):
    pip install -r requirements.txt
    python validation/verify_kpis.py

Expected output is stored in validation/validation_output.txt. All figures were also
checked against a full execution of the 16 SQL scripts (see docs/validation_notes.md).
"""
import re
from pathlib import Path

import numpy as np
import pandas as pd

D = Path(__file__).resolve().parent.parent / "data_raw"
rd = lambda f: pd.read_csv(D / f, dtype=str, keep_default_na=False)
customers, campaigns, perf, conv, txn, act = (rd(f) for f in [
    "customers.csv", "campaigns.csv", "campaign_performance.csv",
    "conversions.csv", "transactions.csv", "activity.csv"])

# ---------- helpers that mirror the SQL ----------
PATTERNS = [(r"\d{4}-\d{2}-\d{2}", "%Y-%m-%d"), (r"\d{2}-\d{2}-\d{4}", "%d-%m-%Y"),
            (r"\d{2}/\d{2}/\d{4}", "%m/%d/%Y"), (r"\d{2} [A-Za-z]{3} \d{4}", "%d %b %Y")]


def parse_date(s):
    s = s.strip()
    for rx, fmt in PATTERNS:
        if re.fullmatch(rx, s):
            try:
                return pd.to_datetime(s, format=fmt)
            except ValueError:          # STR_TO_DATE -> NULL on impossible dates
                return pd.NaT
    return pd.NaT


CHANNELS = {"Paid Search": ["paid search", "paid-search", "ppc", "google ads"],
            "Social": ["social", "facebook ads", "instagram", "social media"],
            "Email": ["email", "e-mail", "email marketing"],
            "Organic": ["organic", "organic search", "seo"],
            "Referral": ["referral", "referal"],
            "Display": ["display", "display ads", "banner"],
            "Affiliate": ["affiliate", "affliate", "partner"]}
CH_MAP = {v: k for k, vs in CHANNELS.items() for v in vs}
norm_channel = lambda s: CH_MAP.get(s.strip().lower(), s.strip())
money = lambda s: pd.to_numeric(re.sub(r"[^0-9.\-]", "", s) or np.nan, errors="coerce")

# ---------- stg_customers ----------
customers["customer_id"] = customers.customer_id.str.strip()
customers = customers[customers.customer_id != ""]
customers["has_email"] = customers.email.str.strip() != ""
customers = (customers.sort_values(["customer_id", "has_email"], ascending=[True, False])
             .drop_duplicates("customer_id").set_index("customer_id"))
customers["signup"] = customers.signup_date.map(parse_date)
customers["acq_channel"] = customers.acquisition_channel.map(norm_channel)

# ---------- stg_campaigns ----------
campaigns["campaign_id"] = campaigns.campaign_id.str.strip()
campaigns = campaigns.drop_duplicates("campaign_id").set_index("campaign_id")
campaigns["campaign_name"] = campaigns.campaign_name.str.strip()   # SQL: NULLIF(TRIM(campaign_name),'')
campaigns["channel"] = campaigns.channel.map(norm_channel)

# ---------- stg_campaign_performance ----------
perf["campaign_id"] = perf.campaign_id.str.strip()
perf = perf[perf.campaign_id.isin(campaigns.index)].copy()
perf["date"] = perf.date.map(parse_date)
imp = pd.to_numeric(perf.impressions.str.strip().replace("", np.nan), errors="coerce")
imp = np.floor(imp + 0.5)                         # DECIMAL -> UNSIGNED rounds
clk = pd.to_numeric(perf.clicks.str.strip().replace("", np.nan), errors="coerce")
perf["impressions"], perf["clicks"] = imp, clk.where(~(clk > imp))
perf["leads"] = pd.to_numeric(perf.leads.str.strip().replace("", np.nan), errors="coerce")
sp = perf.spend.map(money)
perf["spend"] = sp.where(sp >= 0)                 # negative -> NULL
perf = perf.join(campaigns[["channel"]], on="campaign_id")

# ---------- stg_transactions ----------
txn[["transaction_id", "customer_id", "campaign_id"]] = txn[["transaction_id", "customer_id", "campaign_id"]].apply(lambda c: c.str.strip())
txn = txn[(txn.transaction_id != "") & (txn.customer_id != "")].drop_duplicates("transaction_id")
txn = txn[txn.customer_id.isin(customers.index)].copy()
txn["date"] = txn.transaction_date.map(parse_date)
txn["revenue"] = txn.revenue.map(money)
txn["campaign_id"] = txn.campaign_id.where(txn.campaign_id.isin(campaigns.index))   # LEFT JOIN -> NULL

# ---------- stg_conversions / activity ----------
conv[["customer_id", "campaign_id"]] = conv[["customer_id", "campaign_id"]].apply(lambda c: c.str.strip())
conv = conv[conv.customer_id.isin(customers.index) & conv.campaign_id.isin(campaigns.index)].copy()
conv["date"] = conv.conversion_date.map(parse_date)
conv["stage"] = conv.conversion_stage.str.strip().replace("", "Unknown")
act["customer_id"] = act.customer_id.str.strip()
act = act[act.customer_id.isin(customers.index)].copy()
act["date"] = act.activity_date.map(parse_date)

# ---------- first-touch attribution (14_create_views.sql) ----------
ft = (conv[(conv.stage == "Customer") & conv.date.notna()]
      .sort_values(["customer_id", "date"]).drop_duplicates("customer_id")
      .join(campaigns[["channel"]], on="campaign_id"))

spend_by_ch = perf.groupby("channel").spend.sum()
n_ft = ft.groupby("channel").size()
ltv = txn.groupby("customer_id").revenue.sum().reindex(customers.index).fillna(0)
ft["ltv"] = ft.customer_id.map(ltv)

# ---------- retention flag (any event > 30 days after signup) ----------
ev = pd.concat([act[["customer_id", "date"]], txn[["customer_id", "date"]]]).dropna()
ev = ev.join(customers[["signup"]], on="customer_id").dropna()
post = ev[ev.date > ev.signup]
retained = (post.date > post.signup + pd.Timedelta(days=30)).groupby(post.customer_id).max()
customers["retained"] = retained.reindex(customers.index).fillna(False)

# ---------- print ----------
p = lambda k, v: print(f"{k:<58}{v}")
print("=== ROW COUNTS (staged) ===")
p("customers / campaigns / perf / conv / txn / activity",
  (len(customers), len(campaigns), len(perf), len(conv), len(txn), len(act)))
p("sum of staged rows (README claims 175,309)", len(customers) + len(campaigns) + len(perf) + len(conv) + len(txn) + len(act))
print("\n=== HEADLINE KPIs ===")
tot_spend, att_rev, all_rev = perf.spend.sum(), txn[txn.campaign_id.notna()].revenue.sum(), txn.revenue.sum()
p("Total spend (dashboard 230.13M)", f"{tot_spend:,.0f}")
p("Attributed revenue (dashboard 89.14M)", f"{att_rev:,.0f}")
p("ALL revenue incl. unattributed", f"{all_rev:,.0f}  (unattributed {all_rev-att_rev:,.0f} = {100*(all_rev-att_rev)/all_rev:.1f}%)")
p("ROAS attributed / all-revenue", f"{att_rev/tot_spend:.3f} / {all_rev/tot_spend:.3f}")
p("Acquired customers (first-touch, dated)", len(ft))
p("Customers with a 'Customer' stage (incl. undated)", conv[conv.stage == "Customer"].customer_id.nunique())
p("CAC on 3,075 / on 3,175 (dashboard 74.84K / 08 Q1)", f"{tot_spend/len(ft):,.0f} / {tot_spend/conv[conv.stage=='Customer'].customer_id.nunique():,.0f}")
p("Avg revenue-to-date: all customers / first-touch customers", f"{ltv.mean():,.0f} / {ft.ltv.mean():,.0f}")
p("Median / skew-ish (p99) of customer revenue-to-date", f"{ltv.median():,.0f} / {ltv.quantile(.99):,.0f}")
p("LTV:CAC (all-customer LTV / first-touch CAC)  [dash 0.13]", f"{ltv.mean()/(tot_spend/len(ft)):.3f}")
p("Retention flag (dashboard 86.4%)", f"{100*customers.retained.mean():.2f}%")
print("\n=== BY FIRST-TOUCH CHANNEL ===")
tbl = pd.DataFrame({"spend": spend_by_ch, "customers": n_ft})
tbl["CAC"] = tbl.spend / tbl.customers
tbl["avg_LTV_ft"] = ft.groupby("channel").ltv.mean()
tbl["LTV:CAC"] = tbl.avg_LTV_ft / tbl.CAC
tbl["retention_%"] = 100 * ft.assign(r=ft.customer_id.map(customers.retained)).groupby("channel").r.mean()
print(tbl.round(3).sort_values("LTV:CAC", ascending=False))
print("\n=== DATA-QUALITY FACTS ===")
p("Undated spend rows / spend", f"{perf.date.isna().sum()} / {perf[perf.date.isna()].spend.sum():,.0f}")
p("Undated txns / revenue", f"{txn.date.isna().sum()} / {txn[txn.date.isna()].revenue.sum():,.0f}")
p("Negative-revenue txns (refund flag) / value", f"{(txn.revenue<0).sum()} / {txn[txn.revenue<0].revenue.sum():,.0f}")
p("Distinct campaign names vs campaign ids (SQL run: 51; see note)", f"{campaigns.campaign_name.nunique()} vs {len(campaigns)}")
print("   note: 5 duplicated campaign_ids differ only by a '(v2)' name suffix; the SQL ROW_NUMBER tie-break is arbitrary, so the surviving name (48-51 distinct names) can vary")
p("Share of events dated before signup", f"{100*(ev.date<ev.signup).mean():.1f}%")
cmp_ = ft.join(customers[["acq_channel"]], on="customer_id")
p("first-touch channel == customers.acquisition_channel", f"{100*(cmp_.channel==cmp_.acq_channel).mean():.1f}%  (random ≈ 14.3%)")
by_id = perf.groupby("campaign_id").spend.sum().nlargest(5).sum() / tot_spend
by_name = perf.join(campaigns[["campaign_name"]], on="campaign_id").groupby("campaign_name").spend.sum().nlargest(5).sum() / tot_spend
p("Top-5 share of spend: by campaign_id / by campaign_name", f"{100*by_id:.2f}% / {100*by_name:.2f}%")
roas = (txn[txn.campaign_id.notna()].groupby("campaign_id").revenue.sum().reindex(campaigns.index).fillna(0)
        / perf.groupby("campaign_id").spend.sum())
p("Campaigns with ROAS >= 1 (of 220) / max ROAS", f"{(roas>=1).sum()} / {roas.max():.3f}")

try:
    from scipy import stats
    groups = [g.ltv.values for _, g in ft.groupby("channel")]
    p("ANOVA p-value: LTV across first-touch channels", f"{stats.f_oneway(*groups).pvalue:.3f}")
    imp_ch = perf.groupby("channel").impressions.sum()
    chi = stats.chi2_contingency(np.array([n_ft.values, (imp_ch - n_ft).values]))
    p("Chi-square p: customers/impressions across channels", f"{chi[1]:.3f}")
except ImportError:
    print("(install scipy for the significance tests)")

# ---------- additional checks used in the case study ----------
print("\n=== ADDITIONAL CHECKS ===")
rng = np.random.default_rng(42)
print("Bootstrap 95% CI of LTV:CAC by first-touch channel (resampling customers; CAC held fixed):")
for ch, g in ft.groupby("channel"):
    v, cac = g.ltv.values, spend_by_ch[ch] / len(g)
    bs = [rng.choice(v, len(v)).mean() for _ in range(2000)]
    print(f"   {ch:<12} {v.mean()/cac:.3f}  [{np.percentile(bs,2.5)/cac:.3f}, {np.percentile(bs,97.5)/cac:.3f}]")
by_type = (perf.join(campaigns[["campaign_type"]], on="campaign_id").groupby("campaign_type").spend.sum())
rev_type = (txn[txn.campaign_id.notna()].join(campaigns[["campaign_type"]], on="campaign_id").groupby("campaign_type").revenue.sum())
p("ROAS by campaign type", {k: round(rev_type[k] / by_type[k], 3) for k in by_type.index})
srt = ltv.sort_values(ascending=False)
p("Top 10% of customers' share of revenue-to-date", f"{100*srt.head(len(srt)//10).sum()/srt.sum():.1f}%")
m_sp = perf[perf.date.notna()].groupby(perf.date.dt.to_period("M")).spend.sum()
m_rv = txn[txn.date.notna() & txn.campaign_id.notna()].groupby(txn.date.dt.to_period("M")).revenue.sum()
mr = (m_rv / m_sp).dropna()
p("Months with monthly ROAS >= 1 (of 43)", [str(m) for m in mr[mr >= 1].index])
p("Monthly ROAS min / median / max", f"{mr.min():.2f} / {mr.median():.2f} / {mr.max():.2f}")
p("Avg revenue per transaction / transactions per customer", f"{txn.revenue.mean():,.0f} / {len(txn)/len(customers):.2f}")
cp_ = perf.groupby("campaign_id").spend.sum()
p("Campaign spend: min / median / max", f"{cp_.min():,.0f} / {cp_.median():,.0f} / {cp_.max():,.0f}")
p("Unattributed txns (no campaign_id)", f"{txn.campaign_id.isna().sum()} ({100*txn.campaign_id.isna().mean():.1f}%)")
p("Funnel: CTR / click->lead / lead->customer", f"{100*perf.clicks.sum()/perf.impressions.sum():.2f}% / {100*perf.leads.sum()/perf.clicks.sum():.2f}% / {100*len(ft)/perf.leads.sum():.2f}%")
