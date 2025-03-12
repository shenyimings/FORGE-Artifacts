import os
import re
import sys
import ell
import yaml
import dotenv
from time import sleep
from loguru import logger
from typing import List, Dict
from collections import deque
from pydantic import BaseModel
from openai import OpenAI
import sys
from os import path

sys.path.append(path.dirname(path.dirname(path.abspath(__file__))))
from classifier.cwe_handler import CWE, CWEDatabase, CWEHandler
from core.invoker import invoke_classify, TIMEOUT, CONFIG, TEMPERATURE


# define an Exception class
class TruncateException(Exception):
    pass


# {"result":["CWE-284","CWE-664"]}
class Classifier(BaseModel):
    vuln_title: str
    vuln_description: str
    cwe_handler: CWEHandler
    level: int = 0
    top_k: int = 2
    node: List[CWE] = []
    node_count: int = 0
    result_tree: Dict[int, List[CWE]] = {}

    result: List[CWE] = []

    class Config:
        arbitrary_types_allowed: bool = True

    def classify(self, temperature=TEMPERATURE):
        self.top_k = 1 if self.level == 0 else 1
        cwe_info, vuln_info = self._get_prompt(self.node, self.top_k)
        result = invoke_classify(cwe_info, vuln_info)

        last_result = self.result
        self.result = self._parse_result(result)
        # print(self.result,last_result)
        if self.result == last_result:
            logger.info("No new result found, exiting.")
            return

        if self.result:
            self.result_tree[self.level + 1] = [
                "CWE-" + str(res.ID) for res in self.result
            ]
        # for i in self.result:
        choose = ", ".join(["CWE-" + str(i.ID) for i in self.result])
        logger.info("Choose: " + choose)

    def _parse_result(self, res: str) -> List[CWE]:
        # parse the str("CWE-xxx") to int("xxx")
        cwe_result_list: List[CWE] = []
        regex = re.compile(r"(?:\*\*)?Answer(?:\*\*)?:.*?(CWE-\d+)", re.IGNORECASE)
        # regex = re.compile(r"Answer:.*?(CWE-\d+)", re.IGNORECASE)
        handler = self.cwe_handler
        handler.regex = regex
        try:
            cwe_list = handler.cwe_from_string(res)
            if not cwe_list:
                logger.error("No CWE ID found in response.")
            if len(cwe_list) > 1:
                cwe_list = cwe_list[0]
            logger.info("CWE ID found: {}", str(cwe_list))
            cwe_result_list = cwe_list
            return cwe_result_list

        except KeyError:
            logger.error(f"Failed to parse CWE ID in {res}")

        return cwe_result_list

    def _get_prompt(
        self,
        cur_nodes: List[CWE] = [],
        top_k: int = 2,
    ) -> tuple:

        show_description = True if len(cur_nodes) <= 15 else False
        cwe_info = ""
        for node in cur_nodes:
            cwe_info = (
                cwe_info
                + "\n"
                + "CWE-"
                + str(node.ID)
                + ": "
                + node.Name
                + "\n\n"
                # + "\nDescription: "
                # + node.Description
            )
            if show_description:
                cwe_info += ": " + node.Description + "\n"
        vuln_info = (
            "\nTitle: "
            + self.vuln_title
            + "\nDescription: "
            + self.vuln_description
            + "\n"
        )
        # logger.debug(
        #     "Invoking for prompt: "
        #     + str(self.prompt_template.invoke({"vuln": vuln_info}))
        # )
        return (cwe_info, vuln_info)


class TotReasoner:
    @staticmethod
    def analyze(
        vuln_info: Dict[str, str],
        cwe_handler: CWEHandler,
    ) -> Dict[int, CWE]:
        classifier = Classifier(
            vuln_title=vuln_info["title"],
            vuln_description=vuln_info["description"],
            cwe_handler=cwe_handler,
        )

        def bfs_traverse(root: List[CWE]):
            if not root:
                return

            queue = deque(root)
            classifier.result = root
            classifier.level = 0
            classifier.node = root

            while queue:
                classifier.node_count = len(queue)
                logger.debug(
                    f"Level {classifier.level}, count {classifier.node_count}: "
                )
                # DONE: Add exception retry here

                max_retry_times = 3
                attempts = 0
                temperature = 0.2
                while attempts < max_retry_times:
                    try:
                        classifier.classify(temperature=temperature)
                        classifier.node = []
                        break
                    except KeyError as e:
                        temperature += 0.1
                        logger.error(
                            "TruncateException: No CWE ID found in answers, retrying..."
                        )
                        attempts += 1
                        continue
                    except Exception as e:
                        attempts += 1
                        temperature += 0.1
                        logger.error(
                            str(e)
                            + "\nError in classify "
                            + classifier.vuln_title
                            + "\n Retrying, times "
                            + str(attempts)
                        )

                classifier.node = []

                for _ in range(classifier.node_count):
                    node = queue.popleft()
                    if node not in classifier.result:
                        continue

                    if (
                        classifier.level != -100
                    ):  # Change to 0 to exclude first level nodes from second level
                        if (
                            node.Mapping == "Allowed"
                            or node.Mapping == "Allowed-with-Review"
                            or node.Mapping == "Discouraged"
                        ):
                            classifier.node.append(node)

                    for child in node.Child:
                        child_cwe = cwe_handler.cwe_dict.get_by_id(child)
                        classifier.node.append(child_cwe)
                        queue.append(child_cwe)

                next_level = ", ".join(
                    ["CWE-" + str(node.ID) for node in classifier.node]
                )
                logger.info(f"Next level: {next_level}\n")

                # logger.info("\n")
                classifier.level += 1

        cwe_dict = cwe_handler.cwe_dict.root
        initial_cwe_list = [
            cwe_dict["CWE-284"],
            cwe_dict["CWE-435"],
            cwe_dict["CWE-664"],
            cwe_dict["CWE-682"],
            cwe_dict["CWE-691"],
            cwe_dict["CWE-693"],
            cwe_dict["CWE-697"],
            cwe_dict["CWE-703"],
            cwe_dict["CWE-707"],
            cwe_dict["CWE-710"],
        ]
        bfs_traverse(initial_cwe_list)
        logger.debug(classifier.result_tree)
        # classifier.verify()
        return classifier.result_tree


@logger.catch
def test_reasoner():
    reasoner = TotReasoner()
    cwe_handler = CWEHandler()
    cwe_handler.load_dict("mapper/cwe_dict.json")
    test_case = {
        "title": "Out of gas in includeInReward() function",
        "description": "The function `includeInReward()` uses a loop to find and remove addresses from the `_excluded` list, which can cause an OUT_OF_GAS exception if the excluded addresses list is too long.",
    }
    reasoner.analyze(test_case, cwe_handler)


if __name__ == "__main__":
    test_reasoner()
