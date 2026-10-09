"""Pruebas de contratos de entrada: fallos que deben impedir la carga."""
import tempfile
import unittest
from pathlib import Path

from src.files import read_csv


class CsvContractTests(unittest.TestCase):
    def read(self, content):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fuente.csv'
            path.write_bytes(content)
            return read_csv(path, ['id', 'nombre'])

    def test_bom_and_course_double_cr(self):
        self.assertEqual(self.read(b'\xef\xbb\xbfid,nombre\r\r\n1,Central\r\r\n'), [('1', 'Central')])

    def test_quoted_comma(self):
        self.assertEqual(self.read(b'id,nombre\n1,"Central, Guatemala"\n'), [('1', 'Central, Guatemala')])

    def test_header_drift_rejected(self):
        with self.assertRaises(ValueError):
            self.read(b'nombre,id\nCentral,1\n')

    def test_missing_field_rejected(self):
        with self.assertRaises(ValueError):
            self.read(b'id,nombre\n1\n')

    def test_extra_field_rejected(self):
        with self.assertRaises(ValueError):
            self.read(b'id,nombre\n1,Central,extra\n')

    def test_empty_source_rejected(self):
        with self.assertRaises(ValueError):
            self.read(b'id,nombre\n')


if __name__ == '__main__':
    unittest.main()
