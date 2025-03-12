import re
import json
import pickle
from typing import List
import sys
from os import path

sys.path.append(path.dirname(path.dirname(path.abspath(__file__))))
from core.models import CWE, CWEDatabase


class CWEHandler:
    """parse and extract CWE-ID from any strings to CWE object"""

    def __init__(self):
        self.cwe_dict: CWEDatabase = {}
        self.regex = re.compile(r"CWE-\d+", re.IGNORECASE)

    def load_dict(self, path: str):
        if path.endswith(".pkl"):

            with open(path, "rb") as f:
                cwe_dict = pickle.load(f)
        elif path.endswith(".json"):
            with open(path, "r") as f:
                cwe_dict = json.load(f)
            self.cwe_dict = CWEDatabase.model_validate_json(json.dumps(cwe_dict))
        else:
            raise ValueError("Unsupported file format")

    def cwe_from_string(self, text: str) -> List[CWE]:
        """extract CWE ID from a string"""
        cwe_id_list = re.findall(self.regex, text)
        # print(cwe_id_list)
        return self._parse_cwe_list(cwe_id_list)

    def _parse_cwe_list(self, cwe_id_list: List[str]) -> List[CWE]:
        cwe_list = []
        for cwe_id in cwe_id_list:
            cwe_id = cwe_id.upper()
            try:
                cwe_list.append(self.cwe_dict.get_by_name(cwe_id))
            except KeyError:
                continue
        return cwe_list
