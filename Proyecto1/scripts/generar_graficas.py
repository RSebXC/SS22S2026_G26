"""Genera SVG editables con resultados reales; no requiere librerías externas."""
import json
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COLOR = '#137c78'


def chart(title, subtitle, rows, label, value, filename, currency=True):
    width, height = 1000, 160 + 48*len(rows)
    left, available = 230, 575
    maximum = max(float(r[value]) for r in rows) or 1
    pieces = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{escape(title)}">',
              '<rect width="100%" height="100%" rx="14" fill="#f5f8fc"/>',
              '<g font-family="Segoe UI,Arial,sans-serif" fill="#142338">',
              f'<text x="30" y="42" font-size="24" font-weight="700">{escape(title)}</text>',
              f'<text x="30" y="69" font-size="13" fill="#5c6d80">{escape(subtitle)}</text>']
    for i,row in enumerate(rows):
        y = 104 + 48*i
        amount = float(row[value])
        bar = amount / maximum * available
        formatted = f'{amount:,.2f}' if currency else f'{amount:,.0f}'
        pieces += [f'<text x="{left-15}" y="{y+20}" text-anchor="end" font-size="14">{escape(str(row[label]))}</text>',
                   f'<rect x="{left}" y="{y}" width="{bar:.2f}" height="30" rx="5" fill="{COLOR}"/>',
                   f'<text x="{left+bar+12:.2f}" y="{y+20}" font-size="13">{formatted}</text>']
    pieces += [f'<text x="30" y="{height-25}" font-size="12" fill="#5c6d80">Fuente: PostgreSQL / SG-Food ficticio · importes en unidades monetarias · barras desde cero</text>', '</g></svg>']
    path = ROOT / 'docs/graficas' / filename
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text('\n'.join(pieces),encoding='utf-8')


if __name__ == '__main__':
    data = json.loads((ROOT/'evidence/resultados_analiticos.json').read_text(encoding='utf-8'))
    chart('Ventas completadas por mes', 'Subtotal después del descuento original; excluye pendientes y anuladas',
          data['mensual'],'periodo','ventas','ventas_mensuales.svg')
    chart('Ventas completadas por categoría', 'Productos agrupados por su categoría transaccional',
          data['categorias'],'categoria','ventas','ventas_categorias.svg')
    chart('Ventas completadas por sucursal', 'Enero–agosto de 2026 · datos ficticios',
          data['sucursales'],'sucursal','ventas','ventas_sucursales.svg')
    print('Tres gráficas SVG generadas en docs/graficas/')
