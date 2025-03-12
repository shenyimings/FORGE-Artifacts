import os
import re
import json
import os
import json
from loguru import logger
from core.models import ProjectInfo, FetchObject
from core.base import BaseFetcher
from fetcher.project_parser import GithubUrlParser
from typing import List
import git
from github import Github, Auth


class Router:
    def __init__(self, enabled_fetcher: list[str], fetch_mode: int):
        self.enabled_fetcher = enabled_fetcher
        self.fetch_mode = fetch_mode

    def fetch(self, targets: List[FetchObject], work_dir: str):
        if self.fetch_mode == 0:
            targets = [t for t in targets if t.fetcher_name == "github"]
        elif self.fetch_mode == 1:
            targets = [t for t in targets if t.fetcher_name != "github"]
        elif self.fetch_mode == 2:
            targets = targets

        all_failed = True
        messages = {}
        for target in targets:
            fetchers = self._get_fetcher(target.fetcher_name)
            if not fetchers:
                logger.error("Fetcher {} not found!", target.fetcher_name)
                continue
            for fetcher in fetchers:
                success, result = fetcher.fetch(target.target, work_dir)
                if not success:
                    logger.error(
                        "Failed to fetch {} from {}: {}",
                        target.target,
                        target.fetcher_name,
                        result,
                    )
                    continue
                if not result:
                    result = {}
                messages.update(result)
                all_failed = False
                break
        logger.debug("Fetch result: {}", messages)
        if all_failed:
            return {}
        return messages

    def _get_fetcher(self, fetcher_name: str) -> List[BaseFetcher]:
        if fetcher_name == "github":
            return [GithubFetcher()]
        elif fetcher_name == "eth":
            return [EthFetcher()]
        elif fetcher_name == "bsc":
            return [BscFetcher()]
        elif fetcher_name == "polygon":
            return [PolygonFetcher()]
        elif fetcher_name == "base":
            return [BasechainFetcher()]
        elif fetcher_name == "all":
            return [EthFetcher(), BscFetcher(), PolygonFetcher(), BasechainFetcher()]
        else:
            return None


class GithubFetcher(BaseFetcher):
    """
    Fetch source code from GitHub repositories
    """

    def __init__(self):
        super().__init__("github")
        self.github_token = os.getenv("GITHUB_TOKEN")
        self.g = None

    def _do_fetch(self, target: str, work_dir: str) -> tuple[bool, str]:
        """
        Fetch repository from GitHub

        Args:
            target: GitHub repository URL
            work_dir: Directory to save fetched code

        Returns:
            Tuple[bool, str]: Success status and output path or error message
        """
        # Parse the GitHub URL
        url_info = self._parse_url(target)
        if not url_info:
            return False, {}

        # Create output directory
        output_path = os.path.join(work_dir, url_info.repo)
        os.makedirs(output_path, exist_ok=True)

        # Clone the repository
        try:
            git.Repo.clone_from(url_info.git_url, output_path)

            # Checkout specific branch or commit if specified
            if url_info.branch:
                repo = git.Repo(output_path)
                repo.git.checkout(url_info.branch)

            metadata = {"contract_name": url_info.repo, "project_path": output_path}

            return True, metadata

        except Exception as e:
            # Clean up empty directory on failure
            if os.path.exists(output_path) and not os.listdir(output_path):
                os.rmdir(output_path)
            return False, {}

    def _parse_url(self, original_url: str):
        """
        Parse GitHub URL into components

        Args:
            original_url: GitHub repository URL

        Returns:
            GithubUrl object or None if parsing failed
        """
        try:
            url = GithubUrlParser(original_url)
            return url.info
        except Exception as e:
            logger.error(f"Failed to parse GitHub URL: {e}")
            return None

    def auth(self):
        """
        Authenticate with GitHub API using token

        Returns:
            Github object or None if authentication failed
        """
        if not self.github_token:
            logger.error("GitHub token not found in environment")
            return None

        try:
            auth = Auth.Token(self.github_token)
            self.g = Github(auth=auth)
            return self.g
        except Exception as e:
            logger.error(f"Failed to authenticate with GitHub: {e}")
            return None

    def _parse_response(self, response):
        return super()._parse_response(response)

    def _save_result(self, data, work_dir):
        return super()._save_result(data, work_dir)


class EthFetcher(BaseFetcher):
    def __init__(self, name="eth"):
        super().__init__(name)
        self.base_url = "https://api.etherscan.io/api"
        self.api_key = os.getenv("ETH_API_KEY")
        self.addr_parser = r"\b0x[a-fA-F0-9]{40}\b"

    def _do_fetch(self, target: str, work_dir: str) -> tuple[bool, str]:
        """
        Fetch contract source code from Ethereum blockchain

        Args:
            target: Contract address
            work_dir: Directory to save fetched code

        Returns:
            Tuple[bool, str]: Success status and output path or error message
        """

        # Validate address format
        if not re.match(self.addr_parser, target):
            logger.error(f"Invalid address format: {target}")
            return False, {}

        # Call Etherscan API
        success, response = self._request_with_retry(
            url=self.base_url,
            params={
                "module": "contract",
                "action": "getsourcecode",
                "address": target,
                "apikey": self.api_key,
            },
        )

        if not success:
            logger.error(f"Failed to fetch contract code for {target}")
            return False, {}

        # Parse API response
        data = self._parse_response(response.json())
        if not data:
            logger.error(f"Failed to parse contract code for {target}")
            return False, {}

        # Save the fetched contract files
        metadata = self._save_result(data, work_dir)
        return True, metadata

    def _parse_response(self, response):
        """
        Parse the response from Etherscan API

        Args:
            response: API response JSON

        Returns:
            dict: Parsed contract data or None if invalid
        """
        if not response.get("status") == "1" or not response.get("result"):
            return None

        data = response["result"]

        if (
            not isinstance(data, list)
            or len(data) == 0
            or not data[0].get("SourceCode")
        ):
            return None

        if len(data) > 1:
            logger.warning(f"Multiple contracts found for address, using first one")

        source_code = self._parse_code(data[0]["ContractName"], data[0]["SourceCode"])

        return {
            "chain": "eth",
            "contractName": data[0]["ContractName"],
            "compilerVersion": data[0]["CompilerVersion"],
            "sourceCode": source_code,
        }

    def _parse_code(self, contract_name: str, source_code: str) -> dict:
        """
        Parse source code strings that may contain multiple sol files

        Args:
            contract_name: Name of the contract
            source_code: Source code string from API

        Returns:
            dict: Map of filenames to content
        """
        result = {}

        # Try parse to JSON
        try:
            if source_code.startswith("{{"):
                source_code = source_code.strip()[1:-1]

            data = json.loads(source_code)

            if data.get("sources", False):
                result = data["sources"]
                return result
            else:
                result = data
                return result

        except json.JSONDecodeError:
            # If JSON parsing fails, treat as a single file
            result[contract_name + ".sol"] = {"content": source_code}
            return result

    def _save_result(self, data, work_dir):
        """
        Save the fetched contract files to disk

        Args:
            data: Parsed contract data
            work_dir: Directory to save files

        Returns:
            str: Partial project metadata
        """

        contract_name = data["contractName"] or "unknown"
        contract_dir = os.path.join(work_dir, contract_name)

        # Save source code files
        for sol_file, content in data["sourceCode"].items():
            if sol_file.split(".")[-1] != "sol":
                sol_file += ".sol"

            sol_file = sol_file.strip("/").strip("../")
            file_path = os.path.join(contract_dir, sol_file)

            # Create directories if needed
            os.makedirs(os.path.dirname(file_path), exist_ok=True)

            # Write source code file
            with open(file_path, "w", encoding="utf8") as f:
                f.write(content["content"])

        metadata = {
            "chain": data["chain"],
            "contract_name": data["contractName"],
            "compiler_version": data["compilerVersion"],
            "project_path": contract_dir,
        }

        return metadata


class BscFetcher(EthFetcher):
    def __init__(self):
        super().__init__("bsc")
        self.base_url = "https://api.bscscan.com/api"
        self.api_key = os.getenv("BSC_API_KEY")
        self.addr_parser = r"\b0x[a-fA-F0-9]{40}\b"


class PolygonFetcher(EthFetcher):
    def __init__(self):
        super().__init__("polygon")
        self.base_url = "https://api.polygonscan.com/api"
        self.api_key = os.getenv("POLYGON_API_KEY")
        self.addr_parser = r"\b0x[a-fA-F0-9]{40}\b"


class BasechainFetcher(EthFetcher):
    def __init__(self):
        super().__init__("base")
        self.base_url = "https://api.basescan.org/api"
        self.api_key = os.getenv("BASE_API_KEY")
        self.addr_parser = r"\b0x[a-fA-F0-9]{40}\b"
