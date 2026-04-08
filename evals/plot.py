"""
Generate a dot plot with whiskers showing how much shorter each skill
makes Claude's answers compared to a plain "Answer concisely." control.

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
        # positive % = shorter than control (good)
        savings = [
            (1 - (s / t)) * 100 if t else 0.0
            for s, t in zip(skill_tokens, terse_tokens)
        ]
        savings_sorted = sorted(savings)
        n = len(savings_sorted)
        q1 = savings_sorted[n // 4]
        q3 = savings_sorted[(3 * n) // 4]
        rows.append(
            {
                "skill": skill,
                "median": statistics.median(savings),
                "mean": statistics.mean(savings),
                "min": min(savings),
                "max": max(savings),
                "q1": q1,
                "q3": q3,
            }
        )

    rows.sort(key=lambda r: r["median"])  # ascending → best at top in horizontal
    names = [r["skill"] for r in rows]
    medians = [r["median"] for r in rows]
    mins = [r["min"] for r in rows]
    maxs = [r["max"] for r in rows]
    q1s = [r["q1"] for r in rows]
    q3s = [r["q3"] for r in rows]

    fig = go.Figure()

    # min/max thin whisker (full range, faded)
    for name, lo, hi in zip(names, mins, maxs):
        fig.add_trace(
            go.Scatter(
                x=[lo, hi],
                y=[name, name],
                mode="lines",
                line=dict(color="rgba(80,80,80,0.35)", width=2),
                showlegend=False,
                hoverinfo="skip",
            )
        )

    # IQR thicker whisker (q1 to q3, where the middle half lives)
    for name, lo, hi in zip(names, q1s, q3s):
        fig.add_trace(
            go.Scatter(
                x=[lo, hi],
                y=[name, name],
                mode="lines",
                line=dict(color="#2c3e50", width=6),
                showlegend=False,
                hoverinfo="skip",
            )
        )

    # median dot
    fig.add_trace(
        go.Scatter(
            x=medians,
            y=names,
            mode="markers",
            marker=dict(
                symbol="circle",
                size=14,
                color="#2ca02c",
                line=dict(color="white", width=2),
            ),
            name="median",
            hovertemplate="<b>%{y}</b><br>median: %{x:.1f}%<extra></extra>",
        )
    )

    # right-aligned label column outside the data area
    fig.add_trace(
        go.Scatter(
            x=[105] * len(names),
            y=names,
            mode="text",
            text=[f"<b>{m:+.0f}%</b>" for m in medians],
            textposition="middle left",
            textfont=dict(size=14, color="#2c3e50"),
            showlegend=False,
            hoverinfo="skip",
        )
    )

    # zero line — "no effect"
    fig.add_vline(
        x=0,
        line=dict(color="black", width=1.5, dash="dash"),
        annotation_text="  no effect",
        annotation_position="top",
        annotation_font=dict(size=11, color="black"),
    )

    fig.update_layout(
        title=dict(
            text=f"<b>How much shorter does each skill make Claude's answers?</b><br>"
            f"<sub>Compared against the same model with system prompt = "
            f"<i>'Answer concisely.'</i><br>"
            f"{meta.get('model', '?')} · n={meta.get('n_prompts', '?')} prompts · "
            f"single run per arm</sub>",
            x=0.5,
            xanchor="center",
        ),
        xaxis=dict(
            title="← longer  ·  output tokens vs control  ·  shorter →",
            ticksuffix="%",
            zeroline=False,
            gridcolor="rgba(0,0,0,0.08)",
            range=[-30, 110],
        ),
        yaxis=dict(title="", automargin=True),
        plot_bgcolor="white",
        height=440,
        width=950,
        margin=dict(l=120, r=80, t=120, b=110),
        showlegend=False,
        annotations=[
            dict(
                x=0.5,
                y=-0.28,
                xref="paper",
                yref="paper",
                showarrow=False,
                font=dict(size=11, color="#555"),
                text=(
                    "<b>green dot</b> = median across prompts · "
                    "<b>thick bar</b> = IQR (middle 50%) · "
                    "<b>thin line</b> = min / max"
                ),
            )
        ],
    )

    fig.write_html(HTML_OUT)
    print(f"Wrote {HTML_OUT}")
    fig.write_image(PNG_OUT, scale=2)
    print(f"Wrote {PNG_OUT}")


if __name__ == "__main__":
    main()
