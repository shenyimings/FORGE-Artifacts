from pydantic import BaseModel
from typing import List
from extractor.document_handler import DocumentHandler
from extractor.map_reducer import MapReducer
from core.models import Report
from core.base import BaseProcessor
from core.invoker import CHUNK_LENGTH
from loguru import logger


class ExtractProcessor(BaseProcessor):
    def _process(self, input: List[str]) -> Report | None:

        map_reducer = MapReducer()
        map_reduce_result = map_reducer.map_reduce(input, self.context_length)
        logger.info(
            "Finished.  {} finding(s) extracted", len(map_reduce_result.findings)
        )
        report = Report(
            path=self.filepath,
            project_info=map_reduce_result.project_info,
            findings=map_reduce_result.findings,
        )
        return report

    def _parse_file(self, filepath: str) -> List[str] | None:
        self.filepath = filepath
        self.context_length = CHUNK_LENGTH
        max_heading_level = self.config.get("extractor", {}).get("max_heading_level", 3)
        logger.debug("Context window: {}", self.context_length)
        doc_handler = DocumentHandler(
            max_level=max_heading_level, max_tokens=self.context_length
        )
        return doc_handler.process(filepath=self.filepath)
        # temp = doc_handler.split_by_heading(max_heading_level)
        # return doc_handler.merge_documents(self.context_length, temp)

    def _initialize(self) -> bool:
        valid_ext = self.config.get("extractor", {}).get("valid_ext", None)
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
