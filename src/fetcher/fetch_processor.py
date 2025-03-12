import os
import json
from loguru import logger
from pydantic import BaseModel
from typing import List

from core.models import Report, ProjectInfo
from core.base import BaseProcessor
from core.invoker import CONFIG, MAX_RETRIES, INTERVAL

from fetcher.project_parser import ProjectParser
from fetcher.code_fetcher import Router

MODE_OPTIONS = {
    "addr_only": 0,
    "url_only": 1,
    "default": 2,
}
MODE = MODE_OPTIONS.get(CONFIG["fetcher"].get("mode", "addr_priority"), 0)
ENABLED = CONFIG["fetcher"].get("enabled", ["github", "eth", "bsc"])


def _fetcher(report: Report, output: str) -> ProjectInfo:
    parser = ProjectParser(enabled_fetcher=ENABLED)
    fetch_target = parser.parse(report.project_info)  # [(<FETCHER_NAME>,<URL/ADDR>)]
    logger.info("Find {} target to fetch: {}", len(fetch_target), fetch_target)
    router = Router(enabled_fetcher=ENABLED, fetch_mode=MODE)
    output_dir_basename = f"{os.path.basename(report.path)}-source"
    output_dir = os.path.join(output, output_dir_basename)
    message = router.fetch(
        targets=fetch_target,
        work_dir=os.path.join(output, output_dir_basename),
    )
    if not report.project_info.chain or report.project_info.chain == "n/a":
        report.project_info.chain = message.get("chain", "n/a")
    if (
        not report.project_info.compiler_version
        or report.project_info.compiler_version == "n/a"
    ):
        report.project_info.compiler_version = message.get("compiler_version", "n/a")
    contract_name = message.get("contract_name", "contracts")
    project_path = {contract_name: output_dir}
    report.project_info.project_path = project_path
    return report.project_info


class FetchProcessor(BaseProcessor):
    def _process(self, input: Report) -> Report | None:
        report = input
        parser = ProjectParser(enabled_fetcher=ENABLED)
        fetch_target = parser.parse(
            report.project_info
        )  # [(<FETCHER_NAME>,<URL/ADDR>)]
        logger.info("Find {} target to fetch: {}", len(fetch_target), fetch_target)
        router = Router(enabled_fetcher=ENABLED, fetch_mode=MODE)
        output_dir_basename = f"{os.path.basename(report.path)}-source"
        output_dir = os.path.join(self.output, output_dir_basename)
        message = router.fetch(
            targets=fetch_target,
            work_dir=os.path.join(self.output, output_dir_basename),
        )
        if not report.project_info.chain or report.project_info.chain == "n/a":
            report.project_info.chain = message.get("chain", "n/a")
        if (
            not report.project_info.compiler_version
            or report.project_info.compiler_version == "n/a"
        ):
            report.project_info.compiler_version = message.get(
                "compiler_version", "n/a"
            )
        contract_name = message.get("contract_name", "contracts")
        project_path = {contract_name: output_dir}
        report.project_info.project_path = project_path
        return report

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
    fetcher = FetchProcessor(
        task="fetch",
        target="tests/test2.pdf.json",
        output="tests",
        log_dir="logs",
        config_path="config.yaml",
    )
    fetcher.run()
