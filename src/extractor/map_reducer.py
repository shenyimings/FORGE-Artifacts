import os
import re
import ell
import json
import yaml
import time
import tiktoken

from openai import OpenAI
from typing import List
from loguru import logger
from pydantic import BaseModel, TypeAdapter
from typing import Literal
from vendor.commentjson import commentjson
from core.models import MapReduceResult, Context
from core.invoker import invoke_map, invoke_reduce, MAX_RETRIES, INTERVAL, CONFIG

MODE: Literal["strict", "normal"] = CONFIG["extractor"]["mode"]


class MapReducer(BaseModel):

    class Config:
        arbitrary_types_allowed = True

    @logger.catch
    def map_reduce(self, documents: List[str], context_length: int) -> MapReduceResult:
        logger.info("{} mode active.", MODE)
        logger.info("Start Mapping...")
        context_list: List[Context] = self._map(documents)
        logger.info("Start Reducing...")
        return self._reduce(context_list, context_length)

    def _map(self, documents: List[str]) -> List[Context]:

        context_list: List[Context] = []
        total_length = 0
        for i in range(len(documents)):
            context = Context(index=i, document=documents[i], length=0)
            retry = 0
            while retry < MAX_RETRIES:
                try:
                    map_result = self._parse_answer(invoke_map(context.document))
                    context.response = map_result
                    length = self._calc_token_length(map_result)
                    context.length = length
                    total_length += length
                    context_list.append(context)
                    break  # Success, exit retry loop
                except Exception as e:
                    retry += 1
                    backoff_time = INTERVAL * retry  # Exponential backoff
                    logger.error(
                        "Error in mapping document {}: {}\nRetrying: {}/{} after {} seconds",
                        i,
                        str(e),
                        retry,
                        MAX_RETRIES,
                        backoff_time,
                    )
                    if retry < MAX_RETRIES:
                        time.sleep(backoff_time)
                    else:
                        logger.error(
                            "Max retries reached for document {}, skipping.", i
                        )
            if retry == MAX_RETRIES:
                # Add empty context if all retries failed to avoid skipping indices
                context.response = ""
                context.length = 0
                context_list.append(context)
        return context_list

    def _reduce(
        self, context_list: List[Context], context_length: int
    ) -> MapReduceResult:

        reduce_messages = []
        reduce_tokens = 0
        part_results: List[MapReduceResult] = []
        for context in context_list:

            if not reduce_messages:
                reduce_messages.append(
                    f"Fragment {context.index}:\n{context.response}\n"
                )
                reduce_tokens += context.length
                continue
            if reduce_tokens + context.length >= context_length:
                is_appended = False
                if context.length < context_length / 3:
                    reduce_messages.append(
                        f"Fragment {context.index}:\n{context.response}\n"
                    )
                    reduce_tokens += context.length
                    is_appended = True
                logger.info("Current token: {}, start reducing...", reduce_tokens)
                retry = 0
                resp_parsed = None
                while retry < MAX_RETRIES:
                    try:
                        resp = invoke_reduce("\n".join(reduce_messages))
                        resp_parsed = self._parse_json(resp, MapReduceResult)
                        if resp_parsed:
                            break  # Successfully parsed, exit retry loop
                        # If parsing returns None but didn't throw exception
                        retry += 1
                        if len(reduce_messages) > 1:
                            reduce_messages.pop(-1)
                        logger.warning(
                            "Failed to parse response (returned None). Retry: {}/{}",
                            retry,
                            MAX_RETRIES,
                        )
                    except Exception as e:
                        retry += 1
                        logger.error(
                            "Error in reducing or parsing: {}\nRetrying: {}/{}",
                            str(e),
                            retry,
                            MAX_RETRIES,
                        )
                        if retry == MAX_RETRIES:
                            logger.error("Max retries reached, moving on.")

                if resp_parsed:
                    part_results.append(resp_parsed)
                reduce_messages = []
                reduce_tokens = 0
                if not is_appended:
                    reduce_messages.append(
                        f"Fragment {context.index}:\n{context.response}\n"
                    )
                    reduce_tokens += context.length
                continue
            else:
                reduce_messages.append(
                    f"Fragment {context.index}:\n{context.response}\n"
                )
                reduce_tokens += context.length
                continue
        if reduce_messages:
            logger.info("Current token: {}, start reducing...", reduce_tokens)
            retry = 0
            resp_parsed = None
            while retry < MAX_RETRIES:
                try:
                    resp = invoke_reduce("\n".join(reduce_messages))
                    resp_parsed = self._parse_json(resp, MapReduceResult)
                    if resp_parsed:
                        break  # Successfully parsed, exit retry loop
                    # If parsing returns None but didn't throw exception
                    retry += 1
                    logger.warning(
                        "Failed to parse response (returned None). Retry: {}/{}",
                        retry,
                        MAX_RETRIES,
                    )
                except Exception as e:
                    retry += 1
                    logger.error(
                        "Error in reducing or parsing: {}\nRetrying: {}/{}",
                        str(e),
                        retry,
                        MAX_RETRIES,
                    )
                    if retry == MAX_RETRIES:
                        logger.error("Max retries reached, moving on.")

            if resp_parsed:
                part_results.append(resp_parsed)
        return self._merge_results(part_results)

    def _merge_results(self, partial: List[MapReduceResult]) -> MapReduceResult:
        result = MapReduceResult()
        index = 0
        for p in partial:
            # Merge project_info fields individually, keeping non-empty values
            url, commit_id, address, chain = (
                p.project_info.url,
                p.project_info.commit_id,
                p.project_info.address,
                p.project_info.chain,
            )
            # logger.debug(url, commit_id, address, chain)
            if result.project_info.url == "n/a" or not result.project_info.url:
                result.project_info.url = url
            if (
                result.project_info.commit_id == "n/a"
                or not result.project_info.commit_id
            ):
                result.project_info.commit_id = commit_id
            if result.project_info.address == "n/a" or not result.project_info.address:
                result.project_info.address = address
            if result.project_info.chain == "n/a" or not result.project_info.chain:
                result.project_info.chain = chain
            logger.debug("Project metadata merged results: {}", result.project_info)
            p.findings = [
                finding
                for finding in p.findings
                if finding.title != "n/a"
                and finding.description != "n/a"
                and finding.description != ""
                and finding.title != ""
            ]
            p.findings = [
                finding
                for finding in p.findings
                if finding.title != finding.description
            ]
            if MODE == "strict":

                p.findings = [
                    finding
                    for finding in p.findings
                    if finding.severity != "n/a"
                    and finding.location != "n/a"
                    and finding.severity != ""
                    and finding.location != ""
                ]
            for finding in p.findings:
                finding.id = index
                index += 1
            result.findings.extend(p.findings)
            logger.debug(f"Partial result:\n{p}")

        return result

    def _calc_token_length(self, text: str) -> int:
        enc = tiktoken.get_encoding("cl100k_base")
        return len(enc.encode(text))

    def _parse_answer(self, response: str) -> str:
        PATTERN = re.compile(
            r"Answer:\s*(.*)", re.IGNORECASE | re.DOTALL | re.MULTILINE
        )
        action_match = PATTERN.search(response)
        if action_match:
            if len(action_match.group(1).strip("\n")) > 3:
                return action_match.group(1)
            else:
                return response

        return response

    def _parse_json(self, response: str, schema: BaseModel) -> BaseModel:
        """Extract JSON structure from LLM response text."""

        PATTERN = re.compile(
            r"```(?:json\s+)?(\W.*?)```", re.IGNORECASE | re.DOTALL | re.MULTILINE
        )
        action_match = PATTERN.search(response)
        # MapReduceResult.
        try:
            if action_match:
                json_str = action_match.group(1)

                json_dict = commentjson.loads(json_str)
                # logger.debug(json_dict)
                return TypeAdapter(schema).validate_json(json.dumps(json_dict))
                # return RootModel[schema](schema).model_validate_json(json_str)
        except Exception as e:
            logger.error(e)
            return None
        return None

    # @ell.simple(model=MODEL, client=CLIENT, extra_body={"options": {"num_ctx": 8192}})
    # def _map_call(self, document: str):
    #     return [
    #         ell.system("You are Axiom, an AI expert in smart contract security."),
    #         ell.user(
    #             """You are given a document containing excerpts from various smart contract security artifacts such as audit reports or bug bounty disclosures. Your task is to extract all security vulnerabilities involved. Identify and extract the following details:\nVulnerability Title, Vulnerability Description (answer "n/a" if not provided), Severity Level (answer "n/a" if not provided), Location of Vulnerability (contract, function, etc.). \nPlease format the output clearly. Start your response with \"Answer: \" followed by the extracted details. If no relevant information is found, reply with \"Answer: None\"."""
    #         ),
    #         ell.assistant(
    #             "Yes, I understand. I am Axiom, and I will extract all relevant vulnerabilities information from the document fragment you provided."
    #         ),
    #         ell.user(f"Document fragment:\n{document}\n\n\n Please answer briefly."),
    #     ]

    # @ell.simple(model=MODEL, client=CLIENT, extra_body={"options": {"num_ctx": 8192}})
    # def _reduce_call(self, map_results: str):
    #     output_example = """```json\n{"findings": [{ "id": 0, "title": "Reentrancy in includeInReward() function", "description": "The function `includeInReward()` uses a loop to...", "severity": "Low", "location": "includeInReward()" }]}\n```"""
    #     return [
    #         ell.system("You are Axiom, an AI expert in smart contract security."),
    #         ell.user(
    #             'You are given a set of extracted vulnerability info from a smart contract audit report or bug bounty disclosure. These fragments include information about various vulnerabilities (potential duplicates or invalid entries may be present). Your task is to: \n1. Clean and deduplicate the extracted vulnerability data\n2. Generate a well-structured JSON output in the following format: \n{"findings": [ {"id":0, "title": "<Vulnerability title>", "description": "<Detailed description of the vulnerability>", "severity": "<Severity level (e.g., Low, Medium, High, Critical)>", "location": "<The contract or funtion or line where the vulnerability code is located or affected component>"},{"id": 1,...},... ] }.\n\n Use a null value "n/a" for missing fields or entries that could not be determined.'
    #         ),
    #         ell.assistant(
    #             "Yes, I understand. I am Axiom, and I will clean, deduplicate, and organize the extracted vulnerability data and source code details to generate a structured JSON output."
    #         ),
    #         ell.user(
    #             f"Extracted data:\n{map_results}\n\n\n Please Remember combine the fragments and output one well-structured JSON format like: {output_example}"
    #         ),
    #     ]


# map_reducer = MapReducer()

# test_document = """# Scope

# The code under review can be found within the [C4 Superposition repository](https://github.com/code-423n4/2024-08-superposition), and is composed of 26 smart contracts written in the Solidity programming language and includes 5248 lines of Solidity code.

# # Severity Criteria

# C4 assesses the severity of disclosed vulnerabilities based on three primary risk categories: high, medium, and low/non-critical.

# High-level considerations for vulnerabilities span the following key areas when conducting assessments:

# - Malicious Input Handling
# - Escalation of privileges
# - Arithmetic
# - Gas use

# For more information regarding the severity criteria referenced throughout the submission review process, please refer to the documentation provided on [the C4 website](https://code4rena.com), specifically our section on [Severity Categorization](https://docs.code4rena.com/awarding/judging-criteria/severity-categorization).

# # High Risk Findings (7)
# ## [[H-01] `update_emergency_council_7_D_0_C_1_C_58()` updates nft manager instead of emergency council](https://github.com/code-423n4/2024-08-superposition-findings/issues/162)
# *Submitted by [ABAIKUNANBAEV](https://github.com/code-423n4/2024-08-superposition-findings/issues/162), also found by [Q7](https://github.com/code-423n4/2024-08-superposition-findings/issues/153), [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/145), [ZanyBonzy](https://github.com/code-423n4/2024-08-superposition-findings/issues/137), [Rhaydden](https://github.com/code-423n4/2024-08-superposition-findings/issues/134), [Nikki](https://github.com/code-423n4/2024-08-superposition-findings/issues/132), [nslavchev](https://github.com/code-423n4/2024-08-superposition-findings/issues/128), [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/103), [eta](https://github.com/code-423n4/2024-08-superposition-findings/issues/89), [d4r3d3v1l](https://github.com/code-423n4/2024-08-superposition-findings/issues/78), [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/76), [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/64), [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/23), [wasm\_it](https://github.com/code-423n4/2024-08-superposition-findings/issues/11), and [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/7)*

# Inside of `lib.rs`, there is a function `update_emergency_council_7_D_0_C_1_C_58()` that is needed to update the emergency council that can disable the pools. However, in the current implementation, `nft_manager` is updated instead.
# """
# test_extracted_data = """**Vulnerabilities:**
# 1. **Vulnerability Title:** Debugging Code in Production
# **Vulnerability Description:** Debugging code is still present in the production environment, cluttering the codebase and potentially causing issues with the test suite.
# **Severity Level:** Low
# **Location of Vulnerability:** Various contracts in scope
# **Source Code Reference:** https://github.com/search?q=repo%3Acode-423n4%2F2024-08-superposition%20%23%5Bcfg(feature%20%3D%20%22testing-dbg%22)%5D&type=code
# 2. **Vulnerability Title:** Unused `calldata` in NFT Transfers
# **Vulnerability Description:** The `calldata` parameter is not used in `transferFrom` and `safeTransferFrom` functions, potentially causing issues with external integrations.
# **Severity Level:** Low
# **Location of Vulnerability:** `OwnershipNFTs.sol` (lines 148-157, 118-126)
# **Source Code Reference:** https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol
# 3. **Vulnerability Title:** Transfer to Self Allowed
# **Vulnerability Description:** The `transfer_position_E_E_C7_A3_C_D` function allows users to transfer tokens to themselves.
# **Severity Level:** Low
# **Location of Vulnerability:** `lib.rs` (lines 553-569)
# **Source Code Reference:** https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs
# 4. **Vulnerability Title:** Swapping Between Same Pools Allowed
# **Vulnerability Description:** The `swap_2_exact_in_41203_F1_D` function allows swapping between the same pools, potentially allowing malicious users to drain pool liquidity.
# **Severity Level:** Medium
# **Location of Vulnerability:** `lib.rs` (lines 327-336)
# **Source Code Reference:** https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src"""
# # resp = map_reducer.map_call(test_document)

# test_response = """
# Result:

# ```json
# {
#   "project_info": {
#     "url": "https://github.com/code-423n4/2024-08-superposition",
#     "address": "n/a",
#     "chain": "n/a"
#   },
#   "findings": [
#     {
#       "title": "[H-01] update_emergency_council_7_D_0_C_1_C_58() updates nft manager instead of emergency council",
#       "description": "The update_emergency_council_7_D_0_C_1_C_58() function in lib.rs updates nft_manager instead of the emergency council, which can lead to unintended consequences.",
#       "severity": "High",
#       "contract": "lib.rs",
#       "function": "update_emergency_council_7_D_0_C_1_C_58()",
#       "lineNumber": "n/a"
#     }
#   ]
# }
# ```
# """

# test_map_res = """              Now, I'll combine the cleaned vulnerability data and source code details
#               into a single JSON object:

#               ```json
#               {
#                   "project_info": {
#                       "url": "https://github.com/project/contracts",
#                       "address": "0x123456...",
#                       "chain": "eth"
#                   },
#                   "findings": [
#                       {
#                           "id": 0,
#                           "title": "Reentrancy",
#                           "description": "...",
#                           "severity": "High",
#                           "contract": "BankContract",
#                           "function": "withdraw",
#                           "lineNumber": 123
#                       },
#                       {
#                           "id": 1,
#                           "title": "Unprotected function",
#                           "description": "...",
#                           "severity": "Medium",
#                           "contract": "BankContract",
#                           "function": "approve",
#                           "lineNumber": 456
#                       },
#                       {
#                           "id": 2,
#                           "title": "Unused variable",
#                           "description": "...",
#                           "severity": "Low",
#                           "contract": "TokenContract",
#                           "function": "transfer",
#                           "lineNumber": 789
#                       }
#                   ]
#               }
#               ```

#               The resulting JSON object is clean, organized, and follows the specified
#               format."""

# mr = MapReducer()
# a = mr.parse_json(test_map_res, MapReduceResult)
# print(a)
# res = map_reducer.parse_json(test_response, MapReduceResult())
# doc_handler = DocumentHandler(
#     filepath="tests/test_cases/extractor/input/2024-08-superposition-findings.md"
# )

# doc_handler.read_file()
# documents = doc_handler.split_by_heading(2)
# fragments = doc_handler.merge_documents(2048, documents)

# result = map_reducer.map_reduce(fragments)
# print(result)

# res = map_reducer.reduce_call(test_extracted_data)
# print(res)

# mr = MapReducer()
# results = [
#     MapReduceResult(ProjectInfo(url="test"), [Finding(id=1)]),
#     MapReduceResult(ProjectInfo(url="test2"), [Finding(id=1, title="a"), Finding()]),
# ]
# res = mr.merge_results(results)
# print(res)

# test_str = """After cleaning and deduplicating the extracted vulnerability data and source code details, I generated a structured JSON output as follows:


#               ```
#               {
#                 "project_info": {
#                   "url": "https://github.com/BabyChickenOrg/Smart-Contract/",
#                   "commit_id": "ad7858625330b1ced0133118fc3d97287cdbeb7c",
#                   "address": "n/a",
#                   "chain": "n/a"
#                 },
#                 "findings": [
#                   {
#                     "id": 0,
#                     "title": "Out of gas",
#                     "description": "The functions use loops that can cause an OUT_OF_GAS exception if the excluded addresses list is too long.",
#                     "severity": "Low",
#                     "location": "Functions includeInReward() and _getCurrentSupply()"
#                   }
#                 ]
#               }
#               ```

#               Please let me know if this output meets your requirements or if you need
#               any further assistance!
# """

# mr = MapReducer()
# res = mr.parse_json(test_str, MapReduceResult)
# print(res)
