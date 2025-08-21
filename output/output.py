import matplotlib.pyplot as plt

implementations = [
    "TruffleRuby\nsem AR",
    "TruffleRuby\ncom AR",
    "MRI\nsem AR (Gem PG)",
    "MRI\ncom AR\n(callbacks)",
    "MRI 3.4.5\ncom AR (insert_all)",
]
times = [25, 54, 15, 45, 15]

sorted_data = sorted(zip(implementations, times), key=lambda x: x[1])
implementations, times = zip(*sorted_data)

plt.figure(figsize=(10, 6))
colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FECA57', '#FF9FF3']
bars = plt.bar(implementations, times, color=colors)

plt.title("Tempo para processar 100 mil eventos (segundos)")
plt.ylabel("Segundos")
plt.xlabel("Implementação")
plt.ylim(0, 60)
for bar, t in zip(bars, times):
    plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
             f"{t:.1f}s", ha='center', va='bottom')

plt.tight_layout()
png_path = "grafico.png"
plt.savefig(png_path, dpi=150)