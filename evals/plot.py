"""
Generate an interactive bar chart of skill compression vs the terse control arm.

Reads evals/snapshots/results.json and writes:
  - evals/snapshots/results.html  (interactive plotly)
  - evals/snapshots/results.png   (static export for README/PR embed)

Run: uv run --with tiktoken --with plotly --with kaleido python evals/plot.py
"""

from __future__ import annotations

import json
import statistics
from pathlib import Path

import plotly.graph_objects as go
import tiktoken

ENCODING = tiktoken.get_encoding("o200k_base")
SNAPSHOT = Path(__file__).parent / "snapshots" / "results.json"
HTML_OUT = Path(__file__).parent / "snapshots" / "results.html"
PNG_OUT = Path(__file__).parent / "snapshots" / "results.png"


def count(text: str) -> int:
    return len(ENCODING.encode(text))


def main() -> None:
    data = json.loads(SNAPSHOT.read_text())
    arms = data["arms"]
    meta = data.get("metadata", {})

    terse_tokens = [count(o) for o in arms["__terse__"]]

    rows = []
    for skill, outputs in arms.items():
        if skill in ("__baseline__", "__terse__"):
            continue
        skill_tokens = [count(o) for o in outputs]
        # savings as positive percentages (bigger = more compression)
        savings = [
            (1 - (s / t)) * 100 if t else 0.0
            for s, t in zip(skill_tokens, terse_tokens)
        ]
        rows.append(
            {
                "skill": skill,
                "median": statistics.median(savings),
                "mean": statistics.mean(savings),
                "min": min(savings),
                "max": max(savings),
                "all": savings,
            }
        )

    rows.sort(key=lambda r: r["mean"])  # ascending so best is at top in horizontal bar
    names = [r["skill"] for r in rows]
    means = [r["mean"] for r in rows]
    medians = [r["median"] for r in rows]
    mins = [r["min"] for r in rows]
    maxs = [r["max"] for r in rows]

    # color by mean: green for compression, red for inflation
    colors = ["#2ca02c" if m > 0 else "#d62728" for m in means]

    fig = go.Figure()

    # range line (min → max) per skill, behind the bars
    for name, lo, hi in zip(names, mins, maxs):
        fig.add_trace(
            go.Scatter(
                x=[lo, hi],
                y=[name, name],
                mode="lines",
                line=dict(color="rgba(80,80,80,0.5)", width=2),
                showlegend=False,
                hoverinfo="skip",
            )
        )

    # mean bars
    fig.add_trace(
        go.Bar(
            x=means,
            y=names,
            orientation="h",
            marker=dict(color=colors),
            text=[f"{m:+.0f}%" for m in means],
            textposition="outside",
            name="mean",
            hovertemplate="<b>%{y}</b><br>mean: %{x:.1f}%<extra></extra>",
        )
    )

    # median markers
    fig.add_trace(
        go.Scatter(
            x=medians,
            y=names,
            mode="markers",
            marker=dict(symbol="line-ns", size=18, color="black", line=dict(width=2)),
            name="median",
            hovertemplate="<b>%{y}</b><br>median: %{x:.1f}%<extra></extra>",
        )
    )

    # min/max endpoint markers
    fig.add_trace(
        go.Scatter(
            x=mins + maxs,
            y=names + names,
            mode="markers",
            marker=dict(symbol="line-ns", size=10, color="rgba(80,80,80,0.7)"),
            name="min / max",
            hovertemplate="%{x:.1f}%<extra></extra>",
        )
    )

    fig.add_vline(x=0, line=dict(color="black", width=1))

    fig.update_layout(
        title=dict(
            text=f"<b>Output token savings vs terse control</b><br>"
            f"<sub>{meta.get('model', '?')} · n={meta.get('n_prompts', '?')} prompts · "
            f"single run per arm</sub>",
            x=0.5,
            xanchor="center",
        ),
        xaxis=dict(
            title="Savings (%) — positive = compressed, negative = inflated",
            ticksuffix="%",
            zeroline=False,
            gridcolor="rgba(0,0,0,0.08)",
        ),
        yaxis=dict(title=""),
        plot_bgcolor="white",
        height=420,
        width=900,
        margin=dict(l=120, r=80, t=90, b=70),
        legend=dict(
            orientation="h", yanchor="bottom", y=-0.25, xanchor="center", x=0.5
        ),
    )

    fig.write_html(HTML_OUT)
    print(f"Wrote {HTML_OUT}")
    fig.write_image(PNG_OUT, scale=2)
    print(f"Wrote {PNG_OUT}")


if __name__ == "__main__":
    main()
