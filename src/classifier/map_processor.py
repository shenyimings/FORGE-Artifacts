import json
from loguru import logger
from pydantic import BaseModel
from typing import List
from classifier.cwe_handler import CWEHandler, CWE

from classifier.tot_reasoner import TotReasoner
from core.models import Report
from core.base import BaseProcessor
from core.invoker import CONFIG


class ClassifyProcessor(BaseProcessor):
    def _process(self, input: Report) -> Report | None:
        result = input
        cwe_handler = CWEHandler()
        cwe_handler.load_dict(CONFIG["classifier"].get("cwe_data", "cwe_dict.json"))
        reasoner = TotReasoner()
        for finding in result.findings:
            vuln_info = {"title": finding.title, "description": finding.description}
            try:
                category = reasoner.analyze(
                    vuln_info=vuln_info, cwe_handler=cwe_handler
                )
                finding.category = category
                self.export_result(
                    result,
                    filename=self.file_name,
                    output_dir=self.output,
                    overwrite=True,
                )
                logger.info("Classified {} as {}", finding.title, category)
            except Exception as e:
                logger.error(e)
                continue

        return result

    def _parse_file(self, filepath: str) -> Report | None:
        self.filepath = filepath
        with open(self.filepath, "r", encoding="utf8") as f:
            data = json.load(f)
        try:
            report = Report.model_validate_json(json.dumps(data))
            return report
        except Exception as e:
            logger.error(
                "Failed to parse {}, check if the file validates the core model defination! {}",
                self.filepath,
                str(e),
            )

    def _initialize(self) -> bool:
        self.overwrite = True
        valid_ext = [".json"]
        if valid_ext:
            self.valid_ext = valid_ext
            return True
        else:
            return False


if __name__ == "__main__":
    mapper = ClassifyProcessor(
        task="map",
        target="../scripts/test_output/test_pdf1.pdf.json",
        output="../scripts/test_output",
        log_dir="logs",
        config_path="config.yaml",
    )
    mapper.run()
