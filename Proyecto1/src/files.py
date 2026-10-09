"""Lectura estricta de CSV y del diccionario XLSX, sin ejecutar fórmulas."""
import csv
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile


def read_csv(path: Path, columns: list[str]) -> list[tuple]:
    # newline='' permite leer los CRCRLF presentes en los archivos del curso.
    with path.open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != columns:
            raise ValueError(f'Encabezado inesperado en {path.name}: {reader.fieldnames}')
        rows = []
        for record in reader:
            if None in record or any(record[c] is None for c in columns):
                raise ValueError(f'Fila incompleta o columnas adicionales en {path.name}:{reader.line_num}')
            rows.append(tuple(record[c] for c in columns))
        if not rows:
            raise ValueError(f'Archivo vacío: {path.name}')
        return rows


def catalog_rows(path: Path) -> dict[str, list[list[str]]]:
    """Lee las dos hojas documentales del catálogo OOXML entregado."""
    namespace = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    with ZipFile(path) as book:
        strings = [''.join(cell.itertext()) for cell in ET.fromstring(book.read('xl/sharedStrings.xml')).findall('m:si', namespace)]
        sheets = {}
        for index, name in enumerate(('Resumen', 'Diccionario'), start=1):
            rows = []
            for row in ET.fromstring(book.read(f'xl/worksheets/sheet{index}.xml')).findall('m:sheetData/m:row', namespace):
                values = [''] * 6
                for cell in row.findall('m:c', namespace):
                    column = ord(cell.attrib['r'][0]) - ord('A')
                    value = cell.find('m:v', namespace)
                    if value is not None:
                        values[column] = strings[int(value.text)] if cell.attrib.get('t') == 's' else value.text
                rows.append(values)
            sheets[name] = rows
    return sheets
