"""Extrae únicamente los ocho archivos conocidos del ZIP del curso."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    'sgfood_oltp.sql', 'inventario_bodega.csv', 'devoluciones.csv',
    'metas_ventas.csv', 'promociones.csv', 'proveedores_precios.csv',
    'casos_calidad_opcionales.csv', 'catalogo_insumos_sgfood.xlsx',
}


def prepare(archive: Path) -> None:
    destination = ROOT / 'data' / 'input'
    destination.mkdir(parents=True, exist_ok=True)
    with ZipFile(archive) as source:
        if set(source.namelist()) != FILES:
            raise ValueError('El ZIP no coincide con los archivos esperados del curso')
        manifest = {}
        for name in sorted(FILES):
            data = source.read(name)
            target = destination / name
            if target.exists() and target.read_bytes() != data:
                raise FileExistsError(f'No se sobrescribe una fuente modificada: {target}')
            target.write_bytes(data)
            manifest[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    (ROOT / 'docs' / 'manifest_fuentes.json').write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'{len(FILES)} fuentes disponibles en {destination}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('zip', type=Path)
    prepare(parser.parse_args().zip)
