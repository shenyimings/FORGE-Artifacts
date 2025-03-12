from loguru import logger
from pydantic import BaseModel
from typing import List, Optional
from dataclasses import dataclass
from core.models import ProjectInfo, GithubUrl, FetchObject, Address
from urllib.parse import urlparse


class GithubUrlParser:
    def __init__(self, url: str):
        self.info = GithubUrl(href=url)
        self.parsed_url = urlparse(url)
        self._parse()

    def add_branch(self, commit_id: str):
        self.info.branch = commit_id
        self.info.proj = f"https://{self.parsed_url.netloc}/{self.info.owner}/{self.info.repo}/tree/{commit_id}"

    def _parse(self):
        if self.parsed_url.netloc not in ["github.com"]:
            return
        path = self.parsed_url.path
        fragment = self.parsed_url.fragment
        if path:
            path_parts = path.strip("/").split("/")
            if len(path_parts) >= 2:
                self.info.owner = path_parts[0]
                self.info.repo = path_parts[1]
                self.info.proj = f"https://{self.parsed_url.netloc}/{self.info.owner}/{self.info.repo}"
            if len(path_parts) >= 4:
                if path_parts[2] == "tree":
                    self.info.branch = path_parts[3]
                    self.info.dir_name = "/".join(path_parts[4:])
                elif path_parts[2] == "blob":
                    self.info.branch = path_parts[3]
                    self.info.file_name = "/".join(path_parts[4:])
                elif path_parts[2] == "commit":
                    self.info.branch = path_parts[3]
            if self.info.branch:
                self.info.proj = f"{self.info.proj}/tree/{self.info.branch}"

        if fragment:
            self.info.fragment = fragment
        self.info.git_url = (
            f"https://{self.parsed_url.netloc}/{self.info.owner}/{self.info.repo}"
        )


class ProjectParser:
    def __init__(self, enabled_fetcher: list[str]):
        self.enabled_fetcher = enabled_fetcher
        self.delimiters = [",", ";", " "]

    def parse(self, project_info: ProjectInfo) -> List[FetchObject]:
        """
        Parse ProjectInfo to generate a list of FetchObject.
        Handle various data types (str, int, List, None) for the fields.
        """
        logger.debug("Parsing project: {}", project_info)

        if project_info.is_empty():
            return []
        # Process URL, chain, and address fields
        url_list = self._process_field(project_info.url)
        commit_id_list = self._process_field(project_info.commit_id)
        chain_list = self._process_field(project_info.chain)
        address_list = self._process_field(project_info.address)

        # Create fetch objects based on the available data
        result = []

        # Handle GitHub URLs
        if url_list:
            for url in url_list:
                if not url or url == "n/a":
                    continue

                parser = GithubUrlParser(url)
                # logger.debug(commit_id_list)
                if not parser.info.branch and commit_id_list:
                    parser.add_branch(commit_id_list[0])

                fetcher_name = "github"
                if fetcher_name in self.enabled_fetcher:
                    result.append(
                        FetchObject(fetcher_name=fetcher_name, target=parser.info.proj)
                    )

        # Handle addresses
        if address_list:
            logger.debug("Processing addresses: {}", address_list)
            logger.debug("Processing chains: {}", chain_list)
            for i, address in enumerate(address_list):
                if not address or address == "n/a":
                    continue

                # Try to get corresponding chain or use first available one
                chain = ""
                if i < len(chain_list) and chain_list[i] and chain_list[i] != "n/a":
                    chain = chain_list[i]
                elif chain_list and chain_list[0] and chain_list[0] != "n/a":
                    chain = chain_list[0]

                fetcher_name = self._determine_address_fetcher(chain)
                if fetcher_name in self.enabled_fetcher:
                    # Format target as address:chain
                    target = address
                    result.append(FetchObject(fetcher_name=fetcher_name, target=target))

        return result

    def _process_field(self, field) -> List[str]:
        """
        Process a field from ProjectInfo to convert it to a list of strings.
        Handles various data types and attempts to split strings using delimiters.
        """
        if field is None or field == "n/a":
            return []

        # If already a list, use it directly
        if isinstance(field, list):
            return [str(item) for item in field if item is not None and item != "n/a"]

        # If dict, not currently handled (could be implemented based on needs)
        if isinstance(field, dict):
            return []

        # If string or int, try to split if string
        field_str = str(field)
        if field_str == "n/a":
            return []

        # Try to split using delimiters
        for delimiter in self.delimiters:
            if delimiter in field_str:
                parts = [part.strip() for part in field_str.split(delimiter)]
                return [part for part in parts if part and part != "n/a"]

        # If no delimiter found, return as single-element list
        return [field_str]

    def _determine_url_fetcher(self, url: str) -> str:
        """
        Determine the appropriate fetcher based on the URL.
        """
        if "github.com" in url.lower():
            return "github"
        elif "gitlab.com" in url.lower():
            return "gitlab"
        # Add more URL-based fetchers as needed
        return "url"  # Default fallback

    def _determine_address_fetcher(self, chain: str) -> str:
        """
        Determine the appropriate fetcher based on the blockchain.
        """
        chain_lower = chain.lower() if chain else ""

        if chain_lower in ["eth", "ethereum"]:
            return "eth"
        elif chain_lower in ["bsc", "binance"]:
            return "bsc"
        elif chain_lower in ["polygon", "matic"]:
            return "polygon"
        elif chain_lower in ["base"]:
            return "base"
        # Add more chain-specific fetchers as needed
        return "all"  # Default fallback
