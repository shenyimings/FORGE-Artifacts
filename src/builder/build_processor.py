from pydantic import BaseModel
from typing import List
from extractor.document_handler import DocumentHandler
from extractor.map_reducer import MapReducer
from classifier.tot_reasoner import TotReasoner
from classifier.cwe_handler import CWEHandler
from fetcher.fetch_processor import _fetcher
from core.models import Report
from core.base import BaseProcessor
from core.invoker import CONFIG, MAX_RETRIES, INTERVAL, CHUNK_LENGTH
from loguru import logger


class BuildProcessor(BaseProcessor):
    def _process(self, input: List[str]) -> Report | None:

        map_reducer = MapReducer()
        reasoner = TotReasoner()
        cwe_handler = CWEHandler()
        cwe_handler.load_dict(CONFIG["classifier"].get("cwe_data", "cwe_dict.json"))
        map_reduce_result = map_reducer.map_reduce(input, self.context_length)
        logger.info(
            "Finished.  {} finding(s) extracted", len(map_reduce_result.findings)
        )
        report = Report(
            path=self.filepath,
            project_info=map_reduce_result.project_info,
            findings=map_reduce_result.findings,
        )
        self.export_result(
            report,
            filename=self.file_name,
            output_dir=self.output,
            overwrite=True,
        )
        report.project_info = _fetcher(report, self.output)
        self.export_result(
            report,
            filename=self.file_name,
            output_dir=self.output,
            overwrite=True,
        )
        for finding in report.findings:
            vuln_info = {"title": finding.title, "description": finding.description}
            try:
                category = reasoner.analyze(
                    vuln_info=vuln_info, cwe_handler=cwe_handler
                )
                finding.category = category
                self.export_result(
                    report,
                    filename=self.file_name,
                    output_dir=self.output,
                    overwrite=True,
                )
                logger.info("Classified {} as {}", finding.title, category)
            except Exception as e:
                logger.error(e)
                continue
        return report

    def _parse_file(self, filepath: str) -> List[str] | None:
        self.filepath = filepath
        self.context_length = CHUNK_LENGTH
        max_heading_level = CONFIG.get("extractor", {}).get("max_heading_level", 3)
        doc_handler = DocumentHandler(
            max_level=max_heading_level, max_tokens=self.context_length
        )
        return doc_handler.process(filepath=self.filepath)

    def _initialize(self) -> bool:
        valid_ext = CONFIG.get("extractor", {}).get("valid_ext", None)
        # self.overwrite = True
        if valid_ext:
            self.valid_ext = valid_ext
            return True
        else:
            return False


# if __name__ == "__main__":
#     extractor = ExtractProcessor(
#         task="extract",
#         target="tests/test_cases/test_pdf1.pdf",
#         output="tests/test_output",
#         log_dir="src/logs",
#         config_path="src/config.yaml",
#     )
#     extractor.run()
