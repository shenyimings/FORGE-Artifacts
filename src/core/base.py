import os
import json
import yaml
from pathlib import Path
from loguru import logger
from typing import Union, Tuple, Any
from abc import ABC, abstractmethod
from pydantic import BaseModel, TypeAdapter
from datetime import datetime

from .models import ProjectInfo, Report, History
import httpx
import time
import time


class BaseProcessor(ABC):
    """
    The base class of all processors, providing common methods and properties
    """

    def __init__(
        self,
        task: str,
        target: str,
        output: str,
        log_dir: str,
        config_path: str = "config.yaml",
    ):
        self.task = task
        self.target = target
        self.isdir = False
        self.output = output
        self.log_dir = log_dir
        self.valid_ext = [".pdf", ".md", ".json"]
        self.history: History = History()
        self.config_path = config_path
        self.overwrite = False
        self._load_history(self.log_dir)
        self._load_config(self.config_path)

    @abstractmethod
    def _process(self, input: BaseModel) -> Union[BaseModel, None]:
        pass

    @abstractmethod
    def _parse_file(self, filepath: str) -> Union[BaseModel, None]:
        pass

    @abstractmethod
    def _initialize(self) -> bool:
        return True

    def _load_config(self, config_path: str = "config.yaml"):
        with open(config_path, "r") as f:
            self.config = yaml.safe_load(f)

    def _validate_file(self, filename, valid_ext) -> bool:
        if os.path.isfile(filename):
            _, ext = os.path.splitext(filename)

            if ext.lower() in valid_ext:
                return True
        return False

    def validate_target(self) -> bool:
        if not os.path.exists(self.target):

            return False
        if os.path.isdir(self.target):
            self.isdir = True
            return True
        else:
            self.isdir = False
            return self._validate_file(self.target, self.valid_ext)

    def export_result(
        self,
        result: BaseModel,
        filename: str = "!<NONE>!",
        output_dir: str = "!<NONE>!",
        overwrite: bool = False,
    ) -> bool:
        if filename == "!<NONE>!" and output_dir == "!<NONE>!":
            # Temporary save
            filename = self.target
            output_dir = self.output
            overwrite = True
        try:
            if overwrite:
                base, ext = os.path.splitext(filename)
                output_path = Path(output_dir) / f"{base}.json"
            else:
                output_path = Path(output_dir) / f"{filename}.json"
            if os.path.exists(output_path) and not overwrite:
                logger.warning("{} already exists!", output_path)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_path = Path(output_dir) / f"{filename}_{timestamp}.json"

            with output_path.open("w", encoding="utf-8") as f:
                json.dump(result.model_dump(), f, ensure_ascii=False, indent=4)
            return True
        except Exception as e:
            logger.error(f"Export failed: {e}")
            return False

    def _load_history(self, log_dir: str) -> bool:
        try:
            log_path = Path(log_dir) / f"{self.task}.json"
            if log_path.exists():
                with log_path.open("r", encoding="utf-8") as f:
                    history = json.load(f)

                    # TypeAdapter(History).validate_json(json.dumps(history))
                    self.history = History(**history)
                return True
            else:
                return False
        except Exception as e:
            logger.error(f"Load history failed: {e}")
            return False

    def _save_history(
        self, progress: str, log_dir: str, is_failed: bool = False
    ) -> bool:
        try:

            log_path = Path(log_dir) / f"{self.task}.json"
            if is_failed:
                self.history.failed.append(progress)
            else:
                self.history.finished.append(progress)
            with log_path.open("w", encoding="utf-8") as f:
                json.dump(self.history.model_dump(), f, ensure_ascii=False, indent=4)
            return True
        except Exception as e:
            logger.error(f"Save history failed: {e}")
            return False

    @logger.catch
    def run(self) -> bool:
        result = None
        if not self._initialize():
            logger.error("Failed to initialize!")
        if not self.validate_target():
            logger.error("Invalid path or file!")
            return False
        if self.isdir:
            for root, dirs, files in os.walk(self.target):
                for f in files:
                    file_path = os.path.join(root, f)
                    if not self._validate_file(file_path, self.valid_ext):
                        continue
                    if file_path in self.history.finished:
                        logger.info("Skip analyzed file {}", file_path)
                        continue
                    self.file_name = f
                    logger.info("Processing {}...", file_path)
                    input = self._parse_file(file_path)
                    result = self._process(input)
                    is_failed = False
                    if not result:
                        is_failed = True
                    self.export_result(
                        result=result,
                        filename=f,
                        output_dir=self.output,
                        overwrite=self.overwrite,
                    )
                    self._save_history(file_path, self.log_dir, is_failed)
            return True
        else:
            file_path = self.target
            f = os.path.basename(file_path)
            # if file_path in self.history.finished:
            #     logger.info("Skip analyzed file {}", file_path)
            #     return True
            self.file_name = f
            logger.info("Processing {}...", file_path)
            input = self._parse_file(file_path)
            result = self._process(input)
            is_failed = False
            if not result:
                is_failed = True
            self.export_result(
                result=result,
                filename=f,
                output_dir=self.output,
                overwrite=self.overwrite,
            )
            self._save_history(file_path, self.log_dir, is_failed)
            return True


class BaseFetcher(ABC):
    """
    Abstract base class for fetchers that retrieve code from different sources.
    Different implementations (GitHub, Ethereum, BSC, etc.) will extend this class.
    """

    def __init__(self, name: str):
        """
        Initialize the base fetcher with a name.

        Args:
            name: The name of the fetcher (e.g., "github", "ethereum", "bsc")
        """
        self.name = name
        self.max_retries = 3
        self.retry_delay = 3  # seconds
        self.timeout = 60.0

    def fetch(self, target: str, work_dir: str) -> Tuple[bool, str]:
        """
        Main fetch method that handles the fetch process and error handling.

        Args:
            target: The target to fetch (URL, address, etc.)
            work_dir: The directory to save fetched code

        Returns:
            Tuple[bool, str]: Success status and output path or error message
        """
        logger.info(f"{self.name} fetcher starting for target: {target}")

        try:
            # Create output directory if it doesn't exist
            os.makedirs(work_dir, exist_ok=True)

            # Perform the actual fetch operation
            success, result = self._do_fetch(target, work_dir)

            if success:
                logger.info(f"{self.name} fetcher completed successfully.")
            else:
                logger.error(f"{self.name} fetcher failed: {result}")

            return success, result

        except Exception as e:
            error_msg = f"Error in {self.name} fetcher: {str(e)}"
            logger.exception(error_msg)
            return False, error_msg

    def _request_with_retry(
        self, url: str, method: str = "GET", **kwargs
    ) -> Tuple[bool, Any]:
        """
        Make HTTP request with retry logic.

        Args:
            url: The URL to request
            method: HTTP method (GET, POST, etc.)
            **kwargs: Additional arguments to pass to httpx

        Returns:
            Tuple[bool, Any]: Success status and response or error message
        """

        for attempt in range(self.max_retries):
            try:
                with httpx.Client(timeout=self.timeout) as client:
                    if method.upper() == "GET":
                        response = client.get(url, **kwargs)
                    elif method.upper() == "POST":
                        response = client.post(url, **kwargs)
                    else:
                        return False, f"Unsupported HTTP method: {method}"

                    response.raise_for_status()
                    return True, response

            except httpx.HTTPStatusError as e:
                logger.warning(
                    f"HTTP error: {e} (Attempt {attempt+1}/{self.max_retries})"
                )
                if attempt + 1 < self.max_retries:
                    logger.info(f"Retrying in {self.retry_delay} seconds...")
                    time.sleep(self.retry_delay)
                else:
                    return False, f"Failed after {self.max_retries} attempts: {str(e)}"

            except httpx.RequestError as e:
                logger.warning(
                    f"Request error: {e} (Attempt {attempt+1}/{self.max_retries})"
                )
                if attempt + 1 < self.max_retries:
                    logger.info(f"Retrying in {self.retry_delay} seconds...")
                    time.sleep(self.retry_delay)
                else:
                    return (
                        False,
                        f"Connection error after {self.max_retries} attempts: {str(e)}",
                    )

    @abstractmethod
    def _do_fetch(self, target: str, work_dir: str) -> Tuple[bool, str]:
        """
        Perform the actual fetch operation.

        Args:
            target: The target to fetch (URL, address, etc.)
            work_dir: Directory to save fetched code

        Returns:
            Tuple[bool, str]: Success status and output path or error message
        """
        pass

    @abstractmethod
    def _parse_response(self, response: Any) -> Any:
        """
        Parse the response data into a usable format.

        Args:
            response: The response from the request

        Returns:
            Any: Parsed data
        """
        pass

    @abstractmethod
    def _save_result(self, data: Any, work_dir: str) -> str:
        """
        Save the fetched and parsed data to the work directory.

        Args:
            data: The data to save
            work_dir: Directory to save the data

        Returns:
            str: Path where the data was saved
        """
        pass

    def __str__(self) -> str:
        """String representation of the fetcher."""
        return f"{self.name.capitalize()}Fetcher"
